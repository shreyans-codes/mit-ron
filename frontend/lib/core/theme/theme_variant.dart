enum AppThemeVariant {
  darkAcademia,
  parchmentLight,
  midnightOcean,
  coastalBreeze,
  forestDawn,
  twilightGrove,
  sunsetDusk,
  goldenHour;

  String get label => switch (this) {
    darkAcademia => 'Dark academia',
    parchmentLight => 'Parchment',
    midnightOcean => 'Midnight ocean',
    coastalBreeze => 'Coastal breeze',
    forestDawn => 'Forest dawn',
    twilightGrove => 'Twilight grove',
    sunsetDusk => 'Sunset dusk',
    goldenHour => 'Golden hour',
  };

  bool get isDark => switch (this) {
    darkAcademia => true,
    parchmentLight => false,
    midnightOcean => true,
    coastalBreeze => false,
    forestDawn => false,
    twilightGrove => true,
    sunsetDusk => true,
    goldenHour => false,
  };

  String get colorFamily => switch (this) {
    darkAcademia => 'Brown',
    parchmentLight => 'Brown',
    midnightOcean => 'Blue',
    coastalBreeze => 'Blue',
    forestDawn => 'Green',
    twilightGrove => 'Green',
    sunsetDusk => 'Orange',
    goldenHour => 'Orange',
  };

  String get description => switch (this) {
    darkAcademia => 'Deep brown leather, hunter green accents',
    parchmentLight => 'Cream paper, sepia ink, library daylight',
    midnightOcean => 'Deep navy, silver accents, moonlit waves',
    coastalBreeze => 'Sky blue, seafoam, morning shore',
    forestDawn => 'Fresh sage, warm moss, morning light',
    twilightGrove => 'Dark olive, forest shadows, twilight canopy',
    sunsetDusk => 'Warm amber, coral sunset, dusky orange',
    goldenHour => 'Peach glow, golden sunlight, warm horizon',
  };

  static AppThemeVariant fromStorage(String? name) {
    if (name == null) return AppThemeVariant.darkAcademia;
    for (final v in AppThemeVariant.values) {
      if (v.name == name) return v;
    }
    return AppThemeVariant.darkAcademia;
  }
}
