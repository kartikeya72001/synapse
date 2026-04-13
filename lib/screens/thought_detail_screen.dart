import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme/app_theme.dart';
import '../models/thought.dart';
import '../models/thought_group.dart';
import '../providers/synapse_provider.dart';
import 'group_detail_screen.dart';

class ThoughtDetailScreen extends StatefulWidget {
  final Thought item;
  final List<Thought>? allItems;
  final int? initialIndex;

  const ThoughtDetailScreen({
    super.key,
    required this.item,
    this.allItems,
    this.initialIndex,
  });

  @override
  State<ThoughtDetailScreen> createState() => _ThoughtDetailScreenState();
}

class _ThoughtDetailScreenState extends State<ThoughtDetailScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late List<Thought> _allItems;
  late int _currentIndex;
  late AnimationController _wireShimmer;
  bool _isClassifying = false;
  bool _descriptionExpanded = false;
  bool _markdownExpanded = false;
  static const _descriptionPreviewLength = 150;
  static const _markdownPreviewLength = 200;

  bool _indicatorVisible = true;
  Timer? _indicatorTimer;

  @override
  void initState() {
    super.initState();
    _wireShimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _allItems = widget.allItems ?? [widget.item];
    _currentIndex = widget.initialIndex ??
        _allItems.indexWhere((i) => i.id == widget.item.id).clamp(0, _allItems.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _scheduleHideIndicator();
  }

  void _scheduleHideIndicator() {
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _indicatorVisible = false);
    });
  }

  void _showIndicator() {
    if (!_indicatorVisible) {
      setState(() => _indicatorVisible = true);
    }
    _scheduleHideIndicator();
  }

  bool _onVerticalScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.metrics.axis == Axis.vertical) {
      if (_indicatorVisible) {
        _indicatorTimer?.cancel();
        setState(() => _indicatorVisible = false);
      }
    }
    return false;
  }

  @override
  void dispose() {
    _indicatorTimer?.cancel();
    _wireShimmer.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showDots = _allItems.length > 1;

    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _allItems.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _isClassifying = false;
                _descriptionExpanded = false;
                _markdownExpanded = false;
              });
              _showIndicator();
            },
            itemBuilder: (context, index) {
              return NotificationListener<ScrollNotification>(
                onNotification: _onVerticalScroll,
                child: _buildThoughtPage(_allItems[index]),
              );
            },
          ),
          if (showDots)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _indicatorVisible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: _buildPageIndicator(Theme.of(context).colorScheme),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildThoughtPage(Thought item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0E0A18), const Color(0xFF000000)]
              : [const Color(0xFFF3EDFF), Colors.white],
          stops: const [0.0, 0.4],
        ),
      ),
      child: CustomScrollView(
        slivers: [
        _buildAppBar(item, colorScheme),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryRow(item, theme, colorScheme),
                const SizedBox(height: 16),
                Text(
                  item.displayTitle,
                  style: GoogleFonts.spaceGrotesk(
                    textStyle: theme.textTheme.headlineMedium,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (item.siteName != null) ...[
                  const SizedBox(height: 8),
                  _buildSiteRow(item, theme, colorScheme),
                ],
                const SizedBox(height: 16),
                _buildInfoChips(item, theme, colorScheme),
                // Groups this thought belongs to
                _buildGroupsRow(item, theme, colorScheme),
                
                if (item.type == ThoughtType.screenshot && item.imagePath != null) ...[
                  const SizedBox(height: 20),
                  _buildFullScreenshotViewer(item, colorScheme),
                ],
                if (_shouldShowDescription(item)) ...[
                  const SizedBox(height: 20),
                  _buildExpandableDescription(item, theme, colorScheme),
                ],
                if (item.url != null &&
                    item.url!.isNotEmpty &&
                    item.type == ThoughtType.screenshot) ...[
                  const SizedBox(height: 16),
                  _buildSourceLinkCard(item, theme, colorScheme),
                ],
                if (item.llmSummary != null && item.llmSummary!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildMarkdownSection(item.llmSummary!, theme, colorScheme),
                ],
                const SizedBox(height: 16),
                _buildTagsSection(item, theme, colorScheme),
                if (item.isLinkDead) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colorScheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colorScheme.error.withValues(alpha: 0.3),
                      ),
                      boxShadow: SynapseShadows.soft,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.link_off_rounded, color: colorScheme.error),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Severed Connection',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(color: colorScheme.error),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'This pathway has gone dark.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                _buildActions(item),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _buildGroupsRow(Thought item, ThemeData theme, ColorScheme colorScheme) {
    return FutureBuilder<List<ThoughtGroup>>(
      future: context.read<SynapseProvider>().getGroupsForThought(item.id),
      builder: (context, snapshot) {
        final groups = snapshot.data ?? [];
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...groups.map((g) {
                final c = Color(g.color);
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    SynapsePageRoute(builder: (_) => GroupDetailScreen(group: g)),
                  ),
                  child: Chip(
                    avatar: CircleAvatar(backgroundColor: c, radius: 6),
                    label: Text(g.name),
                    visualDensity: VisualDensity.compact,
                    side: BorderSide(color: c.withValues(alpha: 0.4)),
                  ),
                );
              }),
              ActionChip(
                avatar: Icon(Icons.add_rounded, size: 16, color: colorScheme.primary),
                label: Text(
                  groups.isEmpty ? 'Wire to Cluster' : 'More',
                  style: TextStyle(color: colorScheme.primary, fontSize: 12),
                ),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showAddToGroupSheet(item),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToGroupSheet(Thought item) {
    final provider = context.read<SynapseProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.45,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          expand: false,
          builder: (context, scrollController) {
            return _AddToGroupSheet(
              provider: provider,
              thoughtId: item.id,
              scrollController: scrollController,
              onDone: () {
                Navigator.pop(context);
                setState(() {});
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPageIndicator(ColorScheme colorScheme) {
    final dotCount = _allItems.length;
    // For large lists, show a compact "3 / 12" label instead of many dots
    if (dotCount > 10) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16),
            boxShadow: SynapseShadows.soft,
          ),
          child: Text(
            '${_currentIndex + 1} / $dotCount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
        ),
      );
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          boxShadow: SynapseShadows.soft,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            dotCount,
            (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == _currentIndex ? 10 : 6,
              height: i == _currentIndex ? 10 : 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == _currentIndex
                    ? colorScheme.primary
                    : colorScheme.onSurface.withValues(alpha: 0.25),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(Thought item, ColorScheme colorScheme) {
    final hasHeroImage = item.type == ThoughtType.link &&
        item.previewImageUrl != null &&
        item.previewImageUrl!.isNotEmpty;

    return SliverAppBar(
      expandedHeight: hasHeroImage ? 280 : 0,
      pinned: true,
      stretch: hasHeroImage,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: hasHeroImage ? 0.3 : 0),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: hasHeroImage ? Colors.white : colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: hasHeroImage ? 0.3 : 0),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(Icons.more_horiz_rounded,
                color: hasHeroImage ? Colors.white : colorScheme.onSurface),
            onPressed: () => _showActionsSheet(item),
          ),
        ),
      ],
      flexibleSpace: hasHeroImage
          ? FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.previewImageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(Icons.broken_image_rounded,
                          size: 40,
                          color: colorScheme.onSurface.withValues(alpha: 0.2)),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Widget _buildFullScreenshotViewer(Thought item, ColorScheme colorScheme) {
    return GestureDetector(
      onTap: () => _showFullScreenImage(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: SynapseShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Image.file(
                  File(item.imagePath!),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: colorScheme.error.withValues(alpha: 0.1),
                    child: Center(
                      child: Icon(
                        Icons.broken_image_rounded,
                        size: 48,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.fullscreen_rounded, size: 18, color: colorScheme.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Tap to expand memory',
                      style: TextStyle(fontSize: 12, color: colorScheme.primary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullScreenImage(Thought item) {
    if (item.imagePath == null) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.file(File(item.imagePath!), fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceLinkCard(Thought item, ThemeData theme, ColorScheme colorScheme) {
    final url = item.url!;
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2)),
          boxShadow: SynapseShadows.soft,
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Origin',
                    style: theme.textTheme.titleSmall?.copyWith(color: colorScheme.primary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    url,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 18, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildSiteRow(Thought item, ThemeData theme, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.favicon != null && item.favicon!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: item.favicon!,
              width: 20,
              height: 20,
              errorWidget: (context, url, error) => Icon(
                Icons.language_rounded, size: 20, color: colorScheme.primary,
              ),
            ),
          )
        else
          Icon(Icons.language_rounded, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          item.siteName ?? '',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow(Thought item, ThemeData theme, ColorScheme colorScheme) {
    final isLight = theme.brightness == Brightness.light;
    final categoryInk = isLight ? SynapseColors.accent : SynapseColors.darkAccent;
    return GestureDetector(
      onTap: () => _showCategoryPicker(item),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isLight ? SynapseColors.lavenderLight : SynapseColors.darkCard,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                color: categoryInk.withValues(alpha: 0.15),
              ),
              boxShadow: SynapseShadows.soft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.category.emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  item.category.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: categoryInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.edit_rounded,
                  size: 14,
                  color: categoryInk.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
          if (item.isClassified) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isLight
                    ? SynapseColors.success.withValues(alpha: 0.10)
                    : SynapseColors.success.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: SynapseColors.success.withValues(alpha: 0.28),
                ),
                boxShadow: SynapseShadows.soft,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 14, color: SynapseColors.success),
                  const SizedBox(width: 4),
                  Text(
                    'Wired',
                    style: TextStyle(
                      fontSize: 11,
                      color: SynapseColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCategoryPicker(Thought item) {
    final provider = context.read<SynapseProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Set Signal Type', style: Theme.of(context).textTheme.titleLarge),
              ),
              ...ThoughtCategory.values.map((cat) {
                final isSelected = item.category == cat;
                return ListTile(
                  leading: Text(cat.emoji, style: const TextStyle(fontSize: 20)),
                  title: Text(cat.label),
                  trailing: isSelected ? const Icon(Icons.check_rounded, color: Colors.green) : null,
                  selected: isSelected,
                  onTap: () async {
                    Navigator.pop(ctx);
                    await provider.setCategoryForThought(item.id, cat);
                    _refreshCurrentItem(provider, item.id);
                  },
                );
              }),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _refreshCurrentItem(SynapseProvider provider, String itemId) {
    try {
      final updated = provider.items.firstWhere((t) => t.id == itemId);
      final idx = _allItems.indexWhere((t) => t.id == itemId);
      if (idx >= 0) _allItems[idx] = updated;
    } catch (_) {}
    setState(() {});
  }

  Widget _buildTagsSection(Thought item, ThemeData theme, ColorScheme colorScheme) {
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [SynapseColors.darkCard, SynapseColors.darkElevated]
              : [Colors.white, const Color(0xFFF5F0FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : SynapseColors.accent).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tag_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Tags',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...item.tags.map((tag) => Chip(
                label: Text('#$tag'),
                visualDensity: VisualDensity.compact,
                deleteIcon: Icon(Icons.close_rounded, size: 16, color: colorScheme.error),
                onDeleted: () async {
                  final provider = context.read<SynapseProvider>();
                  await provider.removeTagFromThought(item.id, tag);
                  _refreshCurrentItem(provider, item.id);
                },
              )),
              ActionChip(
                avatar: Icon(Icons.add_rounded, size: 16, color: colorScheme.primary),
                label: Text('+ Signal', style: TextStyle(color: colorScheme.primary, fontSize: 12)),
                visualDensity: VisualDensity.compact,
                onPressed: () => _showAddTagSheet(item),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddTagSheet(Thought item) {
    final controller = TextEditingController();
    final provider = context.read<SynapseProvider>();

    // Collect all existing tags across all thoughts for suggestions
    final allTags = <String>{};
    for (final t in provider.items) {
      allTags.addAll(t.tags);
    }
    final suggestions = allTags.where((t) => !item.tags.contains(t)).toList()..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Add Signal Tag', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Name a new signal...',
                  prefixIcon: const Icon(Icons.tag_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded),
                    onPressed: () async {
                      final tag = controller.text.trim().toLowerCase().replaceAll(' ', '-');
                      if (tag.isNotEmpty) {
                        await provider.addTagToThought(item.id, tag);
                        _refreshCurrentItem(provider, item.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      }
                    },
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (value) async {
                  final tag = value.trim().toLowerCase().replaceAll(' ', '-');
                  if (tag.isNotEmpty) {
                    await provider.addTagToThought(item.id, tag);
                    _refreshCurrentItem(provider, item.id);
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
              ),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Known signals',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: suggestions.take(20).map((tag) {
                    return ActionChip(
                      label: Text('#$tag'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await provider.addTagToThought(item.id, tag);
                        _refreshCurrentItem(provider, item.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoChips(Thought item, ThemeData theme, ColorScheme colorScheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: Icon(
            item.type == ThoughtType.link ? Icons.link_rounded : Icons.image_rounded,
            size: 18,
            color: colorScheme.primary,
          ),
          label: Text(
            item.type == ThoughtType.link ? 'Link' : 'Screenshot',
            style: theme.textTheme.bodySmall,
          ),
          visualDensity: VisualDensity.compact,
        ),
        Chip(
          avatar: Icon(Icons.schedule_rounded, size: 18, color: colorScheme.primary),
          label: Text(timeago.format(item.createdAt), style: theme.textTheme.bodySmall),
          visualDensity: VisualDensity.compact,
        ),
        if (item.ocrText != null && item.ocrText!.isNotEmpty)
          Chip(
            avatar: Icon(Icons.text_snippet_rounded, size: 16, color: colorScheme.tertiary),
            label: Text('OCR indexed', style: theme.textTheme.bodySmall),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String title,
    required IconData icon,
    required Widget child,
    Color? accentColor,
  }) {
    final color = accentColor ?? colorScheme.primary;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [SynapseColors.darkCard, SynapseColors.darkElevated]
              : [Colors.white, const Color(0xFFF8F5FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : SynapseColors.accent).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  bool _shouldShowDescription(Thought item) {
    if (item.description == null || item.description!.isEmpty) return false;
    // Skip if description is effectively the same as the title
    if (item.title != null &&
        item.description!.trim().toLowerCase() ==
            item.title!.trim().toLowerCase()) {
      return false;
    }
    // Skip if the LLM summary already exists and contains the description content
    if (item.llmSummary != null &&
        item.llmSummary!.isNotEmpty &&
        item.llmSummary!.toLowerCase().contains(
            item.description!.substring(
                0, (item.description!.length * 0.5).clamp(0, 80).toInt(),
            ).toLowerCase())) {
      return false;
    }
    return true;
  }

  Widget _buildExpandableDescription(
    Thought item,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final desc = item.description!;
    final isLong = desc.length > _descriptionPreviewLength;
    final displayText = (!isLong || _descriptionExpanded)
        ? desc
        : '${desc.substring(0, _descriptionPreviewLength)}…';

    return _buildSection(
      theme: theme,
      colorScheme: colorScheme,
      title: 'Description',
      icon: Icons.description_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            displayText,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
          if (isLong) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() {
                _descriptionExpanded = !_descriptionExpanded;
              }),
              child: Text(
                _descriptionExpanded ? 'Collapse' : 'Expand memory',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMarkdownSection(
    String markdown,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final isLong = markdown.length > _markdownPreviewLength;
    final displayMarkdown = (!isLong || _markdownExpanded)
        ? markdown
        : '${markdown.substring(0, _markdownPreviewLength)}…';

    final mdStyle = MarkdownStyleSheet(
      p: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      h1: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      h2: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      h3: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      listBullet: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
      strong: const TextStyle(fontWeight: FontWeight.w700),
      blockquoteDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        border: Border(
          left: BorderSide(color: colorScheme.primary, width: 3),
        ),
      ),
      blockquotePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      codeblockDecoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      codeblockPadding: const EdgeInsets.all(10),
    );

    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [SynapseColors.darkCard, const Color(0xFF1E1A2E)]
              : [Colors.white, const Color(0xFFF0EAFC)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : SynapseColors.accent).withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: SynapseGradients.accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'Neural Analysis',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MarkdownBody(
            data: displayMarkdown,
            selectable: true,
            onTapLink: (text, href, title) {
              if (href != null) _launchUrl(href);
            },
            styleSheet: mdStyle,
          ),
          if (isLong) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() {
                _markdownExpanded = !_markdownExpanded;
              }),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _markdownExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _markdownExpanded ? 'Collapse' : 'Expand thought',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(Thought item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        if (item.url != null && item.url!.isNotEmpty)
          Expanded(
            child: GestureDetector(
              onTap: _isClassifying ? null : () => _launchUrl(item.url!),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? SynapseColors.darkCard : SynapseColors.ink,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: isDark ? SynapseColors.darkInk : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Open Link',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? SynapseColors.darkInk : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (item.url != null && item.url!.isNotEmpty) const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _isClassifying ? null : () => _classify(item),
            child: _isClassifying
                ? AnimatedBuilder(
                    animation: _wireShimmer,
                    builder: (context, child) {
                      final dx = _wireShimmer.value * 2 - 0.5;
                      return Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment(dx - 0.5, 0),
                            end: Alignment(dx + 0.5, 0),
                            colors: const [
                              Color(0xFF8B5BD8),
                              Color(0xFFBF9EF7),
                              Color(0xFFA371F2),
                              Color(0xFF8B5BD8),
                            ],
                            stops: const [0.0, 0.35, 0.65, 1.0],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: SynapseColors.accent.withValues(alpha: 0.25),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Wiring...',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  )
                : Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? SynapseColors.darkLavender : SynapseColors.lavenderLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: SynapseColors.accent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.auto_awesome_rounded, size: 16, color: SynapseColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Wire',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: SynapseColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    var cleanUrl = url.trim();
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'https://$cleanUrl';
    }
    final uri = Uri.tryParse(cleanUrl);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open: $cleanUrl')),
        );
      }
    }
  }

  Future<void> _classify(Thought item) async {
    setState(() => _isClassifying = true);
    final provider = context.read<SynapseProvider>();
    final success = await provider.classifyThought(item);
    if (mounted) {
      setState(() => _isClassifying = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Synapse wired!')),
        );
        try {
          final updated = provider.items.firstWhere((t) => t.id == item.id);
          final idx = _allItems.indexWhere((t) => t.id == item.id);
          if (idx >= 0) _allItems[idx] = updated;
        } catch (_) {}
        setState(() {});
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.lastLlmError ?? 'Synaptic failure')),
        );
      }
    }
  }

  void _showActionsSheet(Thought item) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              _actionTile(ctx, Icons.folder_rounded, 'Wire to Cluster',
                  SynapseColors.accent, () {
                Navigator.pop(ctx);
                _showAddToGroupSheet(item);
              }),
              _actionTile(ctx, Icons.share_rounded, 'Share', SynapseColors.skyBlue, () {
                Navigator.pop(ctx);
                if (item.url != null) _launchUrl(item.url!);
              }),
              _actionTile(ctx, Icons.delete_rounded, 'Delete', SynapseColors.error, () {
                Navigator.pop(ctx);
                _handleMenuAction('delete', item);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext ctx,
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        label,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  void _handleMenuAction(String action, Thought item) {
    switch (action) {
      case 'group':
        _showAddToGroupSheet(item);
        break;
      case 'delete':
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Sever this synapse?'),
            content: const Text(
              'This will permanently erase this thought from the brain.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<SynapseProvider>().deleteThought(item.id);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Synapse severed')),
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        break;
      case 'share':
        if (item.url != null && item.url!.isNotEmpty) {
          _launchUrl(item.url!);
        }
        break;
    }
  }
}

class _AddToGroupSheet extends StatefulWidget {
  final SynapseProvider provider;
  final String thoughtId;
  final ScrollController scrollController;
  final VoidCallback onDone;

  const _AddToGroupSheet({
    required this.provider,
    required this.thoughtId,
    required this.scrollController,
    required this.onDone,
  });

  @override
  State<_AddToGroupSheet> createState() => _AddToGroupSheetState();
}

class _AddToGroupSheetState extends State<_AddToGroupSheet> {
  Set<String> _memberGroupIds = {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadMembership();
  }

  Future<void> _loadMembership() async {
    final groups = await widget.provider.getGroupsForThought(widget.thoughtId);
    if (mounted) {
      setState(() {
        _memberGroupIds = groups.map((g) => g.id).toSet();
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final allGroups = widget.provider.groups;

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.folder_rounded, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text('Wire to Cluster', style: theme.textTheme.titleLarge),
              const Spacer(),
              TextButton(
                onPressed: widget.onDone,
                child: const Text('Done'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: !_loaded
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ...allGroups.map((group) {
                      final isMember = _memberGroupIds.contains(group.id);
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(group.color),
                          radius: 16,
                          child: isMember
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                              : null,
                        ),
                        title: Text(group.name),
                        subtitle: group.description != null
                            ? Text(group.description!, maxLines: 1, overflow: TextOverflow.ellipsis)
                            : null,
                        trailing: isMember
                            ? TextButton(
                                onPressed: () async {
                                  await widget.provider.removeThoughtFromGroup(
                                      group.id, widget.thoughtId);
                                  _loadMembership();
                                },
                                child: const Text('Remove'),
                              )
                            : FilledButton.tonal(
                                onPressed: () async {
                                  await widget.provider.addThoughtsToGroup(
                                      group.id, [widget.thoughtId]);
                                  _loadMembership();
                                },
                                child: const Text('Add'),
                              ),
                      );
                    }),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final name = await _showNewGroupDialog(context);
                        if (name != null && name.isNotEmpty) {
                          final group = await widget.provider.createGroup(name);
                          await widget.provider.addThoughtsToGroup(
                              group.id, [widget.thoughtId]);
                          _loadMembership();
                        }
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Form New Cluster'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
        ),
      ],
    );
  }

  Future<String?> _showNewGroupDialog(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Cluster'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Cluster name',
            prefixIcon: Icon(Icons.folder_rounded),
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}
