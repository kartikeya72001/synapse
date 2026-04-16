import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/synapse_provider.dart';
import '../services/onboarding_service.dart';
import '../theme/app_theme.dart';
import '../widgets/chat_view.dart';
import '../widgets/library_view.dart';
import '../widgets/tutorial_overlay.dart';
import 'add_thought_screen.dart';
import 'pulse_screen.dart';
import 'settings_screen.dart';
import 'thought_detail_screen.dart';
import 'timeline_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool startTutorial;

  const HomeScreen({super.key, this.startTutorial = false});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _showTutorial = false;

  final _fabKey = GlobalKey();
  final _bottomNavKey = GlobalKey();
  final List<GlobalKey> _navItemKeys =
      List.generate(5, (_) => GlobalKey());

  void _switchTab(int i) {
    setState(() => _tab = i);
  }

  static const _navItems = [
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Cortex'),
    _NavItem(Icons.auto_awesome_mosaic_outlined, Icons.auto_awesome_mosaic_rounded, 'Memories'),
    _NavItem(Icons.timeline_rounded, Icons.timeline_rounded, 'Recall'),
    _NavItem(Icons.monitor_heart_outlined, Icons.monitor_heart_rounded, 'Pulse'),
    _NavItem(Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.startTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndStartTutorial();
      });
    }
  }

  Future<void> _checkAndStartTutorial() async {
    final shouldShow = await OnboardingService.instance.shouldShowOnStartup();
    if (shouldShow && mounted) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _showTutorial = true);
      });
    }
  }

  void startTutorial() {
    setState(() => _showTutorial = true);
  }

  List<TutorialStep> _buildTutorialSteps() {
    return [
      TutorialStep(
        title: 'Welcome to Synapse',
        description:
            'Your second brain, powered by AI. '
            'Let\'s take a quick tour of all the features '
            'that help you save, organize, and recall anything.',
        icon: Icons.psychology_rounded,
        highlightTarget: false,
      ),
      TutorialStep(
        targetKey: _navItemKeys[0],
        title: 'Cortex — AI Chat',
        description:
            'Ask questions about your saved memories. '
            'Cortex uses AI to search, summarize, and compare '
            'everything you\'ve captured.',
        icon: Icons.chat_bubble_rounded,
        onShow: () => _switchTab(0),
      ),
      TutorialStep(
        targetKey: _navItemKeys[1],
        title: 'Memories — Your Library',
        description:
            'All your saved links, screenshots, and posts live here. '
            'Search, filter by category, create clusters, '
            'and bulk-classify with AI.',
        icon: Icons.auto_awesome_mosaic_rounded,
        onShow: () => _switchTab(1),
      ),
      TutorialStep(
        targetKey: _fabKey,
        title: 'Add a Memory',
        description:
            'Tap the + button to manually save a link or capture '
            'a screenshot. You can also share directly from any app '
            'to Synapse.',
        icon: Icons.add_rounded,
        onShow: () => _switchTab(1),
      ),
      TutorialStep(
        targetKey: _navItemKeys[2],
        title: 'Recall — Timeline',
        description:
            'See your memories organized chronologically — '
            'today, yesterday, this week, and beyond. '
            'Perfect for revisiting recent saves.',
        icon: Icons.timeline_rounded,
        onShow: () => _switchTab(2),
      ),
      TutorialStep(
        targetKey: _navItemKeys[3],
        title: 'Pulse — Analytics',
        description:
            'Visualize your knowledge with stats, charts, '
            'tag clouds, and an interactive knowledge graph. '
            'See how your ideas connect.',
        icon: Icons.monitor_heart_rounded,
        onShow: () => _switchTab(3),
      ),
      TutorialStep(
        targetKey: _navItemKeys[4],
        title: 'Settings',
        description:
            'Customize your theme, choose your AI model and persona, '
            'set auto-delete rules, import/export data, add API keys, '
            'and access the Vault for encrypted secrets.',
        icon: Icons.tune_rounded,
        onShow: () => _switchTab(4),
      ),
      TutorialStep(
        title: 'You\'re All Set!',
        description:
            'Share a link or screenshot from any app to start building '
            'your second brain. The more you save, the smarter Cortex gets.',
        icon: Icons.rocket_launch_rounded,
        highlightTarget: false,
        onShow: () => _switchTab(0),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      const SettingsScreen(),
    ];

    return Stack(
      children: [
        Scaffold(
          extendBody: true,
          body: IndexedStack(
            index: _tab,
            children: [
              for (int i = 0; i < pages.length; i++)
                TickerMode(enabled: _tab == i, child: pages[i]),
            ],
          ),
          bottomNavigationBar: _BottomNav(
            key: _bottomNavKey,
            currentIndex: _tab,
            isDark: isDark,
            onTabTap: _switchTab,
            navItemKeys: _navItemKeys,
          ),
          floatingActionButton: _tab == 1
              ? Container(
                    key: _fabKey,
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
        ),
        if (_showTutorial)
          TutorialOverlay(
            steps: _buildTutorialSteps(),
            onComplete: () {
              if (mounted) {
                setState(() => _showTutorial = false);
                _switchTab(0);
              }
            },
            onSkip: () {
              if (mounted) {
                setState(() => _showTutorial = false);
                _switchTab(0);
              }
            },
          ),
      ],
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
  final List<GlobalKey> navItemKeys;

  const _BottomNav({
    super.key,
    required this.currentIndex,
    required this.isDark,
    required this.onTabTap,
    required this.navItemKeys,
  });

  @override
  State<_BottomNav> createState() => _BottomNavState();
}

class _BottomNavState extends State<_BottomNav> {
  bool get isDark => widget.isDark;
  int get currentIndex => widget.currentIndex;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return RepaintBoundary(
      child: Container(
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
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
              child: Row(
                children: List.generate(
                  HomeScreenState._navItems.length,
                  (i) => Expanded(
                    key: widget.navItemKeys[i],
                    child: _buildNavItem(i),
                  ),
                ),
              ),
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
        return isDark ? const Color(0xFFBF9EF7) : const Color(0xFF8B5BD8);
      default:
        return isDark ? SynapseColors.darkInk : SynapseColors.ink;
    }
  }

  Widget _buildNavItem(int idx) {
    final item = HomeScreenState._navItems[idx];
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
