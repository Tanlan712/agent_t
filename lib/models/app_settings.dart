class AppSettings {
  final bool notifyEnabled;
  final int notifyHour;
  final int notifyMinute;
  final bool highlightWishlist;

  const AppSettings({
    this.notifyEnabled = false,
    this.notifyHour = 8,
    this.notifyMinute = 0,
    this.highlightWishlist = true,
  });

  AppSettings copyWith({
    bool? notifyEnabled,
    int? notifyHour,
    int? notifyMinute,
    bool? highlightWishlist,
  }) {
    return AppSettings(
      notifyEnabled: notifyEnabled ?? this.notifyEnabled,
      notifyHour: notifyHour ?? this.notifyHour,
      notifyMinute: notifyMinute ?? this.notifyMinute,
      highlightWishlist: highlightWishlist ?? this.highlightWishlist,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notifyEnabled: json['notifyEnabled'] as bool? ?? false,
      notifyHour: json['notifyHour'] as int? ?? 8,
      notifyMinute: json['notifyMinute'] as int? ?? 0,
      highlightWishlist: json['highlightWishlist'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'notifyEnabled': notifyEnabled,
        'notifyHour': notifyHour,
        'notifyMinute': notifyMinute,
        'highlightWishlist': highlightWishlist,
      };
}
