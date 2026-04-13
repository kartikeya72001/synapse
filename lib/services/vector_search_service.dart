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

  Map<String, List<List<double>>>? _embeddingCache;
  bool _cacheDirty = true;

  VectorSearchService({
    DatabaseService? db,
    EmbeddingService? embedding,
  })  : _db = db ?? DatabaseService(),
        _embedding = embedding ?? EmbeddingService();

  void _invalidateCache() { _cacheDirty = true; }

  Future<Map<String, List<List<double>>>> _getCachedEmbeddings() async {
    if (_cacheDirty || _embeddingCache == null) {
      _embeddingCache = await _db.getAllEmbeddings();
      _cacheDirty = false;
      int totalChunks = 0;
      for (final v in _embeddingCache!.values) totalChunks += v.length;
      _dbg.log('VEC', 'cache refreshed: ${_embeddingCache!.length} thoughts, '
          '$totalChunks total chunks');
    }
    return _embeddingCache!;
  }

  // ── Index a single thought ──

  /// Computes and stores chunk-level embeddings for a thought.
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

    final chunks = EmbeddingService.chunkText(text);
    _dbg.log('VEC', 'indexing "${thought.displayTitle}" '
        '(${text.length} chars, ${chunks.length} chunks)');

    final vectors = <List<double>>[];
    for (final chunk in chunks) {
      final vector = await _embedding.embed(
        chunk,
        taskType: 'RETRIEVAL_DOCUMENT',
        title: thought.title,
      );
      if (vector != null) {
        vectors.add(vector);
      }
    }

    if (vectors.isEmpty) {
      _dbg.log('VEC', 'embed failed for "${thought.displayTitle}"');
      return false;
    }

    await _db.upsertChunkEmbeddings(thought.id, vectors, hash);
    _invalidateCache();
    _dbg.log('VEC', 'indexed "${thought.displayTitle}" OK '
        '(${vectors.length} chunks)');
    return true;
  }

  /// Removes the embedding for a deleted thought.
  Future<void> removeThought(String thoughtId) async {
    await _db.deleteEmbedding(thoughtId);
    _invalidateCache();
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

    // Batch embed with chunking
    int indexed = 0;
    final allChunks = <String>[];
    final chunkMeta = <({int thoughtIdx, int chunkIdx})>[];
    for (int ti = 0; ti < toEmbed.length; ti++) {
      final text = EmbeddingService.thoughtToText(toEmbed[ti]);
      final chunks = EmbeddingService.chunkText(text);
      for (int ci = 0; ci < chunks.length; ci++) {
        allChunks.add(chunks[ci]);
        chunkMeta.add((thoughtIdx: ti, chunkIdx: ci));
      }
    }

    final vectors = await _embedding.batchEmbed(allChunks);

    final thoughtVectors = <int, List<List<double>>>{};
    for (int i = 0; i < chunkMeta.length; i++) {
      final vec = vectors[i];
      if (vec == null) continue;
      thoughtVectors.putIfAbsent(chunkMeta[i].thoughtIdx, () => []).add(vec);
    }

    for (final entry in thoughtVectors.entries) {
      final thought = toEmbed[entry.key];
      final text = EmbeddingService.thoughtToText(thought);
      final hash = _textHash(text);
      await _db.upsertChunkEmbeddings(thought.id, entry.value, hash);
      indexed++;
    }

    _invalidateCache();
    _dbg.log('VEC', 'batch indexing done — $indexed/${toEmbed.length} '
        'thoughts embedded (${allChunks.length} total chunks)');
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

    final storedEmbeddings = await _getCachedEmbeddings();
    _dbg.log('VEC', '${storedEmbeddings.length} thoughts in embedding store');
    if (storedEmbeddings.isEmpty) return [];

    final thoughtMap = {for (final t in allThoughts) t.id: t};

    final scored = <ScoredThought>[];
    for (final entry in storedEmbeddings.entries) {
      final thought = thoughtMap[entry.key];
      if (thought == null) continue;

      // Use the best chunk score for this thought
      double bestScore = 0.0;
      for (final chunkVec in entry.value) {
        final s = EmbeddingService.cosineSimilarity(queryVector, chunkVec);
        if (s > bestScore) bestScore = s;
      }
      if (bestScore >= minScore) {
        scored.add(ScoredThought(thought, bestScore));
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

  // ── Semantic Tree / Hierarchical Index ──

  /// Builds a category → thoughtIds index from all thoughts and computes
  /// a centroid vector per category for coarse-grained filtering.
  Future<Map<String, CategoryNode>> buildSemanticTree(
      List<Thought> allThoughts) async {
    final embeddings = await _getCachedEmbeddings();
    final tree = <String, CategoryNode>{};

    for (final thought in allThoughts) {
      final cat = thought.category.name;
      tree.putIfAbsent(cat, () => CategoryNode(cat));
      tree[cat]!.thoughtIds.add(thought.id);

      final chunks = embeddings[thought.id];
      if (chunks != null) {
        for (final vec in chunks) {
          tree[cat]!.vectors.add(vec);
        }
      }
    }

    for (final node in tree.values) {
      node.computeCentroid();
    }

    _dbg.log('VEC', 'semantic tree built: ${tree.length} categories');
    return tree;
  }

  /// Two-phase search: first rank categories by centroid similarity,
  /// then do fine-grained chunk search only within top categories.
  Future<List<ScoredThought>> hierarchicalSearch(
    String query,
    List<Thought> allThoughts, {
    int topK = defaultTopK,
    int maxCategories = 3,
  }) async {
    final queryVector = await _embedding.embedQuery(query);
    if (queryVector == null) return [];

    final tree = await buildSemanticTree(allThoughts);
    if (tree.isEmpty) return search(query, allThoughts, topK: topK);

    // Phase 1: rank categories by centroid similarity
    final catScores = <String, double>{};
    for (final entry in tree.entries) {
      if (entry.value.centroid == null) continue;
      catScores[entry.key] =
          EmbeddingService.cosineSimilarity(queryVector, entry.value.centroid!);
    }

    final rankedCats = catScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selectedCats = rankedCats.take(maxCategories).map((e) => e.key).toSet();
    _dbg.log('VEC', 'hierarchical search: top categories = $selectedCats');

    // Phase 2: fine-grained search within selected categories
    final relevantIds = <String>{};
    for (final cat in selectedCats) {
      relevantIds.addAll(tree[cat]!.thoughtIds);
    }

    final filteredThoughts =
        allThoughts.where((t) => relevantIds.contains(t.id)).toList();

    return search(query, filteredThoughts, topK: topK);
  }

  // ── Helpers ──

  static String _textHash(String text) {
    return md5.convert(utf8.encode(text)).toString();
  }
}

class CategoryNode {
  final String category;
  final List<String> thoughtIds = [];
  final List<List<double>> vectors = [];
  List<double>? centroid;

  CategoryNode(this.category);

  void computeCentroid() {
    if (vectors.isEmpty) return;
    final dim = vectors.first.length;
    final sum = List<double>.filled(dim, 0.0);
    for (final vec in vectors) {
      for (int i = 0; i < dim; i++) {
        sum[i] += vec[i];
      }
    }
    final n = vectors.length.toDouble();
    centroid = [for (int i = 0; i < dim; i++) sum[i] / n];
  }
}
