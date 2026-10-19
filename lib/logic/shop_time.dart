import '../models/current_shop.dart';

/// 回傳嚴格晚於 [now] 的下一個本地 [hour]:[minute]。
DateTime nextResetAfter(DateTime now, int hour, int minute) {
  final today = DateTime(now.year, now.month, now.day, hour, minute);
  if (today.isAfter(now)) return today;
  return DateTime(now.year, now.month, now.day + 1, hour, minute);
}

bool isDailyActive(CurrentShop shop, DateTime now) {
  final expires = shop.dailyExpiresAt;
  return shop.daily.isNotEmpty && expires != null && now.isBefore(expires);
}

bool isNightMarketActive(CurrentShop shop, DateTime now) {
  final ends = shop.nightMarketEndsAt;
  return shop.nightMarket.isNotEmpty && ends != null && now.isBefore(ends);
}
