import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/secret_item.dart';
import '../services/secret_service.dart';
import '../theme/app_theme.dart';

class SecretsScreen extends StatefulWidget {
  const SecretsScreen({super.key});

  @override
  State<SecretsScreen> createState() => _SecretsScreenState();
}

class _SecretsScreenState extends State<SecretsScreen> {
  final SecretService _secretService = SecretService();
  List<SecretItem> _secrets = [];
  bool _isAuthenticated = false;
  bool _isLoading = true;
  final Map<String, String> _revealedValues = {};

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    final success = await _secretService.authenticate();
    if (success) {
      setState(() => _isAuthenticated = true);
      await _loadSecrets();
    } else if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _loadSecrets() async {
    setState(() => _isLoading = true);
    _secrets = await _secretService.getAllSecrets();
    _revealedValues.clear();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGlass = SynapseStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_isAuthenticated) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.fingerprint_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text('Verifying identity...', style: theme.textTheme.titleLarge),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: isGlass,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.shield_rounded,
                size: 20,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(width: 10),
            ShaderMask(
              shaderCallback: (bounds) =>
                  SynapseColors.gradientPrimary.createShader(bounds),
              child: Text(
                'Vault',
                style: theme.appBarTheme.titleTextStyle
                    ?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_rounded),
            tooltip: 'Seal the vault',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Container(
        decoration: isGlass
            ? BoxDecoration(
                gradient: isDark
                    ? SynapseColors.gradientAurora
                    : SynapseColors.gradientAuroraLight,
              )
            : null,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _secrets.isEmpty
            ? _buildEmptyState(theme, colorScheme)
            : _buildSecretsList(theme, colorScheme),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(theme, colorScheme),
        backgroundColor: colorScheme.error,
        foregroundColor: colorScheme.onError,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    SynapseColors.gradientPrimary.createShader(bounds),
                child: Icon(
                  Icons.enhanced_encryption_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Vault is sealed', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Store passwords, API keys, bank details,\nand other secrets deep in the vault.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'AES-256 encrypted. Biometric lock only.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.error.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecretsList(ThemeData theme, ColorScheme colorScheme) {
    final isGlass = SynapseStyle.of(context);
    final topPadding = isGlass
        ? kToolbarHeight + MediaQuery.of(context).padding.top + 12
        : 12.0;
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, 100),
      itemCount: _secrets.length,
      itemBuilder: (context, index) {
        final secret = _secrets[index];
        final isRevealed = _revealedValues.containsKey(secret.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildSecretCard(secret, isRevealed, theme, colorScheme),
        );
      },
    );
  }

  Widget _buildSecretCard(
    SecretItem secret,
    bool isRevealed,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Icon(Icons.key_rounded, size: 18, color: colorScheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    secret.title,
                    style: theme.textTheme.titleLarge?.copyWith(fontSize: 15),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) => _handleAction(action, secret),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          if (secret.description != null && secret.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Text(
                secret.description!,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isRevealed
                          ? _revealedValues[secret.id]!
                          : '••••••••••••••••',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        color: isRevealed
                            ? colorScheme.onSurface
                            : colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                      maxLines: isRevealed ? 5 : 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _toggleReveal(secret),
                    child: Icon(
                      isRevealed
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 20,
                      color: colorScheme.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _copyToClipboard(secret),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 12,
                  color: colorScheme.onSurface.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 4),
                Text(
                  timeago.format(secret.createdAt),
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                ),
                const Spacer(),
                Icon(
                  Icons.lock_rounded,
                  size: 12,
                  color: colorScheme.error.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 4),
                Text(
                  'AES-256',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: colorScheme.error.withValues(alpha: 0.5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReveal(SecretItem secret) async {
    if (_revealedValues.containsKey(secret.id)) {
      setState(() => _revealedValues.remove(secret.id));
    } else {
      final decrypted = await _secretService.decryptValue(
        secret.encryptedValue,
      );
      setState(() => _revealedValues[secret.id] = decrypted);
    }
  }

  Future<void> _copyToClipboard(SecretItem secret) async {
    final decrypted = await _secretService.decryptValue(secret.encryptedValue);
    await Clipboard.setData(ClipboardData(text: decrypted));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${secret.title}" extracted to clipboard'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _handleAction(String action, SecretItem secret) {
    switch (action) {
      case 'edit':
        _showEditDialog(secret);
      case 'delete':
        _confirmDelete(secret);
    }
  }

  void _confirmDelete(SecretItem secret) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Destroy this secret?'),
        content: Text('Permanently purge "${secret.title}" from the vault?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _secretService.deleteSecret(secret.id);
              _loadSecrets();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddDialog(ThemeData theme, ColorScheme colorScheme) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final valueController = TextEditingController();
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.enhanced_encryption_rounded,
                        color: colorScheme.error,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Bury a Secret',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Gmail Password, Bank IFSC...',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g. Personal account, SBI savings...',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: valueController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Secret Value',
                      hintText: 'The password, key, or secret...',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
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
                        onTap: () async {
                          if (titleController.text.trim().isEmpty ||
                              valueController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'A secret needs both a name and a value.',
                                ),
                              ),
                            );
                            return;
                          }
                          await _secretService.addSecret(
                            title: titleController.text.trim(),
                            description: descController.text.trim().isEmpty
                                ? null
                                : descController.text.trim(),
                            value: valueController.text,
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadSecrets();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.lock_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Seal in Vault',
                                style: TextStyle(
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
              ),
            );
          },
        );
      },
    );
  }

  void _showEditDialog(SecretItem secret) async {
    final titleController = TextEditingController(text: secret.title);
    final descController = TextEditingController(
      text: secret.description ?? '',
    );
    final valueController = TextEditingController();
    bool obscure = true;

    final decrypted = await _secretService.decryptValue(secret.encryptedValue);
    valueController.text = decrypted;

    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                24,
                20,
                MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_rounded, color: colorScheme.error),
                      const SizedBox(width: 10),
                      Text(
                        'Modify Secret',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      prefixIcon: Icon(Icons.description_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: valueController,
                    obscureText: obscure,
                    decoration: InputDecoration(
                      labelText: 'Secret Value',
                      prefixIcon: const Icon(Icons.key_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                        ),
                        onPressed: () =>
                            setSheetState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty ||
                          valueController.text.trim().isEmpty) {
                        return;
                      }
                      final updated = secret.copyWith(
                        title: titleController.text.trim(),
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                      );
                      await _secretService.updateSecret(
                        updated,
                        newValue: valueController.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadSecrets();
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Re-seal'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
