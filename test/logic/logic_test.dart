import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/default_price.dart';
import 'package:agent_t/logic/shop_time.dart';
import 'package:agent_t/logic/skin_search.dart';
import 'package:agent_t/logic/wishlist_match.dart';
import 'package:agent_t/models/current_shop.dart';
import 'package:agent_t/models/skin_info.dart';
import 'package:agent_t/models/tier.dart';

void main() {
  test('defaultPrice 依稀有度', () {
    expect(defaultPrice(Tier.select), 875);
    expect(defaultPrice(Tier.deluxe), 1275);
    expect(defaultPrice(Tier.premium), 1775);
    expect(defaultPrice(Tier.exclusive), 2175);
    expect(defaultPrice(Tier.ultra), 2475);
  });

  group('nextResetAfter', () {
    test('刷新前 → 當天', () {
      expect(nextResetAfter(DateTime(2026, 10, 19, 7, 59), 8, 0),
          DateTime(2026, 10, 19, 8, 0));
    });
    test('剛好在刷新時刻 → 隔天', () {
      expect(nextResetAfter(DateTime(2026, 10, 19, 8, 0), 8, 0),
          DateTime(2026, 10, 20, 8, 0));
    });
    test('深夜 → 隔天', () {
      expect(nextResetAfter(DateTime(2026, 10, 19, 23, 30), 8, 0),
          DateTime(2026, 10, 20, 8, 0));
    });
    test('跨年', () {
      expect(nextResetAfter(DateTime(2026, 12, 31, 9, 0), 8, 0),
          DateTime(2027, 1, 1, 8, 0));
    });
  });

  group('searchSkins', () {
    const odin = SkinInfo(
        uuid: 'o', name: '凌空之志 奧丁', weaponName: '奧丁', tier: Tier.deluxe);
    const prime = SkinInfo(
        uuid: 'p', name: 'Prime 幻象', weaponName: '幻象', tier: Tier.premium);
    const ion = SkinInfo(
        uuid: 'i', name: '離子 幻象', weaponName: '幻象', tier: Tier.premium);
    const all = [odin, prime, ion];

    test('中文部分比對、忽略空白', () {
      for (final q in ['奧丁', '凌空', '凌空之志奧丁', '  凌空 ']) {
        expect(searchSkins(all, q).map((s) => s.uuid), ['o'], reason: q);
      }
    });
    test('不分大小寫', () {
      expect(searchSkins(all, 'prime').map((s) => s.uuid), ['p']);
    });
    test('空字串＋武器篩選', () {
      expect(searchSkins(all, '', weaponName: '幻象').map((s) => s.uuid),
          ['p', 'i']);
    });
    test('找不到', () {
      expect(searchSkins(all, '不存在'), isEmpty);
    });
  });

  group('wishlistUuidsInShop', () {
    final expires = DateTime(2026, 10, 20, 8, 0);
    final shop = CurrentShop(
      daily: const [
        ShopEntry(skinUuid: 'A', price: 1),
        ShopEntry(skinUuid: 'B', price: 1),
      ],
      dailyExpiresAt: expires,
      nightMarket: const [
        NightMarketEntry(skinUuid: 'C', originalPrice: 2, discountedPrice: 1),
      ],
      nightMarketEndsAt: DateTime(2026, 11, 1, 8, 0),
    );

    test('兩區都有效', () {
      expect(
          wishlistUuidsInShop(
              shop, {'A', 'C', 'D'}, DateTime(2026, 10, 19, 10)),
          {'A', 'C'});
    });
    test('每日已過期', () {
      expect(
          wishlistUuidsInShop(shop, {'A', 'C', 'D'}, DateTime(2026, 10, 20, 9)),
          {'C'});
    });
    test('剛好等於到期時刻視為過期', () {
      expect(wishlistUuidsInShop(shop, {'A', 'C'}, expires), {'C'});
      expect(isDailyActive(shop, expires), isFalse);
    });
    test('空區塊不算有效', () {
      expect(isNightMarketActive(const CurrentShop(), DateTime(2026, 10, 19)),
          isFalse);
    });
  });
}
