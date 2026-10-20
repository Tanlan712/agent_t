import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/screens/my_shop_page.dart';
import 'package:valorant_shop_tracker/widgets/skin_tile.dart';

import '../app_harness.dart';
import '../catalog_helpers.dart';
import '../riot_fixtures.dart';

void main() {
  group('Riot 連動', riotTests);
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
    expect(find.text('VP 1500 · 輻能點數 120 · 王國幣 3000'), findsOneWidget);
    expect(find.text('已擁有 2 款造型'), findsOneWidget);
    expect(find.text('已擁有'), findsWidgets);
    expect(h.shop.shop.daily.first.skinUuid, 'skin-odin');
  });

  testWidgets('SkinTile owned 顯示已擁有', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: SkinTile(skin: odin, owned: true))));
    expect(find.text('已擁有'), findsOneWidget);
  });
}
