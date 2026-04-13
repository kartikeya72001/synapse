import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/thought.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Typography helper — Clash Grotesk approximated via Space Grotesk
// ─────────────────────────────────────────────────────────────────────────────

class SynapseType {
  SynapseType._();
  static TextStyle display({
    double fontSize = 36,
    FontWeight fontWeight = FontWeight.w700,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing ?? -1.0,
        height: height ?? 1.1,
      );

  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.5,
        letterSpacing: letterSpacing,
      );

  static TextStyle mono({
    double fontSize = 13,
    Color? color,
    Color? backgroundColor,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: fontSize,
        color: color,
        backgroundColor: backgroundColor,
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Colors
// ─────────────────────────────────────────────────────────────────────────────

class SynapseColors {
  SynapseColors._();

  static const Color ink = Color(0xFF1A1A1A);
  static const Color inkLight = Color(0xFF3D3D3D);
  static const Color inkMuted = Color(0xFF8E8E93);
  static const Color inkFaint = Color(0xFFC7C7CC);

  static const Color accent = Color(0xFFA371F2);
  static const Color accentDark = Color(0xFF8B5BD8);
  static const Color accentSoft = Color(0xFFD4C4F0);
  static const Color accentBg = Color(0xFFEDE4F8);

  static const Color lightBg = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF5F5F7);

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

  static const Color darkBg = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF1C1C1E);
  static const Color darkCard = Color(0xFF2C2C2E);
  static const Color darkElevated = Color(0xFF3A3A3C);
  static const Color darkInk = Color(0xFFF2F2F7);
  static const Color darkInkMuted = Color(0xFF98989D);
  static const Color darkAccent = Color(0xFFBF9EF7);

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
// Gradients — splash-style subtle washes, each page unique
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
    colors: [Color(0xFF2A1848), Color(0xFF0A0610)],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [SynapseColors.accent, SynapseColors.accentDark],
  );

  // Cortex — soft lavender tint
  static const LinearGradient chatBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF3EDFF), Color(0xFFFFF0F8), Color(0xFFFFFFFF)],
    stops: [0.0, 0.45, 1.0],
  );
  static const LinearGradient chatBgDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1438), Color(0xFF120E20), Color(0xFF050308)],
    stops: [0.0, 0.5, 1.0],
  );

  // Memories — lavender wash (splash-style)
  static const LinearGradient libraryBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF0EAFC), Color(0xFFF8EFF8), Color(0xFFFFFFFF)],
    stops: [0.0, 0.4, 1.0],
  );
  static const LinearGradient libraryBgDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A1528), Color(0xFF0F0C18), Color(0xFF050308)],
    stops: [0.0, 0.5, 1.0],
  );

  // Recall — cool sky blue wash
  static const LinearGradient timelineBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE8F2FC), Color(0xFFF0EAFC), Color(0xFFFFFFFF)],
    stops: [0.0, 0.5, 1.0],
  );
  static const LinearGradient timelineBgDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F1828), Color(0xFF0C0F1A), Color(0xFF050308)],
    stops: [0.0, 0.5, 1.0],
  );

  // Vault — serious coral-red undertone
  static const LinearGradient vaultBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFF0EE), Color(0xFFFFF8F6), Color(0xFFFFFFFF)],
    stops: [0.0, 0.35, 1.0],
  );
  static const LinearGradient vaultBgDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF281515), Color(0xFF140C0C), Color(0xFF050308)],
    stops: [0.0, 0.45, 1.0],
  );

  // Pulse — teal/mint analytics gradient
  static const LinearGradient pulseBg = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6F8F5), Color(0xFFECF0FC), Color(0xFFFFFFFF)],
    stops: [0.0, 0.45, 1.0],
  );
  static const LinearGradient pulseBgDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F2028), Color(0xFF0C1420), Color(0xFF050308)],
    stops: [0.0, 0.5, 1.0],
  );

  // Settings — neutral lavender
  static const LinearGradient settingsBg = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF3EDFF), Color(0xFFF8F6FF), Color(0xFFFFFFFF)],
    stops: [0.0, 0.35, 1.0],
  );
  static const LinearGradient settingsBgDark = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1A1525), Color(0xFF0E0C15), Color(0xFF050308)],
    stops: [0.0, 0.45, 1.0],
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
            : [Colors.transparent, Colors.white54, Colors.white],
        stops: const [0.5, 0.8, 1.0],
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

  static LinearGradient platformCard(String? siteName, String? url, {bool dark = false}) {
    final platform = _detectPlatform(siteName, url);
    switch (platform) {
      case 'instagram':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF2D1535), const Color(0xFF1C1C2E)]
              : [const Color(0xFFFCF0F8), const Color(0xFFF5EAFF)],
        );
      case 'linkedin':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF0F1E30), const Color(0xFF1C1C2E)]
              : [const Color(0xFFEDF4FC), const Color(0xFFE8F0FA)],
        );
      case 'twitter':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF0F1820), const Color(0xFF1C1C2E)]
              : [const Color(0xFFEDF7FF), const Color(0xFFE8F2FC)],
        );
      case 'youtube':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF2D1515), const Color(0xFF1C1C2E)]
              : [const Color(0xFFFFF0F0), const Color(0xFFFCECEC)],
        );
      case 'reddit':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF2D1F0F), const Color(0xFF1C1C2E)]
              : [const Color(0xFFFFF5EB), const Color(0xFFFCF0E5)],
        );
      case 'spotify':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF0F2D18), const Color(0xFF1C1C2E)]
              : [const Color(0xFFEDFCF0), const Color(0xFFE5F7EA)],
        );
      case 'pinterest':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF2D1018), const Color(0xFF1C1C2E)]
              : [const Color(0xFFFFF0F3), const Color(0xFFFCECF0)],
        );
      case 'github':
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [const Color(0xFF1A1A25), const Color(0xFF1C1C2E)]
              : [const Color(0xFFF3F3F8), const Color(0xFFEEEEF5)],
        );
      default:
        return LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [SynapseColors.darkLavender, SynapseColors.darkCard]
              : [SynapseColors.lavenderLight, Colors.white],
        );
    }
  }

  static String _detectPlatform(String? siteName, String? url) {
    final name = (siteName ?? '').toLowerCase();
    final link = (url ?? '').toLowerCase();
    if (name.contains('instagram') || link.contains('instagram.com')) return 'instagram';
    if (name.contains('linkedin') || link.contains('linkedin.com')) return 'linkedin';
    if (name.contains('twitter') || name.contains('x.com') || link.contains('twitter.com') || link.contains('x.com')) return 'twitter';
    if (name.contains('youtube') || link.contains('youtube.com') || link.contains('youtu.be')) return 'youtube';
    if (name.contains('reddit') || link.contains('reddit.com')) return 'reddit';
    if (name.contains('spotify') || link.contains('spotify.com')) return 'spotify';
    if (name.contains('pinterest') || link.contains('pinterest.com')) return 'pinterest';
    if (name.contains('github') || link.contains('github.com')) return 'github';
    return 'other';
  }
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
    final accentColor = dark ? SynapseColors.darkAccent : SynapseColors.accent;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accentColor,
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

    return base.copyWith(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      textTheme: base.textTheme.copyWith(
        headlineLarge: SynapseType.display(
            fontSize: 36, fontWeight: FontWeight.w700, color: ink),
        headlineMedium: SynapseType.display(
            fontSize: 28, fontWeight: FontWeight.w600, color: ink,
            letterSpacing: -0.5, height: 1.15),
        headlineSmall: SynapseType.display(
            fontSize: 22, fontWeight: FontWeight.w600, color: ink,
            letterSpacing: -0.3, height: 1.2),
        titleLarge: SynapseType.body(
            fontSize: 17, fontWeight: FontWeight.w600, color: ink),
        titleMedium: SynapseType.body(
            fontSize: 15, fontWeight: FontWeight.w600, color: ink),
        bodyLarge: SynapseType.body(fontSize: 15, color: ink, height: 1.5),
        bodyMedium: SynapseType.body(fontSize: 13, color: inkMuted, height: 1.5),
        bodySmall: SynapseType.body(fontSize: 11, color: inkMuted, height: 1.4),
        labelLarge: SynapseType.body(
            fontSize: 13, fontWeight: FontWeight.w600, color: ink),
        labelSmall: SynapseType.body(
            fontSize: 10, fontWeight: FontWeight.w500, color: inkMuted,
            letterSpacing: 0.5),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: SynapseType.body(
            fontSize: 18, fontWeight: FontWeight.w600, color: ink),
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
        labelStyle: SynapseType.body(
            fontSize: 11, fontWeight: FontWeight.w600, color: SynapseColors.ink),
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
          borderSide: BorderSide(color: accentColor, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        hintStyle: SynapseType.body(fontSize: 14, color: inkMuted),
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
        contentTextStyle: SynapseType.body(
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
          textStyle: SynapseType.body(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: const StadiumBorder(),
          side: BorderSide(color: ink.withValues(alpha: 0.15)),
          foregroundColor: ink,
          textStyle: SynapseType.body(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          textStyle: SynapseType.body(fontSize: 14, fontWeight: FontWeight.w600),
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
