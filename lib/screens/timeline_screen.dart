import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/thought.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';
import 'thought_detail_screen.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isGlass = SynapseStyle.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: isGlass,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timeline_rounded, color: colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Text('Timeline', style: theme.appBarTheme.titleTextStyle),
          ],
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
        child: Consumer<SynapseProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final allThoughts = List<Thought>.from(provider.items)
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (allThoughts.isEmpty) {
              return _buildEmptyState(theme, colorScheme);
            }

            final grouped = _groupByDatePeriod(allThoughts);

            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                0,
                isGlass ? kToolbarHeight + MediaQuery.of(context).padding.top + 8 : 8,
                16,
                40,
              ),
              itemCount: grouped.length,
              itemBuilder: (context, index) {
                final entry = grouped[index];
                return _buildPeriodSection(
                  context,
                  theme,
                  colorScheme,
                  entry.period,
                  entry.thoughts,
                  provider,
                );
              },
            );
          },
        ),
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
                color: SynapseColors.neuroPurple.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: ShaderMask(
                shaderCallback: (bounds) =>
                    SynapseColors.gradientPrimary.createShader(bounds),
                child: Icon(
                  Icons.timeline_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('No memories yet', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Your neural timeline will appear here\nonce the first synapses fire.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<_TimelineGroup> _groupByDatePeriod(List<Thought> thoughts) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));
    final weekStart = todayStart.subtract(const Duration(days: 7));
    final monthStart = todayStart.subtract(const Duration(days: 30));

    final today = <Thought>[];
    final yesterday = <Thought>[];
    final thisWeek = <Thought>[];
    final thisMonth = <Thought>[];
    final older = <Thought>[];

    for (final t in thoughts) {
      if (t.createdAt.isAfter(todayStart) ||
          t.createdAt.isAtSameMomentAs(todayStart)) {
        today.add(t);
      } else if (t.createdAt.isAfter(yesterdayStart) ||
          t.createdAt.isAtSameMomentAs(yesterdayStart)) {
        yesterday.add(t);
      } else if (t.createdAt.isAfter(weekStart)) {
        thisWeek.add(t);
      } else if (t.createdAt.isAfter(monthStart)) {
        thisMonth.add(t);
      } else {
        older.add(t);
      }
    }

    final groups = <_TimelineGroup>[];
    if (today.isNotEmpty) {
      groups.add(_TimelineGroup(period: 'Today', thoughts: today));
    }
    if (yesterday.isNotEmpty) {
      groups.add(_TimelineGroup(period: 'Yesterday', thoughts: yesterday));
    }
    if (thisWeek.isNotEmpty) {
      groups.add(_TimelineGroup(period: 'This Week', thoughts: thisWeek));
    }
    if (thisMonth.isNotEmpty) {
      groups.add(_TimelineGroup(period: 'This Month', thoughts: thisMonth));
    }
    if (older.isNotEmpty) {
      groups.add(_TimelineGroup(period: 'Older', thoughts: older));
    }

    return groups;
  }

  Widget _buildPeriodSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    String period,
    List<Thought> thoughts,
    SynapseProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: SynapseColors.neuroPurple.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  period,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: SynapseColors.neuroPurple,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${thoughts.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        ),
        ...thoughts.asMap().entries.map((entry) {
          final index = entry.key;
          final thought = entry.value;
          final isLast = index == thoughts.length - 1;

          return _buildTimelineNode(
            context,
            theme,
            colorScheme,
            thought,
            isLast,
            provider,
          );
        }),
      ],
    );
  }

  Widget _buildTimelineNode(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    Thought thought,
    bool isLast,
    SynapseProvider provider,
  ) {
    return IntrinsicHeight(
      child: GestureDetector(
        onTap: () {
          final allThoughts = List<Thought>.from(provider.items);
          final idx = allThoughts.indexWhere((i) => i.id == thought.id);

          Navigator.push(
            context,
            SynapsePageRoute(
              builder: (_) => ThoughtDetailScreen(
                item: thought,
                allItems: allThoughts,
                initialIndex: idx >= 0 ? idx : 0,
              ),
            ),
          );
        },
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      color: SynapseColors.neuroPurple,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: SynapseColors.neuroPurple.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: SynapseColors.neuroPurple.withValues(alpha: 0.20),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.15),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildThumbnail(thought, colorScheme),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thought.displayTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 14,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeago.format(thought.createdAt),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                thought.type == ThoughtType.link
                                    ? Icons.link_rounded
                                    : Icons.image_rounded,
                                size: 12,
                                color: colorScheme.onSurface
                                    .withValues(alpha: 0.4),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _buildCategoryBadge(thought, colorScheme),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colorScheme.onSurface.withValues(alpha: 0.25),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(Thought thought, ColorScheme colorScheme) {
    Widget thumbnail;

    if (thought.type == ThoughtType.screenshot &&
        thought.imagePath != null) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(thought.imagePath!),
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildIconThumbnail(Icons.broken_image_rounded, colorScheme),
        ),
      );
    } else if (thought.previewImageUrl != null &&
        thought.previewImageUrl!.isNotEmpty) {
      thumbnail = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: thought.previewImageUrl!,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) =>
              _buildIconThumbnail(Icons.language_rounded, colorScheme),
        ),
      );
    } else if (thought.type == ThoughtType.link) {
      thumbnail =
          _buildIconThumbnail(Icons.link_rounded, colorScheme);
    } else {
      thumbnail =
          _buildIconThumbnail(Icons.image_rounded, colorScheme);
    }

    return thumbnail;
  }

  Widget _buildIconThumbnail(IconData icon, ColorScheme colorScheme) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: SynapseColors.neuroPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: SynapseColors.neuroPurple.withValues(alpha: 0.5)),
    );
  }

  Widget _buildCategoryBadge(Thought thought, ColorScheme colorScheme) {
    if (thought.category == ThoughtCategory.other && !thought.isClassified) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: SynapseColors.neuroPurple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(thought.category.emoji, style: const TextStyle(fontSize: 9)),
          const SizedBox(width: 3),
          Text(
            thought.category.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: SynapseColors.neuroPurple,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineGroup {
  final String period;
  final List<Thought> thoughts;

  const _TimelineGroup({
    required this.period,
    required this.thoughts,
  });
}
