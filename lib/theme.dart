import 'package:flutter/material.dart';

/// Cosmic palette — modern slate dark UI with soft accents (light mode swaps surfaces).
class C {
  static bool _dark = true;

  static bool get isDark => _dark;

  static void applyDarkMode(bool dark) => _dark = dark;

  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);

  // Dark: higher gray index = lighter text on deep slate surfaces.
  static Color get gray50 => _dark ? const Color(0xFF0C0F14) : const Color(0xFFF4F6FB);
  static Color get gray100 => _dark ? const Color(0xFF141A22) : const Color(0xFFFFFFFF);
  static Color get gray200 => _dark ? const Color(0xFF252D3A) : const Color(0xFFE2E8F0);
  static Color get gray300 => _dark ? const Color(0xFF384454) : const Color(0xFFCBD5E1);
  static Color get gray400 => _dark ? const Color(0xFF6B7789) : const Color(0xFF94A3B8);
  static Color get gray500 => _dark ? const Color(0xFF8B97A8) : const Color(0xFF64748B);
  static Color get gray600 => _dark ? const Color(0xFFA8B2C1) : const Color(0xFF475569);
  static Color get gray700 => _dark ? const Color(0xFFC5CDD8) : const Color(0xFF334155);
  static Color get gray800 => _dark ? const Color(0xFFDDE3EA) : const Color(0xFF1E293B);
  static Color get gray900 => _dark ? const Color(0xFFF0F3F7) : const Color(0xFF0F172A);

  static Color get space => gray50;
  static Color get card => _dark ? const Color(0xFF181E28) : const Color(0xFFFFFFFF);
  static Color get textOnGradient =>
      _dark ? const Color(0xFFE8EDF4) : const Color(0xFFFFFFFF);
  static Color get textMutedOnGradient =>
      _dark ? const Color(0xFFA8B5C8) : const Color(0xFFF1F5F9);
  static Color get cardBorder =>
      _dark ? const Color(0xFF2E3A4C) : const Color(0xFFE2E8F0);

  /// Captions, timestamps, hints.
  static Color get textComment => gray500;
  /// Links, values, inline highlights.
  static Color get textHighlight => accentPrimary;
  /// Dividers and hairlines.
  static Color get lineDivider => gray200;

  static Color get neonCyan =>
      _dark ? const Color(0xFF6CB4FF) : const Color(0xFF00D4FF);
  static Color get neonMint =>
      _dark ? const Color(0xFF5EEAD4) : const Color(0xFF059669);
  static Color get nebulaPurple =>
      _dark ? const Color(0xFF9B8CFF) : const Color(0xFF7B4DFF);
  static Color get nebulaPink =>
      _dark ? const Color(0xFFE879A8) : const Color(0xFFFF4FD8);
  static Color get nebulaBlue =>
      _dark ? const Color(0xFF5B8DEF) : const Color(0xFF3D5AFE);
  static Color get starGold =>
      _dark ? const Color(0xFFFBBF24) : const Color(0xFFFFD54F);

  /// Primary accent — soft sky in dark, readable indigo in light.
  static Color get accentPrimary =>
      _dark ? const Color(0xFF6CB4FF) : const Color(0xFF4F46E5);
  static Color get accentSecondary =>
      _dark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
  static Color get accentFocus =>
      _dark ? const Color(0xFF5BA3F5) : const Color(0xFF6366F1);
  static Color get inputFill => _dark ? const Color(0xFF141A22) : const Color(0xFFF8FAFC);
  static Color get navActiveBg =>
      _dark ? accentPrimary.withValues(alpha: 0.14) : accentPrimary.withValues(alpha: 0.12);
  static Color get navActiveBorder =>
      _dark ? accentPrimary.withValues(alpha: 0.45) : accentPrimary.withValues(alpha: 0.35);
  static Color get navActiveFg => _dark ? accentPrimary : accentPrimary;

  static Color get glowTint => _dark ? accentPrimary : accentPrimary;

  static List<BoxShadow> glowShadow({
    double blur = 12,
    Offset offset = const Offset(0, 2),
    double alphaDark = 0.16,
    double alphaLight = 0.12,
  }) =>
      [
        BoxShadow(
          color: glowTint.withValues(alpha: _dark ? alphaDark : alphaLight),
          blurRadius: blur,
          offset: offset,
        ),
      ];

  /// Disabled in dark mode — glow reduces text crispness on OLED screens.
  static List<Shadow> textGlow({double blur = 10, double alphaDark = 0.33, double alphaLight = 0.08}) =>
      _dark
          ? const []
          : [
              Shadow(
                color: glowTint.withValues(alpha: alphaLight),
                blurRadius: blur,
              ),
            ];

  static Color get blue50 => _dark ? const Color(0xFF141E30) : const Color(0xFFEEF2FF);
  static Color get blue100 => _dark ? const Color(0xFF1E2A42) : const Color(0xFFE0E7FF);
  static Color get blue200 => _dark ? const Color(0xFF3B5278) : const Color(0xFF93C5FD);
  static Color get onGradientMuted =>
      _dark ? const Color(0xFFF2F5FA) : const Color(0xFFE0E7FF);
  static Color get blue400 => _dark ? const Color(0xFF7CB8FF) : const Color(0xFF60A5FA);
  static Color get blue500 => _dark ? const Color(0xFF6CB4FF) : const Color(0xFF2563EB);
  static Color get blue600 => _dark ? const Color(0xFF5B8DEF) : const Color(0xFF4F46E5);
  static Color get blue700 => _dark ? const Color(0xFF4A7FD9) : const Color(0xFF4338CA);

  static Color get teal50 => _dark ? const Color(0xFF101F1E) : const Color(0xFFECFDF5);
  static Color get teal100 => _dark ? const Color(0xFF1A2E2C) : const Color(0xFFCCFBF1);
  static Color get teal200 => _dark ? const Color(0xFF2D4A44) : const Color(0xFF99F6E4);
  static Color get teal400 => _dark ? const Color(0xFF5EEAD4) : const Color(0xFF2DD4BF);
  static Color get teal500 => _dark ? const Color(0xFF2DD4BF) : const Color(0xFF0D9488);
  static Color get teal600 => _dark ? const Color(0xFF5EEAD4) : const Color(0xFF0F766E);
  static Color get teal700 => _dark ? const Color(0xFF14B8A6) : const Color(0xFF115E59);

  static Color get green50 => _dark ? const Color(0xFF101F18) : const Color(0xFFF0FDF4);
  static Color get green100 => _dark ? const Color(0xFF1A2E24) : const Color(0xFFDCFCE7);
  static Color get green200 => _dark ? const Color(0xFF2A4536) : const Color(0xFFBBF7D0);
  static Color get green400 => _dark ? const Color(0xFF4ADE80) : const Color(0xFF22C55E);
  static Color get green500 => _dark ? const Color(0xFF34D399) : const Color(0xFF16A34A);
  static Color get green600 => _dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

  /// Gauge arcs and positive metrics.
  static Color get progressGreen => green500;
  static Color get progressMint => neonMint;
  static Color get statusGood => green600;
  static Color get statusFair => _dark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  static Color get statusPoor => _dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static Color get gaugeTrack =>
      _dark ? gray200.withValues(alpha: 0.5) : const Color(0xFFE2E8F0);

  static Color get red50 => _dark ? const Color(0xFF241418) : const Color(0xFFFEF2F2);
  static Color get red100 => _dark ? const Color(0xFF321A22) : const Color(0xFFFEE2E2);
  static Color get red200 => _dark ? const Color(0xFF4A2830) : const Color(0xFFFECACA);
  static Color get red300 => _dark ? const Color(0xFF6B3848) : const Color(0xFFFCA5A5);
  static Color get red400 => _dark ? const Color(0xFFF87171) : const Color(0xFFFF6B8A);
  static Color get red500 => _dark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  static const red600 = Color(0xFFE63956);
  static const red700 = Color(0xFFC42A45);

  static Color get amber50 => _dark ? const Color(0xFF221C10) : const Color(0xFFFFFBEB);
  static Color get amber100 => _dark ? const Color(0xFF322818) : const Color(0xFFFEF3C7);
  static Color get amber200 => _dark ? const Color(0xFF4A3820) : const Color(0xFFFDE68A);
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

  static Color get sky50 => _dark ? const Color(0xFF101820) : const Color(0xFFF0F9FF);
  static Color get sky100 => _dark ? const Color(0xFF182430) : const Color(0xFFE0F2FE);
  static Color get sky200 => _dark ? const Color(0xFF243548) : const Color(0xFFBAE6FD);
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
  static Color get emerald500 => _dark ? const Color(0xFF34D399) : const Color(0xFF059669);
  static Color get emerald600 =>
      _dark ? const Color(0xFF2DD4BF) : const Color(0xFF00C9A0);

  static Color get purple100 => _dark ? const Color(0xFF221A32) : const Color(0xFFF3E8FF);
  static const purple600 = Color(0xFF9D4DFF);
  static Color get pink100 => _dark ? const Color(0xFF3D1838) : const Color(0xFFFCE7F3);
  static const pink600 = Color(0xFFFF4FD8);
}

const kCosmicSpaceGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0C0F14), Color(0xFF121820), Color(0xFF0E141C)],
);

const kCosmicSpaceGradientLight = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9), Color(0xFFEEF2FF)],
);

LinearGradient get cosmicSpaceGradient =>
    C.isDark ? kCosmicSpaceGradient : kCosmicSpaceGradientLight;

LinearGradient get kBlueTealGradient => C.isDark
    ? const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6366F1), Color(0xFF4F7FD9), Color(0xFF6CB4FF)],
      )
    : const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7B4DFF), Color(0xFF3D5AFE), Color(0xFF00D4FF)],
      );

LinearGradient get kNebulaGradient => C.isDark
    ? const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF6366F1), Color(0xFF9B8CFF), Color(0xFF6CB4FF)],
      )
    : const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF7B4DFF), Color(0xFFFF4FD8), Color(0xFF00D4FF)],
      );

const kAmberGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFFFD54F), Color(0xFFFF7B3D)],
);

BoxShadow get kHudGlow => BoxShadow(
      color: C.accentPrimary.withValues(alpha: C.isDark ? 0.22 : 0.27),
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
                color: C.glowTint.withValues(alpha: 0.1),
                blurRadius: 18,
                spreadRadius: -4,
              ),
              const BoxShadow(
                color: Color(0x55000000),
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
      border: Border.all(color: border ?? C.cardBorder.withValues(alpha: C.isDark ? 0.75 : 0.85)),
      boxShadow: C.isDark
          ? [
              BoxShadow(
                color: C.glowTint.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
              const BoxShadow(
                color: Color(0x38000000),
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
    scaffoldBackgroundColor: isDark ? const Color(0xFF0C0F14) : const Color(0xFFF4F6FB),
    colorScheme: base.colorScheme.copyWith(
      primary: isDark ? C.accentPrimary : C.accentPrimary,
      secondary: isDark ? C.accentSecondary : C.accentSecondary,
      surface: isDark ? const Color(0xFF181E28) : const Color(0xFFFFFFFF),
      onSurface: isDark ? C.gray900 : const Color(0xFF0F172A),
      onSurfaceVariant: isDark ? C.gray500 : const Color(0xFF64748B),
      outline: isDark ? C.gray200 : const Color(0xFFE2E8F0),
    ),
    dividerColor: isDark ? C.lineDivider : const Color(0xFFE2E8F0),
    textTheme: TextTheme(
      displayLarge: TextStyle(color: isDark ? C.gray900 : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: isDark ? C.gray900 : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: isDark ? C.gray900 : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: isDark ? C.gray900 : const Color(0xFF0F172A), fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: isDark ? C.gray800 : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: isDark ? C.gray900 : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: isDark ? C.gray800 : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: isDark ? C.gray800 : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: isDark ? C.gray700 : const Color(0xFF0F172A), fontSize: 16),
      bodyMedium: TextStyle(color: isDark ? C.gray700 : const Color(0xFF475569), fontSize: 14),
      bodySmall: TextStyle(color: isDark ? C.gray500 : const Color(0xFF64748B), fontSize: 13),
      labelLarge: TextStyle(color: isDark ? C.gray800 : const Color(0xFF0F172A), fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: isDark ? C.gray500 : const Color(0xFF64748B)),
      labelSmall: TextStyle(color: isDark ? C.gray400 : const Color(0xFF94A3B8)),
    ).apply(fontFamily: 'Helvetica Neue'),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xFF181E28) : C.white,
      titleTextStyle: TextStyle(
        color: isDark ? C.gray900 : const Color(0xFF0F172A),
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
      fillColor: isDark ? const Color(0xFF141A22) : const Color(0xFFF8FAFC),
      hintStyle: TextStyle(color: isDark ? C.gray400 : const Color(0xFF94A3B8), fontSize: 15),
      labelStyle: TextStyle(color: isDark ? C.textComment : const Color(0xFF64748B)),
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
TextStyle get cosmicBodyStyle => TextStyle(
      color: C.isDark ? C.gray700 : C.gray600,
      fontSize: 14,
      height: 1.45,
    );
TextStyle get cosmicSubtitleStyle => TextStyle(
      color: C.textComment,
      fontSize: 14,
      height: 1.4,
    );
TextStyle get cosmicTitleStyle => TextStyle(
      color: C.gray900,
      fontSize: 22,
      fontWeight: FontWeight.bold,
    );
