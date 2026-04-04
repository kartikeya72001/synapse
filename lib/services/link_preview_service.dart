import 'package:any_link_preview/any_link_preview.dart';
import 'package:http/http.dart' as http;

class LinkPreviewData {
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? favicon;

  LinkPreviewData({
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.favicon,
  });
}

class LinkPreviewService {
  static final _titleRegex = RegExp(
    r'<title[^>]*>([^<]+)</title>',
    caseSensitive: false,
  );
  static final _ogRegex = RegExp(
    r'''<meta\s+[^>]*?property\s*=\s*["']og:(\w+)["'][^>]*?content\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );
  static final _ogRegexAlt = RegExp(
    r'''<meta\s+[^>]*?content\s*=\s*["']([^"']+)["'][^>]*?property\s*=\s*["']og:(\w+)["']''',
    caseSensitive: false,
  );
  static final _descRegex = RegExp(
    r'''<meta\s+[^>]*?name\s*=\s*["']description["'][^>]*?content\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  Future<LinkPreviewData?> fetchPreview(String url) async {
    try {
      final metadata = await AnyLinkPreview.getMetadata(
        link: url,
        cache: const Duration(hours: 24),
      );

      if (metadata != null && _isUsable(metadata)) {
        return LinkPreviewData(
          title: metadata.title?.trim(),
          description: metadata.desc?.trim(),
          imageUrl: metadata.image,
          siteName: metadata.siteName ?? _extractSiteName(url),
          favicon: _buildGoogleFaviconUrl(url),
        );
      }
    } catch (_) {}

    // Fallback: direct HTTP fetch with browser-like User-Agent
    return _httpFallback(url);
  }

  bool _isUsable(Metadata metadata) {
    final title = metadata.title?.trim() ?? '';
    if (title.isEmpty) return false;
    if (title.length <= 2) return false;
    if (RegExp(r'^\d+$').hasMatch(title)) return false;
    final lower = title.toLowerCase();
    if (lower.contains('sign in') ||
        lower.contains('log in') ||
        lower == 'linkedin' ||
        lower == 'just a moment' ||
        lower == 'access denied' ||
        lower == 'page not found') {
      return false;
    }
    return true;
  }

  Future<LinkPreviewData?> _httpFallback(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url), headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'en-US,en;q=0.9',
          })
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return _fallbackPreview(url);

      final body = response.body;
      final ogTags = <String, String>{};

      for (final match in _ogRegex.allMatches(body)) {
        ogTags[match.group(1)!] = _decodeHtmlEntities(match.group(2)!);
      }
      for (final match in _ogRegexAlt.allMatches(body)) {
        ogTags.putIfAbsent(
            match.group(2)!, () => _decodeHtmlEntities(match.group(1)!));
      }

      String? title = ogTags['title'];
      if (title == null || title.isEmpty) {
        final titleMatch = _titleRegex.firstMatch(body);
        title = titleMatch != null
            ? _decodeHtmlEntities(titleMatch.group(1)!.trim())
            : null;
      }

      String? description = ogTags['description'];
      if (description == null || description.isEmpty) {
        final descMatch = _descRegex.firstMatch(body);
        description = descMatch != null
            ? _decodeHtmlEntities(descMatch.group(1)!.trim())
            : null;
      }

      if (title == null || title.isEmpty || title.length <= 2 ||
          RegExp(r'^\d+$').hasMatch(title)) {
        return _fallbackPreview(url);
      }

      return LinkPreviewData(
        title: title,
        description: description,
        imageUrl: ogTags['image'],
        siteName: ogTags['site_name'] ?? _extractSiteName(url),
        favicon: _buildGoogleFaviconUrl(url),
      );
    } catch (_) {
      return _fallbackPreview(url);
    }
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&apos;', "'");
  }

  LinkPreviewData _fallbackPreview(String url) {
    return LinkPreviewData(
      title: _extractTitleFromUrl(url),
      siteName: _extractSiteName(url),
      favicon: _buildGoogleFaviconUrl(url),
    );
  }

  String _buildGoogleFaviconUrl(String url) {
    try {
      final uri = Uri.parse(url);
      return 'https://www.google.com/s2/favicons?domain=${uri.host}&sz=128';
    } catch (_) {
      return 'https://www.google.com/s2/favicons?domain=$url&sz=128';
    }
  }

  String _extractSiteName(String url) {
    try {
      final uri = Uri.parse(url);
      var host = uri.host;
      if (host.startsWith('www.')) host = host.substring(4);

      const knownBrands = {
        'linkedin.com': 'LinkedIn',
        'instagram.com': 'Instagram',
        'twitter.com': 'X (Twitter)',
        'x.com': 'X',
        'youtube.com': 'YouTube',
        'youtu.be': 'YouTube',
        'github.com': 'GitHub',
        'reddit.com': 'Reddit',
        'medium.com': 'Medium',
        'stackoverflow.com': 'Stack Overflow',
        'amazon.com': 'Amazon',
        'amazon.in': 'Amazon India',
        'flipkart.com': 'Flipkart',
        'facebook.com': 'Facebook',
        'netflix.com': 'Netflix',
        'imdb.com': 'IMDb',
        'wikipedia.org': 'Wikipedia',
        'spotify.com': 'Spotify',
        'notion.so': 'Notion',
        'figma.com': 'Figma',
        'dribbble.com': 'Dribbble',
        'behance.net': 'Behance',
        'pinterest.com': 'Pinterest',
        'tiktok.com': 'TikTok',
        'threads.net': 'Threads',
        'bsky.app': 'Bluesky',
      };

      for (final entry in knownBrands.entries) {
        if (host.contains(entry.key)) return entry.value;
      }

      final parts = host.split('.');
      if (parts.length >= 2) {
        final name = parts[parts.length - 2];
        return name[0].toUpperCase() + name.substring(1);
      }
      return host;
    } catch (_) {
      return url;
    }
  }

  String _extractTitleFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
      for (final seg in segments.reversed) {
        final cleaned = seg
            .replaceAll(RegExp(r'[-_]'), ' ')
            .replaceAll(RegExp(r'\.\w+$'), '')
            .trim();
        if (cleaned.length > 2 && !RegExp(r'^\d+$').hasMatch(cleaned)) {
          return cleaned
              .split(' ')
              .map((w) =>
                  w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
              .join(' ');
        }
      }
      return _extractSiteName(url);
    } catch (_) {
      return url;
    }
  }
}
