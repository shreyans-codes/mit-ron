import 'package:flutter/material.dart';

import 'mitron_colors.dart';
import 'theme_variant.dart';

abstract final class MitronTheme {
  static ThemeData build(AppThemeVariant variant) {
    return switch (variant) {
      AppThemeVariant.darkAcademia => _darkAcademia(),
      AppThemeVariant.parchmentLight => _parchmentLight(),
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
