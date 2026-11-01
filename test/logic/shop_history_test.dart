import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/shop_history.dart';
import 'package:agent_t/models/current_shop.dart';

CurrentShop _shop(List<String> ids, DateTime expires,
        {List<String> night = const [], DateTime? nightEnds}) =>
    CurrentShop(
      daily: [for (final id in ids) ShopEntry(skinUuid: id, price: 1775)],
      dailyExpiresAt: expires,
      nightMarket: [
        for (final id in night)
          NightMarketEntry(
              skinUuid: id, originalPrice: 1775, discountedPrice: 900),
      ],
      nightMarketEndsAt: nightEnds,
    );

void main() {
  final e1 = DateTime.utc(2026, 11, 1, 0);
  final e2 = DateTime.utc(2026, 11, 2, 0);

  test('同一輪多次同步只記一筆（到期時間差幾秒也算同一輪）', () {
    var h = recordShop(const ShopHistory(), _shop(['a', 'b', 'c', 'd'], e1));
    final again = recordShop(
        h, _shop(['a', 'b', 'c', 'd'], e1.add(const Duration(seconds: 3))));
    expect(identical(again, h), isTrue);
    h = recordShop(h, _shop(['a', 'e', 'f', 'g'], e2));
    expect(h.days.length, 2);
    expect(h.days.last.skins, ['a', 'e', 'f', 'g']);
  });

  test('統計出現次數、上次出現與夜市次數', () {
    var h = recordShop(const ShopHistory(), _shop(['a', 'b', 'c', 'd'], e1));
    h = recordShop(
        h,
        _shop(['a', 'e', 'f', 'g'], e2,
            night: ['b', 'x'], nightEnds: DateTime.utc(2026, 11, 10)));
    final a = appearanceOf(h, 'a')!;
    expect(a.dailyCount, 2);
    expect(a.lastSeen, e2.subtract(const Duration(days: 1)));
    expect(a.lastPrice, 1775);
    expect(appearanceOf(h, 'b')!.nightCount, 1);
    expect(appearanceOf(h, 'x')!.dailyCount, 0);
    expect(appearanceOf(h, 'zzz'), isNull);
    // 最近出現的排前面。
    expect(skinAppearances(h).first.skinUuid, anyOf('a', 'e', 'f', 'g'));
  });

  test('JSON 來回轉換', () {
    final h = recordShop(
        const ShopHistory(),
        _shop(['a', 'b', 'c', 'd'], e1,
            night: ['n'], nightEnds: DateTime.utc(2026, 11, 5)));
    final back = ShopHistory.fromJson(h.toJson());
    expect(back.days.single.skins, ['a', 'b', 'c', 'd']);
    expect(back.days.single.expiresAt, e1);
    expect(back.nights.single.skins, ['n']);
  });

  test('最多保留 maxDays 輪', () {
    var h = const ShopHistory();
    for (var i = 0; i < ShopHistory.maxDays + 5; i++) {
      h = recordShop(h, _shop(['s$i'], e1.add(Duration(days: i))));
    }
    expect(h.days.length, ShopHistory.maxDays);
    expect(h.days.first.skins, ['s5']);
  });

  test('相對日期', () {
    final now = DateTime(2026, 11, 3, 10);
    expect(daysAgoLabel(DateTime(2026, 11, 3, 1), now), '今天');
    expect(daysAgoLabel(DateTime(2026, 11, 2, 23), now), '昨天');
    expect(daysAgoLabel(DateTime(2026, 10, 30), now), '4 天前');
  });
}
