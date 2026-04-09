enum AppThemeVariant {
  darkAcademia,
  parchmentLight;

  String get label => switch (this) {
    darkAcademia => 'Dark academia',
    parchmentLight => 'Parchment',
  };

  bool get isDark => switch (this) {
    darkAcademia => true,
    parchmentLight => false,
  };

  static AppThemeVariant fromStorage(String? name) {
    if (name == null) return AppThemeVariant.darkAcademia;
    for (final v in AppThemeVariant.values) {
      if (v.name == name) return v;
    }
    return AppThemeVariant.darkAcademia;
  }
}
