import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import 'debug_logger.dart';

enum LocalModelChoice {
  gemma4e2b(
    'Gemma 4 E2B',
    'gemma-4-E2B-it',
    '~2.6 GB',
    2600,
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm',
  ),
  gemma4e4b(
    'Gemma 4 E4B',
    'gemma-4-E4B-it',
    '~3.7 GB',
    3700,
    'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm',
  );

  final String displayName;
  final String modelId;
  final String sizeLabel;
  final int sizeMb;
  final String downloadUrl;

  const LocalModelChoice(
    this.displayName,
    this.modelId,
    this.sizeLabel,
    this.sizeMb,
    this.downloadUrl,
  );
}

class LocalLlmService {
  final _dbg = DebugLogger.instance;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  bool _initialized = false;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;

  Future<void> _ensureInitialized({String? huggingFaceToken}) async {
    if (_initialized && huggingFaceToken == null) return;
    if (huggingFaceToken != null && huggingFaceToken.isNotEmpty) {
      await FlutterGemma.initialize(huggingFaceToken: huggingFaceToken);
    } else {
      await FlutterGemma.initialize();
    }
    _initialized = true;
  }

  Future<bool> isModelInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.localModelInstalledPref) ?? false;
  }

  Future<String?> getInstalledModelName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.localModelNamePref);
  }

  Future<String?> getInstalledModelSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.localModelSizePref);
  }

  Future<void> downloadModel(
    LocalModelChoice choice, {
    void Function(double progress)? onProgress,
  }) async {
    if (_isDownloading) return;
    _isDownloading = true;
    _downloadProgress = 0.0;

    try {
      _dbg.log('LOCAL_LLM', 'Starting download of ${choice.displayName}');
      final prefs = await SharedPreferences.getInstance();
      final hfToken = prefs.getString(AppConstants.huggingFaceTokenPref);
      await _ensureInitialized(huggingFaceToken: hfToken);

      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      )
          .fromNetwork(choice.downloadUrl)
          .withProgress((percent) {
            _downloadProgress = percent / 100.0;
            onProgress?.call(_downloadProgress);
          })
          .install();

      await prefs.setBool(AppConstants.localModelInstalledPref, true);
      await prefs.setString(AppConstants.localModelNamePref, choice.displayName);
      await prefs.setString(AppConstants.localModelSizePref, choice.sizeLabel);

      _dbg.log('LOCAL_LLM', '${choice.displayName} download complete');
    } catch (e) {
      _dbg.log('LOCAL_LLM', 'Download error: $e');
      rethrow;
    } finally {
      _isDownloading = false;
      _downloadProgress = 0.0;
    }
  }

  Future<void> deleteModel() async {
    try {
      await _ensureInitialized();
      final models = await FlutterGemma.listInstalledModels();
      for (final modelId in models) {
        await FlutterGemma.uninstallModel(modelId);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(AppConstants.localModelInstalledPref);
      await prefs.remove(AppConstants.localModelNamePref);
      await prefs.remove(AppConstants.localModelSizePref);
      _dbg.log('LOCAL_LLM', 'Model deleted');
    } catch (e) {
      _dbg.log('LOCAL_LLM', 'Delete error: $e');
      rethrow;
    }
  }

  InferenceChat? _chat;
  bool _modelLoaded = false;

  LocalModelChoice? _resolveInstalledChoice(String? name) {
    if (name == null) return null;
    for (final choice in LocalModelChoice.values) {
      if (choice.displayName == name) return choice;
    }
    return null;
  }

  Future<void> _ensureModelLoaded() async {
    if (_modelLoaded && _chat != null) return;
    await _ensureInitialized();

    if (!FlutterGemma.hasActiveModel()) {
      final prefs = await SharedPreferences.getInstance();
      final installedName = prefs.getString(AppConstants.localModelNamePref);
      final choice = _resolveInstalledChoice(installedName);

      if (choice == null) {
        throw StateError(
          'No active model found. Please download a model in Settings.',
        );
      }

      _dbg.log('LOCAL_LLM', 'Re-registering ${choice.displayName} after restart');
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
        fileType: ModelFileType.task,
      ).fromNetwork(choice.downloadUrl).install();
    }

    InferenceModel model;
    try {
      model = await FlutterGemma.getActiveModel(maxTokens: 4096);
      _dbg.log('LOCAL_LLM', 'Model loaded with default backend');
    } catch (e) {
      _dbg.log('LOCAL_LLM', 'Default backend failed, falling back to CPU: $e');
      model = await FlutterGemma.getActiveModel(
        maxTokens: 4096,
        preferredBackend: PreferredBackend.cpu,
      );
      _dbg.log('LOCAL_LLM', 'Model loaded with CPU backend');
    }

    _chat = await model.createChat(
      temperature: 0.7,
      topK: 40,
      tokenBuffer: 256,
    );
    _modelLoaded = true;
    _dbg.log('LOCAL_LLM', 'Chat session created');
  }

  void resetSession() {
    _chat = null;
    _modelLoaded = false;
  }

  Future<String?> askQuestionStreaming(
    String prompt,
    void Function(String partialText) onChunk,
  ) async {
    try {
      await _ensureModelLoaded();

      _dbg.log('LOCAL_LLM', 'Sending prompt (${prompt.length} chars)');
      await _chat!.addQuery(Message(text: prompt, isUser: true));

      final buffer = StringBuffer();
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
          onChunk(buffer.toString());
        }
      }

      final result = buffer.toString();
      _dbg.log('LOCAL_LLM', 'Response: ${result.length} chars');
      return result.isNotEmpty ? result : null;
    } catch (e, st) {
      _dbg.log('LOCAL_LLM', 'Streaming inference error: $e\n$st');
      resetSession();
      rethrow;
    }
  }
}
