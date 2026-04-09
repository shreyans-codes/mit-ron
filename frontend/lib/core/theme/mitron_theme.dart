import 'package:flutter/material.dart';

import 'mitron_colors.dart';
import 'theme_variant.dart';

abstract final class MitronTheme {
  static ThemeData build(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.darkAcademia => _darkAcademia(),
      AppThemeVariant.parchmentLight => _parchmentLight(),
      AppThemeVariant.midnightOcean => _midnightOcean(),
      AppThemeVariant.coastalBreeze => _coastalBreeze(),
      AppThemeVariant.forestDawn => _forestDawn(),
      AppThemeVariant.twilightGrove => _twilightGrove(),
      AppThemeVariant.sunsetDusk => _sunsetDusk(),
      AppThemeVariant.goldenHour => _goldenHour(),
    };
  }

  /// Deep brown leather, hunter green accents, lamp-lit stone.
  static ThemeData _darkAcademia() {
    const ink = Color(0xFFF5F0E6);
    const parchmentMuted = Color(0xFFA8A29E);
    const leather = Color(0xFFB8956B);
    const deepBrown = Color(0xFF1A1512);
    const panel = Color(0xFF2A2420);
    const hunter = Color(0xFF3D5A47);

    final scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: leather,
      onPrimary: Color(0xFF1C1410),
      secondary: hunter,
      onSecondary: Color(0xFFE8F0EA),
      surface: panel,
      onSurface: ink,
      surfaceContainerHighest: Color(0xFF362F2A),
      error: Color(0xFFE07A6E),
      onError: Color(0xFF1A1512),
    );

    final mitron = MitronColors(
      authGradient: const [
        Color(0xFF2C1810),
        Color(0xFF3D2B1F),
        Color(0xFF1A1512),
      ],
      cardSurface: panel,
      cardShadow: const Color(0xFF0C0A08).withValues(alpha: 0.55),
      demoBannerBg: const Color(0xFF3D3028),
      demoBannerFg: const Color(0xFFD4B896),
      brandTitle: ink,
      brandSubtitle: parchmentMuted,
      textMuted: parchmentMuted,
    );

    return _base(scheme, mitron, scaffold: deepBrown);
  }

  /// Cream paper, sepia ink, library daylight.
  static ThemeData _parchmentLight() {
    const ink = Color(0xFF2C2416);
    const muted = Color(0xFF6B5E52);
    const coffee = Color(0xFF6B4423);
    const cream = Color(0xFFFFFCF7);
    const card = Color(0xFFFFFFFF);

    final scheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: coffee,
      onPrimary: Color(0xFFFFFBF5),
      secondary: Color(0xFF4A5D4A),
      onSecondary: Color(0xFFF2F7F2),
      surface: cream,
      onSurface: ink,
      surfaceContainerHighest: Color(0xFFF0E8DC),
      error: Color(0xFFB3261E),
      onError: Colors.white,
    );

    final mitron = MitronColors(
      authGradient: const [
        Color(0xFFF5F0E6),
        Color(0xFFEDE4D3),
        Color(0xFFFAF8F3),
      ],
      cardSurface: card,
      cardShadow: const Color(0xFF3D2B1F).withValues(alpha: 0.12),
      demoBannerBg: const Color(0xFFEDE4D3),
      demoBannerFg: coffee,
      textMuted: muted,
      brandTitle: ink,
      brandSubtitle: muted,
    );

    return _base(scheme, mitron, scaffold: const Color(0xFFFAF8F3));
  }

  /// Deep navy, silver accents, moonlit waves.
  static ThemeData _midnightOcean() {
    const silver = Color(0xFFB8C5D6);
    const muted = Color(0xFF6B7A8A);
    const ocean = Color(0xFF4A90A4);
    const deepNavy = Color(0xFF0D1B2A);
    const panel = Color(0xFF1B2838);
    const seafoam = Color(0xFF2D5A5A);

    final scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: ocean,
      onPrimary: Color(0xFF0D1B2A),
      secondary: seafoam,
      onSecondary: Color(0xFFE8F4F4),
      surface: panel,
      onSurface: silver,
      surfaceContainerHighest: Color(0xFF2A3A4A),
      error: Color(0xFFFF8A7A),
      onError: Color(0xFF0D1B2A),
    );

    final mitron = MitronColors(
      authGradient: const [
        Color(0xFF0A1628),
        Color(0xFF1B2D42),
        Color(0xFF0D1B2A),
      ],
      cardSurface: panel,
      cardShadow: const Color(0xFF050A10).withValues(alpha: 0.55),
      demoBannerBg: const Color(0xFF1B2D3A),
      demoBannerFg: const Color(0xFF6BB3C9),
      brandTitle: silver,
      brandSubtitle: muted,
      textMuted: muted,
    );

    return _base(scheme, mitron, scaffold: deepNavy);
  }

  /// Fresh sage, warm moss, morning light.
  static ThemeData _forestDawn() {
    const ink = Color(0xFF1A2E1A);
    const muted = Color(0xFF5A6B5A);
    const sage = Color(0xFF6B8E6B);
    const fresh = Color(0xFFF5FAF5);
    const card = Color(0xFFFFFFFF);
    const moss = Color(0xFF4A6B4A);

    final scheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: sage,
      onPrimary: Color(0xFFF5FAF5),
      secondary: moss,
      onSecondary: Color(0xFFF2F7F2),
      surface: fresh,
      onSurface: ink,
      surfaceContainerHighest: Color(0xFFE8F0E8),
      error: Color(0xFFB3261E),
      onError: Colors.white,
    );

    final mitron = MitronColors(
      authGradient: const [
        Color(0xFFE8F0E8),
        Color(0xFFD8E8D8),
        Color(0xFFF5FAF5),
      ],
      cardSurface: card,
      cardShadow: const Color(0xFF2A3A2A).withValues(alpha: 0.12),
      demoBannerBg: const Color(0xFFD8E8D8),
      demoBannerFg: sage,
      textMuted: muted,
      brandTitle: ink,
      brandSubtitle: muted,
    );

    return _base(scheme, mitron, scaffold: const Color(0xFFF5FAF5));
  }

  /// Warm amber, coral sunset, dusky orange.
  static ThemeData _sunsetDusk() {
    const cream = Color(0xFFFCE8DC);
    const muted = Color(0xFFB89A7A);
    const amber = Color(0xFFD4854A);
    const deepOrange = Color(0xFF1A0F0A);
    const panel = Color(0xFF2A1810);
    const coral = Color(0xFFB85A3A);

    final scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: amber,
      onPrimary: Color(0xFF1A0F0A),
      secondary: coral,
      onSecondary: Color(0xFFFFF4EC),
      surface: panel,
      onSurface: cream,
      surfaceContainerHighest: Color(0xFF3A2820),
      error: Color(0xFFFF8A7A),
      onError: Color(0xFF1A0F0A),
    );

    final mitron = MitronColors(
      authGradient: const [
        Color(0xFF2A1810),
        Color(0xFF3D2818),
        Color(0xFF1A0F0A),
      ],
      cardSurface: panel,
      cardShadow: Colors.black.withValues(alpha: 0.45),
      demoBannerBg: const Color(0xFF3D2820),
      demoBannerFg: amber,
      brandTitle: cream,
      brandSubtitle: muted,
      textMuted: muted,
    );

    return _base(scheme, mitron, scaffold: deepOrange);
  }

  /// Sky blue, seafoam, morning shore.
  static ThemeData _coastalBreeze() {
    const ink = Color(0xFF1A3040);
    const muted = Color(0xFF5A7A8A);
    const sky = Color(0xFF5B9BD5);
    const fresh = Color(0xFFF5FAFC);
    const card = Color(0xFFFFFFFF);
    const seafoam = Color(0xFF4A8A9A);

    final scheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: sky,
      onPrimary: Color(0xFFF5FAFC),
      secondary: seafoam,
      onSecondary: Color(0xFFF2F7F8),
      surface: fresh,
      onSurface: ink,
      surfaceContainerHighest: Color(0xFFE0EDF3),
      error: Color(0xFFB3261E),
      onError: Colors.white,
    );

    final mitron = MitronColors(
      authGradient: const [
        Color(0xFFE0EDF3),
        Color(0xFFD0E5EF),
        Color(0xFFF5FAFC),
      ],
      cardSurface: card,
      cardShadow: const Color(0xFF2A4050).withValues(alpha: 0.12),
      demoBannerBg: const Color(0xFFD0E5EF),
      demoBannerFg: sky,
      textMuted: muted,
      brandTitle: ink,
      brandSubtitle: muted,
    );

    return _base(scheme, mitron, scaffold: const Color(0xFFF5FAFC));
  }

  /// Dark olive, forest shadows, twilight canopy.
  static ThemeData _twilightGrove() {
    const cream = Color(0xFFE8E6DC);
    const muted = Color(0xFF8A9A7A);
    const olive = Color(0xFF6B8E5A);
    const deepGreen = Color(0xFF0F1A10);
    const panel = Color(0xFF1A2618);
    const forest = Color(0xFF3A5A3A);

    final scheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: olive,
      onPrimary: Color(0xFF0F1A10),
      secondary: forest,
      onSecondary: Color(0xFFE8F4E8),
      surface: panel,
      onSurface: cream,
      surfaceContainerHighest: Color(0xFF2A3A28),
      error: Color(0xFFFF8A7A),
      onError: Color(0xFF0F1A10),
    );

    final mitron = MitronColors(
      authGradient: const [
        Color(0xFF0F1A10),
        Color(0xFF1A2618),
        Color(0xFF0F1A10),
      ],
      cardSurface: panel,
      cardShadow: const Color(0xFF050A06).withValues(alpha: 0.55),
      demoBannerBg: const Color(0xFF1A2618),
      demoBannerFg: const Color(0xFF8ABF7A),
      brandTitle: cream,
      brandSubtitle: muted,
      textMuted: muted,
    );

    return _base(scheme, mitron, scaffold: deepGreen);
  }

  /// Peach glow, golden sunlight, warm horizon.
  static ThemeData _goldenHour() {
    const ink = Color(0xFF2A1A10);
    const muted = Color(0xFF8A6A4A);
    const peach = Color(0xFFE8A85C);
    const fresh = Color(0xFFFFFBF5);
    const card = Color(0xFFFFFFFF);
    const gold = Color(0xFFD4943A);

    final scheme = ColorScheme.light(
      brightness: Brightness.light,
      primary: peach,
      onPrimary: Color(0xFFFFFBF5),
      secondary: gold,
      onSecondary: Color(0xFFFFF8F0),
      surface: fresh,
      onSurface: ink,
      surfaceContainerHighest: Color(0xFFF5E8D8),
      error: Color(0xFFB3261E),
      onError: Colors.white,
    );

    final mitron = MitronColors(
      authGradient: const [
        Color(0xFFF5E8D8),
        Color(0xFFEDE0C8),
        Color(0xFFFFFBF5),
      ],
      cardSurface: card,
      cardShadow: const Color(0xFF3A2A1A).withValues(alpha: 0.12),
      demoBannerBg: const Color(0xFFEDE0C8),
      demoBannerFg: peach,
      textMuted: muted,
      brandTitle: ink,
      brandSubtitle: muted,
    );

    return _base(scheme, mitron, scaffold: const Color(0xFFFFFBF5));
  }

  static ThemeData _base(
    ColorScheme scheme,
    MitronColors mitron, {
    required Color scaffold,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      extensions: [mitron],
    );

    final isDark = scheme.brightness == Brightness.dark;
    final border = isDark
        ? scheme.outline.withValues(alpha: 0.35)
        : const Color(0xFFD4C4B0);
    final fill = mitron.cardSurface;

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: scaffold,
        foregroundColor: scheme.onSurface,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : fill,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        labelStyle: TextStyle(color: mitron.textMuted),
        hintStyle: TextStyle(color: mitron.textMuted.withValues(alpha: 0.85)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: border, width: 1.5),
      ),
    );
  }
}
