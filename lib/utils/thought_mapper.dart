import '../models/thought.dart';

/// Applies an LLM classification result map onto a Thought, producing an
/// updated copy. Used by both SynapseProvider and ShareHandlerService to
/// avoid duplicating the mapping logic.
Thought applyClassificationResult(
  Thought thought,
  Map<String, dynamic> result,
) {
  final category =
      categoryFromString(result['category'] as String? ?? 'other');
  final llmTags = (result['tags'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ??
      [];
  final mergedTags = <String>{...thought.tags, ...llmTags}.toList();
  final markdown = result['markdown'] as String?;
  final title = result['title'] as String?;
  final sourceUrl = result['source_url'] as String?;

  return thought.copyWith(
    category: category,
    tags: mergedTags,
    llmSummary: markdown,
    extractedInfo: markdown,
    title: (title != null && title.isNotEmpty) ? title : thought.title,
    url: (sourceUrl != null && sourceUrl.isNotEmpty)
        ? sourceUrl
        : thought.url,
    isClassified: true,
    updatedAt: DateTime.now(),
  );
}
