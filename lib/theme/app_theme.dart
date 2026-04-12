import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SynapseColors {
  // Primary palette — deep violet spectrum
  static const neuroPurple = Color(0xFF6D28D9);
  static const neuroViolet = Color(0xFF7C3AED);
  static const synapseBlue = Color(0xFF2563EB);
  static const synapseCyan = Color(0xFF0891B2);

  // Accent palette — warm counterpoints
  static const cortexTeal = Color(0xFF0D9488);
  static const plasmaGreen = Color(0xFF059669);
  static const neuralPink = Color(0xFFDB2777);
  static const axonAmber = Color(0xFFD97706);
  static const axonOrange = Color(0xFFF59E0B);

  // Dark surfaces — deep navy-midnight tones
  static const darkSurface = Color(0xFF08081A);
  static const darkCard = Color(0xFF111128);
  static const darkCardBorder = Color(0xFF1E1E42);
  static const darkElevated = Color(0xFF151530);

  // Light surfaces — cool lavender whites
  static const lightSurface = Color(0xFFF5F3FF);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightCardBorder = Color(0xFFE0DAFB);
  static const lightElevated = Color(0xFFEDE9FF);

  static const gradientPrimary = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientAccent = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF0891B2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientWarm = LinearGradient(
    colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const gradientDarkBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0C0B24), Color(0xFF08081A)],
  );

  static const gradientAurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.35, 0.65, 1.0],
    colors: [
      Color(0xFF120B28),
      Color(0xFF0D0E2D),
      Color(0xFF0A0C24),
      Color(0xFF0E0920),
    ],
  );

  static const gradientAuroraLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 0.35, 0.65, 1.0],
    colors: [
      Color(0xFFEBE5FF),
      Color(0xFFE0E6FF),
      Color(0xFFE5ECFF),
      Color(0xFFEDE8FF),
    ],
  );
}

/// Shared glassmorphism tokens for [GlassDecoration], [FrostedGlass], and [AppTheme].
class SynapseGlass {
  SynapseGlass._();

  static const double blurSigma = 20;
  static const double cardRadius = 18;
  static const double borderWidthThin = 0.5;

  /// Card / flat glass tint (dark).
  static const double fillCardDark = 0.05;

  /// Card / flat glass tint (light).
  static const double fillCardLight = 0.55;

  /// Elevated glass tint (dark) — blurred panels, chips, ColorScheme surface.
  static const double fillElevatedDark = 0.06;

  /// Frosted panel fill (dark / light).
  static const double fillFrostedDark = 0.04;
  static const double fillFrostedLight = 0.45;

  /// Text field glass fill (light).
  static const double fillInputLightGlass = 0.40;

  /// Chip background (light glass).
  static const double fillChipLightGlass = 0.5;

  /// Standard glass border (dark).
  static const double borderDark = 0.08;

  /// Card border (light) — [GlassDecoration.card].
  static const double borderLightCard = 0.65;

  /// Theme Material surfaces (card border, chips, buttons) — light glass.
  static const double borderLightMaterial = 0.6;

  /// Frosted / backdrop border (light).
  static const double borderFrostedLight = 0.7;

  /// Backdrop blur overlay border (dark).
  static const double borderBackdropDark = 0.10;

  /// Outlined button border (dark glass).
  static const double borderOutlinedDarkGlass = 0.12;
}

class GlassDecoration {
  static BoxDecoration card({
    required Brightness brightness,
    bool isGlass = false,
    double radius = SynapseGlass.cardRadius,
  }) {
    final isDark = brightness == Brightness.dark;
    if (isGlass) {
      return BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: SynapseGlass.fillCardDark)
            : Colors.white.withValues(alpha: SynapseGlass.fillCardLight),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: SynapseGlass.borderDark)
              : Colors.white.withValues(alpha: SynapseGlass.borderLightCard),
          width: SynapseGlass.borderWidthThin,
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
        width: SynapseGlass.borderWidthThin,
      ),
      boxShadow: isDark
          ? null
          : [
              BoxShadow(
                color: SynapseColors.neuroPurple.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
    );
  }

  static BoxDecoration frosted({
    required Brightness brightness,
    double radius = SynapseGlass.cardRadius,
  }) {
    final isDark = brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark
          ? Colors.white.withValues(alpha: SynapseGlass.fillFrostedDark)
          : Colors.white.withValues(alpha: SynapseGlass.fillFrostedLight),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: SynapseGlass.borderDark)
            : Colors.white.withValues(alpha: SynapseGlass.borderFrostedLight),
        width: SynapseGlass.borderWidthThin,
      ),
    );
  }
}

class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double blur;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const FrostedGlass({
    super.key,
    required this.child,
    this.blur = SynapseGlass.blurSigma,
    this.radius = SynapseGlass.cardRadius,
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
                  ? Colors.white.withValues(alpha: SynapseGlass.fillElevatedDark)
                  : Colors.white.withValues(alpha: SynapseGlass.fillCardLight),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: SynapseGlass.borderBackdropDark)
                    : Colors.white.withValues(alpha: SynapseGlass.borderFrostedLight),
                width: SynapseGlass.borderWidthThin,
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
    this.radius = SynapseGlass.cardRadius,
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
    error: const Color(0xFFDC2626),
  );

  static final _darkColorScheme = ColorScheme.fromSeed(
    seedColor: SynapseColors.neuroPurple,
    brightness: Brightness.dark,
    primary: SynapseColors.neuroViolet,
    secondary: SynapseColors.synapseCyan,
    tertiary: SynapseColors.neuralPink,
    surface: SynapseColors.darkSurface,
    surfaceContainerHighest: SynapseColors.darkCard,
    error: const Color(0xFFDC2626),
  );

  static final _glassLightColorScheme = ColorScheme.fromSeed(
    seedColor: SynapseColors.neuroPurple,
    brightness: Brightness.light,
    primary: SynapseColors.neuroPurple,
    secondary: SynapseColors.synapseCyan,
    tertiary: SynapseColors.neuralPink,
    surface: const Color(0x00000000),
    surfaceContainerHighest:
        Colors.white.withValues(alpha: SynapseGlass.fillCardLight),
    error: const Color(0xFFDC2626),
  );

  static final _glassDarkColorScheme = ColorScheme.fromSeed(
    seedColor: SynapseColors.neuroPurple,
    brightness: Brightness.dark,
    primary: SynapseColors.neuroViolet,
    secondary: SynapseColors.synapseCyan,
    tertiary: SynapseColors.neuralPink,
    surface: const Color(0x00000000),
    surfaceContainerHighest:
        Colors.white.withValues(alpha: SynapseGlass.fillElevatedDark),
    error: const Color(0xFFDC2626),
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
    final bodyFont = GoogleFonts.interTextTheme(base.textTheme);

    final scaffoldBg = isGlass
        ? Colors.transparent
        : (isDark ? SynapseColors.darkSurface : SynapseColors.lightSurface);

    final cardColor = isGlass
        ? (isDark
            ? Colors.white.withValues(alpha: SynapseGlass.fillCardDark)
            : Colors.white.withValues(alpha: SynapseGlass.fillCardLight))
        : (isDark ? SynapseColors.darkCard : SynapseColors.lightCard);

    final cardBorderColor = isGlass
        ? (isDark
            ? Colors.white.withValues(alpha: SynapseGlass.borderDark)
            : Colors.white.withValues(alpha: SynapseGlass.borderLightMaterial))
        : (isDark
            ? SynapseColors.darkCardBorder
            : SynapseColors.lightCardBorder);

    final inputFill = isGlass
        ? (isDark
            ? Colors.white.withValues(alpha: SynapseGlass.fillCardDark)
            : Colors.white.withValues(alpha: SynapseGlass.fillInputLightGlass))
        : (isDark
            ? Colors.white.withValues(alpha: SynapseGlass.fillFrostedDark)
            : const Color(0xFFF0EDFF));

    final dialogBg = isGlass
        ? (isDark ? const Color(0xF0111128) : const Color(0xF0EDEAFF))
        : (isDark ? SynapseColors.darkElevated : SynapseColors.lightCard);

    final appBarBg = isGlass
        ? Colors.transparent
        : (isDark ? SynapseColors.darkSurface : SynapseColors.lightSurface);

    final onSurface = isDark ? const Color(0xFFF0F0F8) : const Color(0xFF0F0E1A);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(onSurface: onSurface),
      textTheme: bodyFont.copyWith(
        headlineLarge: GoogleFonts.outfit(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.8,
        ),
        headlineMedium: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.5,
        ),
        headlineSmall: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
          letterSpacing: -0.3,
        ),
        titleLarge: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: onSurface,
          height: 1.55,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: onSurface.withValues(alpha: 0.72),
          height: 1.55,
        ),
        bodySmall: GoogleFonts.inter(
          fontSize: 12,
          color: onSurface.withValues(alpha: 0.48),
        ),
        labelSmall: GoogleFonts.firaCode(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: onSurface.withValues(alpha: 0.4),
          letterSpacing: 0.5,
        ),
      ),
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        backgroundColor: appBarBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: onSurface,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SynapseGlass.cardRadius),
          side: BorderSide(
              color: cardBorderColor, width: SynapseGlass.borderWidthThin),
        ),
        color: cardColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isGlass
            ? (isDark
                ? Colors.white.withValues(alpha: SynapseGlass.fillElevatedDark)
                : Colors.white.withValues(alpha: SynapseGlass.fillChipLightGlass))
            : colorScheme.primary.withValues(alpha: 0.08),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isGlass
              ? BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: SynapseGlass.borderDark)
                      : Colors.white
                          .withValues(alpha: SynapseGlass.borderLightMaterial),
                  width: SynapseGlass.borderWidthThin,
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
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: cardBorderColor, width: SynapseGlass.borderWidthThin),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: cardBorderColor, width: SynapseGlass.borderWidthThin),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
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
          borderRadius: BorderRadius.circular(22),
        ),
        elevation: isGlass ? 0 : 4,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF1A1A35)
            : const Color(0xFF1E1B4B),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        elevation: isGlass ? 0 : 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          side: BorderSide(
            color: isGlass
                ? (isDark
                    ? Colors.white
                        .withValues(alpha: SynapseGlass.borderOutlinedDarkGlass)
                    : Colors.white
                        .withValues(alpha: SynapseGlass.borderLightMaterial))
                : colorScheme.primary.withValues(alpha: 0.25),
            width: SynapseGlass.borderWidthThin,
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: GoogleFonts.inter(
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
