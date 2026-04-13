import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  bool _vaultVisited = false;

  void _switchTab(int i) {
    if (i == 3 && !_vaultVisited) _vaultVisited = true;
    setState(() => _tab = i);
  }

  static const _navItems = [
    _NavItem(Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Cortex'),
    _NavItem(Icons.auto_awesome_mosaic_outlined, Icons.auto_awesome_mosaic_rounded, 'Memories'),
    _NavItem(Icons.timeline_rounded, Icons.timeline_rounded, 'Recall'),
    _NavItem(Icons.shield_outlined, Icons.shield_rounded, 'Vault'),
    _NavItem(Icons.tune_outlined, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<SynapseProvider>(
      builder: (context, provider, _) {
        _handlePendingShare(provider);

        return Scaffold(
          body: IndexedStack(
            index: _tab,
            children: [
              const ChatView(),
              const LibraryView(),
              const TimelineScreen(),
              if (_vaultVisited)
                const SecretsScreen()
              else
                const SizedBox.shrink(),
              const SettingsScreen(),
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

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isDark;
  final ValueChanged<int> onTabTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isDark,
    required this.onTabTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPad, top: 6),
      decoration: BoxDecoration(
        color: isDark ? SynapseColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          _HomeScreenState._navItems.length,
          (i) => _buildNavItem(i),
        ),
      ),
    );
  }

  Widget _buildNavItem(int idx) {
    final item = _HomeScreenState._navItems[idx];
    final isActive = currentIndex == idx;
    final activeColor = isDark ? SynapseColors.darkInk : SynapseColors.ink;
    final inactiveColor =
        isDark ? SynapseColors.darkInkMuted : SynapseColors.inkFaint;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTabTap(idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.filledIcon : item.outlinedIcon,
              size: 22,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: GoogleFonts.dmSans(
                fontSize: 10,
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
