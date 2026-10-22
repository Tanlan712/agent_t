class AppSettings {
  /// 商店每天刷新的時間（本地時間），用來計算每日商店的到期時刻。
  final int resetHour;
  final int resetMinute;
  final bool highlightWishlist;

  /// 上次選的 Riot 伺服器區域（不是機密；token 另由 SessionStorage 保存）。
  final String loginShard;

  /// 使用者自訂的側欄順序（路由）；空的代表預設順序。
  final List<String> navOrder;

  /// 主題（規格 2026-10-21-ui-themes-design.md §2）；未知值由 ThemeChoice.fromSettings 退回預設。
  final String themeStyle;
  final String themeAccent;
  final String themeBrightness;

  /// EVA 系列的互動背景與掃描線。
  final bool backgroundMotion;

  /// EVA 系列的彩蛋與故事層（規格 §4.4、§4.5）；只存在這個瀏覽器，不含他人資料。
  final bool evaEnabled;
  final bool evaTitleCards;
  final String? evaSeenUltraDate;
  final int evaAngelCount;
  final int evaAngelYear;
  final String? evaBootDate;
  final bool evaBerserkUnlocked;
  final int evaEpisodeDays;
  final String? evaLastOpenDate;
  final List<String> evaFoundEggs;

  /// 遠端操作（規格 2026-10-22-remote-control-design.md）：使用者在設定頁同意後才為 true，
  /// 未同意時所有寫入 Riot 的功能都隱藏且不會送出。
  final bool remoteControl;

  /// 同意遠端操作的時間（ISO 字串）；未同意時為 null。
  final String? remoteControlSince;

  /// 預選特務（valorant-api 的特務 UUID，小寫）；只在同意遠端操作時使用。
  final String? preferredAgent;

  const AppSettings({
    this.resetHour = 8,
    this.resetMinute = 0,
    this.highlightWishlist = true,
    this.loginShard = 'ap',
    this.navOrder = const [],
    this.themeStyle = 'editorial',
    this.themeAccent = 'red',
    this.themeBrightness = 'auto',
    this.backgroundMotion = true,
    this.evaEnabled = true,
    this.evaTitleCards = true,
    this.evaSeenUltraDate,
    this.evaAngelCount = 0,
    this.evaAngelYear = 0,
    this.evaBootDate,
    this.evaBerserkUnlocked = false,
    this.evaEpisodeDays = 0,
    this.evaLastOpenDate,
    this.evaFoundEggs = const [],
    this.remoteControl = false,
    this.remoteControlSince,
    this.preferredAgent,
  });

  AppSettings copyWith({
    int? resetHour,
    int? resetMinute,
    bool? highlightWishlist,
    String? loginShard,
    List<String>? navOrder,
    String? themeStyle,
    String? themeAccent,
    String? themeBrightness,
    bool? backgroundMotion,
    bool? evaEnabled,
    bool? evaTitleCards,
    String? evaSeenUltraDate,
    int? evaAngelCount,
    int? evaAngelYear,
    String? evaBootDate,
    bool? evaBerserkUnlocked,
    int? evaEpisodeDays,
    String? evaLastOpenDate,
    List<String>? evaFoundEggs,
  }) {
    return AppSettings(
      resetHour: resetHour ?? this.resetHour,
      resetMinute: resetMinute ?? this.resetMinute,
      highlightWishlist: highlightWishlist ?? this.highlightWishlist,
      loginShard: loginShard ?? this.loginShard,
      navOrder: navOrder ?? this.navOrder,
      themeStyle: themeStyle ?? this.themeStyle,
      themeAccent: themeAccent ?? this.themeAccent,
      themeBrightness: themeBrightness ?? this.themeBrightness,
      backgroundMotion: backgroundMotion ?? this.backgroundMotion,
      evaEnabled: evaEnabled ?? this.evaEnabled,
      evaTitleCards: evaTitleCards ?? this.evaTitleCards,
      evaSeenUltraDate: evaSeenUltraDate ?? this.evaSeenUltraDate,
      evaAngelCount: evaAngelCount ?? this.evaAngelCount,
      evaAngelYear: evaAngelYear ?? this.evaAngelYear,
      evaBootDate: evaBootDate ?? this.evaBootDate,
      evaBerserkUnlocked: evaBerserkUnlocked ?? this.evaBerserkUnlocked,
      evaEpisodeDays: evaEpisodeDays ?? this.evaEpisodeDays,
      evaLastOpenDate: evaLastOpenDate ?? this.evaLastOpenDate,
      evaFoundEggs: evaFoundEggs ?? this.evaFoundEggs,
      remoteControl: remoteControl,
      remoteControlSince: remoteControlSince,
      preferredAgent: preferredAgent,
    );
  }

  /// 遠端操作的三個欄位直接設定（可以清成 null，[copyWith] 做不到）。
  AppSettings withRemote(
          {required bool enabled, String? since, String? preferredAgent}) =>
      AppSettings(
        resetHour: resetHour,
        resetMinute: resetMinute,
        highlightWishlist: highlightWishlist,
        loginShard: loginShard,
        navOrder: navOrder,
        themeStyle: themeStyle,
        themeAccent: themeAccent,
        themeBrightness: themeBrightness,
        backgroundMotion: backgroundMotion,
        evaEnabled: evaEnabled,
        evaTitleCards: evaTitleCards,
        evaSeenUltraDate: evaSeenUltraDate,
        evaAngelCount: evaAngelCount,
        evaAngelYear: evaAngelYear,
        evaBootDate: evaBootDate,
        evaBerserkUnlocked: evaBerserkUnlocked,
        evaEpisodeDays: evaEpisodeDays,
        evaLastOpenDate: evaLastOpenDate,
        evaFoundEggs: evaFoundEggs,
        remoteControl: enabled,
        remoteControlSince: enabled ? since : null,
        preferredAgent: enabled ? preferredAgent : null,
      );

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // 主題與 EVA 欄位型別不對時退回預設，不丟例外（舊版或被手動修改的 localStorage）。
    String str(String key, String fallback) =>
        json[key] is String ? json[key] as String : fallback;
    String? optStr(String key) =>
        json[key] is String ? json[key] as String : null;
    bool flag(String key, bool fallback) =>
        json[key] is bool ? json[key] as bool : fallback;
    int number(String key) => json[key] is int ? json[key] as int : 0;
    final eggs = json['evaFoundEggs'];
    return AppSettings(
      resetHour: json['resetHour'] as int? ?? 8,
      resetMinute: json['resetMinute'] as int? ?? 0,
      highlightWishlist: json['highlightWishlist'] as bool? ?? true,
      loginShard: json['loginShard'] as String? ?? 'ap',
      navOrder: [
        for (final r in json['navOrder'] as List<dynamic>? ?? const [])
          if (r is String) r,
      ],
      themeStyle: str('themeStyle', 'editorial'),
      themeAccent: str('themeAccent', 'red'),
      themeBrightness: str('themeBrightness', 'auto'),
      backgroundMotion: flag('backgroundMotion', true),
      evaEnabled: flag('evaEnabled', true),
      evaTitleCards: flag('evaTitleCards', true),
      evaSeenUltraDate: optStr('evaSeenUltraDate'),
      evaAngelCount: number('evaAngelCount'),
      evaAngelYear: number('evaAngelYear'),
      evaBootDate: optStr('evaBootDate'),
      evaBerserkUnlocked: flag('evaBerserkUnlocked', false),
      evaEpisodeDays: number('evaEpisodeDays'),
      evaLastOpenDate: optStr('evaLastOpenDate'),
      evaFoundEggs: eggs is List
          ? [
              for (final e in eggs)
                if (e is String) e
            ]
          : const [],
      // 只有明確的 true 才算同意；舊版或被手動修改的值一律視為未同意。
      remoteControl: json['remoteControl'] == true,
      remoteControlSince:
          json['remoteControl'] == true ? optStr('remoteControlSince') : null,
      preferredAgent:
          json['remoteControl'] == true ? optStr('preferredAgent') : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'resetHour': resetHour,
        'resetMinute': resetMinute,
        'highlightWishlist': highlightWishlist,
        'loginShard': loginShard,
        'navOrder': navOrder,
        'themeStyle': themeStyle,
        'themeAccent': themeAccent,
        'themeBrightness': themeBrightness,
        'backgroundMotion': backgroundMotion,
        'evaEnabled': evaEnabled,
        'evaTitleCards': evaTitleCards,
        'evaSeenUltraDate': evaSeenUltraDate,
        'evaAngelCount': evaAngelCount,
        'evaAngelYear': evaAngelYear,
        'evaBootDate': evaBootDate,
        'evaBerserkUnlocked': evaBerserkUnlocked,
        'evaEpisodeDays': evaEpisodeDays,
        'evaLastOpenDate': evaLastOpenDate,
        'evaFoundEggs': evaFoundEggs,
        'remoteControl': remoteControl,
        'remoteControlSince': remoteControlSince,
        'preferredAgent': preferredAgent,
      };
}
