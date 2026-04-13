import 'package:http/http.dart' as http;

import '../models/thought.dart';

class DeadLinkResult {
  final String thoughtId;
  final int? statusCode;
  final bool isDead;

  DeadLinkResult({
    required this.thoughtId,
    this.statusCode,
    required this.isDead,
  });
}

class DeadLinkService {
  static const _timeout = Duration(seconds: 10);

  static final _urlRegex = RegExp(r'https?://\S+');

  List<String> _extractUrls(String? text) {
    if (text == null || text.isEmpty) return [];
    return _urlRegex.allMatches(text).map((m) => m.group(0)!).toList();
  }

  List<String> _getUrlsFromThought(Thought thought) {
    if (thought.url != null && thought.url!.isNotEmpty) {
      return [thought.url!];
    }
    return [];
  }

  Future<List<DeadLinkResult>> checkLinks(List<Thought> thoughts) async {
    final results = <DeadLinkResult>[];

    for (final thought in thoughts) {
      final urls = _getUrlsFromThought(thought);
      if (urls.isEmpty) continue;

      bool isDead = false;
      int? statusCode;

      for (final url in urls) {
        try {
          var uri = Uri.parse(url);
          var response = await http.head(uri).timeout(_timeout);
          
          // Some servers block HEAD requests, retry with GET
          if (response.statusCode == 405 || response.statusCode == 403 || response.statusCode == 500) {
            response = await http.get(uri).timeout(_timeout);
          }
          
          statusCode = response.statusCode;
          if (response.statusCode == 404 || response.statusCode == 410) {
            isDead = true;
            break;
          }
        } catch (_) {
          // Do not aggressively mark as dead on network errors, timeouts, or bot protection blocks
          // A link should only be considered dead if it definitively returns 404 or 410
          isDead = false;
        }
      }

      results.add(DeadLinkResult(
        thoughtId: thought.id,
        statusCode: statusCode,
        isDead: isDead,
      ));
    }

    return results;
  }

  Future<String?> cachePageText(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final body = response.body;
      if (body.isEmpty) return null;

      // Simple text extraction: strip HTML tags
      final text = body
          .replaceAll(RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false), '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }
}
