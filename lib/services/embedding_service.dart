import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/thought.dart';
import '../utils/constants.dart';
import 'debug_logger.dart';

class EmbeddingService {
  final _dbg = DebugLogger.instance;
  static const _model = 'gemini-embedding-001';
  static const _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/$_model';
  static const _embedUrl = '$_baseUrl:embedContent';
  static const _batchUrl = '$_baseUrl:batchEmbedContents';

  /// Full native dimension for maximum recall on entity-rich documents.
  static const outputDimension = 768;

  Future<String?> _getApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.geminiApiKeyPref);
  }

  /// Builds a single text blob from a Thought suitable for embedding.
  /// Avoids duplicating content when llmSummary and extractedInfo are identical.
  static String thoughtToText(Thought thought) {
    final parts = <String>[];
    if (thought.title != null && thought.title!.isNotEmpty) {
      parts.add(thought.title!);
    }
    if (thought.description != null && thought.description!.isNotEmpty) {
      parts.add(thought.description!);
    }
    if (thought.llmSummary != null && thought.llmSummary!.isNotEmpty) {
      parts.add(thought.llmSummary!);
    }
    if (thought.extractedInfo != null &&
        thought.extractedInfo!.isNotEmpty &&
        thought.extractedInfo != thought.llmSummary) {
      parts.add(thought.extractedInfo!);
    }
    if (thought.ocrText != null && thought.ocrText!.isNotEmpty) {
      parts.add(thought.ocrText!);
    }
    if (thought.userNotes != null && thought.userNotes!.isNotEmpty) {
      parts.add('User notes: ${thought.userNotes!}');
    }
    if (thought.tags.isNotEmpty) {
      parts.add('Tags: ${thought.tags.join(", ")}');
    }
    parts.add('Category: ${thought.category.label}');
    return parts.join('\n');
  }

  /// Embed a single piece of text.
  /// [taskType] should be `RETRIEVAL_DOCUMENT` for indexing and
  /// `RETRIEVAL_QUERY` for user questions.
  Future<List<double>?> embed(
    String text, {
    String taskType = 'RETRIEVAL_DOCUMENT',
    String? title,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _dbg.log('EMB', 'No API key — skipping embed');
      return null;
    }

    final snippet = text.length > 60 ? '${text.substring(0, 60)}...' : text;
    _dbg.log('EMB', 'embed($taskType) "$snippet"');

    final body = <String, dynamic>{
      'model': 'models/$_model',
      'content': {
        'parts': [
          {'text': text},
        ],
      },
      'taskType': taskType,
      'outputDimensionality': outputDimension,
    };
    if (title != null) body['title'] = title;

    try {
      final sw = Stopwatch()..start();
      final response = await http
          .post(
            Uri.parse('$_embedUrl?key=$apiKey'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      sw.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final values = data['embedding']?['values'] as List?;
        if (values != null) {
          final vec = values.map((v) => (v as num).toDouble()).toList();
          _dbg.log('EMB', 'OK ${vec.length}d vector in ${sw.elapsedMilliseconds}ms');
          return vec;
        }
        _dbg.log('EMB', '200 but no values in response');
      } else {
        _dbg.log('EMB', 'HTTP ${response.statusCode}: '
            '${response.body.substring(0, response.body.length.clamp(0, 200))}');
      }
    } catch (e) {
      _dbg.log('EMB', 'Request failed: $e');
    }
    return null;
  }

  /// Embed a user query (uses RETRIEVAL_QUERY task type for best recall).
  Future<List<double>?> embedQuery(String query) {
    return embed(query, taskType: 'RETRIEVAL_QUERY');
  }

  /// Embed a Thought document.
  Future<List<double>?> embedThought(Thought thought) {
    final text = thoughtToText(thought);
    if (text.trim().isEmpty) return Future.value(null);
    return embed(
      text,
      taskType: 'RETRIEVAL_DOCUMENT',
      title: thought.title,
    );
  }

  /// Batch-embed multiple texts in a single API call (max 100 per request).
  Future<List<List<double>?>> batchEmbed(List<String> texts) async {
    final apiKey = await _getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      _dbg.log('EMB', 'No API key — skipping batch embed');
      return List.filled(texts.length, null);
    }

    _dbg.log('EMB', 'batchEmbed ${texts.length} texts');
    final results = <List<double>?>[];

    for (var i = 0; i < texts.length; i += 100) {
      final batch = texts.sublist(i, min(i + 100, texts.length));
      _dbg.log('EMB', 'batch ${i ~/ 100 + 1} — ${batch.length} items');

      final requests = batch.map((text) => {
            'model': 'models/$_model',
            'content': {
              'parts': [
                {'text': text},
              ],
            },
            'taskType': 'RETRIEVAL_DOCUMENT',
            'outputDimensionality': outputDimension,
          }).toList();

      try {
        final sw = Stopwatch()..start();
        final response = await http
            .post(
              Uri.parse('$_batchUrl?key=$apiKey'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'requests': requests}),
            )
            .timeout(const Duration(seconds: 60));
        sw.stop();

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final embeddings = data['embeddings'] as List?;
          if (embeddings != null) {
            int ok = 0;
            for (final emb in embeddings) {
              final values = emb['values'] as List?;
              if (values != null) {
                results.add(
                    values.map((v) => (v as num).toDouble()).toList());
                ok++;
              } else {
                results.add(null);
              }
            }
            _dbg.log('EMB', 'batch OK — $ok/${batch.length} '
                'vectors in ${sw.elapsedMilliseconds}ms');
            continue;
          }
        }
        _dbg.log('EMB', 'batch HTTP ${response.statusCode}: '
            '${response.body.substring(0, response.body.length.clamp(0, 200))}');
        results.addAll(List.filled(batch.length, null));
      } catch (e) {
        _dbg.log('EMB', 'batch failed: $e');
        results.addAll(List.filled(batch.length, null));
      }
    }

    return results;
  }

  /// Splits text into chunks of roughly [maxTokens] words.
  /// Preserves paragraph boundaries where possible.
  static List<String> chunkText(String text, {int maxTokens = 300}) {
    if (text.trim().isEmpty) return [];
    final words = text.split(RegExp(r'\s+'));
    if (words.length <= maxTokens) return [text];

    final paragraphs = text.split(RegExp(r'\n{2,}'));
    final chunks = <String>[];
    var current = StringBuffer();
    int currentLen = 0;

    for (final para in paragraphs) {
      final paraWords = para.split(RegExp(r'\s+')).length;
      if (currentLen + paraWords > maxTokens && currentLen > 0) {
        chunks.add(current.toString().trim());
        current = StringBuffer();
        currentLen = 0;
      }
      if (current.isNotEmpty) current.write('\n\n');
      current.write(para);
      currentLen += paraWords;
    }
    if (current.isNotEmpty) {
      chunks.add(current.toString().trim());
    }
    return chunks.where((c) => c.trim().isNotEmpty).toList();
  }

  /// Cosine similarity between two vectors.
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (var i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dotProduct / denom;
  }
}
