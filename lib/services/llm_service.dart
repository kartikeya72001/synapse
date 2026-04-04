import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/thought.dart';
import '../utils/constants.dart';

enum LlmProvider { gemini, openai }

class LlmService {
  static const _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.1-flash-lite-preview:generateContent';
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
    // ~400 tokens per item for markdown output
    final maxTokens = (items.length * 400).clamp(1200, 8000);
    final text = await _callLlmRaw(prompt, maxTokens: maxTokens);
    if (text == null) return null;

    await _incrementCallCount();
    return _parseBatchResponse(text, items.length);
  }

  // ── Classification (screenshots — single, needs image) ──

  Future<Map<String, dynamic>?> extractScreenshotInfo(Thought item) async {
    if (item.imagePath == null) {
      _lastError = 'No image path found.';
      return null;
    }
    if (!await hasApiKey()) {
      _lastError = 'No API key configured.';
      return null;
    }

    final provider = await _getActiveProvider();
    final apiKey = await _getApiKey(provider);
    if (apiKey == null || apiKey.isEmpty) return null;

    final imageFile = File(item.imagePath!);
    if (!await imageFile.exists()) {
      _lastError = 'Image file not found on disk.';
      return null;
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final prompt = _buildScreenshotPrompt();

    try {
      String? text;
      if (provider == LlmProvider.gemini) {
        text = await _callGeminiWithImageRaw(apiKey, prompt, base64Image);
      } else {
        text = await _callOpenaiWithImageRaw(apiKey, prompt, base64Image);
      }
      if (text == null) return null;
      await _incrementCallCount();
      return _parseStructuredResponse(text);
    } catch (e) {
      _lastError = _friendlyError(e);
      debugPrint('Synapse LLM vision error: $e');
      return null;
    }
  }

  // ── Q&A ──

  Future<String?> askQuestion(String question, List<Thought> contextItems) async {
    if (!await hasApiKey()) return null;

    final contextStr = contextItems.map((item) {
      final parts = <String>[];
      if (item.title != null) parts.add('Title: ${item.title}');
      if (item.url != null) parts.add('URL: ${item.url}');
      if (item.description != null) parts.add('Description: ${item.description}');
      if (item.llmSummary != null) parts.add('Summary: ${item.llmSummary}');
      if (item.extractedInfo != null) parts.add('Extracted: ${item.extractedInfo}');
      if (item.tags.isNotEmpty) parts.add('Tags: ${item.tags.join(", ")}');
      parts.add('Category: ${item.category.label}');
      return parts.join('\n');
    }).join('\n---\n');

    final prompt = '''You are Synapse, a personal knowledge assistant. The user has saved various 
links and screenshots. Answer their question based ONLY on the thoughts provided below.
If the answer isn't in the thoughts, say so honestly.

THOUGHTS:
$contextStr

USER QUESTION: $question

Provide a concise, helpful answer.''';

    final text = await _callLlmRaw(prompt);
    return text;
  }

  // ── Prompts ──

  static const batchSize = 5;

  static const _categoryList = 'article, socialMedia, video, image, recipe, product, news, reference, inspiration, todo, game, family, entertainment, music, tool, vacation, sports, stocks, education, health, finance, travel, other';

  static const _systemInstruction = '''You are Synapse, a classification engine for saved links and screenshots. Your job is to categorize, tag, and summarize each item.

RULES (always follow):
- Be factual and concise. Do NOT guess, speculate, or pad with filler.
- Only state what you know for certain or can actually see.
- Keep each item under 80 words.
- Do NOT invent details you are unsure about.
- Do NOT repeat the title or URL in the body.
- Do NOT describe obvious things ("this is a screenshot", "the image shows").
- No generic commentary like "this is a great resource".

VALID CATEGORIES: $_categoryList

OUTPUT FORMAT (per item):
=== ITEM N ===
CATEGORY: <one of the valid categories>
TAGS: <up to 5 comma-separated single-word tags>
TITLE: <short descriptive title>
URL: <if a URL is visible/applicable, write it; otherwise "none">

<2-4 bullet points in markdown with VERIFIED facts only>''';

  String _buildBatchLinkPrompt(List<Thought> items) {
    final itemsBlock = StringBuffer();
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      itemsBlock.writeln('=== ITEM ${i + 1} ===');
      if (item.url != null) itemsBlock.writeln('URL: ${item.url}');
      if (item.title != null) itemsBlock.writeln('Title: ${item.title}');
      if (item.description != null) {
        final desc = item.description!.length > 200
            ? '${item.description!.substring(0, 200)}...'
            : item.description!;
        itemsBlock.writeln('Description: $desc');
      }
      if (item.siteName != null) itemsBlock.writeln('Site: ${item.siteName}');
      itemsBlock.writeln();
    }

    return '''Classify each link below. Output exactly ${items.length} items.

${itemsBlock.toString().trim()}''';
  }

  String _buildScreenshotPrompt() {
    return 'Analyze this screenshot. Output exactly 1 item following the format.';
  }

  // ── Response Parsing ──

  static final _categoryRegex = RegExp(r'^CATEGORY:\s*(.+)$', multiLine: true);
  static final _tagsRegex = RegExp(r'^TAGS:\s*(.+)$', multiLine: true);
  static final _titleRegex = RegExp(r'^TITLE:\s*(.+)$', multiLine: true);
  static final _urlRegex = RegExp(r'^URL:\s*(.+)$', multiLine: true);

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

    // Extract markdown body: everything after the header block
    var markdown = text;
    // Remove the header lines
    final lines = text.split('\n');
    int bodyStart = 0;
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('CATEGORY:') ||
          line.startsWith('TAGS:') ||
          line.startsWith('TITLE:') ||
          line.startsWith('URL:') ||
          line.isEmpty) {
        bodyStart = i + 1;
      } else {
        break;
      }
    }
    markdown = lines.skip(bodyStart).join('\n').trim();

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
      debugPrint('Synapse LLM error: $e');
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
    final url = '$_geminiBaseUrl?key=$apiKey';
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
    final url = '$_geminiBaseUrl?key=$apiKey';
    final body = jsonEncode(
      _geminiBody(prompt: prompt, base64Image: base64Image, maxTokens: 1500),
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
        debugPrint('Synapse: rate-limited (${response.statusCode}), '
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
      debugPrint('Synapse Gemini error ${response.statusCode}: ${response.body}');
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
      debugPrint('Synapse OpenAI error ${response.statusCode}: ${response.body}');
    }
    return null;
  }
}
