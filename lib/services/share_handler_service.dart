import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:uuid/uuid.dart';
import '../models/thought.dart';
import '../services/database_service.dart';
import '../services/exif_service.dart';
import '../services/link_preview_service.dart';
import '../services/llm_service.dart';
import '../services/ocr_service.dart';

class ShareHandlerService {
  static final _urlRegex = RegExp(r'https?://\S+');

  final DatabaseService _db = DatabaseService();
  final LinkPreviewService _linkPreview = LinkPreviewService();
  final LlmService _llm = LlmService();
  final OcrService _ocr = OcrService();
  final ExifService _exif = ExifService();
  final Uuid _uuid = const Uuid();

  StreamSubscription? _intentSub;
  void Function(Thought)? onThoughtSaved;

  final Set<String> _processedPaths = {};
  bool _initialMediaHandled = false;

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

  static const _mobileUserAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  static bool _isSocialMediaUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('instagram.com') ||
        host.contains('tiktok.com') ||
        host.contains('threads.net') ||
        host.contains('twitter.com') ||
        host.contains('x.com');
  }

  Future<Thought> _handleSharedLink(String url) async {
    final preview = await _linkPreview.fetchPreview(url);
    final now = DateTime.now();
    final isSocial = _isSocialMediaUrl(url);

    var thought = Thought(
      id: _uuid.v4(),
      type: ThoughtType.link,
      url: url,
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

    // For social media, download image in-memory, extract data, discard image
    if (isSocial) {
      _extractSocialMediaContent(thought, url, preview?.imageUrl);
    }

    return thought;
  }

  /// Downloads the social media post image (in-memory only), sends it to the
  /// LLM for deep content extraction, then stores the text data. No images
  /// are persisted to disk.
  Future<void> _extractSocialMediaContent(
    Thought thought,
    String postUrl,
    String? ogImageUrl,
  ) async {
    Uint8List? imageBytes;

    // Attempt 1: download the OG preview image with proper headers
    if (ogImageUrl != null) {
      imageBytes = await _downloadWithHeaders(ogImageUrl, postUrl);
    }

    // Attempt 2: fetch the post page HTML and extract a fresh image URL
    if (imageBytes == null) {
      final freshImageUrl = await _scrapeImageUrl(postUrl);
      if (freshImageUrl != null) {
        imageBytes = await _downloadWithHeaders(freshImageUrl, postUrl);
      }
    }

    if (imageBytes == null || imageBytes.length < 1000) {
      debugPrint('Could not download social media image for $postUrl');
      return;
    }

    // Send to LLM for deep extraction — image stays in memory only
    try {
      final result = await _llm.extractAndClassifyPost(thought, imageBytes);
      if (result == null) return;

      final category =
          categoryFromString(result['category'] as String? ?? 'other');
      final llmTags = (result['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final mergedTags = <String>{...thought.tags, ...llmTags}.toList();
      final markdown = result['markdown'] as String?;
      final title = result['title'] as String?;

      final updated = thought.copyWith(
        category: category,
        tags: mergedTags,
        llmSummary: markdown,
        extractedInfo: markdown,
        title: (title != null && title.isNotEmpty) ? title : thought.title,
        isClassified: true,
        updatedAt: DateTime.now(),
      );
      await _db.updateThought(updated);
      onThoughtSaved?.call(updated);
    } catch (e) {
      debugPrint('Social media extraction failed: $e');
    }
  }

  /// Downloads an image URL with browser-like headers to bypass CDN blocks.
  Future<Uint8List?> _downloadWithHeaders(
    String imageUrl,
    String refererUrl,
  ) async {
    final refererHost = Uri.tryParse(refererUrl);
    final referer =
        refererHost != null ? '${refererHost.scheme}://${refererHost.host}/' : '';

    try {
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': _mobileUserAgent,
          'Referer': referer,
          'Accept': 'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Sec-Fetch-Dest': 'image',
          'Sec-Fetch-Mode': 'no-cors',
          'Sec-Fetch-Site': 'cross-site',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 && response.bodyBytes.length > 1000) {
        debugPrint('Image downloaded: ${response.bodyBytes.length} bytes');
        return response.bodyBytes;
      }
      debugPrint('Image download HTTP ${response.statusCode}, '
          '${response.bodyBytes.length} bytes');
    } catch (e) {
      debugPrint('Image download error: $e');
    }
    return null;
  }

  /// Fetches the post page HTML and extracts the og:image URL directly.
  /// This gives a fresh CDN URL that hasn't expired yet.
  Future<String?> _scrapeImageUrl(String postUrl) async {
    try {
      final response = await http.get(
        Uri.parse(postUrl),
        headers: {
          'User-Agent': _mobileUserAgent,
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;

      // Parse og:image from HTML
      final ogImagePattern = RegExp(
        r'''<meta\s+[^>]*?(?:property|name)\s*=\s*["']og:image["'][^>]*?content\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      );
      final ogImagePatternAlt = RegExp(
        r'''<meta\s+[^>]*?content\s*=\s*["']([^"']+)["'][^>]*?(?:property|name)\s*=\s*["']og:image["']''',
        caseSensitive: false,
      );

      var match = ogImagePattern.firstMatch(response.body);
      match ??= ogImagePatternAlt.firstMatch(response.body);

      if (match != null) {
        var imgUrl = match.group(1)!;
        imgUrl = imgUrl.replaceAll('&amp;', '&');
        debugPrint('Scraped fresh og:image: ${imgUrl.substring(0, 80)}...');
        return imgUrl;
      }
    } catch (e) {
      debugPrint('Page scrape failed: $e');
    }
    return null;
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
      debugPrint('Video transcription failed: $e');
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
