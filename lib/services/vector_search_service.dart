import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/thought.dart';
import 'database_service.dart';
import 'debug_logger.dart';
import 'embedding_service.dart';

/// Scored search result pairing a Thought with its similarity to the query.
class ScoredThought {
  final Thought thought;
  final double score;
  const ScoredThought(this.thought, this.score);
}

/// Orchestrates the local vector search pipeline:
/// embed thoughts → store in SQLite → embed queries → cosine rank → top-K.
class VectorSearchService {
  final DatabaseService _db;
  final EmbeddingService _embedding;
  final _dbg = DebugLogger.instance;

  /// How many results to return to the LLM.
  static const int defaultTopK = 10;

  /// Minimum cosine similarity to include from vector search.
  static const double minScore = 0.10;

  VectorSearchService({
    DatabaseService? db,
    EmbeddingService? embedding,
  })  : _db = db ?? DatabaseService(),
        _embedding = embedding ?? EmbeddingService();

  // ── Index a single thought ──

  /// Computes and stores the embedding for a thought.
  /// Skips if the text content hasn't changed (based on hash).
  Future<bool> indexThought(Thought thought) async {
    final text = EmbeddingService.thoughtToText(thought);
    if (text.trim().isEmpty) return false;

    final hash = _textHash(text);
    final existingHash = await _db.getEmbeddingHash(thought.id);
    if (existingHash == hash) {
      _dbg.log('VEC', 'skip "${thought.displayTitle}" (unchanged)');
      return true;
    }

    _dbg.log('VEC', 'indexing "${thought.displayTitle}" '
        '(${text.length} chars)');
    final vector = await _embedding.embedThought(thought);
    if (vector == null) {
      _dbg.log('VEC', 'embed failed for "${thought.displayTitle}"');
      return false;
    }

    await _db.upsertEmbedding(thought.id, vector, hash);
    _dbg.log('VEC', 'indexed "${thought.displayTitle}" OK');
    return true;
  }

  /// Removes the embedding for a deleted thought.
  Future<void> removeThought(String thoughtId) async {
    await _db.deleteEmbedding(thoughtId);
  }

  // ── Batch indexing ──

  /// Indexes all thoughts that don't yet have embeddings (or are stale).
  /// Returns the count of newly indexed items.
  Future<int> indexAll(List<Thought> thoughts) async {
    final embeddedIds = await _db.getEmbeddedThoughtIds();

    // Separate into: needs embedding vs already embedded
    final toEmbed = <Thought>[];
    final toCheck = <Thought>[];

    for (final thought in thoughts) {
      if (embeddedIds.contains(thought.id)) {
        toCheck.add(thought);
      } else {
        toEmbed.add(thought);
      }
    }

    // Check stale embeddings (content changed since last embed)
    for (final thought in toCheck) {
      final text = EmbeddingService.thoughtToText(thought);
      final hash = _textHash(text);
      final existingHash = await _db.getEmbeddingHash(thought.id);
      if (existingHash != hash) {
        toEmbed.add(thought);
      }
    }

    if (toEmbed.isEmpty) {
      _dbg.log('VEC', 'all ${thoughts.length} thoughts already indexed');
      return 0;
    }

    _dbg.log('VEC', 'need to index ${toEmbed.length}/'
        '${thoughts.length} thoughts');

    // Batch embed for efficiency
    final texts = toEmbed.map(EmbeddingService.thoughtToText).toList();
    final vectors = await _embedding.batchEmbed(texts);

    int indexed = 0;
    for (var i = 0; i < toEmbed.length; i++) {
      final vector = vectors[i];
      if (vector == null) continue;
      final hash = _textHash(texts[i]);
      await _db.upsertEmbedding(toEmbed[i].id, vector, hash);
      indexed++;
    }

    _dbg.log('VEC', 'batch indexing done — $indexed/${toEmbed.length} '
        'thoughts embedded');
    return indexed;
  }

  // ── Search ──

  /// Embeds the query and returns the top-K most relevant thoughts.
  Future<List<ScoredThought>> search(
    String query,
    List<Thought> allThoughts, {
    int topK = defaultTopK,
  }) async {
    _dbg.log('VEC', 'search("$query") against '
        '${allThoughts.length} thoughts');

    final sw = Stopwatch()..start();
    final queryVector = await _embedding.embedQuery(query);
    if (queryVector == null) {
      _dbg.log('VEC', 'query embed failed — returning empty');
      return [];
    }
    _dbg.log('VEC', 'query embedded in ${sw.elapsedMilliseconds}ms');

    final storedEmbeddings = await _db.getAllEmbeddings();
    _dbg.log('VEC', '${storedEmbeddings.length} stored embeddings');
    if (storedEmbeddings.isEmpty) return [];

    final thoughtMap = {for (final t in allThoughts) t.id: t};

    final scored = <ScoredThought>[];
    for (final entry in storedEmbeddings.entries) {
      final thought = thoughtMap[entry.key];
      if (thought == null) continue;

      final score = EmbeddingService.cosineSimilarity(
          queryVector, entry.value);
      if (score >= minScore) {
        scored.add(ScoredThought(thought, score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));

    // Supplement with keyword-matched thoughts not already in vector results
    final vectorIds = scored.map((s) => s.thought.id).toSet();
    final kwHits = _keywordFallback(query, allThoughts, vectorIds);
    if (kwHits.isNotEmpty) {
      _dbg.log('VEC', 'keyword fallback added ${kwHits.length} extra hits');
      scored.addAll(kwHits);
    }

    sw.stop();

    final results = scored.take(topK).toList();
    _dbg.log('VEC', '${scored.length} total hits, '
        'returning top ${results.length} in ${sw.elapsedMilliseconds}ms');
    for (final r in results) {
      _dbg.log('VEC', '→ ${r.score.toStringAsFixed(3)} "${r.thought.displayTitle}"');
    }
    return results;
  }

  // ── Keyword fallback ──

  /// Returns thoughts whose text contains significant words from the query,
  /// excluding any already present in [exclude]. Each result gets a synthetic
  /// score so they sort below real vector hits.
  List<ScoredThought> _keywordFallback(
    String query,
    List<Thought> allThoughts,
    Set<String> exclude,
  ) {
    final stopWords = {
      'the', 'a', 'an', 'is', 'are', 'was', 'were', 'in', 'on', 'at', 'to',
      'for', 'of', 'and', 'or', 'but', 'not', 'with', 'from', 'by', 'about',
      'what', 'where', 'when', 'how', 'which', 'who', 'do', 'does', 'did',
      'can', 'could', 'should', 'would', 'will', 'shall', 'may', 'might',
      'i', 'me', 'my', 'we', 'our', 'you', 'your', 'he', 'she', 'it', 'they',
      'them', 'this', 'that', 'these', 'those', 'any', 'some', 'all', 'best',
      'good', 'tell', 'show', 'find', 'give', 'get', 'list', 'know',
    };

    final queryWords = query
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2 && !stopWords.contains(w))
        .toSet();

    if (queryWords.isEmpty) return [];

    final results = <ScoredThought>[];
    for (final thought in allThoughts) {
      if (exclude.contains(thought.id)) continue;
      final text = EmbeddingService.thoughtToText(thought).toLowerCase();
      final matchCount = queryWords.where((w) => text.contains(w)).length;
      if (matchCount > 0) {
        final ratio = matchCount / queryWords.length;
        results.add(ScoredThought(thought, ratio * 0.20));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  // ── Helpers ──

  static String _textHash(String text) {
    return md5.convert(utf8.encode(text)).toString();
  }
}
