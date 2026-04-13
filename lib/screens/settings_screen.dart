import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/permissions.dart';
import '../providers/synapse_provider.dart' show SynapseProvider, AppThemeMode;
import '../services/debug_logger.dart';
import '../services/llm_service.dart';
import '../services/share_handler_service.dart';
import '../services/export_service.dart';
import '../models/thought.dart' show Thought, ThoughtType;
import '../utils/constants.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _geminiKeyController = TextEditingController();
  final _openaiKeyController = TextEditingController();
  LlmProvider _selectedProvider = LlmProvider.gemini;
  bool _obscureGemini = true;
  bool _obscureOpenai = true;
  int _remainingCalls = 0;
  int? _autoDeleteDays;
  bool _isExporting = false;
  bool _backgroundShare = false;
  bool _debugLog = false;
  bool _autoWire = true;
  String _selectedModel = 'gemini-3.1-flash-lite-preview';

  static const List<int?> _autoDeletePresets = [null, 7, 15, 30, 90, 180, 365];

  static const _geminiModels = [
    _ModelOption('gemini-3.1-flash-lite-preview', 'Gemini 3.1 Flash Lite', 'Very Low', 'Medium'),
    _ModelOption('gemini-3.1-flash-preview', 'Gemini 3.1 Flash', 'Low', 'High'),
    _ModelOption('gemini-3.1-pro-preview', 'Gemini 3.1 Pro', 'High', 'Very High'),
    _ModelOption('gemini-2.5-flash', 'Gemini 2.5 Flash', 'Low', 'High'),
    _ModelOption('gemini-2.5-pro', 'Gemini 2.5 Pro', 'Medium', 'Very High'),
  ];
  static const _openaiModels = [
    _ModelOption('gpt-4o-mini', 'GPT-4o Mini', 'Very Low', 'Medium'),
    _ModelOption('gpt-4o', 'GPT-4o', 'Medium', 'High'),
    _ModelOption('gpt-4.1-mini', 'GPT-4.1 Mini', 'Low', 'High'),
    _ModelOption('gpt-4.1', 'GPT-4.1', 'Medium', 'Very High'),
    _ModelOption('o4-mini', 'o4-mini', 'Medium', 'Very High'),
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final synapseProvider = context.read<SynapseProvider>();

    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString(AppConstants.llmProviderPref);
    final geminiKey = prefs.getString(AppConstants.geminiApiKeyPref) ?? '';
    final openaiKey = prefs.getString(AppConstants.openaiApiKeyPref) ?? '';
    final remaining = await synapseProvider.getRemainingFreeCalls();
    final autoDelete = prefs.getInt(AppConstants.autoDeleteDaysPref);
    final bgShare = prefs.getBool(AppConstants.backgroundSharePref) ?? false;
    final dbgLog = prefs.getBool(AppConstants.debugLogPref) ?? false;
    final autoWire = prefs.getBool(AppConstants.autoWirePref) ?? true;
    final selectedModel = prefs.getString(AppConstants.geminiModelPref) ?? 'gemini-3.1-flash-lite-preview';

    if (!mounted) return;

    setState(() {
      _selectedProvider = provider == 'openai' ? LlmProvider.openai : LlmProvider.gemini;
      _geminiKeyController.text = geminiKey;
      _openaiKeyController.text = openaiKey;
      _remainingCalls = remaining;
      _autoDeleteDays = autoDelete;
      _backgroundShare = bgShare;
      _debugLog = dbgLog;
      _autoWire = autoWire;
      _selectedModel = selectedModel;
    });
  }

  @override
  void dispose() {
    // Capture everything synchronously before async gap / controller disposal
    final gemini = _geminiKeyController.text.trim();
    final openai = _openaiKeyController.text.trim();
    final providerName = _selectedProvider.name;
    final synapseProvider = context.read<SynapseProvider>();
    _persistKeys(gemini, openai, providerName, synapseProvider);
    _geminiKeyController.dispose();
    _openaiKeyController.dispose();
    super.dispose();
  }

  /// Lightweight save triggered on every keystroke — no reindex.
  Future<void> _persistKeysQuiet() async {
    final prefs = await SharedPreferences.getInstance();
    final gemini = _geminiKeyController.text.trim();
    final openai = _openaiKeyController.text.trim();
    if (gemini.isNotEmpty) {
      await prefs.setString(AppConstants.geminiApiKeyPref, gemini);
    }
    if (openai.isNotEmpty) {
      await prefs.setString(AppConstants.openaiApiKeyPref, openai);
    }
    await prefs.setString(AppConstants.llmProviderPref, _selectedProvider.name);
  }

  /// Full save on dispose — also triggers reindex if key changed.
  Future<void> _persistKeys(
    String gemini,
    String openai,
    String providerName,
    SynapseProvider synapseProvider,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final oldGeminiKey = prefs.getString(AppConstants.geminiApiKeyPref) ?? '';
    if (gemini.isNotEmpty) {
      await prefs.setString(AppConstants.geminiApiKeyPref, gemini);
    }
    if (openai.isNotEmpty) {
      await prefs.setString(AppConstants.openaiApiKeyPref, openai);
    }
    await prefs.setString(AppConstants.llmProviderPref, providerName);

    if (gemini.isNotEmpty && gemini != oldGeminiKey) {
      synapseProvider.reindexEmbeddings();
      synapseProvider.retryFailedWirings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? SynapseGradients.settingsBgDark : SynapseGradients.settingsBg,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
              child: Text(
                'Settings',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                children: [
          _buildSectionTitle(theme, 'Appearance'),
          _buildThemeSelector(theme, colorScheme, isDark),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'Auto-Delete'),
          const SizedBox(height: 12),
          _buildAutoDeleteSelector(theme, colorScheme, isDark),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'Sharing'),
          const SizedBox(height: 12),
          _buildBackgroundShareToggle(theme, colorScheme, isDark),
          const SizedBox(height: 12),
          _buildDebugLogToggle(theme, colorScheme, isDark),
          const SizedBox(height: 12),
          _buildAutoWireToggle(theme, colorScheme, isDark),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'Neural Engine'),
          const SizedBox(height: 12),
          _buildInfoCard(theme, colorScheme, isDark),
          const SizedBox(height: 16),
          _buildProviderSelector(theme, colorScheme, isDark),
          const SizedBox(height: 16),
          _buildModelSelector(theme, colorScheme, isDark),
          const SizedBox(height: 20),
          _buildApiKeyField(
            theme: theme,
            colorScheme: colorScheme,
            label: 'Gemini API Key',
            controller: _geminiKeyController,
            obscure: _obscureGemini,
            onToggle: () => setState(() => _obscureGemini = !_obscureGemini),
            hint: 'AIzaSy...',
          ),
          const SizedBox(height: 16),
          _buildApiKeyField(
            theme: theme,
            colorScheme: colorScheme,
            label: 'OpenAI API Key',
            controller: _openaiKeyController,
            obscure: _obscureOpenai,
            onToggle: () => setState(() => _obscureOpenai = !_obscureOpenai),
            hint: 'sk-...',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save Settings'),
            style: FilledButton.styleFrom(
              backgroundColor: SynapseColors.ink,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'Data'),
          const SizedBox(height: 12),
          _buildGalleryImportCard(theme, colorScheme, isDark),
          const SizedBox(height: 12),
          _buildExportCsvCard(theme, colorScheme, isDark),
          const SizedBox(height: 12),
          _buildImportCsvCard(theme, colorScheme, isDark),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'About'),
          const SizedBox(height: 12),
          _buildAboutCard(theme, colorScheme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          width: 40,
          decoration: BoxDecoration(
            color: SynapseColors.ink.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final provider = context.watch<SynapseProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: SynapseDecoration.card(dark: isDark),
        child: Row(
          children: [
            _themeOption(
              icon: Icons.brightness_auto_rounded,
              label: 'System',
              isSelected: provider.themeMode == AppThemeMode.system,
              onTap: () => provider.setThemeMode(AppThemeMode.system),
              colorScheme: colorScheme,
            ),
            _themeOption(
              icon: Icons.light_mode_rounded,
              label: 'Light',
              isSelected: provider.themeMode == AppThemeMode.light,
              onTap: () => provider.setThemeMode(AppThemeMode.light),
              colorScheme: colorScheme,
            ),
            _themeOption(
              icon: Icons.dark_mode_rounded,
              label: 'Dark',
              isSelected: provider.themeMode == AppThemeMode.dark,
              onTap: () => provider.setThemeMode(AppThemeMode.dark),
              colorScheme: colorScheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? SynapseColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : SynapseColors.inkMuted,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoDeleteSelector(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    final currentIdx = _autoDeletePresets.indexOf(_autoDeleteDays);
    final selectedIndex = currentIdx >= 0 ? currentIdx : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SynapseDecoration.card(dark: isDark),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_delete_rounded, size: 20, color: SynapseColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Forget memories older than:',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 100,
            child: ListWheelScrollView.useDelegate(
              itemExtent: 36,
              diameterRatio: 1.6,
              perspective: 0.004,
              physics: const FixedExtentScrollPhysics(),
              controller: FixedExtentScrollController(initialItem: selectedIndex),
              onSelectedItemChanged: (index) async {
                final preset = _autoDeletePresets[index];
                setState(() => _autoDeleteDays = preset);
                final prefs = await SharedPreferences.getInstance();
                if (preset == null) {
                  await prefs.remove(AppConstants.autoDeleteDaysPref);
                } else {
                  await prefs.setInt(AppConstants.autoDeleteDaysPref, preset);
                }
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _autoDeletePresets.length,
                builder: (context, index) {
                  final preset = _autoDeletePresets[index];
                  final isActive = _autoDeleteDays == preset;
                  final label = preset == null ? 'Never' : '$preset days';
                  return Container(
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark ? SynapseColors.darkAccent.withValues(alpha: 0.15) : SynapseColors.accent.withValues(alpha: 0.08))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      label,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: isActive ? 16 : 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                        color: isActive
                            ? (isDark ? SynapseColors.darkAccent : SynapseColors.accent)
                            : (isDark ? SynapseColors.darkInkMuted : SynapseColors.inkMuted),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundShareToggle(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SynapseDecoration.card(dark: isDark),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? SynapseColors.darkLavender : SynapseColors.lavenderLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.sync_rounded, size: 20, color: SynapseColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Process in background', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Save shared links without opening the app',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _backgroundShare,
            activeThumbColor: SynapseColors.accent,
            activeTrackColor: SynapseColors.accent.withValues(alpha: 0.4),
            onChanged: (val) async {
              setState(() => _backgroundShare = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppConstants.backgroundSharePref, val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLogToggle(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SynapseDecoration.card(dark: isDark),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? SynapseColors.darkLavender : SynapseColors.lavenderLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.bug_report_rounded, size: 20, color: SynapseColors.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Debug logging', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Save detailed processing logs to Downloads',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _debugLog,
            activeThumbColor: SynapseColors.accent,
            activeTrackColor: SynapseColors.accent.withValues(alpha: 0.4),
            onChanged: (val) async {
              setState(() => _debugLog = val);
              await DebugLogger.instance.setEnabled(val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SynapseDecoration.card(dark: isDark),
      child: Row(
        children: [
          Icon(Icons.info_rounded, color: SynapseColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Free neural wiring calls left: $_remainingCalls',
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Plug in your own API key for unlimited synaptic power.',
                  style: theme.textTheme.bodySmall,
                ),
                if (AppConstants.isDebugMode) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'DEBUG: Call limit disabled',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelector(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: SynapseDecoration.card(dark: isDark),
      child: Row(
        children: [
          _providerOption(
            label: 'Gemini',
            isSelected: _selectedProvider == LlmProvider.gemini,
            onTap: () => setState(() => _selectedProvider = LlmProvider.gemini),
            colorScheme: colorScheme,
          ),
          _providerOption(
            label: 'OpenAI',
            isSelected: _selectedProvider == LlmProvider.openai,
            onTap: () => setState(() => _selectedProvider = LlmProvider.openai),
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _providerOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? SynapseColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildApiKeyField({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggle,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.titleLarge?.copyWith(fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              onPressed: onToggle,
            ),
          ),
          onChanged: (_) => _persistKeysQuiet(),
        ),
      ],
    );
  }

  Widget _buildGalleryImportCard(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: _importFromGallery,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: SynapseDecoration.card(dark: isDark),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? SynapseColors.darkLavender : SynapseColors.lavenderLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.photo_library_rounded, color: SynapseColors.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Absorb Memories',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Scan your device for visual memories. Already memorized ones skipped.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromGallery() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<SynapseProvider>();
    final shareHandler = ShareHandlerService();
    const channel = MethodChannel('com.synapse.synapse/quicksettings');

    final granted = await AppPermissions.requestPhotosAccess();
    if (!granted) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Synapse needs photo access to scan your memories.')),
      );
      return;
    }

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Scanning neural pathways...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final List<dynamic>? paths =
          await channel.invokeMethod<List<dynamic>>('listScreenshots');

      if (paths == null || paths.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No memories found to absorb.')),
        );
        return;
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Found ${paths.length} memories, absorbing...'),
          duration: const Duration(seconds: 2),
        ),
      );

      int imported = 0;
      int skipped = 0;

      for (final p in paths) {
        final path = p as String;
        final thought = await shareHandler.importImageIfNew(path);
        if (thought != null) {
          provider.addThought(thought);
          imported++;
        } else {
          skipped++;
        }
      }

      await provider.loadThoughts();

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Absorbed $imported memory${imported != 1 ? ' fragments' : ''}'
            '${skipped > 0 ? ', $skipped already in the brain' : ''}',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Screenshot import failed: $e');
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t reach the memory banks.')),
      );
    }
  }

  Widget _buildExportCsvCard(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: _isExporting ? null : _exportToCsv,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: SynapseDecoration.card(dark: isDark),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? SynapseColors.darkLavender : SynapseColors.lavenderLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isExporting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SynapseColors.accent,
                      ),
                    )
                  : Icon(Icons.download_rounded, color: SynapseColors.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Export Memories',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Export all saved links and posts as a CSV file to Downloads.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Widget _buildImportCsvCard(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return GestureDetector(
      onTap: _importFromCsv,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: SynapseDecoration.card(dark: isDark),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? SynapseColors.darkLavender : SynapseColors.lavenderLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.upload_file_rounded,
                  color: SynapseColors.accent),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Import Memories',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Restore memories from a previously exported CSV file.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromCsv() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<SynapseProvider>();

    var files = await ExportService.listAllCsvFiles();
    if (files.isEmpty) {
      if (!mounted) return;
      final pickedFile = await _pickCsvManually();
      if (pickedFile == null) return;
      files = [pickedFile];
    }

    if (!mounted) return;

    final selected = await showModalBottomSheet<File>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: SynapseColors.ink.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Select export file',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18, fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 12),
              ...files.take(10).map((f) {
                final name = f.path.split('/').last;
                final modified = f.lastModifiedSync();
                return ListTile(
                  leading: Icon(Icons.description_rounded,
                      color: SynapseColors.success),
                  title: Text(name,
                      style: GoogleFonts.spaceGrotesk(fontSize: 13)),
                  subtitle: Text(
                    '${modified.day}/${modified.month}/${modified.year}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, color: SynapseColors.inkMuted),
                  ),
                  onTap: () => Navigator.pop(ctx, f),
                  contentPadding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );

    if (selected == null) return;
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ImportLoadingDialog(),
    );

    try {
      final thoughts = await ExportService.importFromCsv(selected);
      if (!mounted) return;

      if (thoughts.isEmpty) {
        Navigator.of(context).pop();
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No valid memories found in the file.')),
        );
        return;
      }

      int imported = 0;
      for (final thought in thoughts) {
        await provider.restoreThought(thought);
        imported++;
      }
      await provider.loadThoughts();
      _refetchMissingPreviews(provider, thoughts);

      if (mounted) {
        Navigator.of(context).pop();
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Imported $imported memories successfully.')),
        );
      }
    } catch (e) {
      debugPrint('CSV import failed: $e');
      if (mounted) {
        Navigator.of(context).pop();
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Import failed. Please try again.')),
        );
      }
    }
  }

  void _refetchMissingPreviews(SynapseProvider provider, List<Thought> thoughts) {
    final linksNeedingPreview = thoughts.where(
      (t) => t.type == ThoughtType.link && t.url != null && t.url!.isNotEmpty && (t.previewImageUrl == null || t.previewImageUrl!.isEmpty),
    ).toList();

    if (linksNeedingPreview.isEmpty) return;

    final shareHandler = ShareHandlerService();
    for (final thought in linksNeedingPreview) {
      shareHandler.refetchPreview(thought).then((updated) {
        if (updated != null) {
          provider.updateThought(updated);
        }
      }).catchError((_) {});
    }
  }

  Future<void> _exportToCsv() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<SynapseProvider>();

    setState(() => _isExporting = true);

    try {
      final thoughts = provider.items;
      if (thoughts.isEmpty) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('No memories to export.')),
        );
        return;
      }

      final filePath = await ExportService.exportToCsv(thoughts);

      if (!mounted) return;

      if (filePath != null) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Exported ${thoughts.length} memories to $filePath'),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Export failed. Could not write file.')),
        );
      }
    } catch (e) {
      debugPrint('Export error: $e');
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('Something went wrong during export.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildAboutCard(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: SynapseDecoration.card(dark: isDark),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            decoration: BoxDecoration(
              gradient: isDark ? SynapseGradients.heroDark : SynapseGradients.hero,
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    gradient: SynapseGradients.accent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.psychology_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Synapse',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Second Brain. Wired by AI.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: SynapseColors.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Text(
                  'Version 2.0.0',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text(
                  'Capture thoughts from any app. AI-powered neural wiring, OCR, and deep recall.',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAutoWireToggle(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: SynapseDecoration.card(dark: isDark),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? SynapseColors.darkLavender : SynapseColors.lavenderLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_fix_high_rounded, color: SynapseColors.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Auto-wire on share', style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text('Automatically classify shared content.', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          Switch.adaptive(
            value: _autoWire,
            activeThumbColor: SynapseColors.accent,
            activeTrackColor: SynapseColors.accent.withValues(alpha: 0.4),
            onChanged: (val) async {
              setState(() => _autoWire = val);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool(AppConstants.autoWirePref, val);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector(ThemeData theme, ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: (_selectedProvider == LlmProvider.gemini ? _geminiModels : _openaiModels).map((model) {
        final isSelected = _selectedModel == model.id;
        final costColor = switch (model.cost) {
          'Very Low' => SynapseColors.success,
          'Low' => const Color(0xFF4CAF50),
          'Medium' => const Color(0xFFFF9800),
          'High' => const Color(0xFFFF5722),
          _ => SynapseColors.inkMuted,
        };
        final qualityColor = switch (model.quality) {
          'Very High' => const Color(0xFF7C4DFF),
          'High' => SynapseColors.accent,
          'Medium' => const Color(0xFF42A5F5),
          'Low' => SynapseColors.inkMuted,
          _ => SynapseColors.inkMuted,
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GestureDetector(
            onTap: () async {
              setState(() => _selectedModel = model.id);
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString(AppConstants.geminiModelPref, model.id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [SynapseColors.darkLavender, SynapseColors.darkCard]
                            : [const Color(0xFFF3EDFF), Colors.white],
                      )
                    : null,
                color: isSelected ? null : (isDark ? SynapseColors.darkCard : SynapseColors.lightCard),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? SynapseColors.accent.withValues(alpha: 0.3)
                      : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
                ),
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? SynapseColors.accent : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? SynapseColors.accent : SynapseColors.inkFaint,
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      model.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: costColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.payments_outlined, size: 10, color: costColor),
                        const SizedBox(width: 3),
                        Text(
                          model.cost,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: costColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: qualityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 10, color: qualityColor),
                        const SizedBox(width: 3),
                        Text(
                          model.quality,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: qualityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final oldGeminiKey = prefs.getString(AppConstants.geminiApiKeyPref) ?? '';
    final newGeminiKey = _geminiKeyController.text.trim();

    await prefs.setString(AppConstants.geminiApiKeyPref, newGeminiKey);
    await prefs.setString(AppConstants.openaiApiKeyPref, _openaiKeyController.text.trim());
    await prefs.setString(AppConstants.llmProviderPref, _selectedProvider.name);

    if (_autoDeleteDays == null) {
      await prefs.remove(AppConstants.autoDeleteDaysPref);
    } else {
      await prefs.setInt(AppConstants.autoDeleteDaysPref, _autoDeleteDays!);
    }

    await prefs.setBool(AppConstants.autoWirePref, _autoWire);
    await prefs.setString(AppConstants.geminiModelPref, _selectedModel);

    if (newGeminiKey.isNotEmpty && newGeminiKey != oldGeminiKey && mounted) {
      final provider = context.read<SynapseProvider>();
      provider.reindexEmbeddings();
      provider.retryFailedWirings();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Neural config updated.')),
      );
    }
  }

  Future<File?> _pickCsvManually() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        dialogTitle: 'Select CSV file',
      );
      if (result != null && result.files.single.path != null) {
        return File(result.files.single.path!);
      }
    } catch (e) {
      debugPrint('File picker error: $e');
    }
    return null;
  }
}

class _ModelOption {
  final String id;
  final String name;
  final String cost;
  final String quality;
  const _ModelOption(this.id, this.name, this.cost, this.quality);
}

class _ImportLoadingDialog extends StatelessWidget {
  const _ImportLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [SynapseColors.darkCard, const Color(0xFF1E1A2E)]
                : [Colors.white, const Color(0xFFF3EDFF)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: SynapseShadows.elevated,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: SynapseColors.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Absorbing memories...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
