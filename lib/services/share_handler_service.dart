import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';
import '../models/thought.dart';
import '../services/database_service.dart';
import '../services/debug_logger.dart';
import '../services/exif_service.dart';
import '../services/link_preview_service.dart';
import '../services/llm_service.dart';
import '../services/instagram_fetch_service.dart';
import '../services/ocr_service.dart';
import '../utils/url_utils.dart' as url_utils;
import '../utils/thought_mapper.dart';

class ShareHandlerService {
  static final _urlRegex = RegExp(r'https?://\S+');

  final DatabaseService _db = DatabaseService();
  final LinkPreviewService _linkPreview = LinkPreviewService();
  final LlmService _llm = LlmService();
  final OcrService _ocr = OcrService();
  final ExifService _exif = ExifService();
  final InstagramFetchService _instagram = InstagramFetchService();
  final Uuid _uuid = const Uuid();

  StreamSubscription? _intentSub;
  void Function(Thought)? onThoughtSaved;

  final Set<String> _processedPaths = {};
  bool _initialMediaHandled = false;

  final Set<String> _wiringInProgress = {};

  /// Returns true if async carousel wiring is still running for this thought.
  bool isWiringInProgress(String thoughtId) => _wiringInProgress.contains(thoughtId);

  DebugLogger get _dbg => DebugLogger.instance;

  void init() {
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedFiles,
      onError: (_) {},
    );

    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (!_initialMediaHandled && files.isNotEmpty) {
        _initialMediaHandled = true;
        _handleSharedFiles(files);
      }
    });
  }

  void dispose() {
    _intentSub?.cancel();
    _ocr.dispose();
  }

  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    final uniqueFiles = <SharedMediaFile>[];
    for (final file in files) {
      final key = file.path;
      if (!_processedPaths.contains(key)) {
        _processedPaths.add(key);
        uniqueFiles.add(file);
      }
    }

    for (final file in uniqueFiles) {
      if (file.type == SharedMediaType.url ||
          (file.type == SharedMediaType.text && _isUrl(file.path))) {
        await _handleSharedLink(file.path);
      } else if (file.type == SharedMediaType.video) {
        await _handleSharedVideo(file.path);
      } else if (file.type == SharedMediaType.image) {
        await _handleSharedImage(file.path);
      } else if (file.type == SharedMediaType.text) {
        final text = file.path;
        if (_containsUrl(text)) {
          final url = _extractUrl(text);
          if (url != null) {
            await _handleSharedLink(url);
          } else {
            await _handleSharedText(text);
          }
        } else {
          await _handleSharedText(text);
        }
      }
    }
  }


  Future<Thought> _handleSharedLink(String url) async {
    _dbg.startSession('shared_link');
    _dbg.log('INPUT', 'Raw URL: $url');

    // Clean Instagram URLs: strip tracking params, keep shortcode path
    final cleanUrl = url_utils.cleanInstagramUrl(url);
    if (cleanUrl != url) {
      _dbg.log('CLEAN', 'Cleaned URL: $cleanUrl');
    }

    _dbg.log('PREVIEW', 'Fetching link preview...');
    final preview = await _linkPreview.fetchPreview(cleanUrl);
    final previewDesc = preview?.description;
    final previewSnippet = previewDesc != null
        ? previewDesc.substring(0, previewDesc.length.clamp(0, 80))
        : '';
    _dbg.log('PREVIEW', 'title="${preview?.title}" '
        'desc="$previewSnippet" '
        'image=${preview?.imageUrl != null ? "yes" : "no"} '
        'site=${preview?.siteName}');

    final now = DateTime.now();
    final isSocial = url_utils.isSocialMediaUrl(cleanUrl);
    _dbg.log('DETECT', 'isSocial=$isSocial isInstagram=${url_utils.isInstagramUrl(cleanUrl)}');

    var thought = Thought(
      id: _uuid.v4(),
      type: ThoughtType.link,
      url: cleanUrl,
      title: preview?.title,
      description: preview?.description,
      previewImageUrl: preview?.imageUrl,
      siteName: preview?.siteName,
      favicon: preview?.favicon,
      tags: isSocial ? const ['social-media'] : const ['link'],
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertThought(thought);
    onThoughtSaved?.call(thought);
    _dbg.log('DB', 'Thought saved id=${thought.id}');

    if (isSocial) {
      _dbg.log('SOCIAL', 'Starting social media extraction...');
      _extractSocialMediaContent(thought, cleanUrl, preview?.imageUrl);
    } else {
      _dbg.log('DONE', 'Non-social link — no image extraction needed');
      _dbg.flush();
    }

    return thought;
  }


  /// Public accessor for carousel images — used by classifyThought retry path.
  Future<List<Uint8List>> fetchCarouselImages(String postUrl) async {
    if (url_utils.isInstagramUrl(postUrl)) {
      return _instagram.fetchImages(postUrl);
    }
    return [];
  }

  // ── Main social media extraction entry point ──

  Future<void> _extractSocialMediaContent(
    Thought thought,
    String postUrl,
    String? ogImageUrl,
  ) async {
    _wiringInProgress.add(thought.id);
    _dbg.log('WIRE', '═══ START extraction for ${thought.id} ═══');
    try {
      List<Uint8List> allImages = [];

      if (url_utils.isInstagramUrl(postUrl)) {
        allImages = await _instagram.fetchImages(postUrl);
        _dbg.log('WIRE', 'Instagram → ${allImages.length} image(s)');
      }

      if (allImages.isEmpty && ogImageUrl != null) {
        final bytes = await _instagram.downloadWithHeaders(ogImageUrl, postUrl);
        if (bytes != null) allImages = [bytes];
      }

      if (allImages.isEmpty) {
        final freshUrl = await _instagram.scrapeOgImageUrl(postUrl);
        if (freshUrl != null) {
          final bytes = await _instagram.downloadWithHeaders(freshUrl, postUrl);
          if (bytes != null) allImages = [bytes];
        }
      }

      if (allImages.isEmpty) {
        _dbg.log('WIRE', 'No images obtained — aborting');
        return;
      }

      final caption = _instagram.lastGraphqlCaption;
      if (caption != null && caption.isNotEmpty) {
        final enrichedDesc = thought.description ?? '';
        if (!enrichedDesc.contains(caption)) {
          thought = thought.copyWith(
            description: caption,
            updatedAt: DateTime.now(),
          );
          await _db.updateThought(thought);
        }
      }

      _dbg.log('WIRE', 'Sending ${allImages.length} image(s) to LLM...');
      final result = allImages.length > 1
          ? await _llm.extractAndClassifyCarousel(thought, allImages)
          : await _llm.extractAndClassifyPost(thought, allImages.first);

      if (result == null) {
        _dbg.log('WIRE', 'LLM returned null — ${_llm.lastError}');
        return;
      }

      final updated = applyClassificationResult(thought, result);
      await _db.updateThought(updated);
      onThoughtSaved?.call(updated);
      _dbg.log('WIRE', 'Wired — isClassified=${updated.isClassified}');
    } catch (e) {
      _dbg.logError('WIRE', e);
    } finally {
      _wiringInProgress.remove(thought.id);
      _dbg.log('WIRE', '═══ END extraction for ${thought.id} ═══');
      _dbg.flush();
    }
  }


  Future<Thought> _handleSharedImage(String filePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory(p.join(appDir.path, 'screenshots'));
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '${_uuid.v4()}.png';
    final newPath = p.join(imagesDir.path, fileName);
    await File(filePath).copy(newPath);

    // Use the source file's modified date for proper chronological ordering
    final sourceFile = File(filePath);
    DateTime fileDate;
    try {
      fileDate = await sourceFile.lastModified();
    } catch (_) {
      fileDate = DateTime.now();
    }
    final now = DateTime.now();

    var thought = Thought(
      id: _uuid.v4(),
      type: ThoughtType.screenshot,
      imagePath: newPath,
      title: 'Screenshot',
      tags: const ['screenshot'],
      createdAt: fileDate,
      updatedAt: now,
    );

    await _db.insertThought(thought);
    onThoughtSaved?.call(thought);

    // Background OCR + EXIF extraction — only notify once at the end
    String? ocrText;
    String? exifUrl;

    try {
      ocrText = await _ocr.extractText(newPath);
    } catch (_) {}

    try {
      exifUrl = await _exif.extractUrlFromImage(filePath);
    } catch (_) {}

    String? url = exifUrl;
    if (url == null && ocrText != null && ocrText.isNotEmpty) {
      final match = _urlRegex.firstMatch(ocrText);
      url = match?.group(0);
    }

    if (ocrText != null || url != null) {
      thought = thought.copyWith(
        ocrText: ocrText ?? thought.ocrText,
        url: url ?? thought.url,
        updatedAt: DateTime.now(),
      );
      await _db.updateThought(thought);
    }

    return thought;
  }

  Future<Thought> _handleSharedVideo(String filePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final videosDir = Directory(p.join(appDir.path, 'videos'));
    if (!await videosDir.exists()) {
      await videosDir.create(recursive: true);
    }

    final ext = p.extension(filePath).isNotEmpty ? p.extension(filePath) : '.mp4';
    final fileName = '${_uuid.v4()}$ext';
    final newPath = p.join(videosDir.path, fileName);
    await File(filePath).copy(newPath);

    DateTime fileDate;
    try {
      fileDate = await File(filePath).lastModified();
    } catch (_) {
      fileDate = DateTime.now();
    }
    final now = DateTime.now();

    var thought = Thought(
      id: _uuid.v4(),
      type: ThoughtType.screenshot,
      imagePath: newPath,
      title: 'Shared Video',
      tags: const ['video'],
      createdAt: fileDate,
      updatedAt: now,
    );

    await _db.insertThought(thought);
    onThoughtSaved?.call(thought);

    // Background transcription via Gemini
    _transcribeVideoInBackground(thought, newPath);

    return thought;
  }

  Future<void> _transcribeVideoInBackground(
    Thought thought,
    String videoPath,
  ) async {
    try {
      final transcript = await _llm.transcribeMedia(videoPath);
      if (transcript != null && transcript.isNotEmpty) {
        final updated = thought.copyWith(
          description: transcript,
          extractedInfo: transcript,
          updatedAt: DateTime.now(),
        );
        await _db.updateThought(updated);
        onThoughtSaved?.call(updated);
      }
    } catch (e) {
      _dbg.logError('VIDEO', e);
    }
  }

  Future<Thought> saveVideo(String filePath) async {
    return _handleSharedVideo(filePath);
  }

  Future<Thought> _handleSharedText(String text) async {
    final now = DateTime.now();
    final thought = Thought(
      id: _uuid.v4(),
      type: ThoughtType.link,
      title: text.length > 100 ? '${text.substring(0, 100)}...' : text,
      description: text,
      tags: const ['link'],
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertThought(thought);
    onThoughtSaved?.call(thought);
    return thought;
  }

  Future<Thought> saveLink(String url) async {
    return _handleSharedLink(url);
  }

  Future<Thought> saveImage(String filePath) async {
    return _handleSharedImage(filePath);
  }

  /// Import an image by path, skip if a screenshot with the same file size already exists.
  Future<Thought?> importImageIfNew(String filePath) async {
    final sourceFile = File(filePath);
    if (!await sourceFile.exists()) return null;
    final sourceSize = await sourceFile.length();

    final existing = await _db.getAllThoughts();
    for (final t in existing) {
      if (t.type != ThoughtType.screenshot || t.imagePath == null) continue;
      try {
        final existingFile = File(t.imagePath!);
        if (await existingFile.exists()) {
          final existingSize = await existingFile.length();
          if (existingSize == sourceSize) return null;
        }
      } catch (_) {}
    }
    return _handleSharedImage(filePath);
  }

  Future<Thought?> refetchPreview(Thought thought) async {
    if (thought.url == null || thought.url!.isEmpty) return null;
    try {
      final cleanUrl = url_utils.cleanInstagramUrl(thought.url!);
      final preview = await _linkPreview.fetchPreview(cleanUrl);
      if (preview == null) return null;

      final updated = thought.copyWith(
        previewImageUrl: preview.imageUrl,
        siteName: preview.siteName ?? thought.siteName,
        favicon: preview.favicon ?? thought.favicon,
        title: thought.title ?? preview.title,
        description: thought.description ?? preview.description,
      );
      await _db.insertThought(updated);
      return updated;
    } catch (e) {
      _dbg.log('REFETCH', 'Failed for ${thought.url}: $e');
      return null;
    }
  }

  bool _isUrl(String text) {
    final trimmed = text.trim();
    return Uri.tryParse(trimmed)?.hasScheme ?? false;
  }

  bool _containsUrl(String text) {
    return _urlRegex.hasMatch(text);
  }

  String? _extractUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    return match?.group(0);
  }
}
