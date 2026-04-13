import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/thought.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/thought_card.dart';
import '../screens/thought_detail_screen.dart';
import '../screens/group_detail_screen.dart';
import '../screens/settings_screen.dart';

class LibraryView extends StatefulWidget {
  const LibraryView({super.key});

  @override
  State<LibraryView> createState() => _LibraryViewState();
}

class _LibraryViewState extends State<LibraryView> {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<SynapseProvider>(
      builder: (context, provider, _) {
        return PopScope(
          canPop: !_isSelecting && !_isSearching,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              if (_isSelecting) {
                _exitSelectionMode();
              } else if (_isSearching) {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  provider.search('');
                });
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark ? SynapseGradients.libraryBgDark : SynapseGradients.libraryBg,
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildToolbar(isDark, provider),
                  Expanded(child: _buildContent(isDark, provider)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildToolbar(bool isDark, SynapseProvider provider) {
    if (_isSelecting) return _buildSelectionBar(isDark, provider);
    if (_isSearching) return _buildSearchBar(isDark, provider);
    return _buildDefaultBar(isDark, provider);
  }

  Widget _buildDefaultBar(bool isDark, SynapseProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
      child: Row(
        children: [
          Text(
            'Memories',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? SynapseColors.darkAccent.withValues(alpha: 0.12)
                  : SynapseColors.lavenderLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${provider.items.length}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? SynapseColors.darkAccent
                    : SynapseColors.accent,
              ),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _isSearching = true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SynapseColors.ink.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.search_rounded,
                  size: 20, color: SynapseColors.inkMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(bool isDark, SynapseProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? SynapseColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: SynapseShadows.soft,
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {
                setState(() {
                  _isSearching = false;
                  _searchController.clear();
                  provider.search('');
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(Icons.arrow_back_rounded,
                    size: 20, color: SynapseColors.inkMuted),
              ),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search memories...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onChanged: (q) => provider.search(q),
              ),
            ),
            if (provider.isSemanticSearching)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: SynapseColors.accent,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionBar(bool isDark, SynapseProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: _exitSelectionMode,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.close_rounded, size: 22),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${_selectedIds.length} selected',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
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
          GestureDetector(
            onTap: _selectedIds.isEmpty
                ? null
                : () => _deleteSelected(provider),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.delete_outline_rounded,
                  color: SynapseColors.error, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark, SynapseProvider provider) {
    if (provider.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: SynapseColors.accent,
          strokeWidth: 2,
        ),
      );
    }
    if (provider.totalItemCount == 0) return _buildEmptyState(isDark);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        if (!_isSearching && !_isSelecting && provider.totalItemCount > 0)
          _buildActionStrip(isDark, provider),
        if (!_isSearching && !_isSelecting && provider.totalItemCount > 0)
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
        if (!_isSearching && !_isSelecting)
          _buildFilterRow(isDark, provider),
        if (provider.items.isEmpty && provider.isFilterActive)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildNoMatchesState(isDark, provider),
          )
        else
          _buildList(provider),
      ],
    );
  }

  Widget _buildNoMatchesState(bool isDark, SynapseProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: SynapseColors.peachLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.filter_alt_off_rounded,
                  size: 28, color: SynapseColors.inkFaint),
            ),
            const SizedBox(height: 20),
            Text(
              'No matches',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? SynapseColors.darkInk
                    : SynapseColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'No memories match this filter.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                color: SynapseColors.inkMuted,
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () {
                provider.filterByCategory(null);
                provider.filterByGroup(null);
              },
              icon: const Icon(Icons.clear_all_rounded, size: 18),
              label: const Text('Clear filter'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
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
                gradient: RadialGradient(
                  colors: [
                    SynapseColors.lavenderWash.withValues(alpha: 0.5),
                    SynapseColors.lavenderWash.withValues(alpha: 0.0),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: SynapseColors.lavenderLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.layers_outlined,
                      size: 24, color: SynapseColors.accent),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Nothing here yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? SynapseColors.darkInk
                    : SynapseColors.ink,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share a link or screenshot from any app\nto start building your second brain.',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                color: SynapseColors.inkMuted,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildActionStrip(
      bool isDark, SynapseProvider provider) {
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
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          children: [
            if (provider.isClassifyingAll)
              _actionCard(
                icon: Icons.hourglass_top_rounded,
                label:
                    '${provider.classifyProgress}/${provider.classifyTotal}',
                gradient: SynapseGradients.peachWash,
                textColor: SynapseColors.ink,
                onTap: () => provider.cancelClassification(),
              ),
            if (!provider.isClassifyingAll && unclassified > 0)
              _actionCard(
                icon: Icons.auto_awesome_rounded,
                label: 'Classify $unclassified',
                gradient: SynapseGradients.accent,
                textColor: Colors.white,
                onTap: () => _classifyAll(provider),
              ),
            if (hasBundles)
              _actionCard(
                icon: Icons.auto_awesome_mosaic_rounded,
                label: provider.bundleSuggestions.first.suggestedName,
                gradient: LinearGradient(
                  colors: [
                    SynapseColors.success,
                    SynapseColors.success.withValues(alpha: 0.8),
                  ],
                ),
                textColor: Colors.white,
                onTap: () async {
                  final s = provider.bundleSuggestions.first;
                  await provider.acceptBundleSuggestion(s);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cluster "${s.suggestedName}" formed'),
                      ),
                    );
                  }
                },
                trailing: GestureDetector(
                  onTap: () => provider.dismissBundleSuggestion(
                    provider.bundleSuggestions.first,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(Icons.close_rounded,
                        size: 12, color: Colors.white70),
                  ),
                ),
              ),
            if (hasDeadLinks)
              _actionCard(
                icon: provider.filterDeadLinks
                    ? Icons.close_rounded
                    : Icons.link_off_rounded,
                label: provider.filterDeadLinks
                    ? 'Clear filter'
                    : '${provider.deadLinkCount} broken',
                gradient: LinearGradient(
                  colors: [
                    SynapseColors.error,
                    SynapseColors.error.withValues(alpha: 0.8),
                  ],
                ),
                textColor: Colors.white,
                onTap: () => provider.toggleDeadLinkFilter(),
              ),
            if (provider.filterDeadLinks)
              _actionCard(
                icon: Icons.delete_sweep_rounded,
                label: 'Remove all',
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade700,
                    Colors.red.shade500,
                  ],
                ),
                textColor: Colors.white,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Remove all dead links?'),
                      content: const Text(
                          'This will permanently delete all memories with broken links.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Remove',
                              style: TextStyle(color: SynapseColors.error)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    provider.deleteAllDeadLinks();
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _actionCard({
    required IconData icon,
    required String label,
    required Gradient gradient,
    required Color textColor,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(14),
            boxShadow: SynapseShadows.soft,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildFilterRow(
      bool isDark, SynapseProvider provider) {
    final counts = provider.getCategoryCounts();
    final active = ThoughtCategory.values
        .where((c) => (counts[c] ?? 0) > 0)
        .toList();

    return SliverToBoxAdapter(
      child: SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          children: [
            _filterPill(
              label: 'All',
              isSelected: provider.selectedCategory == null &&
                  provider.selectedGroup == null,
              onTap: () {
                provider.filterByCategory(null);
                provider.filterByGroup(null);
              },
            ),
            ...active.map((cat) => _filterPill(
                  label: '${cat.emoji} ${cat.label}',
                  isSelected: provider.selectedCategory == cat,
                  onTap: () => provider.filterByCategory(cat),
                )),
            if (provider.groups.isNotEmpty) ...[
              Container(
                width: 1,
                height: 16,
                margin: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 12),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : SynapseColors.ink.withValues(alpha: 0.06),
              ),
              ...provider.groups.map((g) {
                final isSelected = provider.selectedGroup?.id == g.id;
                return _filterPill(
                  label: g.name,
                  isSelected: isSelected,
                  onTap: () =>
                      provider.filterByGroup(isSelected ? null : g),
                  onLongPress: () => Navigator.push(
                    context,
                    SynapsePageRoute(
                        builder: (_) => GroupDetailScreen(group: g)),
                  ),
                );
              }),
            ],
            GestureDetector(
              onTap: () => _showCreateGroupDialog(provider),
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : SynapseColors.ink.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : SynapseColors.ink.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(Icons.add_rounded,
                    size: 14,
                    color: isDark
                        ? SynapseColors.darkInkMuted
                        : SynapseColors.inkFaint),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark
        ? SynapseColors.accent.withValues(alpha: 0.25)
        : SynapseColors.accent.withValues(alpha: 0.12);
    final unselectedBg = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.white.withValues(alpha: 0.7);
    final selectedText = isDark ? SynapseColors.darkAccent : SynapseColors.accent;
    final unselectedText = isDark ? SynapseColors.darkInkMuted : SynapseColors.inkMuted;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : SynapseColors.ink.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : unselectedBg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
              color: isSelected
                  ? SynapseColors.accent.withValues(alpha: isDark ? 0.4 : 0.2)
                  : borderColor,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? selectedText : unselectedText,
            ),
          ),
        ),
      ),
    );
  }

  SliverPadding _buildList(SynapseProvider provider) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final thought = provider.items[index];
            final isSelected = _selectedIds.contains(thought.id);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _isSelecting
                  ? _buildSelectableCard(thought, isSelected)
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

  Widget _buildSelectableCard(Thought thought, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: isSelected
              ? Border.all(color: SynapseColors.accent, width: 2)
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
              top: 12,
              right: 12,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isSelected
                      ? SynapseColors.accent
                      : (isDark
                          ? SynapseColors.darkCard
                          : Colors.white),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? SynapseColors.accent
                        : SynapseColors.inkFaint,
                    width: 1.5,
                  ),
                  boxShadow: SynapseShadows.soft,
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
        content: Text(
          'Permanently delete $count thought${count > 1 ? 's' : ''}?',
        ),
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
                    '$count thought${count > 1 ? 's' : ''} deleted',
                  ),
                ),
              );
              _exitSelectionMode();
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
          onPressed: () => provider.restoreThought(thought),
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
                      color: SynapseColors.ink.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Add to cluster',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 12),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text('No clusters yet',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            color: SynapseColors.inkMuted,
                          )),
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
                          style: GoogleFonts.spaceGrotesk(fontSize: 14)),
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
