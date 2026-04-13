import 'dart:convert';
import 'package:http/http.dart' as http;
import 'debug_logger.dart';

class TwitterFetchResult {
  final String? tweetText;
  final String? authorName;
  final String? authorHandle;
  final List<String> imageUrls;
  final String? publishDate;

  TwitterFetchResult({
    this.tweetText,
    this.authorName,
    this.authorHandle,
    this.imageUrls = const [],
    this.publishDate,
  });
}

class TwitterFetchService {
  final _dbg = DebugLogger.instance;

  static const _userAgent =
      'Mozilla/5.0 (compatible; Synapse/1.0; +https://synapse.app)';

  Future<TwitterFetchResult?> fetchTweetDetails(String url) async {
    try {
      _dbg.log('TW', 'Fetching tweet: $url');

      final normalizedUrl = url
          .replaceFirst('x.com', 'twitter.com')
          .replaceFirst('//mobile.', '//');

      // Try vxtwitter (public proxy that returns JSON without auth)
      final vxUrl = normalizedUrl.replaceFirst(
          'twitter.com', 'api.vxtwitter.com');
      try {
        final vxResponse = await http.get(
          Uri.parse(vxUrl),
          headers: {'User-Agent': _userAgent},
        ).timeout(const Duration(seconds: 10));

        if (vxResponse.statusCode == 200) {
          final result = _parseVxResponse(vxResponse.body);
          if (result != null) return result;
        }
      } catch (_) {}

      // Fallback: scrape OG meta from original URL
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _dbg.log('TW', 'HTTP ${response.statusCode}');
        return null;
      }

      return _parseFromHtml(response.body);
    } catch (e) {
      _dbg.log('TW', 'Error: $e');
      return null;
    }
  }

  TwitterFetchResult? _parseVxResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;

      final images = <String>[];
      if (json['media_extended'] is List) {
        for (final m in json['media_extended'] as List) {
          if (m is Map && m['type'] == 'image') {
            images.add(m['url'] as String);
          }
        }
      }

      return TwitterFetchResult(
        tweetText: json['text'] as String?,
        authorName: json['user_name'] as String?,
        authorHandle: json['user_screen_name'] as String?,
        imageUrls: images,
        publishDate: json['date'] as String?,
      );
    } catch (e) {
      _dbg.log('TW', 'vxtwitter parse error: $e');
      return null;
    }
  }

  TwitterFetchResult? _parseFromHtml(String html) {
    final title = _extractMeta(html, 'og:title');
    final desc = _extractMeta(html, 'og:description');
    final image = _extractMeta(html, 'og:image');

    String? author;
    String? tweetText;
    if (title != null && title.contains(' on X:')) {
      final parts = title.split(' on X:');
      author = parts[0].trim();
      tweetText = parts.length > 1 ? parts[1].trim().replaceAll('"', '') : null;
    } else if (title != null && title.contains(' on Twitter:')) {
      final parts = title.split(' on Twitter:');
      author = parts[0].trim();
      tweetText = parts.length > 1 ? parts[1].trim().replaceAll('"', '') : null;
    }

    return TwitterFetchResult(
      tweetText: tweetText ?? desc,
      authorName: author,
      imageUrls: image != null ? [image] : [],
    );
  }

  String? _extractMeta(String html, String property) {
    final patterns = [
      RegExp('property="$property"\\s+content="([^"]*)"'),
      RegExp('content="([^"]*)"\\s+property="$property"'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(html);
      if (m != null) return _decodeHtmlEntities(m.group(1)!);
    }
    return null;
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  String buildEnhancedDescription(TwitterFetchResult result) {
    final sb = StringBuffer();
    if (result.authorName != null) {
      sb.write('${result.authorName}');
      if (result.authorHandle != null) sb.write(' (@${result.authorHandle})');
      sb.writeln();
    }
    if (result.publishDate != null) sb.writeln('Posted: ${result.publishDate}');
    if (result.tweetText != null) sb.writeln('\n${result.tweetText}');
    return sb.toString().trim();
  }
}
