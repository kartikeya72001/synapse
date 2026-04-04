import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/thought.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/thought_card.dart';
import 'thought_detail_screen.dart';
import 'add_thought_screen.dart';
import 'chat_screen.dart';
import 'group_detail_screen.dart';
import 'secrets_screen.dart';
import 'settings_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;
  bool _isSelecting = false;
  final Set<String> _selectedIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelecting = false;
      _selectedIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Consumer<SynapseProvider>(
      builder: (context, provider, _) {
        return PopScope(
          canPop: !_isSelecting,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && _isSelecting) _exitSelectionMode();
          },
          child: _buildBody(theme, colorScheme, provider),
        );
      },
    );
  }

  Widget _buildBody(
      ThemeData theme, ColorScheme colorScheme, SynapseProvider provider) {
    final isGlass = SynapseStyle.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background
          if (isGlass)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? SynapseColors.gradientAurora
                      : SynapseColors.gradientAuroraLight,
                ),
              ),
            ),

          // Scrollable content
          CustomScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(height: topPad + 68),
              ),

              if (!_isSearching &&
                  !_isSelecting &&
                  provider.items.isNotEmpty)
                _buildActionStrip(theme, colorScheme, provider),

              if (!_isSearching && !_isSelecting)
                _buildFilterRow(theme, colorScheme, provider),

              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.items.isEmpty)
                _buildEmptyState(theme)
              else
                _buildList(provider),
            ],
          ),

          // Frosted app bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildFrostedAppBar(theme, colorScheme, provider, topPad),
          ),
        ],
      ),
      floatingActionButton: _isSelecting ? null : _buildFab(),
    );
  }

  // ── Frosted App Bar ──

  Widget _buildFrostedAppBar(ThemeData theme, ColorScheme colorScheme,
      SynapseProvider provider, double topPad) {
    final isGlass = SynapseStyle.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget content = _isSelecting
        ? _buildSelectionRow(theme, colorScheme, provider)
        : _isSearching
            ? _buildSearchRow(theme, colorScheme, provider)
            : _buildTitleRow(theme, colorScheme, provider);

    content = Padding(
      padding: EdgeInsets.fromLTRB(20, topPad + 10, 12, 10),
      child: content,
    );

    if (isGlass) {
      return ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.40)
                  : Colors.white.withValues(alpha: 0.55),
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 0.5,
                ),
              ),
            ),
            child: content,
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? SynapseColors.darkSurface : SynapseColors.lightSurface,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
      ),
      child: content,
    );
  }

  Widget _buildTitleRow(
      ThemeData theme, ColorScheme colorScheme, SynapseProvider provider) {
    return Row(
      children: [
        Text(
          'Synapse',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 24,
            color: SynapseColors.neuroPurple,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: SynapseColors.neuroPurple.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${provider.items.length}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: SynapseColors.neuroPurple.withValues(alpha: 0.7),
            ),
          ),
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.search_rounded, size: 22),
          onPressed: () => setState(() => _isSearching = true),
          visualDensity: VisualDensity.compact,
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded, size: 22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          onSelected: (v) {
            switch (v) {
              case 'timeline':
                Navigator.push(context,
                    SynapsePageRoute(builder: (_) => const TimelineScreen()));
              case 'vault':
                Navigator.push(context,
                    SynapsePageRoute(builder: (_) => const SecretsScreen()));
              case 'settings':
                Navigator.push(context,
                    SynapsePageRoute(builder: (_) => const SettingsScreen()));
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'timeline',
                child: Row(children: [
                  Icon(Icons.timeline_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Timeline'),
                ])),
            PopupMenuItem(
                value: 'vault',
                child: Row(children: [
                  Icon(Icons.shield_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Vault'),
                ])),
            PopupMenuItem(
                value: 'settings',
                child: Row(children: [
                  Icon(Icons.settings_rounded, size: 18),
                  SizedBox(width: 10),
                  Text('Settings'),
                ])),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchRow(
      ThemeData theme, ColorScheme colorScheme, SynapseProvider provider) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 22),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchController.clear();
              provider.search('');
            });
          },
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search thoughts...',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
              hintStyle: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ),
            style: theme.textTheme.bodyLarge,
            onChanged: (q) => provider.search(q),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionRow(
      ThemeData theme, ColorScheme colorScheme, SynapseProvider provider) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 22),
          onPressed: _exitSelectionMode,
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Text(
          '${_selectedIds.length} selected',
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 17),
        ),
        const Spacer(),
        TextButton(
          onPressed: () {
            setState(() {
              if (_selectedIds.length == provider.items.length) {
                _selectedIds.clear();
              } else {
                _selectedIds.addAll(provider.items.map((i) => i.id));
              }
            });
          },
          child: Text(
            _selectedIds.length == provider.items.length ? 'None' : 'All',
          ),
        ),
        IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              color: colorScheme.error, size: 22),
          onPressed:
              _selectedIds.isEmpty ? null : () => _deleteSelected(provider),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  // ── Action Strip ──

  SliverToBoxAdapter _buildActionStrip(
      ThemeData theme, ColorScheme colorScheme, SynapseProvider provider) {
    final unclassified = provider.unclassifiedCount;
    final hasBundles = provider.bundleSuggestions.isNotEmpty;
    final hasDeadLinks = provider.deadLinkCount > 0;

    if (unclassified == 0 &&
        !provider.isClassifyingAll &&
        !hasBundles &&
        !hasDeadLinks) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          children: [
            if (provider.isClassifyingAll)
              _actionChip(
                icon: Icons.hourglass_top_rounded,
                label:
                    '${provider.classifyProgress}/${provider.classifyTotal}',
                color: SynapseColors.synapseCyan,
                onTap: () => provider.cancelClassification(),
              ),
            if (!provider.isClassifyingAll && unclassified > 0)
              _actionChip(
                icon: Icons.auto_awesome_rounded,
                label: 'Classify $unclassified',
                color: SynapseColors.neuroPurple,
                onTap: () => _classifyAll(provider),
              ),
            if (hasBundles)
              _actionChip(
                icon: Icons.auto_awesome_mosaic_rounded,
                label: provider.bundleSuggestions.first.suggestedName,
                color: SynapseColors.cortexTeal,
                onTap: () async {
                  final s = provider.bundleSuggestions.first;
                  await provider.acceptBundleSuggestion(s);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text('Cluster "${s.suggestedName}" formed')),
                    );
                  }
                },
                trailing: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 14),
                  onPressed: () => provider.dismissBundleSuggestion(
                      provider.bundleSuggestions.first),
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ),
            if (hasDeadLinks)
              _actionChip(
                icon: Icons.link_off_rounded,
                label: '${provider.deadLinkCount} broken',
                color: theme.colorScheme.error,
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border:
                Border.all(color: color.withValues(alpha: 0.15), width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }

  // ── Filter Row ──

  SliverToBoxAdapter _buildFilterRow(
      ThemeData theme, ColorScheme colorScheme, SynapseProvider provider) {
    final counts = provider.getCategoryCounts();
    final active = ThoughtCategory.values
        .where((c) => (counts[c] ?? 0) > 0)
        .toList();

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          physics: const BouncingScrollPhysics(),
          children: [
            _filterChip(
              label: 'All',
              isSelected: provider.selectedCategory == null &&
                  provider.selectedGroup == null,
              onTap: () {
                provider.filterByCategory(null);
                provider.filterByGroup(null);
              },
              colorScheme: colorScheme,
            ),
            ...active.map((cat) => _filterChip(
                  label: '${cat.emoji} ${cat.label}',
                  isSelected: provider.selectedCategory == cat,
                  onTap: () => provider.filterByCategory(cat),
                  colorScheme: colorScheme,
                )),
            if (provider.groups.isNotEmpty) ...[
              Container(
                width: 1,
                height: 14,
                margin:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                color: colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              ...provider.groups.map((g) {
                final isSelected = provider.selectedGroup?.id == g.id;
                final c = Color(g.color);
                return _filterChip(
                  label: g.name,
                  isSelected: isSelected,
                  onTap: () =>
                      provider.filterByGroup(isSelected ? null : g),
                  onLongPress: () => Navigator.push(
                    context,
                    SynapsePageRoute(
                      builder: (_) => GroupDetailScreen(group: g),
                    ),
                  ),
                  colorScheme: colorScheme,
                  accentColor: c,
                );
              }),
            ],
            GestureDetector(
              onTap: () => _showCreateGroupDialog(provider),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.onSurface.withValues(alpha: 0.06),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.add_rounded,
                    size: 14,
                    color: colorScheme.onSurface.withValues(alpha: 0.25)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
    VoidCallback? onLongPress,
    Color? accentColor,
  }) {
    final color = accentColor ?? colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 5),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.3)
                  : colorScheme.onSurface.withValues(alpha: 0.05),
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? color
                  : colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  // ── List ──

  SliverPadding _buildList(SynapseProvider provider) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final thought = provider.items[index];
            final isSelected = _selectedIds.contains(thought.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _isSelecting
                  ? _buildSelectableCard(
                      thought, isSelected, Theme.of(context).colorScheme)
                  : GestureDetector(
                      onLongPress: () => _enterSelectionMode(thought),
                      child: ThoughtCard(
                        thought: thought,
                        onTap: () => _openDetail(thought, provider),
                        onDelete: () => _deleteThought(thought),
                        onCluster: () => _showQuickClusterSheet(thought),
                      ),
                    ),
            );
          },
          childCount: provider.items.length,
        ),
      ),
    );
  }

  Widget _buildSelectableCard(
      Thought thought, bool isSelected, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedIds.remove(thought.id);
            if (_selectedIds.isEmpty) _isSelecting = false;
          } else {
            _selectedIds.add(thought.id);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: isSelected
              ? Border.all(color: SynapseColors.neuroPurple, width: 2)
              : null,
        ),
        child: Stack(
          children: [
            AbsorbPointer(
              child: ThoughtCard(
                thought: thought,
                onTap: () {},
                onDelete: () {},
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: isSelected
                      ? SynapseColors.neuroPurple
                      : Colors.white.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? SynapseColors.neuroPurple
                        : Colors.black.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty State ──

  SliverFillRemaining _buildEmptyState(ThemeData theme) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.psychology_rounded,
                size: 52,
                color: SynapseColors.neuroPurple.withValues(alpha: 0.18),
              ),
              const SizedBox(height: 18),
              Text(
                'Nothing here yet',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.25),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Share a link or screenshot from any app\nto start building your second brain.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color:
                      theme.colorScheme.onSurface.withValues(alpha: 0.20),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAB ──

  Widget _buildFab() {
    final isGlass = SynapseStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: FloatingActionButton(
            heroTag: 'chat',
            onPressed: () => Navigator.push(
              context,
              SynapsePageRoute(builder: (_) => const ChatScreen()),
            ),
            elevation: isGlass ? 0 : 2,
            backgroundColor: isGlass
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : Colors.white.withValues(alpha: 0.55))
                : SynapseColors.synapseCyan.withValues(alpha: 0.9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: isGlass
                  ? BorderSide(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white.withValues(alpha: 0.6),
                      width: 0.5,
                    )
                  : BorderSide.none,
            ),
            child: Icon(Icons.auto_awesome_rounded,
                size: 18,
                color: isGlass
                    ? SynapseColors.synapseCyan
                    : Colors.white),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: 50,
          height: 50,
          child: FloatingActionButton(
            heroTag: 'add',
            onPressed: () async {
              final p = context.read<SynapseProvider>();
              await Navigator.push(
                context,
                SynapsePageRoute(builder: (_) => const AddThoughtScreen()),
              );
              if (mounted) p.loadThoughts();
            },
            elevation: isGlass ? 0 : 3,
            backgroundColor: SynapseColors.neuroPurple,
            child:
                const Icon(Icons.add_rounded, size: 22, color: Colors.white),
          ),
        ),
      ],
    );
  }

  // ── Actions ──

  void _enterSelectionMode(Thought thought) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelecting = true;
      _selectedIds.add(thought.id);
    });
  }

  void _deleteSelected(SynapseProvider provider) {
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete thoughts?'),
        content:
            Text('Permanently delete $count thought${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteMultipleThoughts(Set.from(_selectedIds));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '$count thought${count > 1 ? 's' : ''} deleted')),
              );
              _exitSelectionMode();
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

  void _openDetail(Thought thought, SynapseProvider provider) {
    final all = List<Thought>.from(provider.items);
    final idx = all.indexWhere((i) => i.id == thought.id);

    Navigator.push(
      context,
      SynapsePageRoute(
        builder: (_) => ThoughtDetailScreen(
          item: thought,
          allItems: all,
          initialIndex: idx >= 0 ? idx : 0,
        ),
      ),
    ).then((_) => provider.loadThoughts());
  }

  void _deleteThought(Thought thought) {
    final provider = context.read<SynapseProvider>();
    provider.deleteThought(thought.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('"${thought.displayTitle}" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => provider.addThought(thought),
        ),
      ),
    );
  }

  Future<void> _classifyAll(SynapseProvider provider) async {
    final hasKey = await provider.hasApiKey();
    if (!hasKey && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Add an API key in Settings first'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => Navigator.push(
              context,
              SynapsePageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ),
      );
      return;
    }

    final count = await provider.classifyAllThoughts();
    if (mounted) {
      final total = provider.classifyTotal;
      final err = provider.lastClassifyError ?? provider.lastLlmError;
      if (count > 0 && count == total) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count thoughts classified')),
        );
      } else if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count of $total done. ${err ?? ''}'),
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Classification failed'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showCreateGroupDialog(SynapseProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New cluster'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              await provider.createGroup(name);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"$name" created')),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _showQuickClusterSheet(Thought thought) async {
    final provider = context.read<SynapseProvider>();
    final groups = provider.groups;
    final memberGroups = await provider.getGroupsForThought(thought.id);
    final memberIds = memberGroups.map((g) => g.id).toSet();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Add to cluster',
                    style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No clusters yet',
                          style: Theme.of(ctx).textTheme.bodyMedium),
                    ),
                  )
                else
                  ...groups.map((g) {
                    final c = Color(g.color);
                    final isMember = memberIds.contains(g.id);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: c,
                        radius: 10,
                        child: isMember
                            ? const Icon(Icons.check,
                                size: 12, color: Colors.white)
                            : null,
                      ),
                      title: Text(g.name,
                          style: const TextStyle(fontSize: 14)),
                      trailing: isMember
                          ? TextButton(
                              onPressed: () {
                                provider.removeThoughtFromGroup(
                                    g.id, thought.id);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Remove'),
                            )
                          : null,
                      onTap: isMember
                          ? null
                          : () {
                              provider.addThoughtsToGroup(
                                  g.id, [thought.id]);
                              Navigator.pop(ctx);
                            },
                      contentPadding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New cluster'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showCreateAndWireDialog(thought);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateAndWireDialog(Thought thought) {
    final ctrl = TextEditingController();
    final provider = context.read<SynapseProvider>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New cluster'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isEmpty) return;
              final group = await provider.createGroup(name);
              await provider.addThoughtsToGroup(group.id, [thought.id]);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
