import 'dart:typed_data';
import '../models/thought.dart';
import '../utils/url_utils.dart' as url_utils;
import '../utils/thought_mapper.dart';
import 'debug_logger.dart';
import 'llm_service.dart';

/// Handles the classification of individual thoughts, decoupled from
/// provider state management.
class ClassificationService {
  final LlmService _llm;
  final _dbg = DebugLogger.instance;

  bool Function(String thoughtId)? isWiringInProgress;
  Future<List<Uint8List>> Function(String postUrl)? fetchCarouselImages;

  ClassificationService(this._llm);

  /// Classify a single thought. Returns the updated thought or null on failure.
  Future<Thought?> classify(Thought thought) async {
    if (isWiringInProgress != null && isWiringInProgress!(thought.id)) {
      _dbg.log('CLASSIFY', 'skipping — async wiring in progress for ${thought.id}');
      return null;
    }

    if (thought.type == ThoughtType.screenshot) {
      final result = await _llm.extractScreenshotInfo(thought);
      if (result == null) return null;
      return applyClassificationResult(thought, result);
    }

    final isSocial = thought.tags.contains('social-media') ||
        (thought.url != null && url_utils.isSocialMediaUrl(thought.url!));

    if (isSocial && thought.url != null && fetchCarouselImages != null) {
      _dbg.log('CLASSIFY', 'fetching carousel for ${thought.url}');
      final carouselImages = await fetchCarouselImages!(thought.url!);
      if (carouselImages.isNotEmpty) {
        _dbg.log('CLASSIFY', 'got ${carouselImages.length} carousel images');
        final result = await _llm.extractAndClassifyCarousel(
          thought,
          carouselImages,
        );
        if (result != null) {
          return applyClassificationResult(thought, result);
        }
      }
    }

    if (thought.previewImageUrl != null) {
      final imageBytes = await _downloadImage(thought.previewImageUrl!);
      if (imageBytes != null) {
        final result = isSocial
            ? await _llm.extractAndClassifyPost(thought, imageBytes)
            : await _llm.classifyLinkWithImage(thought, imageBytes);
        if (result != null) {
          return applyClassificationResult(thought, result);
        }
      }
    }

    final results = await _llm.classifyBatch([thought]);
    if (results == null || results.isEmpty) return null;
    return applyClassificationResult(thought, results.first);
  }

  Future<Uint8List?> _downloadImage(String url) async {
    try {
      return await url_utils.fetchUrlBytesIfOk(
        url,
        headers: {
          'User-Agent': url_utils.mobileUserAgent,
          'Referer': url_utils.refererOriginFromUrl(url),
          'Accept': 'image/*,*/*;q=0.8',
        },
        timeout: const Duration(seconds: 15),
      );
    } catch (e) {
      _dbg.log('CLASSIFY', 'Image download failed: $e');
    }
    return null;
  }
}
