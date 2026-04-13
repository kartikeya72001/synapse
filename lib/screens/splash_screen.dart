import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ringCtrl;
  late final AnimationController _contentCtrl;

  late final Animation<double> _ringScale;
  late final Animation<double> _ringFade;
  late final Animation<double> _brandFade;
  late final Animation<Offset> _brandSlide;
  late final Animation<double> _tagFade;

  @override
  void initState() {
    super.initState();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _contentCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _ringScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _ringFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringCtrl,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
      ),
    );
    _brandFade = CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _brandSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));
    _tagFade = CurvedAnimation(
      parent: _contentCtrl,
      curve: const Interval(0.35, 0.7, curve: Curves.easeOut),
    );

    _ringCtrl.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _contentCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? SynapseGradients.heroDark
                  : SynapseGradients.hero,
            ),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _ringCtrl,
              builder: (context, _) => CustomPaint(
                size: Size(size.width, size.width),
                painter: _GlowRingsPainter(
                  progress: _ringScale.value,
                  opacity: _ringFade.value,
                  isDark: isDark,
                ),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SlideTransition(
                  position: _brandSlide,
                  child: FadeTransition(
                    opacity: _brandFade,
                    child: Text(
                      'synapse',
                      style: GoogleFonts.fraunces(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: isDark
                            ? SynapseColors.darkInk
                            : SynapseColors.ink,
                        letterSpacing: -2.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                FadeTransition(
                  opacity: _tagFade,
                  child: Text(
                    'YOUR SECOND BRAIN',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? SynapseColors.darkInkMuted
                          : SynapseColors.inkMuted,
                      letterSpacing: 3.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowRingsPainter extends CustomPainter {
  final double progress;
  final double opacity;
  final bool isDark;

  _GlowRingsPainter({
    required this.progress,
    required this.opacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width * 0.38;

    final colors = isDark
        ? [SynapseColors.darkAccent, const Color(0xFF4A3565)]
        : [SynapseColors.lavenderWash, SynapseColors.blush];

    for (var i = 3; i >= 0; i--) {
      final t = (i / 3);
      final radius = maxRadius * (0.4 + t * 0.6) * progress;
      final ringOpacity = opacity * (0.15 - t * 0.03);

      final paint = Paint()
        ..color = Color.lerp(colors[0], colors[1], t)!
            .withValues(alpha: ringOpacity)
        ..style = PaintingStyle.fill
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 20 + i * 12);

      canvas.drawCircle(center, radius, paint);
    }

    final innerPaint = Paint()
      ..color = (isDark ? SynapseColors.darkAccent : SynapseColors.accent)
          .withValues(alpha: opacity * 0.08)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, maxRadius * 0.25 * progress, innerPaint);
  }

  @override
  bool shouldRepaint(_GlowRingsPainter old) =>
      progress != old.progress || opacity != old.opacity;
}
