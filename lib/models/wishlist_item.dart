class WishlistItem {
  final String skinUuid;
  final DateTime addedAt;

  const WishlistItem({required this.skinUuid, required this.addedAt});

  factory WishlistItem.fromJson(Map<String, dynamic> json) {
    return WishlistItem(
      skinUuid: json['skinUuid'] as String,
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'skinUuid': skinUuid,
        'addedAt': addedAt.toIso8601String(),
      };
}
