enum AppThemeVariant {
  darkAcademia,
  parchmentLight,
  candlelitHall;

  String get label => switch (this) {
        darkAcademia => 'Dark academia',
        parchmentLight => 'Parchment',
        candlelitHall => 'Candlelit hall',
      };

  static AppThemeVariant fromStorage(String? name) {
    if (name == null) return AppThemeVariant.darkAcademia;
    for (final v in AppThemeVariant.values) {
      if (v.name == name) return v;
    }
    return AppThemeVariant.darkAcademia;
  }
}
