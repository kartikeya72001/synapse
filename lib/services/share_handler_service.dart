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
import '../services/debug_logger.dart';
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
  String? _lastGraphqlCaption;

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
    _dbg.startSession('shared_link');
    _dbg.log('INPUT', 'Raw URL: $url');

    // Clean Instagram URLs: strip tracking params, keep shortcode path
    final cleanUrl = _cleanInstagramUrl(url);
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
    final isSocial = _isSocialMediaUrl(cleanUrl);
    _dbg.log('DETECT', 'isSocial=$isSocial isInstagram=${_isInstagramUrl(cleanUrl)}');

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

  /// Strips tracking parameters from Instagram URLs so the shortcode
  /// regex matches cleanly and the URL works for API calls.
  static String _cleanInstagramUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    if (!uri.host.contains('instagram.com')) return url;
    // Keep only the path (e.g. /p/SHORTCODE/) — drop query params
    return 'https://www.instagram.com${uri.path}';
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

    if (_isInstagramUrl(postUrl)) {
      _dbg.log('IG_FETCH', 'Starting Instagram image fetch for $postUrl');
      allImages = await _fetchInstagramImages(postUrl);
      _dbg.log('IG_FETCH', 'Instagram returned ${allImages.length} image(s)');
    }

    if (allImages.isEmpty && ogImageUrl != null) {
      _dbg.log('FALLBACK_OG', 'Trying OG image: $ogImageUrl');
      final bytes = await _downloadWithHeaders(ogImageUrl, postUrl);
      if (bytes != null) {
        allImages = [bytes];
        _dbg.log('FALLBACK_OG', 'Downloaded ${bytes.length} bytes');
      } else {
        _dbg.log('FALLBACK_OG', 'OG image download failed');
      }
    }

    if (allImages.isEmpty) {
      _dbg.log('FALLBACK_SCRAPE', 'Scraping page for og:image...');
      final freshUrl = await _scrapeOgImageUrl(postUrl);
      if (freshUrl != null) {
        _dbg.log('FALLBACK_SCRAPE', 'Found: $freshUrl');
        final bytes = await _downloadWithHeaders(freshUrl, postUrl);
        if (bytes != null) {
          allImages = [bytes];
          _dbg.log('FALLBACK_SCRAPE', 'Downloaded ${bytes.length} bytes');
        }
      } else {
        _dbg.log('FALLBACK_SCRAPE', 'No og:image found on page');
      }
    }

    if (allImages.isEmpty) {
      _dbg.log('RESULT', 'No images obtained — aborting extraction');
      _dbg.flush();
      return;
    }

    _dbg.log('RESULT', 'Total images for LLM: ${allImages.length} '
        '(sizes: ${allImages.map((b) => b.length).join(", ")} bytes)');

    // Enrich thought with GraphQL caption
    if (_lastGraphqlCaption != null && _lastGraphqlCaption!.isNotEmpty) {
      _dbg.log('CAPTION', 'GraphQL caption: '
          '${_lastGraphqlCaption!.substring(0, _lastGraphqlCaption!.length.clamp(0, 120))}...');
      final enrichedDesc = thought.description ?? '';
      if (!enrichedDesc.contains(_lastGraphqlCaption!)) {
        thought = thought.copyWith(
          description: _lastGraphqlCaption,
          updatedAt: DateTime.now(),
        );
        await _db.updateThought(thought);
      }
      _lastGraphqlCaption = null;
    }

    // Send to LLM
    try {
      _dbg.log('LLM', 'Sending ${allImages.length} image(s) to Gemini...');
      final result = allImages.length > 1
          ? await _llm.extractAndClassifyCarousel(thought, allImages)
          : await _llm.extractAndClassifyPost(thought, allImages.first);

      if (result == null) {
        _dbg.log('LLM', 'LLM returned null — error: ${_llm.lastError}');
        _dbg.flush();
        return;
      }

      _dbg.log('LLM', 'category=${result['category']} '
          'tags=${result['tags']} title="${result['title']}"');
      _dbg.log('LLM', 'Markdown length: ${(result['markdown'] as String?)?.length ?? 0}');

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
      _dbg.log('DONE', 'Thought updated successfully');
    } catch (e) {
      _dbg.logError('LLM', e);
    }
    _dbg.flush();
  }

  // ── Instagram shortcode extraction ──

  static final _shortcodeRegex = RegExp(
    r'instagram\.com/(?:p|reel|reels|tv)/([A-Za-z0-9_-]+)',
  );

  static String? _extractShortcode(String url) {
    return _shortcodeRegex.firstMatch(url)?.group(1);
  }

  // ── Instagram image fetcher ──

  static const _igGraphqlUrl = 'https://www.instagram.com/graphql/query/';
  static const _igAppId = '936619743392459';
  static const _igPostDocId = '8845758582119845';
  static const _igPostDocIdAlt = '10015901848480474';

  static const _desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  /// Multi-strategy Instagram image fetcher:
  /// 1. Cookie + GraphQL — replicates what incognito browsers do
  /// 2. HTML scraping for embedded carousel JSON (legacy fallback)
  /// 3. /media/?size=l — guaranteed cover image
  Future<List<Uint8List>> _fetchInstagramImages(String postUrl) async {
    final shortcode = _extractShortcode(postUrl);
    _dbg.log('SHORTCODE', 'URL=$postUrl → shortcode=$shortcode');
    if (shortcode == null) {
      _dbg.log('SHORTCODE', 'Could not extract shortcode — aborting');
      return [];
    }

    // Strategy 1: cookie-based GraphQL
    _dbg.log('STRATEGY_1', 'Trying cookie-based GraphQL...');
    final fromGraphql = await _fetchViaGraphql(shortcode, postUrl);
    if (fromGraphql.isNotEmpty) {
      _dbg.log('STRATEGY_1', 'GraphQL returned ${fromGraphql.length} image(s)');
      return fromGraphql;
    }
    _dbg.log('STRATEGY_1', 'GraphQL returned 0 images');

    // Strategy 2: HTML scraping
    _dbg.log('STRATEGY_2', 'Trying HTML carousel extraction...');
    final fromHtml = await _tryHtmlCarouselExtraction(postUrl);
    if (fromHtml.isNotEmpty) {
      _dbg.log('STRATEGY_2', 'HTML returned ${fromHtml.length} image(s)');
      return fromHtml;
    }
    _dbg.log('STRATEGY_2', 'HTML returned 0 images');

    // Strategy 3: /media/?size=l
    _dbg.log('STRATEGY_3', 'Trying /media/?size=l endpoint...');
    final coverBytes = await _fetchInstagramMediaEndpoint(shortcode);
    if (coverBytes != null) {
      _dbg.log('STRATEGY_3', 'Got cover image: ${coverBytes.length} bytes');
      return [coverBytes];
    }
    _dbg.log('STRATEGY_3', '/media/ endpoint failed');

    return [];
  }

  /// Two-pronged GraphQL approach:
  /// 1A. Try /api/graphql with doc_id 10015901848480474 + lsd token (no cookies needed)
  /// 1B. Try /graphql/query/ with doc_id 8845758582119845 + cookies (original approach)
  Future<List<Uint8List>> _fetchViaGraphql(
    String shortcode,
    String postUrl,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      // Step 1: Fetch the page to extract cookies AND lsd token
      final cleanPostUrl = 'https://www.instagram.com/p/$shortcode/';
      _dbg.log('GQL_STEP1', 'Fetching page: $cleanPostUrl');
      final pageReq = await client.getUrl(Uri.parse(cleanPostUrl));
      pageReq.headers.set('User-Agent', _desktopUserAgent);
      pageReq.headers.set('Accept', 'text/html,application/xhtml+xml');
      pageReq.headers.set('Accept-Language', 'en-US,en;q=0.9');
      pageReq.followRedirects = true;

      final pageResp = await pageReq.close().timeout(
        const Duration(seconds: 20),
      );

      // Read page body to extract lsd token
      final pageBody = await pageResp.transform(utf8.decoder).join();

      _dbg.log('GQL_STEP1', 'Page HTTP ${pageResp.statusCode}, '
          'body ${pageBody.length} chars');

      if (pageResp.statusCode != 200) {
        _dbg.log('GQL_STEP1', 'Non-200 — aborting');
        return [];
      }

      // Extract cookies
      final cookies = pageResp.cookies;
      String? csrfToken;
      for (final cookie in cookies) {
        if (cookie.name == 'csrftoken') csrfToken = cookie.value;
      }
      _dbg.log('GQL_COOKIES', '${cookies.length} cookie(s): '
          '${cookies.map((c) => '${c.name}=${c.value.substring(0, c.value.length.clamp(0, 8))}...').join(", ")}');

      // Extract lsd token from page HTML
      String? lsdToken;
      final lsdMatch = RegExp(r'"LSD",\[\],\{"token":"([^"]+)"').firstMatch(pageBody);
      if (lsdMatch != null) {
        lsdToken = lsdMatch.group(1);
      } else {
        final lsdMatch2 = RegExp(r'"lsd"[,:]+"([^"]+)"').firstMatch(pageBody);
        if (lsdMatch2 != null) lsdToken = lsdMatch2.group(1);
      }
      _dbg.log('GQL_LSD', 'lsd token: ${lsdToken != null ? "${lsdToken.substring(0, lsdToken.length.clamp(0, 8))}..." : "NOT FOUND"}');

      // ── Strategy 1A: /api/graphql with newer doc_id (no cookies needed) ──
      if (lsdToken != null) {
        _dbg.log('GQL_1A', 'Trying /api/graphql with doc_id=$_igPostDocIdAlt');
        final result = await _tryGraphqlEndpoint(
          client: client,
          endpoint: 'https://www.instagram.com/api/graphql',
          docId: _igPostDocIdAlt,
          shortcode: shortcode,
          lsdToken: lsdToken,
          csrfToken: csrfToken,
          cookies: cookies,
          postUrl: postUrl,
        );
        if (result.isNotEmpty) return result;
        _dbg.log('GQL_1A', 'Strategy 1A returned 0 images');
      }

      // ── Strategy 1B: /graphql/query/ with original doc_id + cookies ──
      if (csrfToken != null && csrfToken.isNotEmpty) {
        _dbg.log('GQL_1B', 'Trying /graphql/query/ with doc_id=$_igPostDocId');
        final result = await _tryGraphqlEndpoint(
          client: client,
          endpoint: _igGraphqlUrl,
          docId: _igPostDocId,
          shortcode: shortcode,
          lsdToken: lsdToken,
          csrfToken: csrfToken,
          cookies: cookies,
          postUrl: postUrl,
        );
        if (result.isNotEmpty) return result;
        _dbg.log('GQL_1B', 'Strategy 1B returned 0 images');
      }

      return [];
    } catch (e) {
      _dbg.logError('GQL', e);
      return [];
    } finally {
      client.close();
    }
  }

  /// Shared helper: POST to a GraphQL endpoint and parse the response.
  Future<List<Uint8List>> _tryGraphqlEndpoint({
    required HttpClient client,
    required String endpoint,
    required String docId,
    required String shortcode,
    required String? lsdToken,
    required String? csrfToken,
    required List<Cookie> cookies,
    required String postUrl,
  }) async {
    try {
      final variables = jsonEncode({
        'shortcode': shortcode,
        'fetch_tagged_user_count': null,
        'hoisted_comment_id': null,
        'hoisted_reply_id': null,
      });

      final bodyParts = <String>[
        'variables=${Uri.encodeComponent(variables)}',
        'doc_id=$docId',
      ];
      if (lsdToken != null) bodyParts.add('lsd=$lsdToken');
      final gqlBody = bodyParts.join('&');
      final gqlBodyBytes = utf8.encode(gqlBody);

      final gqlReq = await client.postUrl(Uri.parse(endpoint));
      gqlReq.headers.set('User-Agent', _desktopUserAgent);
      gqlReq.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      gqlReq.headers.set('X-IG-App-ID', _igAppId);
      gqlReq.headers.set('X-ASBD-ID', '129477');
      gqlReq.headers.set('Sec-Fetch-Site', 'same-origin');
      gqlReq.headers.set('Referer', 'https://www.instagram.com/p/$shortcode/');
      gqlReq.headers.set('Origin', 'https://www.instagram.com');
      gqlReq.headers.set('Accept', '*/*');

      if (lsdToken != null) {
        gqlReq.headers.set('X-FB-LSD', lsdToken);
      }
      if (csrfToken != null) {
        gqlReq.headers.set('X-CSRFToken', csrfToken);
        gqlReq.headers.set('X-Requested-With', 'XMLHttpRequest');
      }
      if (cookies.isNotEmpty) {
        gqlReq.headers.set('Cookie',
            cookies.map((c) => '${c.name}=${c.value}').join('; '));
      }

      gqlReq.contentLength = gqlBodyBytes.length;
      gqlReq.add(gqlBodyBytes);

      final gqlResp = await gqlReq.close().timeout(
        const Duration(seconds: 25),
      );
      final gqlRespBody = await gqlResp.transform(utf8.decoder).join();

      _dbg.log('GQL_RESP', 'HTTP ${gqlResp.statusCode}, ${gqlRespBody.length} chars');

      if (gqlResp.statusCode != 200) {
        _dbg.log('GQL_RESP', gqlRespBody.substring(
            0, gqlRespBody.length.clamp(0, 400)));
        return [];
      }

      return _parseGraphqlResponse(gqlRespBody, postUrl);
    } catch (e) {
      _dbg.logError('GQL_ENDPOINT', e);
      return [];
    }
  }

  /// Parses the GraphQL JSON for display_urls and downloads images.
  Future<List<Uint8List>> _parseGraphqlResponse(
    String responseBody,
    String postUrl,
  ) async {
    final gqlData = jsonDecode(responseBody) as Map<String, dynamic>;

    // Try both xdt_shortcode_media (newer) and shortcode_media (older)
    final media = (gqlData['data']?['xdt_shortcode_media']
        ?? gqlData['data']?['shortcode_media']) as Map<String, dynamic>?;

    if (media == null) {
      final dataKeys = gqlData['data']?.keys?.toList();
      _dbg.log('GQL_PARSE', 'No media in response. data keys: $dataKeys');
      return [];
    }

    _dbg.log('GQL_PARSE', 'Media type: ${media['__typename']}');

    final imageUrls = <String>[];

    // Carousel: edge_sidecar_to_children (GraphQL) or carousel_media (REST-like)
    final sidecar = media['edge_sidecar_to_children']?['edges'] as List?;
    final carouselMedia = media['carousel_media'] as List?;

    if (sidecar != null && sidecar.isNotEmpty) {
      for (final edge in sidecar) {
        final node = (edge is Map ? edge['node'] : edge) as Map<String, dynamic>?;
        if (node == null) continue;
        final displayUrl = node['display_url']?.toString();
        if (displayUrl != null && displayUrl.isNotEmpty) {
          imageUrls.add(displayUrl);
        }
      }
    } else if (carouselMedia != null && carouselMedia.isNotEmpty) {
      for (final item in carouselMedia) {
        final candidates = item['image_versions2']?['candidates'] as List?;
        if (candidates != null && candidates.isNotEmpty) {
          final best = candidates.first['url']?.toString();
          if (best != null && best.isNotEmpty) imageUrls.add(best);
        }
      }
    } else {
      final displayUrl = media['display_url']?.toString();
      if (displayUrl != null && displayUrl.isNotEmpty) {
        imageUrls.add(displayUrl);
      }
    }

    _dbg.log('GQL_PARSE', 'Found ${imageUrls.length} display_url(s)');
    if (imageUrls.isEmpty) return [];

    // Extract caption
    _lastGraphqlCaption = null;
    final captionEdges = media['edge_media_to_caption']?['edges'] as List?;
    if (captionEdges != null && captionEdges.isNotEmpty) {
      _lastGraphqlCaption = captionEdges[0]['node']?['text']?.toString();
    }
    // Also try REST-style caption
    _lastGraphqlCaption ??= media['caption']?['text']?.toString();

    _dbg.log('GQL_DL', 'Downloading ${imageUrls.length} image(s)...');
    final urls = imageUrls.take(10).toList();
    final futures = urls.map((url) => _downloadWithHeaders(url, postUrl));
    final results = await Future.wait(futures);

    final downloaded = results
        .where((b) => b != null && b.length > 1000)
        .cast<Uint8List>()
        .toList();
    _dbg.log('GQL_DL', '${downloaded.length}/${urls.length} images downloaded');
    return downloaded;
  }

  /// Fetches the public /media/?size=l endpoint which redirects to the CDN
  /// image for any public Instagram post. No auth required.
  Future<Uint8List?> _fetchInstagramMediaEndpoint(String shortcode) async {
    final url = 'https://www.instagram.com/p/$shortcode/media/?size=l';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _mobileUserAgent,
          'Accept': 'image/*,*/*;q=0.8',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 && response.bodyBytes.length > 1000) {
        return response.bodyBytes;
      }
      debugPrint('Instagram /media/ returned ${response.statusCode}, '
          '${response.bodyBytes.length} bytes');
    } catch (e) {
      debugPrint('Instagram /media/ fetch failed: $e');
    }
    return null;
  }

  /// Legacy: extract carousel URLs from embedded page JSON.
  Future<List<Uint8List>> _tryHtmlCarouselExtraction(String postUrl) async {
    try {
      final response = await http.get(
        Uri.parse(postUrl),
        headers: {
          'User-Agent': _mobileUserAgent,
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return [];

      final body = response.body;
      final mediaUrls = <String>[];

      _tryExtractSharedData(body, mediaUrls);
      _tryExtractAdditionalData(body, mediaUrls);
      _tryExtractJsonLd(body, mediaUrls);

      if (mediaUrls.isEmpty) {
        final ogUrl = _parseOgImage(body);
        if (ogUrl != null) mediaUrls.add(ogUrl);
      }

      if (mediaUrls.isEmpty) return [];

      debugPrint('Found ${mediaUrls.length} media URL(s) from page HTML');

      final urls = mediaUrls.take(10).toList();
      final futures = urls.map((url) => _downloadWithHeaders(url, postUrl));
      final results = await Future.wait(futures);

      return results
          .where((b) => b != null && b.length > 1000)
          .cast<Uint8List>()
          .toList();
    } catch (e) {
      debugPrint('HTML carousel extraction failed: $e');
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
