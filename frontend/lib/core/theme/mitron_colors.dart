import 'package:flutter/material.dart';

/// Semantic colors for Mitron UI (auth shells, cards, brand text).
@immutable
class MitronColors extends ThemeExtension<MitronColors> {
  const MitronColors({
    required this.authGradient,
    required this.cardSurface,
    required this.cardShadow,
    required this.demoBannerBg,
    required this.demoBannerFg,
    required this.brandTitle,
    required this.brandSubtitle,
    required this.textMuted,
  });

  final List<Color> authGradient;
  final Color cardSurface;
  final Color cardShadow;
  final Color demoBannerBg;
  final Color demoBannerFg;
  final Color brandTitle;
  final Color brandSubtitle;
  final Color textMuted;

  static MitronColors of(BuildContext context) {
    final ext = Theme.of(context).extension<MitronColors>();
    assert(ext != null, 'MitronColors missing from ThemeData.extensions');
    return ext!;
  }

  @override
  MitronColors copyWith({
    List<Color>? authGradient,
    Color? cardSurface,
    Color? cardShadow,
    Color? demoBannerBg,
    Color? demoBannerFg,
    Color? brandTitle,
    Color? brandSubtitle,
    Color? textMuted,
  }) {
    return MitronColors(
      authGradient: authGradient ?? this.authGradient,
      cardSurface: cardSurface ?? this.cardSurface,
      cardShadow: cardShadow ?? this.cardShadow,
      demoBannerBg: demoBannerBg ?? this.demoBannerBg,
      demoBannerFg: demoBannerFg ?? this.demoBannerFg,
      brandTitle: brandTitle ?? this.brandTitle,
      brandSubtitle: brandSubtitle ?? this.brandSubtitle,
      textMuted: textMuted ?? this.textMuted,
    );
  }

  @override
  MitronColors lerp(ThemeExtension<MitronColors>? other, double t) {
    if (other is! MitronColors) return this;
    if (t == 0) return this;
    if (t == 1) return other;
    final n = authGradient.length <= other.authGradient.length
        ? authGradient.length
        : other.authGradient.length;
    return MitronColors(
      authGradient: List.generate(
        n,
        (i) => Color.lerp(authGradient[i], other.authGradient[i], t)!,
      ),
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
      demoBannerBg: Color.lerp(demoBannerBg, other.demoBannerBg, t)!,
      demoBannerFg: Color.lerp(demoBannerFg, other.demoBannerFg, t)!,
      brandTitle: Color.lerp(brandTitle, other.brandTitle, t)!,
      brandSubtitle: Color.lerp(brandSubtitle, other.brandSubtitle, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
    );
  }

  LinearGradient authBackgroundGradient() {
    final stops = authGradient.length == 3
        ? const [0.0, 0.45, 1.0]
        : List<double>.generate(
            authGradient.length,
            (i) => i / (authGradient.length - 1).clamp(1, 99),
          );
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: authGradient,
      stops: stops,
    );
  }

  List<BoxShadow> cardElevationShadow() => [
        BoxShadow(
          color: cardShadow,
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}
