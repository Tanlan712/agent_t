import '../models/current_shop.dart';
import 'shop_time.dart';

/// 找出仍有效的每日／夜市區塊中，屬於願望清單的造型 uuid。
Set<String> wishlistUuidsInShop(
  CurrentShop shop,
  Iterable<String> wishlistUuids,
  DateTime now,
) {
  final wanted = wishlistUuids.toSet();
  return {
    if (isDailyActive(shop, now)) ...shop.daily.map((e) => e.skinUuid),
    if (isNightMarketActive(shop, now))
      ...shop.nightMarket.map((e) => e.skinUuid),
  }.intersection(wanted);
}
