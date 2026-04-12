import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_view.dart';
import '../widgets/library_view.dart';
import 'add_thought_screen.dart';
import 'secrets_screen.dart';
import 'settings_screen.dart';
import 'thought_detail_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _barsVisible = true;
  double _cumulativeDelta = 0;

  static const _hideThreshold = 50.0;

  late final AnimationController _barAnim;
  late final Animation<Offset> _topSlide;
  late final Animation<Offset> _bottomSlide;

  @override
  void initState() {
    super.initState();
    _barAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _topSlide = Tween(
      begin: Offset.zero,
      end: const Offset(0, -2.0),
    ).animate(CurvedAnimation(parent: _barAnim, curve: Curves.easeInOutCubic));
    _bottomSlide = Tween(
      begin: Offset.zero,
      end: const Offset(0, 2.0),
    ).animate(CurvedAnimation(parent: _barAnim, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _barAnim.dispose();
    super.dispose();
  }

  bool _isUserScrolling = false;

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollStartNotification) {
      _isUserScrolling = true;
      _cumulativeDelta = 0;
      return false;
    }

    if (notification is ScrollEndNotification) {
      _isUserScrolling = false;
      _cumulativeDelta = 0;
      return false;
    }

    if (notification is OverscrollNotification) {
      return false;
    }

    if (notification is ScrollUpdateNotification && _isUserScrolling) {
      final delta = notification.scrollDelta ?? 0;
      if (delta.abs() < 0.5) return false;

      _cumulativeDelta += delta;
      _cumulativeDelta = _cumulativeDelta.clamp(
        -_hideThreshold * 2,
        _hideThreshold * 2,
      );

      if (_cumulativeDelta > _hideThreshold && _barsVisible) {
        _barsVisible = false;
        _cumulativeDelta = 0;
        _barAnim.forward();
      } else if (_cumulativeDelta < -_hideThreshold && !_barsVisible) {
        _barsVisible = true;
        _cumulativeDelta = 0;
        _barAnim.reverse();
      }
    }
    return false;
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
    _cumulativeDelta = 0;
    if (!_barsVisible) {
      _barsVisible = true;
      _barAnim.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Consumer<SynapseProvider>(
      builder: (context, provider, _) {
        _handlePendingShare(provider);

        return Scaffold(
          extendBodyBehindAppBar: true,
          extendBody: true,
          body: Stack(
            children: [
              if (SynapseStyle.of(context))
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? SynapseColors.gradientAurora
                          : SynapseColors.gradientAuroraLight,
                    ),
                  ),
                ),

              Positioned.fill(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _handleScrollNotification,
                  child: IndexedStack(
                    index: _currentIndex,
                    children: [
                      ChatView(
                        topPad: topPad + 76,
                        bottomPad: bottomPad + 80,
                      ),
                      LibraryView(
                        topPad: topPad + 76,
                        bottomPad: bottomPad + 80,
                      ),
                    ],
                  ),
                ),
              ),

              // Floating app bar
              Positioned(
                top: topPad + 6,
                left: 12,
                right: 12,
                child: SlideTransition(
                  position: _topSlide,
                  child: _buildFloatingAppBar(theme, colorScheme, isDark),
                ),
              ),

              // Floating bottom nav — always visible
              Positioned(
                bottom: bottomPad + 8,
                left: 16,
                right: 16,
                child: _buildFloatingBottomNav(theme, colorScheme, isDark),
              ),
            ],
          ),
          floatingActionButton: _currentIndex == 1 ? _buildFab() : null,
        );
      },
    );
  }

  void _handlePendingShare(SynapseProvider provider) {
    final pending = provider.pendingSharedThought;
    if (pending != null) {
      provider.consumePendingSharedThought();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _switchTab(1);
        final title = pending.displayTitle;
        final short = title.length > 40 ? '${title.substring(0, 40)}…' : title;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(short, maxLines: 1, overflow: TextOverflow.ellipsis),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                Navigator.push(
                  context,
                  SynapsePageRoute(
                    builder: (_) => ThoughtDetailScreen(item: pending),
                  ),
                );
              },
            ),
          ),
        );
      });
    }
  }

  // ── Floating App Bar ──

  Widget _buildFloatingAppBar(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xDD0D0D1F)
                : const Color(0xE0FFFFFF),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark
                  ? SynapseColors.neuroPurple.withValues(alpha: 0.18)
                  : SynapseColors.neuroPurple.withValues(alpha: 0.10),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: SynapseColors.neuroPurple.withValues(alpha: isDark ? 0.15 : 0.08),
                blurRadius: 30,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: SynapseColors.gradientPrimary,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: SynapseColors.neuroPurple.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Synapse',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 20,
                  color: colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 8),
              Consumer<SynapseProvider>(
                builder: (_, provider, __) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: SynapseColors.neuroPurple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${provider.totalItemCount}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SynapseColors.neuroPurple.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (_currentIndex == 0)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, size: 20),
                  tooltip: 'Clear chat',
                  onPressed: () => _confirmClearChat(),
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
                      Navigator.push(
                        context,
                        SynapsePageRoute(
                          builder: (_) => const TimelineScreen(),
                        ),
                      );
                    case 'vault':
                      Navigator.push(
                        context,
                        SynapsePageRoute(
                          builder: (_) => const SecretsScreen(),
                        ),
                      );
                    case 'settings':
                      Navigator.push(
                        context,
                        SynapsePageRoute(
                          builder: (_) => const SettingsScreen(),
                        ),
                      );
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'timeline',
                    child: Row(children: [
                      Icon(Icons.timeline_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Timeline'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'vault',
                    child: Row(children: [
                      Icon(Icons.shield_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Vault'),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: Row(children: [
                      Icon(Icons.settings_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('Settings'),
                    ]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Floating Bottom Navigation ──

  Widget _buildFloatingBottomNav(
    ThemeData theme,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xDD0D0D1F)
                : const Color(0xE0FFFFFF),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? SynapseColors.neuroPurple.withValues(alpha: 0.15)
                  : SynapseColors.neuroPurple.withValues(alpha: 0.08),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: SynapseColors.neuroPurple.withValues(alpha: isDark ? 0.12 : 0.05),
                blurRadius: 24,
                offset: const Offset(0, -2),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(
                icon: Icons.auto_awesome_rounded,
                label: 'Cortex',
                isActive: _currentIndex == 0,
                isDark: isDark,
                onTap: () => _switchTab(0),
              ),
              _navItem(
                icon: Icons.folder_rounded,
                label: 'Library',
                isActive: _currentIndex == 1,
                isDark: isDark,
                onTap: () => _switchTab(1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? 22 : 18,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: isActive ? SynapseColors.gradientPrimary : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: SynapseColors.neuroPurple.withValues(alpha: 0.4),
                    blurRadius: 14,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive
                  ? Colors.white
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.35)),
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── FAB (only on Library tab) ──

  Widget _buildFab() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 72),
      child: SizedBox(
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
          elevation: 4,
          backgroundColor: SynapseColors.neuroPurple,
          child:
              const Icon(Icons.add_rounded, size: 22, color: Colors.white),
        ),
      ),
    );
  }

  // ── Actions ──

  void _confirmClearChat() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear chat?'),
        content: const Text(
          'This will erase the conversation history. '
          'Your saved memories are not affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<SynapseProvider>().clearChat();
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}
