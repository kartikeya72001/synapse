import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/synapse_provider.dart';
import '../services/share_handler_service.dart';
import '../theme/app_theme.dart';

class AddThoughtScreen extends StatefulWidget {
  const AddThoughtScreen({super.key});

  @override
  State<AddThoughtScreen> createState() => _AddThoughtScreenState();
}

class _AddThoughtScreenState extends State<AddThoughtScreen> {
  final _urlController = TextEditingController();
  final _shareHandler = ShareHandlerService();
  bool _isLoading = false;
  int _selectedTab = 0;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'New Memory',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.appBarTheme.foregroundColor ?? colorScheme.onSurface,
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? SynapseGradients.libraryBgDark : SynapseGradients.libraryBg,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabSelector(context),
              const SizedBox(height: 32),
              Expanded(
                child: _selectedTab == 0
                    ? _buildLinkTab(theme, colorScheme)
                    : _buildScreenshotTab(theme, colorScheme),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: SynapseDecoration.card(dark: isDark),
      child: Row(
        children: [
          _buildTab(
            index: 0,
            icon: Icons.link_rounded,
            label: 'Link',
          ),
          _buildTab(
            index: 1,
            icon: Icons.image_rounded,
            label: 'Screenshot',
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? SynapseColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? Colors.white : SynapseColors.inkMuted,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : SynapseColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinkTab(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Feed a link',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Drop any URL and the brain will absorb it instantly.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _urlController,
          decoration: const InputDecoration(
            hintText: 'https://...',
            prefixIcon: Icon(Icons.link_rounded),
          ),
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _saveLink(),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: SynapseColors.ink,
            borderRadius: BorderRadius.circular(14),
          ),
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _saveLink,
            icon: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(_isLoading ? 'Saving...' : 'Save Memory'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              disabledBackgroundColor: Colors.transparent,
              disabledForegroundColor: Colors.white70,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotTab(ThemeData theme, ColorScheme colorScheme) {
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Capture a memory',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Import a visual memory from your gallery.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 32),
        _buildImagePickerCard(
          icon: Icons.photo_library_rounded,
          label: 'Choose from Gallery',
          onTap: () => _pickImage(ImageSource.gallery),
          colorScheme: colorScheme,
          isDark: isDark,
        ),
        const SizedBox(height: 16),
        _buildImagePickerCard(
          icon: Icons.camera_alt_rounded,
          label: 'Take a Photo',
          onTap: () => _pickImage(ImageSource.camera),
          colorScheme: colorScheme,
          isDark: isDark,
        ),
      ],
    );
  }

  Widget _buildImagePickerCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: SynapseDecoration.card(dark: isDark),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SynapseColors.lavenderLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: SynapseColors.accent),
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.chevron_right_rounded,
              color: colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveLink() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feed the brain a URL first.')),
      );
      return;
    }

    if (!Uri.tryParse(url)!.hasScheme) {
      _urlController.text = 'https://$url';
    }

    setState(() => _isLoading = true);

    try {
      final thought =
          await _shareHandler.saveLink(_urlController.text.trim());
      if (mounted) {
        context.read<SynapseProvider>().addThought(thought);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory absorbed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final thought = await _shareHandler.saveImage(image.path);
      if (mounted) {
        context.read<SynapseProvider>().addThought(thought);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Memory absorbed!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }
}
