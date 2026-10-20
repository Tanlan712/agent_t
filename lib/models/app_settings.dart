class AppSettings {
  /// 商店每天刷新的時間（本地時間），用來計算每日商店的到期時刻。
  final int resetHour;
  final int resetMinute;
  final bool highlightWishlist;

  /// 上次選的 Riot 伺服器區域（不是機密，可以保存；token 依 AGENTS.md 不保存）。
  final String loginShard;

  const AppSettings({
    this.resetHour = 8,
    this.resetMinute = 0,
    this.highlightWishlist = true,
    this.loginShard = 'ap',
  });

  AppSettings copyWith(
      {int? resetHour,
      int? resetMinute,
      bool? highlightWishlist,
      String? loginShard}) {
    return AppSettings(
      resetHour: resetHour ?? this.resetHour,
      resetMinute: resetMinute ?? this.resetMinute,
      highlightWishlist: highlightWishlist ?? this.highlightWishlist,
      loginShard: loginShard ?? this.loginShard,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      resetHour: json['resetHour'] as int? ?? 8,
      resetMinute: json['resetMinute'] as int? ?? 0,
      highlightWishlist: json['highlightWishlist'] as bool? ?? true,
      loginShard: json['loginShard'] as String? ?? 'ap',
    );
  }

  Map<String, dynamic> toJson() => {
        'resetHour': resetHour,
        'resetMinute': resetMinute,
        'highlightWishlist': highlightWishlist,
        'loginShard': loginShard,
      };
}
