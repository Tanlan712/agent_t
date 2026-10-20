import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/screens/my_shop_page.dart';
import 'package:valorant_shop_tracker/widgets/skin_card.dart';
import 'package:valorant_shop_tracker/widgets/skin_tile.dart';

import '../app_harness.dart';
import '../catalog_helpers.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  group('Riot 連動', riotTests);
  group('響應式版面', layoutTests);
  final now = DateTime(2026, 10, 19, 10);
  final expires = DateTime(2026, 10, 20, 8);

  CurrentShop dailyShop(List<String> ids) => CurrentShop(
        daily: [for (final id in ids) ShopEntry(skinUuid: id, price: 1775)],
        dailyExpiresAt: expires,
      );

  testWidgets('願望清單造型上架時顯示計數與金框', (tester) async {
    final h = await Harness.create(tester,
        shop: dailyShop(['o', 'p', 'i', 'r']), wishlist: ['o', 'x']);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('今天有 1 個願望清單造型上架'), findsOneWidget);
    expect(find.text('★ 願望清單'), findsOneWidget);
    expect(find.text('剩餘 22 小時 0 分'), findsOneWidget);
  });

  testWidgets('過期的每日商店標示且不計入', (tester) async {
    final h = await Harness.create(tester,
        shop: dailyShop(['o', 'p', 'i', 'r']), wishlist: ['o']);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => expires)));
    await tester.pumpAndSettle();
    expect(find.text('已過期，請更新'), findsOneWidget);
    expect(find.textContaining('今天有'), findsNothing);
  });

  testWidgets('目錄裡找不到的造型顯示未知造型', (tester) async {
    final h =
        await Harness.create(tester, shop: dailyShop(['o', 'p', 'i', 'gone']));
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('未知造型'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('空商店三區都顯示尚未輸入', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('尚未輸入'), findsNWidgets(3));
    expect(find.text('每日商店'), findsOneWidget);
    expect(find.text('夜市'), findsOneWidget);
    expect(find.text('精選組合包'), findsOneWidget);
  });

  testWidgets('關閉標示願望清單時不顯示金框', (tester) async {
    final h = await Harness.create(tester,
        shop: dailyShop(['o', 'p', 'i', 'r']), wishlist: ['o']);
    await h.settings.setHighlightWishlist(false);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('★ 願望清單'), findsNothing);
    expect(find.textContaining('今天有'), findsNothing);
  });

  testWidgets('目錄下載失敗時顯示重試', (tester) async {
    final h =
        await Harness.create(tester, catalog: await failedCatalog(tester));
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pump();
    expect(find.text('重試'), findsOneWidget);
  });
}

void riotTests() {
  final now = DateTime.now();

  testWidgets('未登入時顯示登入 Riot 入口', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('登入 Riot 以自動同步'), findsOneWidget);
  });

  testWidgets('已登入時顯示帳號、同步按鈕，同步後顯示錢包與已擁有', (tester) async {
    final h = await Harness.create(tester,
        catalog: await loadedCatalog(tester, skins: const [
          SkinInfo(
              uuid: 'skin-odin',
              name: '凌空之志 奧丁',
              weaponName: '奧丁',
              tier: Tier.deluxe,
              levelUuid: 'lvl-odin'),
        ]));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('已登入：Tester#TW1（ap）'), findsOneWidget);
    await tester.tap(find.text('從 Riot 同步'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    Finder kpi(String t) => find.descendant(
        of: find.byKey(const ValueKey('shop-kpi')), matching: find.text(t));
    expect(kpi('1500'), findsOneWidget);
    expect(kpi('120'), findsOneWidget);
    expect(kpi('3000'), findsOneWidget);
    // 已擁有造型數移到 KPI。
    expect(kpi('2'), findsOneWidget);
    expect(find.text('已擁有'), findsWidgets);
    expect(h.shop.shop.daily.first.skinUuid, 'skin-odin');
  });

  testWidgets('360 寬、已登入有錢包：帳號列不溢出', (tester) async {
    setWidth(tester, 360);
    final h = await Harness.create(tester,
        catalog: await loadedCatalog(tester, skins: const [
          SkinInfo(
              uuid: 'skin-odin',
              name: '凌空之志 奧丁',
              weaponName: '奧丁',
              tier: Tier.deluxe,
              levelUuid: 'lvl-odin'),
        ]));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.runAsync(() => h.riot.sync(shop: h.shop, catalog: h.catalog));
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    Finder kpi(String t) => find.descendant(
        of: find.byKey(const ValueKey('shop-kpi')), matching: find.text(t));
    expect(kpi('1500'), findsOneWidget);
    expect(kpi('120'), findsOneWidget);
    expect(kpi('3000'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SkinTile owned 顯示已擁有', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SkinTile(skin: odin, owned: true))));
    expect(find.text('已擁有'), findsOneWidget);
  });
}

void layoutTests() {
  final now = DateTime(2026, 10, 19, 10);
  final shop = CurrentShop(
    daily: [
      for (final id in ['o', 'p', 'i', 'r'])
        ShopEntry(skinUuid: id, price: 1775),
    ],
    dailyExpiresAt: DateTime(2026, 10, 20, 8),
  );

  List<double> cardTops(WidgetTester tester) => [
        for (final e in find.byType(SkinCard).evaluate())
          tester.getTopLeft(find.byWidget(e.widget)).dy,
      ];

  testWidgets('1400 寬：每日 4 款在同一列', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester, shop: shop);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    final tops = cardTops(tester);
    expect(tops.length, 4);
    expect(tops.toSet().length, 1);
  });

  testWidgets('帳號列與每日商店標題之間有間距', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    final barBottom = tester
        .getBottomLeft(find.ancestor(
            of: find.text('登入 Riot 以自動同步'), matching: find.byType(Card)))
        .dy;
    final headerTop = tester.getTopLeft(find.text('每日商店')).dy;
    expect(headerTop - barBottom, greaterThanOrEqualTo(16));
  });

  testWidgets('390 寬：每日 4 款各佔一列', (tester) async {
    setWidth(tester, 390);
    final h = await Harness.create(tester, shop: shop);
    await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
    await tester.pumpAndSettle();
    final tops = cardTops(tester);
    expect(tops.toSet().length, tops.length);
    expect(tester.takeException(), isNull);
  });

  group('戰術 HUD', () {
    testWidgets('未登入時 KPI 只有每日商店倒數', (tester) async {
      final h = await Harness.create(tester,
          shop: CurrentShop(
            daily: const [ShopEntry(skinUuid: 'o', price: 1275)],
            dailyExpiresAt: now.add(const Duration(hours: 22)),
          ));
      await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
      await tester.pumpAndSettle();
      Finder kpi(String t) => find.descendant(
          of: find.byKey(const ValueKey('shop-kpi')), matching: find.text(t));
      expect(kpi('商店刷新'), findsOneWidget);
      expect(kpi('22 小時 0 分'), findsOneWidget);
      expect(kpi('VP'), findsNothing);
    });

    testWidgets('夜市折扣用 StatusChip 顯示百分比', (tester) async {
      final h = await Harness.create(tester,
          shop: CurrentShop(
            nightMarket: const [
              NightMarketEntry(
                  skinUuid: 'o', originalPrice: 1000, discountedPrice: 700),
            ],
            nightMarketEndsAt: now.add(const Duration(days: 3)),
          ));
      await tester.pumpWidget(h.wrap(home: MyShopPage(now: () => now)));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(StatusChip, '-30%'), findsOneWidget);
    });
  });
}
