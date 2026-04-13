import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? SynapseGradients.timelineBgDark : SynapseGradients.timelineBg,
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recall',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your memory timeline',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 13,
                      color: SynapseColors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Consumer<SynapseProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: SynapseColors.accent,
                        strokeWidth: 2,
                      ),
                    );
                  }

                  final allThoughts = List<Thought>.from(provider.items)
                    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                  if (allThoughts.isEmpty) {
                    return _buildEmptyState(isDark);
                  }

                  final grouped = _groupByDatePeriod(allThoughts);

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(0, 8, 16, 100),
                    itemCount: grouped.length,
                    itemBuilder: (context, index) {
                      final entry = grouped[index];
                      return _buildPeriodSection(
                        context, isDark, entry.period, entry.thoughts, provider,
                      );
                    },
                  );
                },
              ),
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
                color: SynapseColors.skyBlueLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.timeline_rounded,
                size: 36,
                color: SynapseColors.ink.withValues(alpha: 0.25),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No memories yet',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your timeline will appear here\nonce you start saving memories.',
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
    if (today.isNotEmpty) groups.add(_TimelineGroup(period: 'Today', thoughts: today));
    if (yesterday.isNotEmpty) groups.add(_TimelineGroup(period: 'Yesterday', thoughts: yesterday));
    if (thisWeek.isNotEmpty) groups.add(_TimelineGroup(period: 'This Week', thoughts: thisWeek));
    if (thisMonth.isNotEmpty) groups.add(_TimelineGroup(period: 'This Month', thoughts: thisMonth));
    if (older.isNotEmpty) groups.add(_TimelineGroup(period: 'Older', thoughts: older));

    return groups;
  }

  Widget _buildPeriodSection(
    BuildContext context,
    bool isDark,
    String period,
    List<Thought> thoughts,
    SynapseProvider provider,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? SynapseColors.darkCard : SynapseColors.skyBlueLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                period,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isDark
                      ? SynapseColors.skyBlueLight
                      : Colors.white.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${thoughts.length}',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6BA3D6),
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
          return _buildTimelineNode(context, isDark, thought, isLast, provider);
        }),
      ],
    );
  }

  Widget _buildTimelineNode(
    BuildContext context,
    bool isDark,
    Thought thought,
    bool isLast,
    SynapseProvider provider,
  ) {
    final catTint = SynapseColors.categoryTint(thought.category, dark: isDark);

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
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Center(
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: SynapseColors.categoryAccent(thought.category)
                                  .withValues(alpha: 0.25),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: SynapseColors.categoryAccent(thought.category),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              SynapseColors.categoryAccent(thought.category)
                                  .withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                          ),
                        ),
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
                  color: isDark ? SynapseColors.darkCard : catTint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    _buildThumbnail(thought),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            thought.displayTitle,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                              color: isDark
                                  ? SynapseColors.darkInk
                                  : SynapseColors.ink,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            timeago.format(thought.createdAt),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 11,
                              color: SynapseColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: SynapseColors.inkFaint,
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

  Widget _buildThumbnail(Thought thought) {
    if (thought.type == ThoughtType.screenshot && thought.imagePath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(thought.imagePath!),
          width: 40, height: 40, fit: BoxFit.cover,
          errorBuilder: (c, e, s) => _buildIconThumbnail(
            Icons.broken_image_rounded, thought.category,
          ),
        ),
      );
    } else if (thought.previewImageUrl != null &&
        thought.previewImageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: thought.previewImageUrl!,
          width: 40, height: 40, fit: BoxFit.cover,
          errorWidget: (c, u, e) => _buildIconThumbnail(
            Icons.language_rounded, thought.category,
          ),
        ),
      );
    }
    return _buildIconThumbnail(
      thought.type == ThoughtType.link
          ? Icons.link_rounded
          : Icons.image_rounded,
      thought.category,
    );
  }

  Widget _buildIconThumbnail(IconData icon, ThoughtCategory cat) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: SynapseColors.categoryAccent(cat).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20,
          color: SynapseColors.categoryAccent(cat).withValues(alpha: 0.5)),
    );
  }
}

class _TimelineGroup {
  final String period;
  final List<Thought> thoughts;
  const _TimelineGroup({required this.period, required this.thoughts});
}
