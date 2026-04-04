import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/thought.dart';
import '../theme/app_theme.dart';

class ThoughtCard extends StatelessWidget {
  final Thought thought;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback? onCluster;

  const ThoughtCard({
    super.key,
    required this.thought,
    required this.onTap,
    required this.onDelete,
    this.onCluster,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGlass = SynapseStyle.of(context);

    Widget card = thought.type == ThoughtType.link
        ? _LinkRow(thought: thought, onCluster: onCluster)
        : _ScreenshotRow(thought: thought, onCluster: onCluster);

    card = Container(
      decoration: isGlass
          ? BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.04),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.65),
                        Colors.white.withValues(alpha: 0.40),
                      ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.70),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            )
          : BoxDecoration(
              color:
                  isDark ? SynapseColors.darkCard : SynapseColors.lightCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark
                    ? SynapseColors.darkCardBorder
                    : SynapseColors.lightCardBorder,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: SynapseColors.neuroPurple
                      .withValues(alpha: isDark ? 0.08 : 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
      clipBehavior: Clip.antiAlias,
      child: card,
    );

    return Dismissible(
      key: Key(thought.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        decoration: BoxDecoration(
          color: theme.colorScheme.error,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final Thought thought;
  final VoidCallback? onCluster;
  const _LinkRow({required this.thought, this.onCluster});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.4);
    final hasImage = thought.previewImageUrl != null &&
        thought.previewImageUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImage)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: CachedNetworkImage(
                    imageUrl: thought.previewImageUrl!,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 150),
                    placeholder: (c, u) => Container(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF0EDFF),
                    ),
                    errorWidget: (c, u, e) => Container(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.04)
                          : const Color(0xFFF0EDFF),
                      child: Icon(Icons.language_rounded,
                          size: 20, color: muted),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Source
                Row(
                  children: [
                    if (thought.favicon != null &&
                        thought.favicon!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: CachedNetworkImage(
                            imageUrl: thought.favicon!,
                            width: 12, height: 12,
                            errorWidget: (c, u, e) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        thought.siteName ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: muted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Title
                Text(
                  thought.displayTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 14,
                    height: 1.25,
                    letterSpacing: -0.2,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                if (thought.description != null &&
                    thought.description!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    thought.description!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.45),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 6),
                _MetaRow(thought: thought, onCluster: onCluster),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenshotRow extends StatelessWidget {
  final Thought thought;
  final VoidCallback? onCluster;
  const _ScreenshotRow({required this.thought, this.onCluster});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 88,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (thought.imagePath != null)
            SizedBox(
              width: 72,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
                child: Image.file(
                  File(thought.imagePath!),
                  fit: BoxFit.cover,
                  cacheWidth: 180,
                  errorBuilder: (c, e, s) => ColoredBox(
                    color: SynapseColors.neuroPurple.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    thought.displayTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.15,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (thought.extractedInfo != null &&
                      thought.extractedInfo!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      thought.extractedInfo!,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _MetaRow(thought: thought, onCluster: onCluster),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final Thought thought;
  final VoidCallback? onCluster;
  const _MetaRow({required this.thought, this.onCluster});

  @override
  Widget build(BuildContext context) {
    final muted =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
    final hasCat = thought.category != ThoughtCategory.other ||
        thought.isClassified;

    return Row(
      children: [
        if (hasCat) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: SynapseColors.neuroPurple.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${thought.category.emoji} ${thought.category.label}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: SynapseColors.neuroPurple.withValues(alpha: 0.7),
              ),
            ),
          ),
          _dot(muted),
        ],
        Text(
          timeago.format(thought.createdAt),
          style: TextStyle(fontSize: 10, color: muted),
        ),
        const Spacer(),
        if (onCluster != null)
          GestureDetector(
            onTap: onCluster,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Icon(Icons.workspaces_outline, size: 14, color: muted),
            ),
          ),
        if (thought.isClassified)
          Icon(Icons.auto_awesome_rounded,
              size: 12, color: SynapseColors.neuroPurple.withValues(alpha: 0.4)),
      ],
    );
  }

  Widget _dot(Color c) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Text('·', style: TextStyle(color: c, fontSize: 10)),
      );
}
