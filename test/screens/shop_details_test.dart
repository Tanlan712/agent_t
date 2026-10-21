import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/screens/details/bundle_detail_page.dart';
import 'package:valorant_shop_tracker/screens/my_shop_page.dart';

import '../app_harness.dart';
import '../database_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;
import 'database_details_test.dart' show bareSkin, fakeApi, noIcon;

void main() {
  final now = DateTime(2026, 10, 19, 10);
  final shop = CurrentShop(
    daily: const [ShopEntry(skinUuid: 'o', price: 1275)],
    dailyExpiresAt: now.add(const Duration(hours: 9, minutes: 1)),
    featuredBundle: const BundleEntry(bundleUuid: 'b', price: 7100),
  );

  BundleCatalogLoader loader() => BundleCatalogLoader(fakeApi({
        '/v1/themes': [
          {'uuid': 't-rgx', 'displayName': 'RGX 11z Pro'},
        ],
        '/v1/weapons': [
          {
            ...noIcon(vandalJson()),
            'skins': [bareSkin('o', 't-other'), bareSkin('s1', 't-rgx')],
          },
        ],
      }));

  Finder kpi(String t) => find.descendant(
      of: find.byKey(const ValueKey('shop-kpi')), matching: find.text(t));

  testWidgets('商店刷新倒數用短格式（時:分），窄欄不會被截斷', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester, shop: shop);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(kpi('9:01'), findsOneWidget);
  });

  testWidgets('點每日商店的造型：看等級與炫彩', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester, shop: shop);
    await tester.pumpWidget(h.wrap(
        home: MyShopPage(now: () => now, catalogLoader: loader())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-skin-o')));
    await tester.pumpAndSettle();
    expect(find.text('等級 2'), findsOneWidget);
    expect(find.byKey(const ValueKey('level-video-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('點精選組合包：看組合包內的造型', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester, shop: shop);
    await tester.pumpWidget(h.wrap(
        home: MyShopPage(now: () => now, catalogLoader: loader())));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('shop-bundle')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-bundle')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('db-skin-s1')), findsOneWidget);
    expect(find.byKey(const ValueKey('db-skin-o')), findsNothing);
  });

  testWidgets('目錄裡找不到這款造型時說明', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester,
        shop: CurrentShop(
          daily: const [ShopEntry(skinUuid: 'zzz', price: 1275)],
          dailyExpiresAt: now.add(const Duration(hours: 2)),
        ));
    await tester.pumpWidget(h.wrap(
        home: MyShopPage(now: () => now, catalogLoader: loader())));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('shop-skin-zzz')));
    await tester.pumpAndSettle();
    expect(find.text('找不到這款造型的資料'), findsOneWidget);
  });
}
