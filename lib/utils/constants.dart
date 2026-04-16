class AppConstants {
  static const String appName = 'Synapse';
  static const String appTagline = 'Your Second Brain';

  static const String geminiApiKeyPref = 'gemini_api_key';
  static const String openaiApiKeyPref = 'openai_api_key';
  static const String llmProviderPref = 'llm_provider';
  static const String themePref = 'theme_mode';
  static const String visualStylePref = 'visual_style';
  static const String llmCallCountPref = 'llm_call_count';
  static const String autoDeleteDaysPref = 'auto_delete_days';
  static const String lastDeadLinkCheckPref = 'last_dead_link_check';
  static const String qsTilePromptedPref = 'qs_tile_prompted';
  static const String galleryImportPromptedPref = 'gallery_import_prompted';
  static const String backgroundSharePref = 'background_share';
  static const String debugLogPref = 'debug_log_enabled';
  static const String autoWirePref = 'auto_wire_on_share';
  static const String geminiModelPref = 'gemini_model';
  static const String openaiModelPref = 'openai_model';
  static const String ragPersonaPref = 'rag_persona';
  static const String onboardingCompletedPref = 'onboarding_completed';
  static const String onboardingShowOnStartupPref = 'onboarding_show_on_startup';
  static const String localModelInstalledPref = 'local_model_installed';
  static const String localModelNamePref = 'local_model_name';
  static const String localModelSizePref = 'local_model_size';
  static const String huggingFaceTokenPref = 'hugging_face_token';

  static const int maxFreeLlmCalls = 2;
  static const int maxChatHistory = 50;

  static const bool isDebugMode = bool.fromEnvironment(
    'dart.vm.product',
    defaultValue: false,
  ) == false;
}
