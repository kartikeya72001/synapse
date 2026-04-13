import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/thought.dart';
import '../utils/constants.dart';
import 'debug_logger.dart';

enum LlmProvider { gemini, openai }

class LlmService {
  final _dbg = DebugLogger.instance;

  static const _defaultModel = 'gemini-2.5-flash';

  Future<String> _getGeminiUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final model = prefs.getString(AppConstants.geminiModelPref) ?? _defaultModel;
    return 'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
  }

  static const _openaiBaseUrl = 'https://api.openai.com/v1/chat/completions';

  String? _lastError;
  String? get lastError => _lastError;

  Future<String?> _getApiKey(LlmProvider provider) async {
    final prefs = await SharedPreferences.getInstance();
    switch (provider) {
      case LlmProvider.gemini:
        return prefs.getString(AppConstants.geminiApiKeyPref);
      case LlmProvider.openai:
        return prefs.getString(AppConstants.openaiApiKeyPref);
    }
  }

  Future<LlmProvider> _getActiveProvider() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString(AppConstants.llmProviderPref);
    if (provider == 'openai') return LlmProvider.openai;
    return LlmProvider.gemini;
  }

  Future<bool> hasApiKey() async {
    final provider = await _getActiveProvider();
    final key = await _getApiKey(provider);
    return key != null && key.isNotEmpty;
  }

  Future<bool> canMakeClassificationCall() async {
    final hasKey = await hasApiKey();
    if (!hasKey) {
      _lastError = 'No API key configured. Add one in Settings.';
      return false;
    }
    if (AppConstants.isDebugMode) return true;

    final prefs = await SharedPreferences.getInstance();
    final callCount = prefs.getInt(AppConstants.llmCallCountPref) ?? 0;
    if (callCount >= AppConstants.maxFreeLlmCalls && !hasKey) {
      _lastError = 'Free calls exhausted. Add your own API key.';
      return false;
    }
    return true;
  }

  Future<void> _incrementCallCount() async {
    if (AppConstants.isDebugMode) return;
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt(AppConstants.llmCallCountPref) ?? 0;
    await prefs.setInt(AppConstants.llmCallCountPref, current + 1);
  }

  Future<int> getRemainingFreeCalls() async {
    final prefs = await SharedPreferences.getInstance();
    final used = prefs.getInt(AppConstants.llmCallCountPref) ?? 0;
    return (AppConstants.maxFreeLlmCalls - used).clamp(0, AppConstants.maxFreeLlmCalls);
  }

  // ── Classification (links — batch) ──

  Future<List<Map<String, dynamic>>?> classifyBatch(List<Thought> items) async {
    if (items.isEmpty) return [];
    if (!await canMakeClassificationCall()) return null;

    final prompt = _buildBatchLinkPrompt(items);
    final maxTokens = (items.length * 600).clamp(1500, 12000);
    final text = await _callLlmRaw(prompt, maxTokens: maxTokens);
    if (text == null) return null;

    await _incrementCallCount();
    return _parseBatchResponse(text, items.length);
  }

  // ── Vision Job Runner ──

  Future<Map<String, dynamic>?> _runVisionJob({
    required String prompt,
    required List<String> base64Images,
  }) async {
    if (!await hasApiKey()) return null;
    final provider = await _getActiveProvider();
    final apiKey = await _getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) return null;

    try {
      String? text;
      if (provider == LlmProvider.gemini) {
        if (base64Images.length == 1) {
          text = await _callGeminiWithImageRaw(apiKey, prompt, base64Images.first);
        } else {
          text = await _callGeminiWithMultipleImages(apiKey, prompt, base64Images);
        }
      } else {
        text = await _callOpenaiWithImageRaw(apiKey, prompt, base64Images.first);
      }
      if (text == null) return null;
      await _incrementCallCount();
      return _parseStructuredResponse(text);
    } catch (e) {
      _lastError = _friendlyError(e);
      _dbg.log('LLM', 'vision job error: $e');
      return null;
    }
  }

  // ── Classification (screenshots — single, needs image) ──

  Future<Map<String, dynamic>?> extractScreenshotInfo(Thought item) async {
    if (item.imagePath == null) {
      _lastError = 'No image path found.';
      return null;
    }

    final imageFile = File(item.imagePath!);
    if (!await imageFile.exists()) {
      _lastError = 'Image file not found on disk.';
      return null;
    }

    final bytes = await imageFile.readAsBytes();
    final prompt = _buildScreenshotPrompt();
    return _runVisionJob(prompt: prompt, base64Images: [base64Encode(bytes)]);
  }

  // ── Q&A ──

  Future<String?> askQuestion(String question, List<Thought> contextItems) async {
    if (!await hasApiKey()) return null;

    _dbg.log('LLM', 'askQuestion with ${contextItems.length} context items');
    for (final item in contextItems) {
      final fields = <String>[];
      if (item.title != null) fields.add('title');
      if (item.description != null) fields.add('desc');
      if (item.llmSummary != null) fields.add('summary(${item.llmSummary!.length}c)');
      if (item.extractedInfo != null) fields.add('extracted(${item.extractedInfo!.length}c)');
      if (item.ocrText != null) fields.add('ocr');
      _dbg.log('LLM', '  → "${item.displayTitle}" [${fields.join(", ")}]');
    }

    final contextStr = contextItems.map((item) {
      final parts = <String>[];
      if (item.title != null) parts.add('Title: ${item.title}');
      if (item.url != null) parts.add('URL: ${item.url}');
      if (item.description != null) parts.add('Description: ${item.description}');
      if (item.llmSummary != null) parts.add('Summary: ${item.llmSummary}');
      if (item.extractedInfo != null) parts.add('Details: ${item.extractedInfo}');
      if (item.ocrText != null) parts.add('OCR Text: ${item.ocrText}');
      if (item.tags.isNotEmpty) parts.add('Tags: ${item.tags.join(", ")}');
      parts.add('Category: ${item.category.label}');
      return parts.join('\n');
    }).join('\n---\n');

    final prompt = '''You are Synapse, a personal assistant that ONLY answers 
from the user's saved memories provided below. You must NEVER use outside 
knowledge, training data, or information from the internet.

STRICT RULES:
1. ONLY use facts, names, details, and recommendations found in the CONTEXT below.
2. Do NOT supplement, expand, or enrich answers with your own knowledge.
3. If the context contains partial information, share only what is available — 
   do not fill in gaps with general knowledge.
4. If the context does NOT contain relevant information, say: "I don't have 
   information on that in your saved memories yet. Try saving some related 
   posts or links first!"
5. Never mention "context", "saved items", "memories", or "knowledge base" — 
   just answer naturally as if you recall this from what the user shared.
6. Use markdown formatting (headers, bullets, bold) when helpful.

IMPORTANT: Search through ALL context items carefully. Information may 
appear in titles, descriptions, summaries, extracted details, or OCR text.
Names, places, products, and specific details may be mentioned in any field.
Match partial names and related terms — e.g. "herbivore cafe" should match 
"Truly Herbivore Restaurant".

CONTEXT:
$contextStr

QUESTION: $question''';

    final text = await _callLlmRaw(prompt);
    return text;
  }

  // ── Video / Audio Transcription ──

  Future<String?> transcribeMedia(String filePath) async {
    if (!await hasApiKey()) {
      _lastError = 'No API key configured.';
      return null;
    }

    final file = File(filePath);
    if (!await file.exists()) {
      _lastError = 'Media file not found.';
      return null;
    }

    final fileSize = await file.length();
    if (fileSize > 20 * 1024 * 1024) {
      _lastError = 'File too large for inline processing (>20MB).';
      return null;
    }

    final provider = await _getActiveProvider();
    final apiKey = await _getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) return null;

    final bytes = await file.readAsBytes();
    final base64Data = base64Encode(bytes);
    final ext = filePath.split('.').last.toLowerCase();
    final mimeType = _mediaMimeType(ext);

    const prompt = '''Transcribe all spoken words in this media file verbatim. 
Also briefly describe the visual content (what is shown, any text overlays, 
locations, food, products, etc.). 

Format:
TRANSCRIPT: <verbatim speech>
VISUAL: <brief description of what is shown>''';

    try {
      if (provider == LlmProvider.gemini) {
        return await _callGeminiWithMediaRaw(
          apiKey, prompt, base64Data, mimeType,
        );
      }
      // OpenAI doesn't support arbitrary media — fall back to text-only
      _lastError = 'Video transcription requires Gemini API.';
      return null;
    } catch (e) {
      _lastError = _friendlyError(e);
      _dbg.log('LLM', 'media transcription error: $e');
      return null;
    }
  }

  String _mediaMimeType(String ext) {
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'mp3':
        return 'audio/mp3';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      default:
        return 'video/mp4';
    }
  }

  Future<String?> _callGeminiWithMediaRaw(
    String apiKey,
    String prompt,
    String base64Data,
    String mimeType,
  ) async {
    final geminiBaseUrl = await _getGeminiUrl();
    final url = '$geminiBaseUrl?key=$apiKey';
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Data,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 2000,
      },
    });

    return _callWithRetry(
      () => http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 120)),
      _extractGeminiText,
    );
  }

  // ── Prompt Helpers ──

  void _appendThoughtFields(
    StringBuffer sb,
    Thought item, {
    int maxDescLength = 800,
    String urlLabel = 'Post URL',
    String descLabel = 'Caption',
    String siteLabel = 'Platform',
  }) {
    if (item.url != null) sb.writeln('$urlLabel: ${item.url}');
    if (item.title != null) sb.writeln('Title: ${item.title}');
    if (item.description != null) {
      final desc = item.description!.length > maxDescLength
          ? '${item.description!.substring(0, maxDescLength)}...'
          : item.description!;
      sb.writeln('$descLabel: $desc');
    }
    if (item.siteName != null) sb.writeln('$siteLabel: ${item.siteName}');
  }

  String _buildSocialPostPreamble(Thought item, {int? slideCount}) {
    final sb = StringBuffer();

    if (slideCount != null && slideCount > 1) {
      sb.writeln('You are analyzing a social media CAROUSEL post with $slideCount slides/images.');
      sb.writeln('Each image is attached in order (Slide 1, Slide 2, etc.).');
    } else {
      sb.writeln('You are analyzing a social media post. Your job is to extract EVERY piece of information.');
    }
    sb.writeln();

    sb.writeln('CRITICAL INSTRUCTIONS:');
    if (slideCount != null && slideCount > 1) {
      sb.writeln('1. Analyze EVERY slide individually — do not skip any.');
      sb.writeln('2. Read ALL text visible in each slide — overlays, captions, watermarks, signs, menus, labels, ratings, prices, addresses, phone numbers.');
      sb.writeln('3. Identify ALL named entities — restaurant names, place names, brand names, usernames, product names.');
      sb.writeln('4. Extract ALL numbers — ratings (e.g. 9/10), prices, quantities, dates, phone numbers, addresses.');
      sb.writeln('5. Describe what is visually shown — food items, locations, products, people, activities.');
      sb.writeln('6. Capture recommendations, tips, reviews, or opinions expressed.');
      sb.writeln('7. Combine information from ALL slides into one comprehensive summary.');
    } else {
      sb.writeln('1. Read ALL text visible in the image — overlays, captions, watermarks, signs, menus, labels, ratings, prices.');
      sb.writeln('2. Identify ALL named entities — restaurant names, place names, brand names, usernames, product names.');
      sb.writeln('3. Extract ALL numbers — ratings (e.g. 9/10), prices, quantities, dates, phone numbers, addresses.');
      sb.writeln('4. Describe what is visually shown — food items, locations, products, people, activities.');
      sb.writeln('5. Capture recommendations, tips, reviews, or opinions expressed.');
    }
    sb.writeln();

    _appendThoughtFields(sb, item);
    sb.writeln();

    sb.writeln('OUTPUT FORMAT:');
    sb.writeln('CATEGORY: <category>');
    sb.writeln('TAGS: <tags>');
    sb.writeln('TITLE: <descriptive title>');
    sb.writeln('URL: none');
    sb.writeln();

    if (slideCount != null && slideCount > 1) {
      sb.writeln('Then write a COMPREHENSIVE extraction covering ALL $slideCount slides with:');
      sb.writeln('- Every name, place, product, and recommendation mentioned across all slides');
      sb.writeln('- All text overlays verbatim from each slide');
      sb.writeln('- All ratings, prices, and specific details');
      sb.writeln('- Description of visual content from each slide');
      sb.writeln('- Be thorough — the user should be able to recall ANY detail from ANY slide by reading your output alone.');
    } else {
      sb.writeln('Then write a COMPREHENSIVE extraction with:');
      sb.writeln('- Every name, place, product, and recommendation mentioned');
      sb.writeln('- All text overlays verbatim');
      sb.writeln('- All ratings, prices, and specific details');
      sb.writeln('- Description of visual content');
      sb.writeln('- Be thorough — the user should be able to recall ANY detail from this post by reading your output alone.');
    }

    return sb.toString();
  }

  // ── Deep Content Extraction (social media posts) ──

  /// Extracts ALL visible information from a post image and returns both
  /// classification data and a comprehensive text dump for Q&A.
  Future<Map<String, dynamic>?> extractAndClassifyPost(
    Thought item,
    Uint8List imageBytes,
  ) async {
    final prompt = _buildSocialPostPreamble(item);
    return _runVisionJob(prompt: prompt, base64Images: [base64Encode(imageBytes)]);
  }

  // ── Carousel Extraction (multiple images in one request) ──

  /// Sends ALL carousel images to Gemini in a single request for comprehensive
  /// OCR and content extraction across all slides.
  Future<Map<String, dynamic>?> extractAndClassifyCarousel(
    Thought item,
    List<Uint8List> images,
  ) async {
    if (images.isEmpty) return null;
    if (images.length == 1) return extractAndClassifyPost(item, images.first);

    final prompt = _buildSocialPostPreamble(item, slideCount: images.length);
    return _runVisionJob(
      prompt: prompt,
      base64Images: images.map((b) => base64Encode(b)).toList(),
    );
  }

  // ── Link Classification with Preview Image ──

  Future<Map<String, dynamic>?> classifyLinkWithImage(
    Thought item,
    Uint8List imageBytes,
  ) async {
    final prompt = _buildSingleLinkWithImagePrompt(item);
    return _runVisionJob(prompt: prompt, base64Images: [base64Encode(imageBytes)]);
  }

  String _buildSingleLinkWithImagePrompt(Thought item) {
    final sb = StringBuffer();
    sb.writeln('Analyze this post image thoroughly. Read ALL text visible in the image.');
    sb.writeln();
    sb.writeln('You MUST:');
    sb.writeln('- Read every text overlay, watermark, label, sign, menu item, rating');
    sb.writeln('- Identify all named entities (restaurant/store/brand names, place names, usernames)');
    sb.writeln('- Extract all numbers (ratings, prices, quantities, phone numbers)');
    sb.writeln('- Describe specific visual content (food dishes, products, locations)');
    sb.writeln('- Capture any recommendations, tips, or reviews');
    sb.writeln();
    _appendThoughtFields(sb, item, maxDescLength: 500);
    sb.writeln();
    sb.writeln('Output exactly 1 item. Do NOT include "=== ITEM ===" headers.');
    sb.writeln('Be comprehensive — the user should be able to recall ANY detail from this post.');
    return sb.toString();
  }

  // ── Prompts ──

  static const batchSize = 5;

  static const _categoryList = 'article, socialMedia, video, image, recipe, product, news, reference, inspiration, todo, game, family, entertainment, music, tool, vacation, sports, stocks, education, health, finance, travel, other';

  static const _systemInstruction = '''You are Synapse, a classification and knowledge-extraction engine for saved links, posts, and screenshots.

Your goals:
1. Categorize and tag the item.
2. Extract ALL useful, specific information — names, places, prices, dates, recommendations, ingredients, steps, products, tips, etc.
3. Produce a rich summary that captures every concrete detail so the user never needs to revisit the original.

RULES:
- Be factual. Do NOT invent details.
- Extract SPECIFIC data: names of places/products/people, prices, addresses, ratings, quantities, steps, ingredients — anything concrete.
- Do NOT repeat the title or URL verbatim in the body.
- Do NOT use filler like "this is a great resource" or "the image shows".
- Use markdown: headers, bold for key terms, bullet lists, numbered lists where appropriate.
- For social media posts (Instagram, TikTok, etc.): capture the full message/caption meaning plus any visual content (food, locations, products shown).
- Aim for 100-250 words of substantive analysis per item.

VALID CATEGORIES: $_categoryList

OUTPUT FORMAT (per item):
CATEGORY: <one of the valid categories>
TAGS: <up to 7 comma-separated tags>
TITLE: <descriptive title>
URL: <if a URL is visible; otherwise "none">

<Detailed markdown summary with ALL extracted specifics>''';

  String _buildBatchLinkPrompt(List<Thought> items) {
    final itemsBlock = StringBuffer();
    for (int i = 0; i < items.length; i++) {
      itemsBlock.writeln('--- INPUT ${i + 1} ---');
      _appendThoughtFields(
        itemsBlock, items[i],
        maxDescLength: 500,
        urlLabel: 'URL',
        descLabel: 'Description',
        siteLabel: 'Site',
      );
      itemsBlock.writeln();
    }

    return '''Classify each link below. Output exactly ${items.length} items.
Separate each output item with "=== ITEM N ===" headers.
Extract ALL specific details — names, places, prices, tips, etc.

${itemsBlock.toString().trim()}''';
  }

  String _buildScreenshotPrompt() {
    return '''Analyze this screenshot thoroughly. Extract ALL text, data, names, 
numbers, and specific details visible. Output exactly 1 item. 
Do NOT include "=== ITEM ===" headers.''';
  }

  // ── Response Parsing ──

  static final _categoryRegex = RegExp(r'^CATEGORY:\s*(.+)$', multiLine: true);
  static final _tagsRegex = RegExp(r'^TAGS:\s*(.+)$', multiLine: true);
  static final _titleRegex = RegExp(r'^TITLE:\s*(.+)$', multiLine: true);
  static final _urlRegex = RegExp(r'^URL:\s*(.+)$', multiLine: true);

  static final _itemHeaderRegex = RegExp(r'^\s*={2,}\s*ITEM\s*\d*\s*={2,}\s*$');

  Map<String, dynamic>? _parseStructuredResponse(String text) {
    final categoryMatch = _categoryRegex.firstMatch(text);
    final tagsMatch = _tagsRegex.firstMatch(text);
    final titleMatch = _titleRegex.firstMatch(text);
    final urlMatch = _urlRegex.firstMatch(text);

    final category = categoryMatch?.group(1)?.trim().toLowerCase() ?? 'other';
    final tagsStr = tagsMatch?.group(1)?.trim() ?? '';
    final tags = tagsStr
        .split(',')
        .map((t) => t.trim().toLowerCase().replaceAll(' ', '-'))
        .where((t) => t.isNotEmpty && t != '-')
        .take(5)
        .toList();
    final title = titleMatch?.group(1)?.trim();
    final url = urlMatch?.group(1)?.trim();

    // Strip all metadata lines and keep only the markdown body
    final lines = text.split('\n');
    final bodyLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (_itemHeaderRegex.hasMatch(trimmed)) continue;
      if (trimmed.startsWith('CATEGORY:')) continue;
      if (trimmed.startsWith('TAGS:')) continue;
      if (trimmed.startsWith('TITLE:')) continue;
      if (trimmed.startsWith('URL:')) continue;
      bodyLines.add(line);
    }
    // Remove leading/trailing blank lines from body
    while (bodyLines.isNotEmpty && bodyLines.first.trim().isEmpty) {
      bodyLines.removeAt(0);
    }
    while (bodyLines.isNotEmpty && bodyLines.last.trim().isEmpty) {
      bodyLines.removeLast();
    }
    final markdown = bodyLines.join('\n').trim();

    return {
      'category': _normalizeCategory(category),
      'tags': tags,
      'title': title,
      'source_url': (url != null && url != 'none' && url != 'null' && url.startsWith('http'))
          ? url
          : null,
      'markdown': markdown,
    };
  }

  List<Map<String, dynamic>> _parseBatchResponse(String text, int expectedCount) {
    // Split by the "=== ITEM N ===" separator
    final itemBlocks = <String>[];
    final parts = text.split(RegExp(r'===\s*ITEM\s*\d+\s*==='));
    for (final part in parts) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) itemBlocks.add(trimmed);
    }

    final results = <Map<String, dynamic>>[];
    for (final block in itemBlocks) {
      final parsed = _parseStructuredResponse(block);
      if (parsed != null) results.add(parsed);
    }
    return results;
  }

  String _normalizeCategory(String raw) {
    final normalized = raw.replaceAll(RegExp(r'[^a-z/]'), '');
    const aliases = {
      'socialmedia': 'socialMedia',
      'social': 'socialMedia',
      'movies': 'entertainment',
      'series': 'entertainment',
      'movie': 'entertainment',
      'movies/series': 'entertainment',
      'tv': 'entertainment',
      'gaming': 'game',
      'games': 'game',
      'investing': 'stocks',
      'trading': 'stocks',
      'crypto': 'stocks',
      'cryptocurrency': 'stocks',
      'study': 'education',
      'learning': 'education',
      'course': 'education',
      'tutorial': 'education',
      'medical': 'health',
      'fitness': 'health',
      'wellness': 'health',
      'workout': 'sports',
      'money': 'finance',
      'banking': 'finance',
      'payment': 'finance',
      'holiday': 'vacation',
      'trip': 'travel',
      'flight': 'travel',
      'hotel': 'travel',
    };
    if (aliases.containsKey(normalized)) return aliases[normalized]!;
    const valid = [
      'article', 'video', 'image', 'recipe', 'product', 'news',
      'reference', 'inspiration', 'todo', 'game', 'family',
      'entertainment', 'music', 'tool', 'vacation', 'sports',
      'stocks', 'education', 'health', 'finance', 'travel', 'other',
    ];
    if (valid.contains(normalized)) return normalized;
    return 'other';
  }

  // ── LLM Calls (raw text return) ──

  Future<String?> _callLlmRaw(String prompt, {int? maxTokens}) async {
    final provider = await _getActiveProvider();
    final apiKey = await _getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) {
      _lastError = 'API key is empty.';
      return null;
    }

    try {
      switch (provider) {
        case LlmProvider.gemini:
          return await _callGeminiRaw(apiKey, prompt, maxTokens: maxTokens);
        case LlmProvider.openai:
          return await _callOpenaiRaw(apiKey, prompt, maxTokens: maxTokens);
      }
    } catch (e) {
      _lastError = _friendlyError(e);
      _dbg.log('LLM', 'error: $e');
      return null;
    }
  }

  String _friendlyError(Object e) {
    if (e is TimeoutException) return 'Request timed out. Try again.';
    if (e is SocketException) return 'Network error. Check your connection.';
    return 'LLM call failed: $e';
  }

  Map<String, dynamic> _geminiBody({
    required String prompt,
    String? base64Image,
    int? maxTokens,
  }) {
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
    ];
    if (base64Image != null) {
      parts.add({
        'inline_data': {
          'mime_type': 'image/png',
          'data': base64Image,
        },
      });
    }
    return {
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction},
        ],
      },
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': maxTokens ?? 1200,
      },
    };
  }

  Future<String?> _callGeminiRaw(String apiKey, String prompt, {int? maxTokens}) async {
    final geminiBaseUrl = await _getGeminiUrl();
    final url = '$geminiBaseUrl?key=$apiKey';
    final tokens = maxTokens ?? 1200;
    final timeout = tokens > 2000 ? 90 : 45;
    final body = jsonEncode(_geminiBody(prompt: prompt, maxTokens: tokens));

    return _callWithRetry(
      () => http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(Duration(seconds: timeout)),
      _extractGeminiText,
    );
  }

  Future<String?> _callGeminiWithImageRaw(
    String apiKey,
    String prompt,
    String base64Image,
  ) async {
    final geminiBaseUrl = await _getGeminiUrl();
    final url = '$geminiBaseUrl?key=$apiKey';
    final body = jsonEncode(
      _geminiBody(prompt: prompt, base64Image: base64Image, maxTokens: 3000),
    );

    return _callWithRetry(
      () => http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 90)),
      _extractGeminiText,
    );
  }

  /// Sends multiple images in a single Gemini request (carousel support).
  Future<String?> _callGeminiWithMultipleImages(
    String apiKey,
    String prompt,
    List<String> base64Images,
  ) async {
    final geminiBaseUrl = await _getGeminiUrl();
    final url = '$geminiBaseUrl?key=$apiKey';
    final parts = <Map<String, dynamic>>[
      {'text': prompt},
    ];
    for (final img in base64Images) {
      parts.add({
        'inline_data': {
          'mime_type': 'image/jpeg',
          'data': img,
        },
      });
    }

    final maxTokens = (base64Images.length * 1500).clamp(3000, 8000);
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': _systemInstruction},
        ],
      },
      'contents': [
        {'parts': parts},
      ],
      'generationConfig': {
        'temperature': 0.4,
        'maxOutputTokens': maxTokens,
      },
    });

    return _callWithRetry(
      () => http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 180)),
      _extractGeminiText,
    );
  }

  Future<String?> _callWithRetry(
    Future<http.Response> Function() request,
    String? Function(http.Response) extractor, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (true) {
      final response = await request();
      if (response.statusCode == 429 || response.statusCode == 503) {
        attempt++;
        if (attempt >= maxRetries) {
          extractor(response);
          return null;
        }
        final waitSeconds = attempt * 5;
        _dbg.log('LLM', 'rate-limited (${response.statusCode}), '
            'retrying in ${waitSeconds}s (attempt $attempt/$maxRetries)');
        await Future.delayed(Duration(seconds: waitSeconds));
        continue;
      }
      return extractor(response);
    }
  }

  String? _extractGeminiText(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text != null && text.isNotEmpty) return text;
      _lastError = 'Gemini returned no text in response.';
    } else if (response.statusCode == 429) {
      _lastError = 'Rate limited (429). Wait a moment and try again.';
    } else if (response.statusCode == 503) {
      _lastError = 'Gemini is overloaded (503). Try again later.';
    } else {
      _lastError = 'Gemini API error ${response.statusCode}';
      _dbg.log('LLM', 'Gemini error ${response.statusCode}: ${response.body}');
    }
    return null;
  }

  Future<String?> _callOpenaiRaw(String apiKey, String prompt, {int? maxTokens}) async {
    final tokens = maxTokens ?? 1200;
    final timeout = tokens > 2000 ? 90 : 45;
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': _systemInstruction},
        {'role': 'user', 'content': prompt},
      ],
      'temperature': 0.4,
      'max_tokens': tokens,
    });

    return _callWithRetry(
      () => http.post(
        Uri.parse(_openaiBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      ).timeout(Duration(seconds: timeout)),
      _extractOpenaiText,
    );
  }

  Future<String?> _callOpenaiWithImageRaw(
    String apiKey,
    String prompt,
    String base64Image,
  ) async {
    final body = jsonEncode({
      'model': 'gpt-4o-mini',
      'messages': [
        {'role': 'system', 'content': _systemInstruction},
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/png;base64,$base64Image',
              },
            },
          ],
        },
      ],
      'temperature': 0.4,
      'max_tokens': 1500,
    });

    return _callWithRetry(
      () => http.post(
        Uri.parse(_openaiBaseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: body,
      ).timeout(const Duration(seconds: 90)),
      _extractOpenaiText,
    );
  }

  String? _extractOpenaiText(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['choices']?[0]?['message']?['content'] as String?;
      if (text != null && text.isNotEmpty) return text;
      _lastError = 'OpenAI returned no text.';
    } else if (response.statusCode == 429) {
      _lastError = 'Rate limited (429). Wait a moment and try again.';
    } else {
      _lastError = 'OpenAI error ${response.statusCode}';
      _dbg.log('LLM', 'OpenAI error ${response.statusCode}: ${response.body}');
    }
    return null;
  }
}
