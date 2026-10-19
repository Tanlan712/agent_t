class AppSettings {
  /// 商店每天刷新的時間（本地時間），用來計算每日商店的到期時刻。
  final int resetHour;
  final int resetMinute;
  final bool highlightWishlist;

  const AppSettings({
    this.resetHour = 8,
    this.resetMinute = 0,
    this.highlightWishlist = true,
  });

  AppSettings copyWith({int? resetHour, int? resetMinute, bool? highlightWishlist}) {
    return AppSettings(
      resetHour: resetHour ?? this.resetHour,
      resetMinute: resetMinute ?? this.resetMinute,
      highlightWishlist: highlightWishlist ?? this.highlightWishlist,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      resetHour: json['resetHour'] as int? ?? 8,
      resetMinute: json['resetMinute'] as int? ?? 0,
      highlightWishlist: json['highlightWishlist'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'resetHour': resetHour,
        'resetMinute': resetMinute,
        'highlightWishlist': highlightWishlist,
      };
}
