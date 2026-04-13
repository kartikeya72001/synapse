import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/synapse_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_view.dart';
import '../widgets/library_view.dart';
import 'add_thought_screen.dart';
import 'pulse_screen.dart';
import 'secrets_screen.dart';
import 'settings_screen.dart';
import 'thought_detail_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _vaultVisited = false;

  void _switchTab(int i) {
    if (i == 4 && !_vaultVisited) _vaultVisited = true;
    setState(() => _tab = i);
  }

  static const _navItems = [
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Cortex'),
    _NavItem(Icons.auto_awesome_mosaic_outlined, Icons.auto_awesome_mosaic_rounded, 'Memories'),
    _NavItem(Icons.timeline_rounded, Icons.timeline_rounded, 'Recall'),
    _NavItem(Icons.monitor_heart_outlined, Icons.monitor_heart_rounded, 'Pulse'),
    _NavItem(Icons.shield_outlined, Icons.shield_rounded, 'Vault'),
    _NavItem(Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Only rebuild HomeScreen when a new share arrives, not on every provider change
    final hasPending = context.select<SynapseProvider, bool>(
        (p) => p.pendingSharedThought != null);
    if (hasPending) {
      _handlePendingShare(context.read<SynapseProvider>());
    }

    final pages = <Widget>[
      const ChatView(),
      const LibraryView(),
      const TimelineScreen(),
      const PulseScreen(),
      if (_vaultVisited) const SecretsScreen() else const SizedBox.shrink(),
      const SettingsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          for (int i = 0; i < pages.length; i++)
            TickerMode(enabled: _tab == i, child: pages[i]),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _tab,
        isDark: isDark,
        onTabTap: _switchTab,
      ),
      floatingActionButton: _tab == 1
          ? Container(
              decoration: BoxDecoration(
                color: SynapseColors.ink,
                borderRadius: BorderRadius.circular(18),
              ),
              child: FloatingActionButton(
                heroTag: 'add',
                backgroundColor: Colors.transparent,
                elevation: 0,
                onPressed: () async {
                  final p = context.read<SynapseProvider>();
                  await Navigator.push(
                    context,
                    SynapsePageRoute(
                        builder: (_) => const AddThoughtScreen()),
                  );
                  if (mounted) p.loadThoughts();
                },
                child: const Icon(Icons.add_rounded, size: 26),
              ),
            )
          : null,
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
        final short =
            title.length > 40 ? '${title.substring(0, 40)}…' : title;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(short, maxLines: 1, overflow: TextOverflow.ellipsis),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => Navigator.push(
                context,
                SynapsePageRoute(
                  builder: (_) => ThoughtDetailScreen(item: pending),
                ),
              ),
            ),
          ),
        );
      });
    }
  }

}

class _NavItem {
  final IconData outlinedIcon;
  final IconData filledIcon;
  final String label;
  const _NavItem(this.outlinedIcon, this.filledIcon, this.label);
}

class _BottomNav extends StatefulWidget {
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTabTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isDark,
    required this.onTabTap,
  });

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> {
  final _scrollCtrl = ScrollController();
  bool _canScrollRight = true;
  bool _canScrollLeft = false;

  bool get isDark => widget.isDark;
  int get currentIndex => widget.currentIndex;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    final newRight = pos.pixels < pos.maxScrollExtent - 4;
    final newLeft = pos.pixels > 4;
    if (newRight != _canScrollRight || newLeft != _canScrollLeft) {
      setState(() {
        _canScrollRight = newRight;
        _canScrollLeft = newLeft;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final screenWidth = MediaQuery.of(context).size.width;
    final navBarWidth = screenWidth - 32;
    const horizontalPad = 8.0;
    final usableWidth = navBarWidth - horizontalPad * 2;
    final itemWidth = usableWidth / 4.4;

    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            padding: const EdgeInsets.symmetric(
                vertical: 10, horizontal: horizontalPad),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
              ),
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: List.generate(
                      _HomeScreenState._navItems.length,
                      (i) => SizedBox(
                        width: itemWidth,
                        child: _buildNavItem(i),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: _scrollChevron(
                    icon: Icons.chevron_right_rounded,
                    visible: _canScrollRight,
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _scrollChevron(
                    icon: Icons.chevron_left_rounded,
                    visible: _canScrollLeft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _scrollChevron({required IconData icon, required bool visible}) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Center(
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.10),
            ),
            child: Icon(
              icon,
              size: 14,
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }

  Color _pageAccentColor(int idx, bool isDark) {
    switch (idx) {
      case 0:
        return isDark ? const Color(0xFFBF9EF7) : const Color(0xFF8B5BD8);
      case 1:
        return isDark ? const Color(0xFFBF9EF7) : const Color(0xFFA371F2);
      case 2:
        return isDark ? const Color(0xFF64B5F6) : const Color(0xFF5B9BD5);
      case 3:
        return isDark ? const Color(0xFF4DD0B8) : const Color(0xFF00897B);
      case 4:
        return isDark ? const Color(0xFFEF9A9A) : const Color(0xFFD32F2F);
      case 5:
        return isDark ? const Color(0xFFBF9EF7) : const Color(0xFF8B5BD8);
      default:
        return isDark ? SynapseColors.darkInk : SynapseColors.ink;
    }
  }

  Widget _buildNavItem(int idx) {
    final item = _HomeScreenState._navItems[idx];
    final isActive = currentIndex == idx;
    final activeColor = _pageAccentColor(idx, isDark);
    final inactiveColor =
        isDark ? Colors.white.withValues(alpha: 0.5) : SynapseColors.inkMuted;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onTabTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.filledIcon : item.outlinedIcon,
              size: 20,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
