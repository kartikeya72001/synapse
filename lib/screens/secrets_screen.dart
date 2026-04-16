import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:uuid/uuid.dart';
import '../models/secret_item.dart';
import '../models/thought.dart';
import '../providers/synapse_provider.dart';
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
  bool _authFailed = false;
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
      setState(() => _authFailed = true);
    }
  }

  Future<void> _loadSecrets() async {
    setState(() => _isLoading = true);
    _secrets = await _secretService.getAllSecrets();
    _revealedValues.clear();
    setState(() => _isLoading = false);
  }

  void _lockVault() {
    setState(() {
      _isAuthenticated = false;
      _authFailed = true;
      _secrets = [];
      _revealedValues.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? SynapseGradients.vaultBgDark : SynapseGradients.vaultBg,
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isDark, theme, colorScheme),
              Expanded(child: _buildBody(isDark, theme, colorScheme)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: SynapseColors.ink.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 18,
                color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
              ),
            ),
          ),
          Text(
            'Vault',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          if (_isAuthenticated)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showAddDialog(theme, colorScheme),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SynapseColors.ink,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _lockVault,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SynapseColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_rounded,
                        size: 18, color: SynapseColors.error),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildBody(bool isDark, ThemeData theme, ColorScheme colorScheme) {
    if (!_isAuthenticated) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SynapseColors.coralLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.fingerprint_rounded,
                size: 40,
                color: SynapseColors.error.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _authFailed ? 'Vault locked' : 'Verifying identity...',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
              ),
            ),
            if (_authFailed) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() => _authFailed = false);
                  _authenticate();
                },
                icon: const Icon(Icons.fingerprint_rounded),
                label: const Text('Unlock with biometrics'),
              ),
            ],
          ],
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: SynapseColors.accent,
          strokeWidth: 2,
        ),
      );
    }

    if (_secrets.isEmpty) return _buildEmptyState(isDark, theme, colorScheme);
    return _buildSecretsList(isDark, theme, colorScheme);
  }

  Widget _buildEmptyState(bool isDark, ThemeData theme, ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: SynapseColors.coralLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.enhanced_encryption_rounded,
                size: 36,
                color: SynapseColors.error.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Vault is sealed',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Store passwords, API keys, bank details,\nand other secrets deep in the vault.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: SynapseColors.inkMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'AES-256 encrypted · Biometric lock only',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                color: SynapseColors.error.withValues(alpha: 0.6),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecretsList(bool isDark, ThemeData theme, ColorScheme colorScheme) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _secrets.length,
      itemBuilder: (context, index) {
        final secret = _secrets[index];
        final isRevealed = _revealedValues.containsKey(secret.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildSecretCard(secret, isRevealed, isDark, theme, colorScheme),
        );
      },
    );
  }

  Widget _buildSecretCard(
    SecretItem secret,
    bool isRevealed,
    bool isDark,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? SynapseColors.darkCard : SynapseColors.coralLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: SynapseColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.key_rounded, size: 14, color: colorScheme.error),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    secret.title,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) => _handleAction(action, secret),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'push',
                      child: Row(
                        children: [
                          Icon(Icons.upload_rounded, size: 18),
                          SizedBox(width: 8),
                          Text('Push to Memories'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: SynapseColors.inkMuted,
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
                style: GoogleFonts.spaceGrotesk(fontSize: 12, color: SynapseColors.inkMuted),
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
                color: isDark
                    ? SynapseColors.darkElevated
                    : Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
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
                            ? (isDark ? SynapseColors.darkInk : SynapseColors.ink)
                            : SynapseColors.inkFaint,
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
                      color: SynapseColors.error,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _copyToClipboard(secret),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 20,
                      color: SynapseColors.accent,
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
                Icon(Icons.access_time_rounded, size: 12, color: SynapseColors.inkFaint),
                const SizedBox(width: 4),
                Text(
                  timeago.format(secret.createdAt),
                  style: GoogleFonts.spaceGrotesk(fontSize: 11, color: SynapseColors.inkMuted),
                ),
                const Spacer(),
                Icon(Icons.lock_rounded, size: 12,
                    color: SynapseColors.error.withValues(alpha: 0.4)),
                const SizedBox(width: 4),
                Text(
                  'AES-256',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    color: SynapseColors.error.withValues(alpha: 0.5),
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
      final decrypted = await _secretService.decryptValue(secret.encryptedValue);
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
      case 'push':
        _confirmPushToMemories(secret);
    }
  }

  void _confirmPushToMemories(SecretItem secret) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Push to Memories?'),
        content: Text(
          'Move "${secret.title}" out of the vault into your regular memories? '
          'The decrypted value will be stored as a note. '
          'Biometric verification is required.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await _pushToMemories(secret);
            },
            icon: const Icon(Icons.fingerprint_rounded, size: 18),
            label: const Text('Verify & Push'),
          ),
        ],
      ),
    );
  }

  Future<void> _pushToMemories(SecretItem secret) async {
    final reAuth = await _secretService.authenticate();
    if (!reAuth) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Biometric verification failed.')),
        );
      }
      return;
    }

    final decrypted = await _secretService.decryptValue(secret.encryptedValue);
    final provider = context.read<SynapseProvider>();

    final thought = Thought(
      id: const Uuid().v4(),
      title: secret.title,
      description: secret.description,
      userNotes: decrypted,
      type: ThoughtType.link,
      category: ThoughtCategory.other,
      tags: const ['from-vault'],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await provider.addThought(thought);

    final keepInVault = await _askKeepInVault();
    if (!keepInVault) {
      await _secretService.deleteSecret(secret.id);
      await _loadSecrets();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${secret.title}" pushed to your memories.'),
        ),
      );
    }
  }

  Future<bool> _askKeepInVault() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keep in Vault?'),
        content: const Text(
          'The secret has been pushed to Memories. '
          'Do you also want to keep a copy in the Vault?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Remove from Vault'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Keep both'),
          ),
        ],
      ),
    );
    return result ?? true;
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
              backgroundColor: SynapseColors.error,
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
                20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.enhanced_encryption_rounded, color: colorScheme.error),
                      const SizedBox(width: 10),
                      Text('Bury a Secret', style: theme.textTheme.headlineSmall),
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
                          obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        ),
                        onPressed: () => setSheetState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty ||
                          valueController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('A secret needs both a name and a value.'),
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
                    icon: const Icon(Icons.lock_rounded, size: 20),
                    label: const Text('Seal in Vault'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
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

  void _showEditDialog(SecretItem secret) async {
    final titleController = TextEditingController(text: secret.title);
    final descController = TextEditingController(text: secret.description ?? '');
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
                20, 24, 20, MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.edit_rounded, color: colorScheme.error),
                      const SizedBox(width: 10),
                      Text('Modify Secret', style: theme.textTheme.headlineSmall),
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
                          obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                        ),
                        onPressed: () => setSheetState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty ||
                          valueController.text.trim().isEmpty) return;
                      final updated = secret.copyWith(
                        title: titleController.text.trim(),
                        description: descController.text.trim().isEmpty
                            ? null
                            : descController.text.trim(),
                      );
                      await _secretService.updateSecret(updated, newValue: valueController.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      _loadSecrets();
                    },
                    icon: const Icon(Icons.save_rounded),
                    label: const Text('Re-seal'),
                    style: FilledButton.styleFrom(
                      backgroundColor: SynapseColors.error,
                      foregroundColor: Colors.white,
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
