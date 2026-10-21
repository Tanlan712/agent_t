class ShopEntry {
  final String skinUuid;
  final int price;

  const ShopEntry({required this.skinUuid, required this.price});

  factory ShopEntry.fromJson(Map<String, dynamic> json) => ShopEntry(
        skinUuid: json['skinUuid'] as String,
        price: json['price'] as int,
      );

  Map<String, dynamic> toJson() => {'skinUuid': skinUuid, 'price': price};
}

class NightMarketEntry {
  final String skinUuid;
  final int originalPrice;
  final int discountedPrice;

  const NightMarketEntry({
    required this.skinUuid,
    required this.originalPrice,
    required this.discountedPrice,
  });

  factory NightMarketEntry.fromJson(Map<String, dynamic> json) =>
      NightMarketEntry(
        skinUuid: json['skinUuid'] as String,
        originalPrice: json['originalPrice'] as int,
        discountedPrice: json['discountedPrice'] as int,
      );

  Map<String, dynamic> toJson() => {
        'skinUuid': skinUuid,
        'originalPrice': originalPrice,
        'discountedPrice': discountedPrice,
      };
}

class BundleEntry {
  final String bundleUuid;
  final int price;

  /// 這個組合包下架的時間；手動輸入或舊資料沒有。
  final DateTime? endsAt;

  const BundleEntry(
      {required this.bundleUuid, required this.price, this.endsAt});

  factory BundleEntry.fromJson(Map<String, dynamic> json) => BundleEntry(
        bundleUuid: json['bundleUuid'] as String,
        price: json['price'] as int,
        endsAt: json['endsAt'] is String
            ? DateTime.tryParse(json['endsAt'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'bundleUuid': bundleUuid,
        'price': price,
        if (endsAt != null) 'endsAt': endsAt!.toIso8601String(),
      };
}

/// 使用者手動輸入的當前商店；只保留一份。
class CurrentShop {
  final List<ShopEntry> daily;
  final DateTime? dailyExpiresAt;
  final DateTime? dailyUpdatedAt;
  final List<NightMarketEntry> nightMarket;
  final DateTime? nightMarketEndsAt;
  final DateTime? nightMarketUpdatedAt;
  final BundleEntry? featuredBundle;

  /// 所有精選組合包（Riot 同時上架多個）；舊資料只有 [featuredBundle]。
  final List<BundleEntry> featuredBundles;
  final DateTime? featuredBundleUpdatedAt;

  const CurrentShop({
    this.daily = const [],
    this.dailyExpiresAt,
    this.dailyUpdatedAt,
    this.nightMarket = const [],
    this.nightMarketEndsAt,
    this.nightMarketUpdatedAt,
    this.featuredBundle,
    this.featuredBundles = const [],
    this.featuredBundleUpdatedAt,
  });

  /// 要顯示的精選組合包：有 [featuredBundles] 用它，否則用 [featuredBundle]。
  List<BundleEntry> get bundles => featuredBundles.isNotEmpty
      ? featuredBundles
      : [if (featuredBundle case final b?) b];

  CurrentShop copyWith({
    List<ShopEntry>? daily,
    DateTime? dailyExpiresAt,
    DateTime? dailyUpdatedAt,
    List<NightMarketEntry>? nightMarket,
    DateTime? nightMarketEndsAt,
    DateTime? nightMarketUpdatedAt,
    BundleEntry? featuredBundle,
    List<BundleEntry>? featuredBundles,
    DateTime? featuredBundleUpdatedAt,
  }) {
    return CurrentShop(
      daily: daily ?? this.daily,
      dailyExpiresAt: dailyExpiresAt ?? this.dailyExpiresAt,
      dailyUpdatedAt: dailyUpdatedAt ?? this.dailyUpdatedAt,
      nightMarket: nightMarket ?? this.nightMarket,
      nightMarketEndsAt: nightMarketEndsAt ?? this.nightMarketEndsAt,
      nightMarketUpdatedAt: nightMarketUpdatedAt ?? this.nightMarketUpdatedAt,
      featuredBundle: featuredBundle ?? this.featuredBundle,
      featuredBundles: featuredBundles ?? this.featuredBundles,
      featuredBundleUpdatedAt:
          featuredBundleUpdatedAt ?? this.featuredBundleUpdatedAt,
    );
  }

  CurrentShop clearDaily() => CurrentShop(
        nightMarket: nightMarket,
        nightMarketEndsAt: nightMarketEndsAt,
        nightMarketUpdatedAt: nightMarketUpdatedAt,
        featuredBundle: featuredBundle,
        featuredBundles: featuredBundles,
        featuredBundleUpdatedAt: featuredBundleUpdatedAt,
      );

  CurrentShop clearNightMarket() => CurrentShop(
        daily: daily,
        dailyExpiresAt: dailyExpiresAt,
        dailyUpdatedAt: dailyUpdatedAt,
        featuredBundle: featuredBundle,
        featuredBundles: featuredBundles,
        featuredBundleUpdatedAt: featuredBundleUpdatedAt,
      );

  CurrentShop clearFeaturedBundle() => CurrentShop(
        daily: daily,
        dailyExpiresAt: dailyExpiresAt,
        dailyUpdatedAt: dailyUpdatedAt,
        nightMarket: nightMarket,
        nightMarketEndsAt: nightMarketEndsAt,
        nightMarketUpdatedAt: nightMarketUpdatedAt,
      );

  factory CurrentShop.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final v = json[key] as String?;
      return v == null ? null : DateTime.parse(v);
    }

    final bundle = json['featuredBundle'] as Map<String, dynamic>?;
    return CurrentShop(
      daily: (json['daily'] as List<dynamic>? ?? [])
          .map((e) => ShopEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      dailyExpiresAt: date('dailyExpiresAt'),
      dailyUpdatedAt: date('dailyUpdatedAt'),
      nightMarket: (json['nightMarket'] as List<dynamic>? ?? [])
          .map((e) => NightMarketEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      nightMarketEndsAt: date('nightMarketEndsAt'),
      nightMarketUpdatedAt: date('nightMarketUpdatedAt'),
      featuredBundle: bundle == null ? null : BundleEntry.fromJson(bundle),
      featuredBundles: [
        for (final b in json['featuredBundles'] as List<dynamic>? ?? const [])
          if (b is Map<String, dynamic>) BundleEntry.fromJson(b),
      ],
      featuredBundleUpdatedAt: date('featuredBundleUpdatedAt'),
    );
  }

  Map<String, dynamic> toJson() => {
        'daily': daily.map((e) => e.toJson()).toList(),
        'dailyExpiresAt': dailyExpiresAt?.toIso8601String(),
        'dailyUpdatedAt': dailyUpdatedAt?.toIso8601String(),
        'nightMarket': nightMarket.map((e) => e.toJson()).toList(),
        'nightMarketEndsAt': nightMarketEndsAt?.toIso8601String(),
        'nightMarketUpdatedAt': nightMarketUpdatedAt?.toIso8601String(),
        'featuredBundle': featuredBundle?.toJson(),
        'featuredBundles': featuredBundles.map((e) => e.toJson()).toList(),
        'featuredBundleUpdatedAt': featuredBundleUpdatedAt?.toIso8601String(),
      };
}
