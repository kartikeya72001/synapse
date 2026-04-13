import 'package:http/http.dart' as http;
import 'debug_logger.dart';

class YoutubeFetchResult {
  final String? title;
  final String? description;
  final String? channelName;
  final String? thumbnailUrl;
  final String? duration;
  final String? publishDate;

  YoutubeFetchResult({
    this.title,
    this.description,
    this.channelName,
    this.thumbnailUrl,
    this.duration,
    this.publishDate,
  });
}

class YoutubeFetchService {
  final _dbg = DebugLogger.instance;

  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36';

  Future<YoutubeFetchResult?> fetchVideoDetails(String url) async {
    try {
      _dbg.log('YT', 'Fetching video details from: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': _userAgent},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _dbg.log('YT', 'HTTP ${response.statusCode}');
        return null;
      }

      final body = response.body;
      final result = YoutubeFetchResult(
        title: _extractMeta(body, 'og:title') ?? _extractMeta(body, 'title'),
        description: _extractMeta(body, 'og:description') ??
            _extractMeta(body, 'description'),
        channelName: _extractChannelName(body),
        thumbnailUrl: _extractMeta(body, 'og:image'),
        duration: _extractDuration(body),
        publishDate: _extractMeta(body, 'datePublished'),
      );

      _dbg.log('YT', 'Extracted: title="${result.title}", '
          'channel="${result.channelName}", duration="${result.duration}"');
      return result;
    } catch (e) {
      _dbg.log('YT', 'Error: $e');
      return null;
    }
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
      if (m != null) {
        return _decodeHtmlEntities(m.group(1)!);
      }
    }
    return null;
  }

  String? _extractChannelName(String html) {
    final channelPattern = RegExp(r'"ownerChannelName"\s*:\s*"([^"]*)"');
    final m = channelPattern.firstMatch(html);
    if (m != null) return m.group(1);

    final linkPattern =
        RegExp(r'<link\s+itemprop="name"\s+content="([^"]*)"');
    final m2 = linkPattern.firstMatch(html);
    return m2?.group(1);
  }

  String? _extractDuration(String html) {
    final pattern = RegExp(r'"lengthSeconds"\s*:\s*"(\d+)"');
    final m = pattern.firstMatch(html);
    if (m == null) return null;
    final seconds = int.tryParse(m.group(1)!);
    if (seconds == null) return null;
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins}m ${secs}s';
  }

  String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'");
  }

  String buildEnhancedDescription(YoutubeFetchResult result) {
    final sb = StringBuffer();
    if (result.channelName != null) sb.writeln('Channel: ${result.channelName}');
    if (result.duration != null) sb.writeln('Duration: ${result.duration}');
    if (result.publishDate != null) sb.writeln('Published: ${result.publishDate}');
    if (result.description != null) sb.writeln('\n${result.description}');
    return sb.toString().trim();
  }
}
