import 'package:flutter/material.dart';

/// Cosmic gaming palette — dark space UI with neon accents (light mode swaps surfaces).
class C {
  static bool _dark = true;

  static bool get isDark => _dark;

  static void applyDarkMode(bool dark) => _dark = dark;

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  static Color get gray50 => _dark ? const Color(0xFF06041A) : const Color(0xFFF4F6FB);
  static Color get gray100 => _dark ? const Color(0xFF12102E) : const Color(0xFFFFFFFF);
  static Color get gray200 => _dark ? const Color(0xFF352F5C) : const Color(0xFFE2E8F0);
  static Color get gray300 => _dark ? const Color(0xFF4A4168) : const Color(0xFFCBD5E1);
  static Color get gray400 => _dark ? const Color(0xFFB8B0D8) : const Color(0xFF94A3B8);
  static Color get gray500 => _dark ? const Color(0xFFD4CCF0) : const Color(0xFF64748B);
  static Color get gray600 => _dark ? const Color(0xFFE6E0FA) : const Color(0xFF475569);
  static Color get gray700 => _dark ? const Color(0xFFF0ECFF) : const Color(0xFF334155);
  static Color get gray800 => _dark ? const Color(0xFFF7F5FF) : const Color(0xFF1E293B);
  static Color get gray900 => _dark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);

  static Color get space => gray50;
  static Color get card => _dark ? const Color(0xFF2A2458) : const Color(0xFFFFFFFF);
  static Color get textOnGradient =>
      _dark ? const Color(0xFFE8E4FF) : const Color(0xFFFFFFFF);
  static Color get textMutedOnGradient =>
      _dark ? const Color(0xFFD0CAF5) : const Color(0xFFF1F5F9);
  static Color get cardBorder =>
      _dark ? const Color(0xFF5B4DFF) : const Color(0xFFE2E8F0);

  static const neonCyan = Color(0xFF00D4FF);
  static Color get neonMint => _dark ? const Color(0xFF00FFC8) : const Color(0xFF059669);
  static const nebulaPurple = Color(0xFF7B4DFF);
  static const nebulaPink = Color(0xFFFF4FD8);
  static const nebulaBlue = Color(0xFF3D5AFE);
  static const starGold = Color(0xFFFFD54F);

  /// Primary accent — neon in dark, readable indigo in light.
  static Color get accentPrimary => _dark ? neonCyan : const Color(0xFF4F46E5);
  static Color get accentSecondary => _dark ? nebulaPurple : const Color(0xFF7C3AED);
  static Color get accentFocus => _dark ? neonCyan : const Color(0xFF6366F1);
  static Color get inputFill => _dark ? const Color(0xFF12102E) : const Color(0xFFF8FAFC);
  static Color get navActiveBg =>
      _dark ? nebulaPurple.withValues(alpha: 0.55) : accentPrimary.withValues(alpha: 0.12);
  static Color get navActiveBorder =>
      _dark ? neonCyan.withValues(alpha: 0.7) : accentPrimary.withValues(alpha: 0.35);
  static Color get navActiveFg => _dark ? white : accentPrimary;

  static Color get glowTint => _dark ? neonCyan : accentPrimary;

  static List<BoxShadow> glowShadow({
    double blur = 12,
    Offset offset = const Offset(0, 2),
    double alphaDark = 0.33,
    double alphaLight = 0.12,
  }) =>
      [
        BoxShadow(
          color: glowTint.withValues(alpha: _dark ? alphaDark : alphaLight),
          blurRadius: blur,
          offset: offset,
        ),
      ];

  static List<Shadow> textGlow({double blur = 10, double alphaDark = 0.33, double alphaLight = 0.08}) =>
      [
        Shadow(
          color: glowTint.withValues(alpha: _dark ? alphaDark : alphaLight),
          blurRadius: blur,
        ),
      ];

  static Color get blue50 => _dark ? const Color(0xFF2A2560) : const Color(0xFFEEF2FF);
  static Color get blue100 => _dark ? const Color(0xFF3A3480) : const Color(0xFFE0E7FF);
  static Color get blue200 => _dark ? const Color(0xFF9EB4FF) : const Color(0xFF93C5FD);
  static Color get onGradientMuted =>
      _dark ? const Color(0xFFC8D8FF) : const Color(0xFFE0E7FF);
  static Color get blue400 => _dark ? const Color(0xFF5CE1FF) : const Color(0xFF60A5FA);
  static Color get blue500 => _dark ? const Color(0xFF00D4FF) : const Color(0xFF2563EB);
  static Color get blue600 => _dark ? const Color(0xFF7B4DFF) : const Color(0xFF4F46E5);
  static Color get blue700 => _dark ? const Color(0xFF5A32E6) : const Color(0xFF4338CA);

  static Color get teal50 => _dark ? const Color(0xFF0D2A28) : const Color(0xFFECFDF5);
  static Color get teal100 => _dark ? const Color(0xFFB8FFF0) : const Color(0xFFCCFBF1);
  static Color get teal200 => _dark ? const Color(0xFF7CFFE8) : const Color(0xFF99F6E4);
  static Color get teal400 => _dark ? const Color(0xFF5CFFD4) : const Color(0xFF2DD4BF);
  static Color get teal500 => _dark ? const Color(0xFF00FFC8) : const Color(0xFF0D9488);
  static Color get teal600 => _dark ? const Color(0xFF00C9A0) : const Color(0xFF0F766E);
  static Color get teal700 => _dark ? const Color(0xFF00997A) : const Color(0xFF115E59);

  static Color get green50 => _dark ? const Color(0xFF0D2818) : const Color(0xFFF0FDF4);
  static Color get green100 => _dark ? const Color(0xFF14382A) : const Color(0xFFDCFCE7);
  static Color get green200 => _dark ? const Color(0xFF1E5038) : const Color(0xFFBBF7D0);
  static Color get green400 => _dark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E);
  static Color get green500 => _dark ? const Color(0xFF22F58B) : const Color(0xFF16A34A);
  static Color get green600 => _dark ? const Color(0xFF16C96E) : const Color(0xFF15803D);

  /// Gauge arcs and positive metrics — neon in dark, forest green in light.
  static Color get progressGreen => green500;
  static Color get progressMint => neonMint;
  static Color get statusGood => green600;
  static Color get statusFair => _dark ? const Color(0xFFFFD54F) : const Color(0xFFD97706);
  static Color get statusPoor => _dark ? const Color(0xFFFF4D6D) : const Color(0xFFDC2626);
  static Color get gaugeTrack =>
      _dark ? gray200.withValues(alpha: 0.5) : const Color(0xFFE2E8F0);

  static Color get red50 => _dark ? const Color(0xFF2A1018) : const Color(0xFFFEF2F2);
  static Color get red100 => _dark ? const Color(0xFF3D1520) : const Color(0xFFFEE2E2);
  static Color get red200 => _dark ? const Color(0xFF5C2030) : const Color(0xFFFECACA);
  static Color get red300 => _dark ? const Color(0xFF8A3048) : const Color(0xFFFCA5A5);
  static const red400 = Color(0xFFFF6B8A);
  static Color get red500 => _dark ? const Color(0xFFFF4D6D) : const Color(0xFFDC2626);
  static const red600 = Color(0xFFE63956);
  static const red700 = Color(0xFFC42A45);

  static Color get amber50 => _dark ? const Color(0xFF2A2010) : const Color(0xFFFFFBEB);
  static Color get amber100 => _dark ? const Color(0xFF3D2E14) : const Color(0xFFFEF3C7);
  static Color get amber200 => _dark ? const Color(0xFF5C4520) : const Color(0xFFFDE68A);
  static const amber300 = Color(0xFFFFD54F);
  static const amber400 = Color(0xFFFFC107);
  static const amber500 = Color(0xFFFFB300);
  static const amber600 = Color(0xFFFF9800);
  static const amber700 = Color(0xFFF57C00);

  static Color get orange50 => _dark ? const Color(0xFF2A1808) : const Color(0xFFFFF7ED);
  static Color get orange100 => _dark ? const Color(0xFF3D2410) : const Color(0xFFFFEDD5);
  static const orange400 = Color(0xFFFF9A5C);
  static const orange500 = Color(0xFFFF7B3D);
  static const orange600 = Color(0xFFFF5722);

  static Color get sky50 => _dark ? const Color(0xFF101828) : const Color(0xFFF0F9FF);
  static Color get sky100 => _dark ? const Color(0xFF182438) : const Color(0xFFE0F2FE);
  static Color get sky200 => _dark ? const Color(0xFF243550) : const Color(0xFFBAE6FD);
  static const sky500 = Color(0xFF38BDF8);
  static const sky600 = Color(0xFF0EA5E9);

  static Color get rose50 => _dark ? const Color(0xFF2A1020) : const Color(0xFFFFF1F2);
  static Color get rose100 => _dark ? const Color(0xFF3D1830) : const Color(0xFFFFE4E6);
  static const rose500 = Color(0xFFFF4FD8);
  static const rose600 = Color(0xFFE91E8C);

  static Color get yellow50 => _dark ? const Color(0xFF2A2410) : const Color(0xFFFFFDE7);
  static Color get yellow100 => _dark ? const Color(0xFF3D3618) : const Color(0xFFFEF9C3);
  static Color get yellow200 => _dark ? const Color(0xFF5C5020) : const Color(0xFFFEF08A);
  static const yellow400 = Color(0xFFFFE066);
  static Color get yellow500 => _dark ? const Color(0xFFFFD54F) : const Color(0xFFD97706);
  static const yellow600 = Color(0xFFFFC107);
  static const yellow700 = Color(0xFFFFB300);

  static Color get emerald50 => _dark ? const Color(0xFF0D2818) : const Color(0xFFECFDF5);
  static Color get emerald100 => _dark ? const Color(0xFF14382A) : const Color(0xFFD1FAE5);
  static Color get emerald200 => _dark ? const Color(0xFF1E5038) : const Color(0xFFA7F3D0);
  static Color get emerald500 => _dark ? const Color(0xFF00FFC8) : const Color(0xFF059669);
  static const emerald600 = Color(0xFF00C9A0);

  static Color get purple100 => _dark ? const Color(0xFF2A1848) : const Color(0xFFF3E8FF);
  static const purple600 = Color(0xFF9D4DFF);
  static Color get pink100 => _dark ? const Color(0xFF3D1838) : const Color(0xFFFCE7F3);
  static const pink600 = Color(0xFFFF4FD8);
}

const kCosmicSpaceGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF06041A), Color(0xFF12082E), Color(0xFF0A1628)],
);

const kCosmicSpaceGradientLight = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFEEF2FF)],
);

LinearGradient get cosmicSpaceGradient =>
    C.isDark ? kCosmicSpaceGradient : kCosmicSpaceGradientLight;

const kBlueTealGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7B4DFF), Color(0xFF3D5AFE), Color(0xFF00D4FF)],
);

const kNebulaGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF7B4DFF), Color(0xFFFF4FD8), Color(0xFF00D4FF)],
);

const kAmberGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFFFD54F), Color(0xFFFF7B3D)],
);

const kHudGlow = BoxShadow(
  color: Color(0x4400D4FF),
  blurRadius: 16,
  spreadRadius: 0,
);

/// Logical pixels for a physical length in millimeters (160 dpi baseline).
double logicalMm(double millimeters) => millimeters * 160.0 / 25.4;

BoxDecoration cosmicPanelDecoration({double radius = 20}) => BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: C.cardBorder.withValues(alpha: C.isDark ? 0.55 : 0.9),
      ),
      boxShadow: C.isDark
          ? [
              BoxShadow(
                color: C.glowTint.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: -4,
              ),
              const BoxShadow(
                color: Color(0x66000000),
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ]
          : [
              BoxShadow(
                color: C.glowTint.withValues(alpha: 0.06),
                blurRadius: 16,
                spreadRadius: -2,
              ),
              const BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
    );

BoxDecoration cardDecoration({double radius = 16, Color? border}) => BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border ?? C.cardBorder.withValues(alpha: C.isDark ? 0.45 : 0.85)),
      boxShadow: C.isDark
          ? [
              BoxShadow(
                color: C.glowTint.withValues(alpha: 0.13),
                blurRadius: 14,
                offset: Offset(0, 2),
              ),
              const BoxShadow(
                color: Color(0x44000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ]
          : [
              const BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
              BoxShadow(
                color: C.glowTint.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
    );

ThemeData buildAppTheme({required bool isDark}) {
  final base = ThemeData(useMaterial3: true, brightness: isDark ? Brightness.dark : Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: isDark ? const Color(0xFF06041A) : const Color(0xFFF4F6FB),
    colorScheme: base.colorScheme.copyWith(
      primary: isDark ? C.neonCyan : C.accentPrimary,
      secondary: isDark ? C.nebulaPurple : C.accentSecondary,
      surface: isDark ? const Color(0xFF2A2458) : const Color(0xFFFFFFFF),
      onSurface: isDark ? C.white : const Color(0xFF0F172A),
      outline: isDark ? C.gray200 : const Color(0xFFE2E8F0),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontSize: 16),
      bodyMedium: TextStyle(color: isDark ? C.gray600 : const Color(0xFF475569), fontSize: 14),
      bodySmall: TextStyle(color: isDark ? C.gray500 : const Color(0xFF64748B), fontSize: 13),
      labelLarge: TextStyle(color: isDark ? C.white : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: isDark ? C.gray500 : const Color(0xFF64748B)),
      labelSmall: TextStyle(color: isDark ? C.gray400 : const Color(0xFF94A3B8)),
    ).apply(fontFamily: 'Helvetica Neue'),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xFF2A2458) : C.white,
      titleTextStyle: TextStyle(
        color: isDark ? C.white : const Color(0xFF0F172A),
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: cosmicBodyStyle,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: C.cardBorder.withValues(alpha: 0.55)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF12102E) : const Color(0xFFF8FAFC),
      hintStyle: TextStyle(color: isDark ? C.gray400 : const Color(0xFF94A3B8), fontSize: 15),
      labelStyle: TextStyle(color: isDark ? C.gray500 : const Color(0xFF64748B)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
            color: isDark ? C.gray200.withValues(alpha: 0.7) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: C.accentFocus, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: C.accentFocus,
      selectionColor: C.accentFocus.withValues(alpha: 0.28),
      selectionHandleColor: C.accentFocus,
    ),
    splashFactory: NoSplash.splashFactory,
  );
}

@Deprecated('Use buildAppTheme')
ThemeData buildTheme() => buildAppTheme(isDark: true);

/// Readable body/subtitle styles on cosmic surfaces.
TextStyle get cosmicBodyStyle => TextStyle(color: C.gray600, fontSize: 14, height: 1.45);
TextStyle get cosmicSubtitleStyle => TextStyle(color: C.gray500, fontSize: 14, height: 1.4);
TextStyle get cosmicTitleStyle => TextStyle(
      color: C.gray900,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );
