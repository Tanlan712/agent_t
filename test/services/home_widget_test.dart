import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/models/current_shop.dart';
import 'package:agent_t/services/home_widget.dart';

void main() {
  final now = DateTime(2026, 10, 23, 12);

  test('小工具資料：每日 4 款名稱與價格、到期時間；夜市開放時附註', () {
    final shop = CurrentShop(
      daily: const [
        ShopEntry(skinUuid: 'a', price: 1775),
        ShopEntry(skinUuid: 'b', price: 875),
      ],
      dailyExpiresAt: now.add(const Duration(hours: 3)),
      nightMarket: const [
        NightMarketEntry(skinUuid: 'n', originalPrice: 100, discountedPrice: 50)
      ],
      nightMarketEndsAt: now.add(const Duration(days: 2)),
    );
    final data = homeWidgetData(shop, (id) => id == 'a' ? '光幻 暴徒' : null, now)!;
    expect(data['lines'], [
      {'name': '光幻 暴徒', 'price': 1775},
      {'name': '未知造型', 'price': 875},
    ]);
    expect(data['expiresAt'],
        now.add(const Duration(hours: 3)).millisecondsSinceEpoch);
    expect(data['night'], '夜市開放中（1 款）');
    // 不含任何帳號或 token 欄位。
    expect(data.keys.toSet(), {'lines', 'expiresAt', 'night'});
  });

  test('沒有每日商店時不更新小工具', () {
    expect(homeWidgetData(const CurrentShop(), (_) => null, now), isNull);
  });

  test('測試環境（非 Android）push 不做任何事', () async {
    await HomeWidgetSync().push(const CurrentShop(), (_) => null);
  });
}
