import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/permissions.dart';
import '../providers/synapse_provider.dart' show SynapseProvider, AppThemeMode, AppVisualStyle;
import '../services/llm_service.dart';
import '../services/share_handler_service.dart';
import '../services/export_service.dart';
import '../utils/constants.dart';

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

  static const List<int?> _autoDeletePresets = [null, 7, 15, 30, 90, 180, 365];

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

    if (!mounted) return;

    setState(() {
      _selectedProvider = provider == 'openai' ? LlmProvider.openai : LlmProvider.gemini;
      _geminiKeyController.text = geminiKey;
      _openaiKeyController.text = openaiKey;
      _remainingCalls = remaining;
      _autoDeleteDays = autoDelete;
      _backgroundShare = bgShare;
    });
  }

  @override
  void dispose() {
    _persistKeys();
    _geminiKeyController.dispose();
    _openaiKeyController.dispose();
    super.dispose();
  }

  Future<void> _persistKeys() async {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isGlass = SynapseStyle.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: isGlass,
      appBar: AppBar(
        title: Text('Settings', style: theme.appBarTheme.titleTextStyle),
      ),
      body: Container(
        decoration: isGlass
            ? BoxDecoration(
                gradient: isDark
                    ? SynapseColors.gradientAurora
                    : SynapseColors.gradientAuroraLight,
              )
            : null,
        child: ListView(
          padding: EdgeInsets.only(
            left: 20, right: 20, bottom: 20,
            top: isGlass ? kToolbarHeight + MediaQuery.of(context).padding.top + 20 : 20,
          ),
        children: [
          _buildSectionTitle(theme, 'Appearance'),
          _buildThemeSelector(theme, colorScheme),
          const SizedBox(height: 20),
          _buildVisualStyleSelector(theme, colorScheme),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'Auto-Delete'),
          const SizedBox(height: 12),
          _buildAutoDeleteSelector(theme, colorScheme),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'Sharing'),
          const SizedBox(height: 12),
          _buildBackgroundShareToggle(theme, colorScheme),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'Neural Engine'),
          const SizedBox(height: 12),
          _buildInfoCard(theme, colorScheme),
          const SizedBox(height: 16),
          _buildProviderSelector(theme, colorScheme),
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
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: SynapseColors.gradientPrimary,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: SynapseColors.neuroPurple.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _saveSettings,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Commit Config',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'Data'),
          const SizedBox(height: 12),
          _buildGalleryImportCard(theme, colorScheme),
          const SizedBox(height: 12),
          _buildExportCsvCard(theme, colorScheme),
          const SizedBox(height: 32),
          _buildSectionTitle(theme, 'About'),
          const SizedBox(height: 12),
          _buildAboutCard(theme, colorScheme),
        ],
      ),
      ),
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return ShaderMask(
      shaderCallback: (bounds) =>
          SynapseColors.gradientPrimary.createShader(bounds),
      child: Text(
        title,
        style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeData theme, ColorScheme colorScheme) {
    final provider = context.watch<SynapseProvider>();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
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
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVisualStyleSelector(ThemeData theme, ColorScheme colorScheme) {
    final provider = context.watch<SynapseProvider>();
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _themeOption(
            icon: Icons.palette_rounded,
            label: 'Material You',
            isSelected: provider.visualStyle == AppVisualStyle.materialYou,
            onTap: () => provider.setVisualStyle(AppVisualStyle.materialYou),
            colorScheme: colorScheme,
          ),
          _themeOption(
            icon: Icons.blur_on_rounded,
            label: 'Material Glass',
            isSelected: provider.visualStyle == AppVisualStyle.materialGlass,
            onTap: () => provider.setVisualStyle(AppVisualStyle.materialGlass),
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildAutoDeleteSelector(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_delete_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Forget memories older than:',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _autoDeletePresets.map((preset) {
              final isActive = _autoDeleteDays == preset;
              final label = preset == null ? 'Never' : '$preset days';
              return GestureDetector(
                onTap: () async {
                  setState(() => _autoDeleteDays = preset);
                  final prefs = await SharedPreferences.getInstance();
                  if (preset == null) {
                    await prefs.remove(AppConstants.autoDeleteDaysPref);
                  } else {
                    await prefs.setInt(AppConstants.autoDeleteDaysPref, preset);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? colorScheme.primary
                        : colorScheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? colorScheme.primary
                          : colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isActive ? colorScheme.onPrimary : colorScheme.onSurface,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundShareToggle(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text('Process in background',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        subtitle: Text(
          'Save shared links without opening the app',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        value: _backgroundShare,
        activeColor: colorScheme.primary,
        onChanged: (val) async {
          setState(() => _backgroundShare = val);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(AppConstants.backgroundSharePref, val);
        },
      ),
    );
  }

  Widget _buildInfoCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_rounded, color: colorScheme.secondary),
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

  Widget _buildProviderSelector(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
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
            color: isSelected ? colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isSelected ? colorScheme.onPrimary : colorScheme.primary,
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
          onChanged: (_) => _persistKeys(),
        ),
      ],
    );
  }

  Widget _buildGalleryImportCard(ThemeData theme, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _importFromGallery,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.photo_library_rounded, color: colorScheme.primary),
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

  Widget _buildExportCsvCard(ThemeData theme, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: _isExporting ? null : _exportToCsv,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.tertiary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _isExporting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.tertiary,
                      ),
                    )
                  : Icon(Icons.download_rounded, color: colorScheme.tertiary),
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

  Widget _buildAboutCard(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.psychology_rounded,
              size: 40,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          ShaderMask(
            shaderCallback: (bounds) =>
                SynapseColors.gradientPrimary.createShader(bounds),
            child: Text(
              'Synapse',
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: Colors.white),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your Second Brain. Wired by AI.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
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
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.geminiApiKeyPref, _geminiKeyController.text.trim());
    await prefs.setString(AppConstants.openaiApiKeyPref, _openaiKeyController.text.trim());
    await prefs.setString(AppConstants.llmProviderPref, _selectedProvider.name);

    if (_autoDeleteDays == null) {
      await prefs.remove(AppConstants.autoDeleteDaysPref);
    } else {
      await prefs.setInt(AppConstants.autoDeleteDaysPref, _autoDeleteDays!);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Neural config updated.')),
      );
    }
  }
}
