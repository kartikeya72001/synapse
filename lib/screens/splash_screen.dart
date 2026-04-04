import 'dart:math';
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
  late final AnimationController _pulseController;
  late final AnimationController _entryController;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _titleSlide;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;
  late final Animation<double> _ringScale;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
      ),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );
    _ringScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _titleSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOutCubic),
      ),
    );
    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.4, 0.65, curve: Curves.easeOut),
      ),
    );
    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.55, 0.75, curve: Curves.easeOut),
      ),
    );

    _entryController.forward();

    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) widget.onComplete();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGlass = SynapseStyle.of(context);

    final gradient = isGlass
        ? (isDark ? SynapseColors.gradientAurora : SynapseColors.gradientAuroraLight)
        : (isDark
            ? SynapseColors.gradientDarkBg
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
              ));

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: gradient),
        child: Stack(
          children: [
            _buildBackgroundOrbs(isDark),
            Center(
              child: AnimatedBuilder(
                animation: _entryController,
                builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildLogo(isDark),
                    const SizedBox(height: 32),
                    _buildTitle(),
                    const SizedBox(height: 8),
                    _buildSubtitle(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundOrbs(bool isDark) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulse = _pulseController.value;
        return Stack(
          children: [
            Positioned(
              top: -60 + pulse * 10,
              right: -40,
              child: _buildOrb(
                200,
                isDark
                    ? SynapseColors.neuroPurple.withValues(alpha: 0.15)
                    : SynapseColors.neuroPurple.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: -80 + pulse * 15,
              left: -60,
              child: _buildOrb(
                260,
                isDark
                    ? SynapseColors.synapseBlue.withValues(alpha: 0.12)
                    : SynapseColors.synapseBlue.withValues(alpha: 0.06),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).size.height * 0.35,
              left: -30,
              child: _buildOrb(
                120,
                isDark
                    ? SynapseColors.synapseCyan.withValues(alpha: 0.1)
                    : SynapseColors.synapseCyan.withValues(alpha: 0.05),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ScaleTransition(
            scale: _ringScale,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final pulse = 1.0 + _pulseController.value * 0.06;
                return Transform.scale(
                  scale: pulse,
                  child: CustomPaint(
                    size: const Size(140, 140),
                    painter: _GlowRingPainter(
                      color: SynapseColors.neuroPurple,
                      progress: _pulseController.value,
                      isDark: isDark,
                    ),
                  ),
                );
              },
            ),
          ),
          FadeTransition(
            opacity: _logoOpacity,
            child: ScaleTransition(
              scale: _logoScale,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SynapseColors.gradientPrimary,
                  boxShadow: [
                    BoxShadow(
                      color:
                          SynapseColors.neuroPurple.withValues(alpha: 0.4),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Transform.translate(
      offset: Offset(0, _titleSlide.value),
      child: Opacity(
        opacity: _titleOpacity.value,
        child: ShaderMask(
          shaderCallback: (bounds) =>
              SynapseColors.gradientPrimary.createShader(bounds),
          child: Text(
            'SYNAPSE',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 6,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Opacity(
      opacity: _subtitleOpacity.value,
      child: Text(
        'Your Second Brain',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _GlowRingPainter extends CustomPainter {
  final Color color;
  final double progress;
  final bool isDark;

  _GlowRingPainter({
    required this.color,
    required this.progress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: isDark ? 0.2 : 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, radius, glowPaint);

    final arcPaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 2 * pi,
        colors: [
          color.withValues(alpha: 0),
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(progress * 2 * pi),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, arcPaint);
  }

  @override
  bool shouldRepaint(_GlowRingPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
