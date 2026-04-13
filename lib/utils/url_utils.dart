import 'dart:typed_data';

import 'package:http/http.dart' as http;

const mobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

/// Value suitable for a [Referer] header: `https://host/` from [url].
String refererOriginFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return '';
  return '${uri.scheme}://${uri.host}/';
}

/// GET [url] with [headers]; returns body bytes on HTTP 200 and sufficient size.
Future<Uint8List?> fetchUrlBytesIfOk(
  String url, {
  required Map<String, String> headers,
  Duration timeout = const Duration(seconds: 15),
  int minLength = 1000,
}) async {
  final response =
      await http.get(Uri.parse(url), headers: headers).timeout(timeout);
  if (response.statusCode == 200 && response.bodyBytes.length > minLength) {
    return response.bodyBytes;
  }
  return null;
}

bool isSocialMediaUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host.contains('instagram.com') ||
      host.contains('tiktok.com') ||
      host.contains('threads.net') ||
      host.contains('twitter.com') ||
      host.contains('x.com') ||
      host.contains('youtube.com') ||
      host.contains('youtu.be') ||
      host.contains('linkedin.com');
}

bool isYoutubeUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host.contains('youtube.com') || host.contains('youtu.be');
}

bool isTwitterUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host.contains('twitter.com') || host.contains('x.com');
}

bool isLinkedInUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host.contains('linkedin.com');
}

bool isInstagramUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
  return host.contains('instagram.com');
}

String cleanInstagramUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (!uri.host.contains('instagram.com')) return url;
  return 'https://www.instagram.com${uri.path}';
}
