class AppSettings {
  /// 商店每天刷新的時間（本地時間），用來計算每日商店的到期時刻。
  final int resetHour;
  final int resetMinute;
  final bool highlightWishlist;

  /// 上次選的 Riot 伺服器區域（不是機密；token 另由 SessionStorage 保存）。
  final String loginShard;

  /// 主題（規格 2026-10-21-ui-themes-design.md §2）；未知值由 ThemeChoice.fromSettings 退回預設。
  final String themeStyle;
  final String themeAccent;
  final String themeBrightness;

  /// EVA 系列的互動背景與掃描線。
  final bool backgroundMotion;

  const AppSettings({
    this.resetHour = 8,
    this.resetMinute = 0,
    this.highlightWishlist = true,
    this.loginShard = 'ap',
    this.themeStyle = 'editorial',
    this.themeAccent = 'red',
    this.themeBrightness = 'auto',
    this.backgroundMotion = true,
  });

  AppSettings copyWith({
    int? resetHour,
    int? resetMinute,
    bool? highlightWishlist,
    String? loginShard,
    String? themeStyle,
    String? themeAccent,
    String? themeBrightness,
    bool? backgroundMotion,
  }) {
    return AppSettings(
      resetHour: resetHour ?? this.resetHour,
      resetMinute: resetMinute ?? this.resetMinute,
      highlightWishlist: highlightWishlist ?? this.highlightWishlist,
      loginShard: loginShard ?? this.loginShard,
      themeStyle: themeStyle ?? this.themeStyle,
      themeAccent: themeAccent ?? this.themeAccent,
      themeBrightness: themeBrightness ?? this.themeBrightness,
      backgroundMotion: backgroundMotion ?? this.backgroundMotion,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // 主題欄位型別不對時退回預設，不丟例外（舊版或被手動修改的 localStorage）。
    String str(String key, String fallback) =>
        json[key] is String ? json[key] as String : fallback;
    return AppSettings(
      resetHour: json['resetHour'] as int? ?? 8,
      resetMinute: json['resetMinute'] as int? ?? 0,
      highlightWishlist: json['highlightWishlist'] as bool? ?? true,
      loginShard: json['loginShard'] as String? ?? 'ap',
      themeStyle: str('themeStyle', 'editorial'),
      themeAccent: str('themeAccent', 'red'),
      themeBrightness: str('themeBrightness', 'auto'),
      backgroundMotion: json['backgroundMotion'] is bool
          ? json['backgroundMotion'] as bool
          : true,
    );
  }

  Map<String, dynamic> toJson() => {
        'resetHour': resetHour,
        'resetMinute': resetMinute,
        'highlightWishlist': highlightWishlist,
        'loginShard': loginShard,
        'themeStyle': themeStyle,
        'themeAccent': themeAccent,
        'themeBrightness': themeBrightness,
        'backgroundMotion': backgroundMotion,
      };
}
