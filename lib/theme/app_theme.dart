import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SynapseColors {
  static const neuroPurple = Color(0xFF7C3AED);
  static const neuroViolet = Color(0xFF8B5CF6);
  static const synapseBlue = Color(0xFF3B82F6);
  static const synapseCyan = Color(0xFF06B6D4);
  static const cortexTeal = Color(0xFF14B8A6);
  static const plasmaGreen = Color(0xFF10B981);
  static const neuralPink = Color(0xFFEC4899);
  static const axonOrange = Color(0xFFF59E0B);

  static const darkSurface = Color(0xFF0B0B16);
  static const darkCard = Color(0xFF14142A);
  static const darkCardBorder = Color(0xFF222240);
  static const darkElevated = Color(0xFF18182E);

  static const lightSurface = Color(0xFFF7F5FF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardBorder = Color(0xFFE8E4F8);
  static const lightElevated = Color(0xFFF0EDFF);

  static const gradientPrimary = LinearGradient(
    colors: [neuroPurple, synapseBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientAccent = LinearGradient(
    colors: [synapseBlue, synapseCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientWarm = LinearGradient(
    colors: [neuroPurple, neuralPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientDarkBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0F0B1E), Color(0xFF0B0B16)],
  );

  static const gradientAurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.4, 0.7, 1.0],
    colors: [
      Color(0xFF140B2E),
      Color(0xFF0E1030),
      Color(0xFF0C0F28),
      Color(0xFF100A24),
    ],
  );

  static const gradientAuroraLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.4, 0.7, 1.0],
    colors: [
      Color(0xFFEDE5FF),
      Color(0xFFE3EAFF),
      Color(0xFFE8F0FF),
      Color(0xFFF0ECFF),
    ],
  );
}

class GlassDecoration {
  static BoxDecoration card({
    required Brightness brightness,
    bool isGlass = false,
    double radius = 18,
  }) {
    final isDark = brightness == Brightness.dark;
    if (isGlass) {
      return BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.65),
          width: 0.5,
        ),
      );
    }
    return BoxDecoration(
      color: isDark ? SynapseColors.darkCard : SynapseColors.lightCard,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? SynapseColors.darkCardBorder
            : SynapseColors.lightCardBorder,
        width: 0.5,
      ),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
    );
  }

  static BoxDecoration frosted({
    required Brightness brightness,
    double radius = 18,
  }) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: 0.04)
          : Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.7),
        width: 0.5,
      ),
    );
  }
}

/// Wraps [child] in a frosted glass container with real blur.
class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const FrostedGlass({
    super.key,
    required this.child,
    this.blur = 20,
    this.radius = 18,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGlass = SynapseStyle.of(context);

    if (!isGlass) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: GlassDecoration.card(
          brightness: Theme.of(context).brightness,
          radius: radius,
        ),
        child: child,
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.07)
                  : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.70),
                width: 0.5,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedGlass(
      radius: radius,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}

class SynapseStyle extends InheritedWidget {
  final bool isGlass;

  const SynapseStyle({
    super.key,
    required this.isGlass,
    required super.child,
  });

  static bool of(BuildContext context) {
    final widget = context.dependOnInheritedWidgetOfExactType<SynapseStyle>();
    return widget?.isGlass ?? false;
  }

  @override
  bool updateShouldNotify(SynapseStyle oldWidget) =>
      isGlass != oldWidget.isGlass;
}

class SynapsePageRoute<T> extends PageRouteBuilder<T> {
  SynapsePageRoute({required WidgetBuilder builder})
      : super(
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );

            return FadeTransition(
              opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
              child: child,
            );
          },
        );
}

class AppTheme {
  static final _lightColorScheme = ColorScheme.fromSeed(
    seedColor: SynapseColors.neuroPurple,
    brightness: Brightness.light,
    primary: SynapseColors.neuroPurple,
    secondary: SynapseColors.synapseCyan,
    tertiary: SynapseColors.neuralPink,
    surface: SynapseColors.lightSurface,
    surfaceContainerHighest: SynapseColors.lightCard,
    error: const Color(0xFFEF4444),
  );

  static final _darkColorScheme = ColorScheme.fromSeed(
    seedColor: SynapseColors.neuroPurple,
    brightness: Brightness.dark,
    primary: SynapseColors.neuroViolet,
    secondary: SynapseColors.synapseCyan,
    tertiary: SynapseColors.neuralPink,
    surface: SynapseColors.darkSurface,
    surfaceContainerHighest: SynapseColors.darkCard,
    error: const Color(0xFFEF4444),
  );

  static final _glassLightColorScheme = ColorScheme.fromSeed(
    seedColor: SynapseColors.neuroPurple,
    brightness: Brightness.light,
    primary: SynapseColors.neuroPurple,
    secondary: SynapseColors.synapseCyan,
    tertiary: SynapseColors.neuralPink,
    surface: const Color(0x00000000),
    surfaceContainerHighest: Colors.white.withValues(alpha: 0.55),
    error: const Color(0xFFEF4444),
  );

  static final _glassDarkColorScheme = ColorScheme.fromSeed(
    seedColor: SynapseColors.neuroPurple,
    brightness: Brightness.dark,
    primary: SynapseColors.neuroViolet,
    secondary: SynapseColors.synapseCyan,
    tertiary: SynapseColors.neuralPink,
    surface: const Color(0x00000000),
    surfaceContainerHighest: Colors.white.withValues(alpha: 0.06),
    error: const Color(0xFFEF4444),
  );

  static ThemeData lightTheme({bool glass = false}) =>
      _buildTheme(glass ? _glassLightColorScheme : _lightColorScheme,
          isGlass: glass);
  static ThemeData darkTheme({bool glass = false}) =>
      _buildTheme(glass ? _glassDarkColorScheme : _darkColorScheme,
          isGlass: glass);

  static ThemeData _buildTheme(ColorScheme colorScheme,
      {bool isGlass = false}) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final base = isDark ? ThemeData.dark() : ThemeData.light();
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(base.textTheme);

    final scaffoldBg = isGlass
        ? Colors.transparent
        : (isDark ? SynapseColors.darkSurface : SynapseColors.lightSurface);

    final cardColor = isGlass
        ? (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.55))
        : (isDark ? SynapseColors.darkCard : SynapseColors.lightCard);

    final cardBorderColor = isGlass
        ? (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.6))
        : (isDark
            ? SynapseColors.darkCardBorder
            : SynapseColors.lightCardBorder);

    final inputFill = isGlass
        ? (isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.4))
        : (isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.white.withValues(alpha: 0.9));

    final dialogBg = isGlass
        ? (isDark ? const Color(0xF0141425) : const Color(0xF0F0ECFF))
        : (isDark ? SynapseColors.darkElevated : SynapseColors.lightCard);

    final appBarBg = isGlass
        ? Colors.transparent
        : (isDark ? SynapseColors.darkSurface : SynapseColors.lightSurface);

    final onSurface = isDark ? Colors.white : const Color(0xFF0F0F1A);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(onSurface: onSurface),
      textTheme: textTheme.copyWith(
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.5,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.3,
        ),
        headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        titleLarge: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          color: onSurface,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: onSurface.withValues(alpha: 0.75),
          height: 1.5,
        ),
        bodySmall: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          color: onSurface.withValues(alpha: 0.5),
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: onSurface.withValues(alpha: 0.45),
          letterSpacing: 0.5,
        ),
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: cardBorderColor, width: 0.5),
        ),
        color: cardColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isGlass
            ? (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.5))
            : colorScheme.primary.withValues(alpha: 0.08),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isGlass
              ? BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.white.withValues(alpha: 0.6),
                  width: 0.5,
                )
              : BorderSide.none,
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SynapseColors.neuroPurple,
        foregroundColor: Colors.white,
        elevation: isGlass ? 0 : 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorderColor, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: cardBorderColor, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dialogBg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: isGlass ? 0 : 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1A1A30)
            : const Color(0xFF1E1B4B),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: isGlass ? 0 : 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(
            color: isGlass
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.6))
                : colorScheme.primary.withValues(alpha: 0.25),
            width: 0.5,
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        thickness: 0.5,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
