import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/thought.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Colors — clean white / deep black, no yellow hue
// ─────────────────────────────────────────────────────────────────────────────

class SynapseColors {
  SynapseColors._();

  // Light ink hierarchy
  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkLight = Color(0xFF3D3D3D);
  static const Color inkMuted = Color(0xFF8E8E93);
  static const Color inkFaint = Color(0xFFC7C7CC);

  // Accent — vibrant purple
  static const Color accent = Color(0xFFA371F2);
  static const Color accentDark = Color(0xFF8B5BD8);
  static const Color accentSoft = Color(0xFFD4C4F0);
  static const Color accentBg = Color(0xFFEDE4F8);

  // Backgrounds — pure white, zero warmth
  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF5F5F7);

  // Vibrant pastels
  static const Color peach = Color(0xFFFFD6BA);
  static const Color peachLight = Color(0xFFFFEBDD);
  static const Color lavenderWash = Color(0xFFE5DAFA);
  static const Color lavenderLight = Color(0xFFF0EAFC);
  static const Color blush = Color(0xFFF8E0F0);
  static const Color mint = Color(0xFFD4F0E4);
  static const Color mintLight = Color(0xFFE8F7F0);
  static const Color skyBlue = Color(0xFFD6E8F8);
  static const Color skyBlueLight = Color(0xFFE8F2FC);
  static const Color coral = Color(0xFFFDD8D8);
  static const Color coralLight = Color(0xFFFFECEC);

  static const Color error = Color(0xFFFF3B30);
  static const Color success = Color(0xFF34C759);

  // Dark theme — true deep blacks, no brown
  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkCard = Color(0xFF2C2C2E);
  static const Color darkElevated = Color(0xFF3A3A3C);
  static const Color darkInk = Color(0xFFF2F2F7);
  static const Color darkInkMuted = Color(0xFF98989D);
  static const Color darkAccent = Color(0xFFBF9EF7);

  // Dark pastels — vibrant versions for dark mode
  static const Color darkPeach = Color(0xFF3D2A1F);
  static const Color darkLavender = Color(0xFF2D2440);
  static const Color darkMint = Color(0xFF1A3028);
  static const Color darkSky = Color(0xFF1A2838);
  static const Color darkCoral = Color(0xFF3D1F1F);

  static Color categoryTint(ThoughtCategory cat, {bool dark = false}) {
    if (dark) return _darkCategoryTint(cat);
    switch (cat) {
      case ThoughtCategory.socialMedia:
      case ThoughtCategory.family:
        return peachLight;
      case ThoughtCategory.tool:
      case ThoughtCategory.product:
      case ThoughtCategory.reference:
        return lavenderLight;
      case ThoughtCategory.travel:
      case ThoughtCategory.vacation:
        return skyBlueLight;
      case ThoughtCategory.recipe:
      case ThoughtCategory.health:
        return mintLight;
      case ThoughtCategory.news:
      case ThoughtCategory.article:
        return const Color(0xFFFFF5E0);
      case ThoughtCategory.video:
      case ThoughtCategory.entertainment:
      case ThoughtCategory.music:
        return coralLight;
      case ThoughtCategory.education:
      case ThoughtCategory.stocks:
      case ThoughtCategory.finance:
        return skyBlueLight;
      case ThoughtCategory.inspiration:
      case ThoughtCategory.game:
      case ThoughtCategory.sports:
        return mintLight;
      case ThoughtCategory.image:
      case ThoughtCategory.todo:
      case ThoughtCategory.other:
        return lightCard;
    }
  }

  static Color _darkCategoryTint(ThoughtCategory cat) {
    switch (cat) {
      case ThoughtCategory.socialMedia:
      case ThoughtCategory.family:
        return darkPeach;
      case ThoughtCategory.tool:
      case ThoughtCategory.product:
      case ThoughtCategory.reference:
        return darkLavender;
      case ThoughtCategory.travel:
      case ThoughtCategory.vacation:
      case ThoughtCategory.education:
      case ThoughtCategory.stocks:
      case ThoughtCategory.finance:
        return darkSky;
      case ThoughtCategory.recipe:
      case ThoughtCategory.health:
      case ThoughtCategory.inspiration:
      case ThoughtCategory.game:
      case ThoughtCategory.sports:
        return darkMint;
      case ThoughtCategory.news:
      case ThoughtCategory.article:
        return const Color(0xFF332A14);
      case ThoughtCategory.video:
      case ThoughtCategory.entertainment:
      case ThoughtCategory.music:
        return darkCoral;
      case ThoughtCategory.image:
      case ThoughtCategory.todo:
      case ThoughtCategory.other:
        return darkCard;
    }
  }

  static Color categoryAccent(ThoughtCategory cat) {
    switch (cat) {
      case ThoughtCategory.socialMedia:
      case ThoughtCategory.family:
        return const Color(0xFFE8A87C);
      case ThoughtCategory.tool:
      case ThoughtCategory.product:
      case ThoughtCategory.reference:
        return accent;
      case ThoughtCategory.travel:
      case ThoughtCategory.vacation:
        return const Color(0xFF6BA3D6);
      case ThoughtCategory.recipe:
      case ThoughtCategory.health:
        return success;
      case ThoughtCategory.news:
      case ThoughtCategory.article:
        return const Color(0xFFD4A843);
      case ThoughtCategory.video:
      case ThoughtCategory.entertainment:
      case ThoughtCategory.music:
        return const Color(0xFFE07070);
      case ThoughtCategory.education:
      case ThoughtCategory.stocks:
      case ThoughtCategory.finance:
        return const Color(0xFF5B9BD5);
      default:
        return inkMuted;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gradients — vibrant pastel backgrounds, clean endpoints
// ─────────────────────────────────────────────────────────────────────────────

class SynapseGradients {
  SynapseGradients._();

  static const LinearGradient hero = LinearGradient(
    begin: Alignment(-0.8, -0.6),
    end: Alignment(0.8, 0.8),
    colors: [SynapseColors.lavenderWash, SynapseColors.blush, Colors.white],
  );

  static const LinearGradient heroDark = LinearGradient(
    begin: Alignment(-0.8, -0.6),
    end: Alignment(0.8, 0.8),
    colors: [Color(0xFF1A1030), Color(0xFF000000)],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SynapseColors.accent, SynapseColors.accentDark],
  );

  static const LinearGradient chatBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0EAFC), Colors.white],
  );

  static const LinearGradient chatBgDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF12101A), Color(0xFF000000)],
  );

  static const LinearGradient libraryBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFEBDD), Colors.white],
  );

  static const LinearGradient libraryBgDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1410), Color(0xFF000000)],
  );

  static const LinearGradient timelineBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFE8F2FC), Colors.white],
  );

  static const LinearGradient timelineBgDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1520), Color(0xFF000000)],
  );

  static const LinearGradient vaultBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFECEC), Colors.white],
  );

  static const LinearGradient vaultBgDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A0D0D), Color(0xFF000000)],
  );

  static const LinearGradient settingsBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF0EAFC), Colors.white],
  );

  static const LinearGradient settingsBgDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF12101A), Color(0xFF000000)],
  );

  static const LinearGradient peachWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SynapseColors.peachLight, Color(0xFFFFF8F4)],
  );

  static LinearGradient imageOverlay({bool dark = false}) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: dark
            ? [Colors.transparent, Colors.black54, Colors.black87]
            : [Colors.transparent, Colors.white70, Colors.white],
        stops: const [0.35, 0.75, 1.0],
      );

  static LinearGradient categoryCard(ThoughtCategory cat, {bool dark = false}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          SynapseColors.categoryTint(cat, dark: dark),
          dark ? SynapseColors.darkCard : Colors.white,
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Shadows
// ─────────────────────────────────────────────────────────────────────────────

class SynapseShadows {
  SynapseShadows._();

  static const List<BoxShadow> none = [];

  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevated => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get glow => [
        BoxShadow(
          color: SynapseColors.accent.withValues(alpha: 0.2),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softDark => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Decoration helpers
// ─────────────────────────────────────────────────────────────────────────────

class SynapseDecoration {
  SynapseDecoration._();

  static BoxDecoration card({bool dark = false}) => BoxDecoration(
        color: dark ? SynapseColors.darkCard : SynapseColors.lightCard,
        borderRadius: BorderRadius.circular(20),
      );

  static BoxDecoration elevatedCard({bool dark = false}) => BoxDecoration(
        color: dark ? SynapseColors.darkElevated : Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: dark ? SynapseShadows.softDark : SynapseShadows.soft,
      );

  static BoxDecoration frostedCard({bool dark = false}) => BoxDecoration(
        color: (dark ? SynapseColors.darkCard : Colors.white)
            .withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      );

  static BoxDecoration pastelCard({
    required ThoughtCategory category,
    bool dark = false,
  }) =>
      BoxDecoration(
        gradient: SynapseGradients.categoryCard(category, dark: dark),
        borderRadius: BorderRadius.circular(20),
      );

  static BoxDecoration accentSection({bool dark = false}) => BoxDecoration(
        color: dark ? SynapseColors.darkCard : SynapseColors.lavenderLight,
        borderRadius: BorderRadius.circular(20),
      );

  static BoxDecoration pill({
    required bool active,
    bool dark = false,
  }) =>
      BoxDecoration(
        color: active
            ? SynapseColors.ink
            : (dark ? SynapseColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(100),
        border: active
            ? null
            : Border.all(
                color: (dark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
              ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Frosted wrapper widget
// ─────────────────────────────────────────────────────────────────────────────

class FrostedContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double sigma;

  const FrostedContainer({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding,
    this.sigma = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (isDark ? Colors.black : Colors.white)
                .withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black)
                  .withValues(alpha: 0.06),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Page route
// ─────────────────────────────────────────────────────────────────────────────

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
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(curve),
                child: child,
              ),
            );
          },
        );
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData lightTheme() => _build(Brightness.light);
  static ThemeData darkTheme() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final base = dark ? ThemeData.dark() : ThemeData.light();

    final bg = dark ? SynapseColors.darkBg : SynapseColors.lightBg;
    final card = dark ? SynapseColors.darkCard : SynapseColors.lightCard;
    final ink = dark ? SynapseColors.darkInk : SynapseColors.ink;
    final inkMuted =
        dark ? SynapseColors.darkInkMuted : SynapseColors.inkMuted;
    final accent = dark ? SynapseColors.darkAccent : SynapseColors.accent;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: SynapseColors.peach,
      onSecondary: SynapseColors.ink,
      tertiary: SynapseColors.success,
      error: SynapseColors.error,
      onError: Colors.white,
      surface: bg,
      onSurface: ink,
      surfaceContainerHighest: card,
      outline: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
      outlineVariant:
          (dark ? Colors.white : Colors.black).withValues(alpha: 0.04),
    );

    final fraunces = GoogleFonts.fraunces;
    final dmSans = GoogleFonts.dmSans;

    return base.copyWith(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: base.textTheme.copyWith(
        headlineLarge: fraunces(
          fontSize: 36, fontWeight: FontWeight.w800, color: ink,
          letterSpacing: -1.0, height: 1.1,
        ),
        headlineMedium: fraunces(
          fontSize: 28, fontWeight: FontWeight.w700, color: ink,
          letterSpacing: -0.5, height: 1.15,
        ),
        headlineSmall: fraunces(
          fontSize: 22, fontWeight: FontWeight.w700, color: ink,
          letterSpacing: -0.3, height: 1.2,
        ),
        titleLarge: dmSans(fontSize: 17, fontWeight: FontWeight.w600, color: ink),
        titleMedium: dmSans(fontSize: 15, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: dmSans(fontSize: 15, color: ink, height: 1.5),
        bodyMedium: dmSans(fontSize: 13, color: inkMuted, height: 1.5),
        bodySmall: dmSans(fontSize: 11, color: inkMuted, height: 1.4),
        labelLarge: dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: ink),
        labelSmall: dmSans(
          fontSize: 10, fontWeight: FontWeight.w500, color: inkMuted,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: fraunces(fontSize: 18, fontWeight: FontWeight.w600, color: ink),
        iconTheme: IconThemeData(color: ink, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: SynapseColors.peachLight,
        labelStyle: dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: SynapseColors.ink),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: SynapseColors.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? SynapseColors.darkCard : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        hintStyle: dmSans(fontSize: 14, color: inkMuted),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark ? SynapseColors.darkSurface : Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? SynapseColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: dark ? SynapseColors.darkInk : SynapseColors.ink,
        contentTextStyle: dmSans(
          fontSize: 13,
          color: dark ? SynapseColors.darkBg : Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: dark ? SynapseColors.darkInk : SynapseColors.ink,
          foregroundColor: dark ? SynapseColors.darkBg : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          side: BorderSide(color: ink.withValues(alpha: 0.15)),
          foregroundColor: ink,
          textStyle: dmSans(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: dmSans(fontSize: 14, fontWeight: FontWeight.w600),
          shape: const StadiumBorder(),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: ink.withValues(alpha: 0.06),
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
