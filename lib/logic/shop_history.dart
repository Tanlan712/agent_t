import '../models/current_shop.dart';

/// 商店歷史（規格 docs/superpowers/specs/2026-11-01-five-features-design.md §1）：
/// 每次同步到的每日商店與夜市，各帳號分開、只存在本機。

/// 一輪每日商店（4 款）；以到期時間辨識是哪一輪。
class ShopDay {
  final DateTime expiresAt;
  final List<String> skins;
  final List<int> prices;

  const ShopDay(
      {required this.expiresAt, required this.skins, this.prices = const []});

  /// 這一輪上架的時間（到期前 24 小時）。
  DateTime get startsAt => expiresAt.subtract(const Duration(days: 1));

  factory ShopDay.fromJson(Map<String, dynamic> json) => ShopDay(
        expiresAt: DateTime.parse(json['e'] as String),
        skins: [for (final s in json['s'] as List<dynamic>) s as String],
        prices: [
          for (final p in json['p'] as List<dynamic>? ?? const [])
            (p as num).toInt()
        ],
      );

  Map<String, dynamic> toJson() => {
        'e': expiresAt.toUtc().toIso8601String(),
        's': skins,
        'p': prices,
      };
}

/// 一期夜市（6 款）；以結束時間辨識。
class NightRun {
  final DateTime endsAt;
  final List<String> skins;
  final List<int> prices;

  const NightRun(
      {required this.endsAt, required this.skins, this.prices = const []});

  factory NightRun.fromJson(Map<String, dynamic> json) => NightRun(
        endsAt: DateTime.parse(json['e'] as String),
        skins: [for (final s in json['s'] as List<dynamic>) s as String],
        prices: [
          for (final p in json['p'] as List<dynamic>? ?? const [])
            (p as num).toInt()
        ],
      );

  Map<String, dynamic> toJson() => {
        'e': endsAt.toUtc().toIso8601String(),
        's': skins,
        'p': prices,
      };
}

class ShopHistory {
  /// 每日商店，依時間由舊到新。
  final List<ShopDay> days;

  /// 夜市，依時間由舊到新。
  final List<NightRun> nights;

  const ShopHistory({this.days = const [], this.nights = const []});

  static const maxDays = 1000;
  static const maxNights = 100;

  /// 同一輪商店在不同時間同步，到期時間會差幾秒（由剩餘秒數推算）；差距在這以內視為同一輪。
  static const sameRotation = Duration(hours: 2);

  bool get isEmpty => days.isEmpty && nights.isEmpty;

  factory ShopHistory.fromJson(Map<String, dynamic> json) => ShopHistory(
        days: [
          for (final d in json['days'] as List<dynamic>? ?? const [])
            if (d is Map<String, dynamic>) ShopDay.fromJson(d),
        ],
        nights: [
          for (final n in json['nights'] as List<dynamic>? ?? const [])
            if (n is Map<String, dynamic>) NightRun.fromJson(n),
        ],
      );

  Map<String, dynamic> toJson() => {
        'days': [for (final d in days) d.toJson()],
        'nights': [for (final n in nights) n.toJson()],
      };
}

bool _near(DateTime a, DateTime b) =>
    a.difference(b).abs() <= ShopHistory.sameRotation;

/// 把這次同步到的商店記進歷史；同一輪以最後一次為準。沒有變化時回傳同一個物件。
ShopHistory recordShop(ShopHistory h, CurrentShop shop) {
  var days = h.days;
  var nights = h.nights;
  final expires = shop.dailyExpiresAt;
  if (shop.daily.isNotEmpty && expires != null) {
    final day = ShopDay(
      expiresAt: expires,
      skins: [for (final e in shop.daily) e.skinUuid],
      prices: [for (final e in shop.daily) e.price],
    );
    final i = days.indexWhere((d) => _near(d.expiresAt, expires));
    if (i < 0 || !_sameList(days[i].skins, day.skins)) {
      days = [
        for (final d in days)
          if (!_near(d.expiresAt, expires)) d,
        day,
      ]..sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
      if (days.length > ShopHistory.maxDays) {
        days = days.sublist(days.length - ShopHistory.maxDays);
      }
    }
  }
  final ends = shop.nightMarketEndsAt;
  if (shop.nightMarket.isNotEmpty && ends != null) {
    final run = NightRun(
      endsAt: ends,
      skins: [for (final e in shop.nightMarket) e.skinUuid],
      prices: [for (final e in shop.nightMarket) e.discountedPrice],
    );
    final i = nights.indexWhere((n) => _near(n.endsAt, ends));
    if (i < 0 || !_sameList(nights[i].skins, run.skins)) {
      nights = [
        for (final n in nights)
          if (!_near(n.endsAt, ends)) n,
        run,
      ]..sort((a, b) => a.endsAt.compareTo(b.endsAt));
      if (nights.length > ShopHistory.maxNights) {
        nights = nights.sublist(nights.length - ShopHistory.maxNights);
      }
    }
  }
  if (identical(days, h.days) && identical(nights, h.nights)) return h;
  return ShopHistory(days: days, nights: nights);
}

bool _sameList(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 一個造型在歷史裡的出現紀錄。
class SkinAppearance {
  final String skinUuid;

  /// 出現在每日商店的那幾輪的上架時間，由新到舊。
  final List<DateTime> dailyDates;
  final int? lastPrice;

  /// 出現在夜市的次數。
  final int nightCount;

  const SkinAppearance({
    required this.skinUuid,
    required this.dailyDates,
    this.lastPrice,
    this.nightCount = 0,
  });

  int get dailyCount => dailyDates.length;
  DateTime? get lastSeen => dailyDates.isEmpty ? null : dailyDates.first;
}

/// 統計每個造型出現的次數與最後出現時間，依最後出現由新到舊排序。
List<SkinAppearance> skinAppearances(ShopHistory h) {
  final dates = <String, List<DateTime>>{};
  final price = <String, int>{};
  final night = <String, int>{};
  for (final d in h.days.reversed) {
    for (var i = 0; i < d.skins.length; i++) {
      final id = d.skins[i];
      (dates[id] ??= []).add(d.startsAt);
      if (i < d.prices.length) price.putIfAbsent(id, () => d.prices[i]);
    }
  }
  for (final n in h.nights) {
    for (final id in n.skins) {
      night[id] = (night[id] ?? 0) + 1;
    }
  }
  final ids = {...dates.keys, ...night.keys};
  final list = [
    for (final id in ids)
      SkinAppearance(
        skinUuid: id,
        dailyDates: dates[id] ?? const [],
        lastPrice: price[id],
        nightCount: night[id] ?? 0,
      ),
  ];
  list.sort((a, b) {
    final x = a.lastSeen, y = b.lastSeen;
    if (x == null && y == null) return b.nightCount.compareTo(a.nightCount);
    if (x == null) return 1;
    if (y == null) return -1;
    return y.compareTo(x);
  });
  return list;
}

/// 單一造型的出現紀錄；沒出現過時 null。
SkinAppearance? appearanceOf(ShopHistory h, String skinUuid) {
  final id = skinUuid;
  for (final a in skinAppearances(h)) {
    if (a.skinUuid == id) return a;
  }
  return null;
}

/// 「3 天前」「今天」這類相對日期（以本地日曆日計算）。
String daysAgoLabel(DateTime when, DateTime now) {
  final a = DateTime(when.year, when.month, when.day);
  final b = DateTime(now.year, now.month, now.day);
  final n = b.difference(a).inDays;
  if (n <= 0) return '今天';
  if (n == 1) return '昨天';
  return '$n 天前';
}
