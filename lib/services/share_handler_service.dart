import 'dart:async';
import 'dart:convert';
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

  // ── Instagram detection ──

  static bool _isInstagramUrl(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return host.contains('instagram.com');
  }

  // ── Main social media extraction entry point ──

  Future<void> _extractSocialMediaContent(
    Thought thought,
    String postUrl,
    String? ogImageUrl,
  ) async {
    List<Uint8List> allImages = [];

    // For Instagram, try to get ALL carousel images
    if (_isInstagramUrl(postUrl)) {
      allImages = await _fetchInstagramImages(postUrl);
    }

    // Fallback: single OG image
    if (allImages.isEmpty && ogImageUrl != null) {
      final bytes = await _downloadWithHeaders(ogImageUrl, postUrl);
      if (bytes != null) allImages = [bytes];
    }

    // Fallback: scrape page for og:image
    if (allImages.isEmpty) {
      final freshUrl = await _scrapeOgImageUrl(postUrl);
      if (freshUrl != null) {
        final bytes = await _downloadWithHeaders(freshUrl, postUrl);
        if (bytes != null) allImages = [bytes];
      }
    }

    if (allImages.isEmpty) {
      debugPrint('No images found for $postUrl');
      return;
    }

    debugPrint('Got ${allImages.length} image(s) for $postUrl');

    // Send to LLM — multi-image if carousel, single if not
    try {
      final result = allImages.length > 1
          ? await _llm.extractAndClassifyCarousel(thought, allImages)
          : await _llm.extractAndClassifyPost(thought, allImages.first);
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

  // ── Instagram carousel fetcher (ported from Intagram_data_gen) ──

  /// Fetches the Instagram post page HTML, parses embedded JSON blobs
  /// for carousel data, and downloads all image URLs in-memory.
  Future<List<Uint8List>> _fetchInstagramImages(String postUrl) async {
    try {
      final response = await http.get(
        Uri.parse(postUrl),
        headers: {
          'User-Agent': _mobileUserAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Accept-Encoding': 'gzip, deflate',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final body = response.body;
      final mediaUrls = <String>[];

      // Strategy 1: window._sharedData embedded JSON
      _tryExtractSharedData(body, mediaUrls);

      // Strategy 2: window.__additionalDataLoaded embedded JSON
      _tryExtractAdditionalData(body, mediaUrls);

      // Strategy 3: JSON-LD contentUrl
      _tryExtractJsonLd(body, mediaUrls);

      // Strategy 4: fall back to og:image if nothing found
      if (mediaUrls.isEmpty) {
        final ogUrl = _parseOgImage(body);
        if (ogUrl != null) mediaUrls.add(ogUrl);
      }

      if (mediaUrls.isEmpty) return [];

      debugPrint('Found ${mediaUrls.length} media URL(s) from page HTML');

      // Download all images in parallel (in-memory, cap at 10)
      final urls = mediaUrls.take(10).toList();
      final futures = urls.map((url) => _downloadWithHeaders(url, postUrl));
      final results = await Future.wait(futures);

      return results
          .where((b) => b != null && b.length > 1000)
          .cast<Uint8List>()
          .toList();
    } catch (e) {
      debugPrint('Instagram carousel fetch failed: $e');
      return [];
    }
  }

  /// Parses window._sharedData for shortcode_media with carousel edges.
  static void _tryExtractSharedData(String body, List<String> urls) {
    final match = RegExp(
      r'window\._sharedData\s*=\s*(\{.+?\});\s*$',
      multiLine: true,
    ).firstMatch(body);
    if (match == null) return;

    try {
      final data = jsonDecode(match.group(1)!);
      final postPage = data['entry_data']?['PostPage'];
      if (postPage is List && postPage.isNotEmpty) {
        final media = postPage[0]['graphql']?['shortcode_media'] ??
            postPage[0]['media'];
        if (media != null) _extractMediaUrls(media, urls);
      }
    } catch (_) {}
  }

  /// Parses window.__additionalDataLoaded for shortcode_media.
  static void _tryExtractAdditionalData(String body, List<String> urls) {
    final match = RegExp(
      r"""window\.__additionalDataLoaded\s*\(\s*['"].*?['"]\s*,\s*(\{.+?\})\s*\)""",
      dotAll: true,
    ).firstMatch(body);
    if (match == null) return;

    try {
      final data = jsonDecode(match.group(1)!);
      final media = data['graphql']?['shortcode_media'] ?? data['media'];
      if (media != null) _extractMediaUrls(media, urls);
    } catch (_) {}
  }

  /// Parses JSON-LD for contentUrl (image/video).
  static void _tryExtractJsonLd(String body, List<String> urls) {
    final ldRegex = RegExp(
      r"""<script\s+type\s*=\s*["']application/ld\+json["']\s*>([\s\S]*?)</script>""",
      caseSensitive: false,
    );
    for (final match in ldRegex.allMatches(body)) {
      try {
        final data = jsonDecode(match.group(1)!);
        if (data is Map<String, dynamic>) {
          final contentUrl = data['contentUrl']?.toString();
          if (contentUrl != null && !urls.contains(contentUrl)) {
            urls.add(contentUrl);
          }
          final imageObj = data['image'];
          if (imageObj is String && !urls.contains(imageObj)) {
            urls.add(imageObj);
          }
        }
      } catch (_) {}
    }
  }

  /// Extracts all image/video display_url from GraphQL shortcode_media,
  /// including carousel children from edge_sidecar_to_children.
  static void _extractMediaUrls(
    Map<String, dynamic> media,
    List<String> urls,
  ) {
    final sidecar = media['edge_sidecar_to_children']?['edges'];
    if (sidecar is List) {
      for (final edge in sidecar) {
        final node = edge['node'];
        if (node == null) continue;
        final isVideo = node['is_video'] == true;
        // For images: display_url. For videos: use display_url (thumbnail).
        // We want visual frames for OCR, not video streams.
        final url = node['display_url']?.toString();
        if (url != null && url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
        // If it's a video, also grab video_url for potential transcription
        if (isVideo) {
          final videoUrl = node['video_url']?.toString();
          if (videoUrl != null && !urls.contains(videoUrl)) {
            // Skip video URLs for now — we're doing image OCR
          }
        }
      }
    } else {
      // Single image/video post
      final url = media['display_url']?.toString();
      if (url != null && url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
  }

  /// Parses og:image from raw HTML.
  static String? _parseOgImage(String body) {
    final patterns = [
      RegExp(
        r'''<meta\s+[^>]*?property\s*=\s*["']og:image["'][^>]*?content\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ),
      RegExp(
        r'''<meta\s+[^>]*?content\s*=\s*["']([^"']+)["'][^>]*?property\s*=\s*["']og:image["']''',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) {
        return match.group(1)!.replaceAll('&amp;', '&');
      }
    }
    return null;
  }

  // ── Image download helper ──

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
  Future<String?> _scrapeOgImageUrl(String postUrl) async {
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
      return _parseOgImage(response.body);
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
