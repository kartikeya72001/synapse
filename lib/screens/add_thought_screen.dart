import 'package:flutter/material.dart';
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
    final isGlass = SynapseStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: isGlass,
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) =>
              SynapseColors.gradientPrimary.createShader(bounds),
          child: Text(
            'New Synapse',
            style: theme.appBarTheme.titleTextStyle?.copyWith(color: Colors.white),
          ),
        ),
      ),
      body: Container(
        decoration: isGlass
            ? BoxDecoration(
                gradient: isDark
                    ? SynapseColors.gradientAurora
                    : SynapseColors.gradientAuroraLight,
              )
            : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            isGlass ? kToolbarHeight + MediaQuery.of(context).padding.top + 20 : 20,
            20,
            20,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTabSelector(colorScheme),
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

  Widget _buildTabSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _buildTab(
            index: 0,
            icon: Icons.link_rounded,
            label: 'Link',
            colorScheme: colorScheme,
          ),
          _buildTab(
            index: 1,
            icon: Icons.image_rounded,
            label: 'Screenshot',
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  Widget _buildTab({
    required int index,
    required IconData icon,
    required String label,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
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
                size: 20,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.primary,
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
          style: theme.textTheme.headlineSmall,
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
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: SynapseColors.gradientPrimary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _isLoading ? null : _saveLink,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    else
                      const Icon(Icons.save_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _isLoading ? 'Absorbing...' : 'Commit to Memory',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenshotTab(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Capture a memory',
          style: theme.textTheme.headlineSmall,
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
        ),
        const SizedBox(height: 16),
        _buildImagePickerCard(
          icon: Icons.camera_alt_rounded,
          label: 'Take a Photo',
          onTap: () => _pickImage(ImageSource.camera),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildImagePickerCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: colorScheme.primary),
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
