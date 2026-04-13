import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/onboarding_service.dart';

class TutorialStep {
  final GlobalKey? targetKey;
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onShow;
  final bool highlightTarget;

  const TutorialStep({
    this.targetKey,
    required this.title,
    required this.description,
    required this.icon,
    this.onShow,
    this.highlightTarget = true,
  });
}

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onSkip,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  Rect? _targetRect;
  bool _showOnStartup = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
    _scaleAnim = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutBack),
    );
    _loadPrefs();
    _showStep(0);
  }

  Future<void> _loadPrefs() async {
    final val = await OnboardingService.instance.getShowOnStartup();
    if (mounted) setState(() => _showOnStartup = val);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _showStep(int index) {
    if (index >= widget.steps.length) {
      _finish();
      return;
    }
    _animCtrl.reset();
    final step = widget.steps[index];
    step.onShow?.call();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentStep = index;
        _targetRect = _getTargetRect(step);
      });
      _animCtrl.forward();
    });
  }

  Rect? _getTargetRect(TutorialStep step) {
    if (step.targetKey == null || !step.highlightTarget) return null;
    final ctx = step.targetKey!.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    final position = box.localToGlobal(Offset.zero);
    return Rect.fromLTWH(
      position.dx,
      position.dy,
      box.size.width,
      box.size.height,
    );
  }

  void _next() {
    if (_currentStep < widget.steps.length - 1) {
      _showStep(_currentStep + 1);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      _showStep(_currentStep - 1);
    }
  }

  void _skip() {
    _finish();
    widget.onSkip?.call();
  }

  Future<void> _finish() async {
    await OnboardingService.instance.markCompleted();
    await OnboardingService.instance.setShowOnStartup(_showOnStartup);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final step = widget.steps[_currentStep];
    final isLast = _currentStep == widget.steps.length - 1;
    final isFirst = _currentStep == 0;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {},
              child: AnimatedBuilder(
                animation: _fadeAnim,
                builder: (_, _) => CustomPaint(
                  painter: _SpotlightPainter(
                    targetRect: _targetRect,
                    opacity: _fadeAnim.value * 0.82,
                    isDark: isDark,
                  ),
                  size: size,
                ),
              ),
            ),
          ),

          if (_targetRect != null)
            AnimatedBuilder(
              animation: _fadeAnim,
              builder: (_, _) => Positioned(
                left: _targetRect!.left - 6,
                top: _targetRect!.top - 6,
                width: _targetRect!.width + 12,
                height: _targetRect!.height + 12,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: _fadeAnim.value,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: SynapseColors.accent.withValues(alpha: 0.7),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: SynapseColors.accent.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          _buildTooltipCard(context, step, isLast, isFirst, isDark, size),
        ],
      ),
    );
  }

  Widget _buildTooltipCard(
    BuildContext context,
    TutorialStep step,
    bool isLast,
    bool isFirst,
    bool isDark,
    Size screenSize,
  ) {
    final cardWidth = screenSize.width - 48;
    double top;
    double left = 24;

    if (_targetRect != null) {
      final targetCenter = _targetRect!.center.dy;
      final screenMid = screenSize.height / 2;
      if (targetCenter < screenMid) {
        top = _targetRect!.bottom + 20;
      } else {
        top = _targetRect!.top - 260;
      }
      top = top.clamp(60, screenSize.height - 300);
    } else {
      top = screenSize.height / 2 - 130;
    }

    return AnimatedBuilder(
      animation: _fadeAnim,
      builder: (_, child) => Positioned(
        left: left,
        top: top,
        width: cardWidth,
        child: Opacity(
          opacity: _fadeAnim.value,
          child: Transform.scale(
            scale: _scaleAnim.value,
            child: child,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0xFF2A2440), const Color(0xFF1E1A2E)]
                : [Colors.white, const Color(0xFFF8F4FF)],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: SynapseColors.accent.withValues(alpha: isDark ? 0.3 : 0.15),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
              blurRadius: 30,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: SynapseGradients.accent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(step.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? SynapseColors.darkInk
                              : SynapseColors.ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Step ${_currentStep + 1} of ${widget.steps.length}',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: SynapseColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: _skip,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Skip',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SynapseColors.inkMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              step.description,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13.5,
                height: 1.5,
                color: isDark
                    ? SynapseColors.darkInk.withValues(alpha: 0.85)
                    : SynapseColors.ink.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 8),
            _buildProgressDots(isDark),
            const SizedBox(height: 16),
            if (isLast) _buildStartupToggle(isDark),
            Row(
              children: [
                if (!isFirst)
                  GestureDetector(
                    onTap: _prev,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.arrow_back_rounded,
                              size: 14, color: SynapseColors.inkMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Back',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: SynapseColors.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const Spacer(),
                GestureDetector(
                  onTap: _next,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: SynapseGradients.accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: SynapseColors.accent.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isLast ? 'Get Started' : 'Next',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          isLast
                              ? Icons.check_rounded
                              : Icons.arrow_forward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressDots(bool isDark) {
    return Row(
      children: List.generate(widget.steps.length, (i) {
        final isActive = i == _currentStep;
        final isPast = i < _currentStep;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: isActive ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.only(right: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: isActive
                ? SynapseColors.accent
                : isPast
                    ? SynapseColors.accent.withValues(alpha: 0.4)
                    : (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.1),
          ),
        );
      }),
    );
  }

  Widget _buildStartupToggle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () async {
          final newVal = !_showOnStartup;
          setState(() => _showOnStartup = newVal);
        },
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: _showOnStartup
                    ? SynapseColors.accent
                    : Colors.transparent,
                border: Border.all(
                  color: _showOnStartup
                      ? SynapseColors.accent
                      : SynapseColors.inkFaint,
                  width: 1.5,
                ),
              ),
              child: _showOnStartup
                  ? const Icon(Icons.check_rounded,
                      size: 12, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              'Show this guide on every startup',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 12,
                color: SynapseColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double opacity;
  final bool isDark;

  _SpotlightPainter({
    required this.targetRect,
    required this.opacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isDark ? Colors.black : const Color(0xFF1A1330))
          .withValues(alpha: opacity);

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final rr = RRect.fromRectAndRadius(
      targetRect!.inflate(8),
      const Radius.circular(16),
    );

    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rr);
    path.fillType = PathFillType.evenOdd;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.targetRect != targetRect || old.opacity != opacity;
}
