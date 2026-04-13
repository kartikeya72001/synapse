import 'package:http/http.dart' as http;
import 'debug_logger.dart';

class LinkedInFetchResult {
  final String? title;
  final String? description;
  final String? authorName;
  final String? thumbnailUrl;
  final String? articleUrl;

  LinkedInFetchResult({
    this.title,
    this.description,
    this.authorName,
    this.thumbnailUrl,
    this.articleUrl,
  });
}

class LinkedInFetchService {
  final _dbg = DebugLogger.instance;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  Future<LinkedInFetchResult?> fetchPostDetails(String url) async {
    try {
      _dbg.log('LI', 'Fetching LinkedIn post: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _dbg.log('LI', 'HTTP ${response.statusCode}');
        return null;
      }

      final body = response.body;

      final result = LinkedInFetchResult(
        title: _extractMeta(body, 'og:title'),
        description: _extractMeta(body, 'og:description'),
        authorName: _extractAuthor(body),
        thumbnailUrl: _extractMeta(body, 'og:image'),
        articleUrl: _extractMeta(body, 'og:url'),
      );

      _dbg.log('LI', 'Extracted: title="${result.title}", '
          'author="${result.authorName}"');
      return result;
    } catch (e) {
      _dbg.log('LI', 'Error: $e');
      return null;
    }
  }

  String? _extractAuthor(String html) {
    // LinkedIn puts author in a structured data block or title
    final titleMeta = _extractMeta(html, 'og:title') ?? '';
    // Typical pattern: "Author Name on LinkedIn: Post text"
    if (titleMeta.contains(' on LinkedIn:')) {
      return titleMeta.split(' on LinkedIn:')[0].trim();
    }
    if (titleMeta.contains(' | LinkedIn')) {
      return titleMeta.split(' | LinkedIn')[0].trim();
    }
    // Try twitter:creator or article:author
    return _extractMeta(html, 'article:author') ??
        _extractMeta(html, 'twitter:creator');
  }

  String? _extractMeta(String html, String property) {
    final patterns = [
      RegExp('property="$property"\\s+content="([^"]*)"'),
      RegExp('name="$property"\\s+content="([^"]*)"'),
      RegExp('content="([^"]*)"\\s+property="$property"'),
      RegExp('content="([^"]*)"\\s+name="$property"'),
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

  String buildEnhancedDescription(LinkedInFetchResult result) {
    final sb = StringBuffer();
    if (result.authorName != null) sb.writeln('Author: ${result.authorName}');
    if (result.description != null) sb.writeln('\n${result.description}');
    return sb.toString().trim();
  }
}
