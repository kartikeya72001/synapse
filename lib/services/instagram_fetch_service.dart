import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'debug_logger.dart';
import '../utils/url_utils.dart' as url_utils;

/// Handles all Instagram-specific image/carousel fetching via multiple
/// strategies: GraphQL, HTML scraping, and the /media/ endpoint.
class InstagramFetchService {
  final _dbg = DebugLogger.instance;

  static const _igGraphqlUrl = 'https://www.instagram.com/graphql/query/';
  static const _igAppId = '936619743392459';
  static const _igPostDocId = '8845758582119845';
  static const _igPostDocIdAlt = '10015901848480474';

  static const _desktopUserAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  static final _shortcodeRegex = RegExp(
    r'instagram\.com/(?:p|reel|reels|tv)/([A-Za-z0-9_-]+)',
  );

  String? _lastGraphqlCaption;
  String? get lastGraphqlCaption => _lastGraphqlCaption;

  static String? extractShortcode(String url) {
    return _shortcodeRegex.firstMatch(url)?.group(1);
  }

  /// Multi-strategy Instagram image fetcher:
  /// 1. Cookie + GraphQL
  /// 2. HTML scraping for embedded carousel JSON
  /// 3. /media/?size=l — guaranteed cover image
  Future<List<Uint8List>> fetchImages(String postUrl) async {
    final shortcode = extractShortcode(postUrl);
    _dbg.log('IG', 'URL=$postUrl → shortcode=$shortcode');
    if (shortcode == null) {
      _dbg.log('IG', 'Could not extract shortcode — aborting');
      return [];
    }

    _dbg.log('IG', 'Strategy 1: cookie-based GraphQL');
    final fromGraphql = await _fetchViaGraphql(shortcode, postUrl);
    if (fromGraphql.isNotEmpty) {
      _dbg.log('IG', 'GraphQL → ${fromGraphql.length} image(s)');
      return fromGraphql;
    }

    _dbg.log('IG', 'Strategy 2: HTML carousel extraction');
    final fromHtml = await _tryHtmlCarouselExtraction(postUrl);
    if (fromHtml.isNotEmpty) {
      _dbg.log('IG', 'HTML → ${fromHtml.length} image(s)');
      return fromHtml;
    }

    _dbg.log('IG', 'Strategy 3: /media/?size=l');
    final coverBytes = await _fetchMediaEndpoint(shortcode);
    if (coverBytes != null) {
      _dbg.log('IG', '/media/ → ${coverBytes.length} bytes');
      return [coverBytes];
    }

    _dbg.log('IG', 'All strategies exhausted — 0 images');
    return [];
  }

  // ── GraphQL ──

  Future<List<Uint8List>> _fetchViaGraphql(
    String shortcode,
    String postUrl,
  ) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    try {
      final cleanPostUrl = 'https://www.instagram.com/p/$shortcode/';
      final pageReq = await client.getUrl(Uri.parse(cleanPostUrl));
      pageReq.headers.set('User-Agent', _desktopUserAgent);
      pageReq.headers.set('Accept', 'text/html,application/xhtml+xml');
      pageReq.headers.set('Accept-Language', 'en-US,en;q=0.9');
      pageReq.followRedirects = true;

      final pageResp = await pageReq.close().timeout(
        const Duration(seconds: 20),
      );
      final pageBody = await pageResp.transform(utf8.decoder).join();

      if (pageResp.statusCode != 200) {
        _dbg.log('GQL', 'Page HTTP ${pageResp.statusCode} — aborting');
        return [];
      }

      final cookies = pageResp.cookies;
      String? csrfToken;
      for (final cookie in cookies) {
        if (cookie.name == 'csrftoken') csrfToken = cookie.value;
      }

      String? lsdToken;
      final lsdMatch =
          RegExp(r'"LSD",\[\],\{"token":"([^"]+)"').firstMatch(pageBody);
      if (lsdMatch != null) {
        lsdToken = lsdMatch.group(1);
      } else {
        final lsdMatch2 =
            RegExp(r'"lsd"[,:]+"([^"]+)"').firstMatch(pageBody);
        if (lsdMatch2 != null) lsdToken = lsdMatch2.group(1);
      }

      // Strategy 1A: /api/graphql with newer doc_id
      if (lsdToken != null) {
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
      }

      // Strategy 1B: /graphql/query/ with original doc_id + cookies
      if (csrfToken != null && csrfToken.isNotEmpty) {
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
      }

      return [];
    } catch (e) {
      _dbg.logError('GQL', e);
      return [];
    } finally {
      client.close();
    }
  }

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
      gqlReq.headers.set(
          'Referer', 'https://www.instagram.com/p/$shortcode/');
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
        gqlReq.headers.set(
            'Cookie', cookies.map((c) => '${c.name}=${c.value}').join('; '));
      }

      gqlReq.contentLength = gqlBodyBytes.length;
      gqlReq.add(gqlBodyBytes);

      final gqlResp =
          await gqlReq.close().timeout(const Duration(seconds: 25));
      final gqlRespBody = await gqlResp.transform(utf8.decoder).join();

      if (gqlResp.statusCode != 200) {
        _dbg.log('GQL', 'HTTP ${gqlResp.statusCode} from $endpoint');
        return [];
      }

      return _parseGraphqlResponse(gqlRespBody, postUrl);
    } catch (e) {
      _dbg.logError('GQL', e);
      return [];
    }
  }

  Future<List<Uint8List>> _parseGraphqlResponse(
    String responseBody,
    String postUrl,
  ) async {
    final gqlData = jsonDecode(responseBody) as Map<String, dynamic>;

    final media = (gqlData['data']?['xdt_shortcode_media'] ??
        gqlData['data']?['shortcode_media']) as Map<String, dynamic>?;

    if (media == null) {
      _dbg.log('GQL', 'No media in response');
      return [];
    }

    final imageUrls = <String>[];

    final sidecar = media['edge_sidecar_to_children']?['edges'] as List?;
    final carouselMedia = media['carousel_media'] as List?;

    if (sidecar != null && sidecar.isNotEmpty) {
      for (final edge in sidecar) {
        final node =
            (edge is Map ? edge['node'] : edge) as Map<String, dynamic>?;
        if (node == null) continue;
        final displayUrl = node['display_url']?.toString();
        if (displayUrl != null && displayUrl.isNotEmpty) {
          imageUrls.add(displayUrl);
        }
      }
    } else if (carouselMedia != null && carouselMedia.isNotEmpty) {
      for (final item in carouselMedia) {
        final candidates =
            item['image_versions2']?['candidates'] as List?;
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

    _dbg.log('GQL', '${imageUrls.length} display_url(s) found');
    if (imageUrls.isEmpty) return [];

    _lastGraphqlCaption = null;
    final captionEdges =
        media['edge_media_to_caption']?['edges'] as List?;
    if (captionEdges != null && captionEdges.isNotEmpty) {
      _lastGraphqlCaption =
          captionEdges[0]['node']?['text']?.toString();
    }
    _lastGraphqlCaption ??= media['caption']?['text']?.toString();

    final urls = imageUrls.take(10).toList();
    final futures = urls.map((url) => downloadWithHeaders(url, postUrl));
    final results = await Future.wait(futures);

    return results
        .where((b) => b != null && b.length > 1000)
        .cast<Uint8List>()
        .toList();
  }

  // ── /media/ endpoint ──

  Future<Uint8List?> _fetchMediaEndpoint(String shortcode) async {
    final url = 'https://www.instagram.com/p/$shortcode/media/?size=l';
    try {
      return await url_utils.fetchUrlBytesIfOk(
        url,
        headers: {
          'User-Agent': url_utils.mobileUserAgent,
          'Accept': 'image/*,*/*;q=0.8',
        },
        timeout: const Duration(seconds: 20),
      );
    } catch (e) {
      _dbg.logError('IG_MEDIA', e);
    }
    return null;
  }

  // ── HTML scraping ──

  Future<List<Uint8List>> _tryHtmlCarouselExtraction(String postUrl) async {
    try {
      final response = await http.get(
        Uri.parse(postUrl),
        headers: {
          'User-Agent': url_utils.mobileUserAgent,
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
        final ogUrl = parseOgImage(body);
        if (ogUrl != null) mediaUrls.add(ogUrl);
      }

      if (mediaUrls.isEmpty) return [];

      final urls = mediaUrls.take(10).toList();
      final futures = urls.map((url) => downloadWithHeaders(url, postUrl));
      final results = await Future.wait(futures);

      return results
          .where((b) => b != null && b.length > 1000)
          .cast<Uint8List>()
          .toList();
    } catch (e) {
      _dbg.logError('HTML', e);
      return [];
    }
  }

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

  static void _extractMediaUrls(
    Map<String, dynamic> media,
    List<String> urls,
  ) {
    final sidecar = media['edge_sidecar_to_children']?['edges'];
    if (sidecar is List) {
      for (final edge in sidecar) {
        final node = edge['node'];
        if (node == null) continue;
        final url = node['display_url']?.toString();
        if (url != null && url.isNotEmpty && !urls.contains(url)) {
          urls.add(url);
        }
      }
    } else {
      final url = media['display_url']?.toString();
      if (url != null && url.isNotEmpty && !urls.contains(url)) {
        urls.add(url);
      }
    }
  }

  /// Parses og:image from raw HTML.
  static String? parseOgImage(String body) {
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

  // ── Download helper ──

  Future<Uint8List?> downloadWithHeaders(
    String imageUrl,
    String refererUrl,
  ) async {
    try {
      return await url_utils.fetchUrlBytesIfOk(
        imageUrl,
        headers: {
          'User-Agent': url_utils.mobileUserAgent,
          'Referer': url_utils.refererOriginFromUrl(refererUrl),
          'Accept':
              'image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9',
          'Sec-Fetch-Dest': 'image',
          'Sec-Fetch-Mode': 'no-cors',
          'Sec-Fetch-Site': 'cross-site',
        },
        timeout: const Duration(seconds: 20),
      );
    } catch (e) {
      _dbg.logError('DL', e);
    }
    return null;
  }

  /// Fetches og:image URL by scraping the post page HTML.
  Future<String?> scrapeOgImageUrl(String postUrl) async {
    try {
      final response = await http.get(
        Uri.parse(postUrl),
        headers: {
          'User-Agent': url_utils.mobileUserAgent,
          'Accept': 'text/html,application/xhtml+xml',
          'Accept-Language': 'en-US,en;q=0.9',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) return null;
      return parseOgImage(response.body);
    } catch (e) {
      _dbg.logError('SCRAPE', e);
    }
    return null;
  }
}
