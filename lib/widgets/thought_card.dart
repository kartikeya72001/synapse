import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final card = Container(
      decoration: SynapseDecoration.pastelCard(
        category: thought.category,
        dark: isDark,
      ),
      clipBehavior: Clip.antiAlias,
      child: thought.type == ThoughtType.link
          ? _LinkCard(thought: thought, onCluster: onCluster)
          : _ScreenshotCard(thought: thought, onCluster: onCluster),
    );

    return Dismissible(
      key: Key(thought.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 28),
        decoration: BoxDecoration(
          color: SynapseColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(Icons.delete_outline_rounded,
            color: SynapseColors.error, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

class _LinkCard extends StatelessWidget {
  final Thought thought;
  final VoidCallback? onCluster;
  const _LinkCard({required this.thought, this.onCluster});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage =
        thought.previewImageUrl != null && thought.previewImageUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage)
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 2.2,
                child: CachedNetworkImage(
                  imageUrl: thought.previewImageUrl!,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 200),
                  placeholder: (c, u) => Container(
                    decoration: BoxDecoration(
                      gradient: SynapseGradients.peachWash,
                    ),
                  ),
                  errorWidget: (c, u, e) => Container(
                    decoration: BoxDecoration(
                      gradient: SynapseGradients.peachWash,
                    ),
                    child: Center(
                      child: Icon(Icons.language_rounded,
                          size: 24, color: SynapseColors.inkFaint),
                    ),
                  ),
                ),
              ),
              if (thought.isClassified)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: SynapseColors.success.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded,
                            size: 10, color: Colors.white),
                        const SizedBox(width: 3),
                        Text(
                          'Wired',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(16, hasImage ? 10 : 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!hasImage) const SizedBox(height: 2),
              if (thought.siteName != null && thought.siteName!.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(bottom: 5, top: hasImage ? 0 : 0),
                  child: Text(
                    thought.siteName!.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: SynapseColors.inkMuted,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              Text(
                thought.displayTitle,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? SynapseColors.darkInk : SynapseColors.ink,
                  height: 1.25,
                  letterSpacing: -0.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (thought.description != null &&
                  thought.description!.isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  thought.description!,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    color: SynapseColors.inkMuted,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              _MetaRow(
                  thought: thought,
                  onCluster: onCluster,
                  showWiredBadge: !hasImage),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScreenshotCard extends StatelessWidget {
  final Thought thought;
  final VoidCallback? onCluster;
  const _ScreenshotCard({required this.thought, this.onCluster});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 100,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (thought.imagePath != null)
            SizedBox(
              width: 80,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(thought.imagePath!),
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                      errorBuilder: (c, e, s) => Container(
                        decoration: BoxDecoration(
                          gradient: SynapseGradients.peachWash,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    thought.displayTitle,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? SynapseColors.darkInk
                          : SynapseColors.ink,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
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
  final bool showWiredBadge;
  const _MetaRow({
    required this.thought,
    this.onCluster,
    this.showWiredBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCat =
        thought.category != ThoughtCategory.other || thought.isClassified;

    return Row(
      children: [
        if (hasCat) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? SynapseColors.darkAccent.withValues(alpha: 0.12)
                  : SynapseColors.categoryAccent(thought.category)
                      .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${thought.category.emoji} ${thought.category.label}',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? SynapseColors.darkAccent
                    : SynapseColors.categoryAccent(thought.category),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          timeago.format(thought.createdAt),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            color: SynapseColors.inkFaint,
          ),
        ),
        const Spacer(),
        if (onCluster != null)
          GestureDetector(
            onTap: onCluster,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.workspaces_outline,
                  size: 14, color: SynapseColors.inkFaint),
            ),
          ),
        if (showWiredBadge) ...[
          const SizedBox(width: 4),
          if (thought.isClassified)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: SynapseColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_rounded,
                  size: 10,
                  color: SynapseColors.success),
            )
          else if (thought.type == ThoughtType.link)
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: SynapseColors.inkFaint,
              ),
            ),
        ],
      ],
    );
  }
}
