import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/screens/collection_page.dart';
import 'package:valorant_shop_tracker/screens/progress_page.dart';
import 'package:valorant_shop_tracker/screens/shop_edit_page.dart';
import 'package:valorant_shop_tracker/screens/wishlist_page.dart';

import '../app_harness.dart';
import '../catalog_helpers.dart';
import '../progress_fixtures.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

const _primeLv = SkinInfo(
    uuid: 'p',
    name: 'Prime 幻象',
    weaponName: '幻象',
    tier: Tier.premium,
    levelUuid: 'lvl-noicon');
const _odinLv = SkinInfo(
    uuid: 'o',
    name: '凌空之志 奧丁',
    weaponName: '奧丁',
    tier: Tier.deluxe,
    levelUuid: 'lvl-odin');

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime(2026, 10, 22, 12);

  /// 從 Riot 同步一次商店：每日商店的假資料有 lvl-noicon 2475（Prime 幻象推估 1775）與 lvl-odin 1275。
  Future<Harness> withPrices(WidgetTester tester,
      {List<String> wishlist = const []}) async {
    final catalog = await loadedCatalog(tester,
        skins: const [_primeLv, _odinLv, ion, reaver]);
    final h = await Harness.create(tester,
        catalog: catalog, wishlist: wishlist, riotHttp: riotClient());
    await tester.runAsync(() async {
      await h.riot.login(fakeRedirect);
      await h.riot.sync(shop: h.shop, catalog: h.catalog);
    });
    return h;
  }

  group('實際定價', () {
    testWidgets('選造型時預設價格優先用實際定價，沒有才用推估', (tester) async {
      final h = await withPrices(tester);
      final picks = [_primeLv, _odinLv, ion, reaver];
      await tester.pumpWidget(h.wrap(
        home: ShopEditPage(section: ShopSection.daily, now: () => now),
        routes: {
          '/skin-picker': (context) {
            WidgetsBinding.instance.addPostFrameCallback(
                (_) => Navigator.pop(context, picks.removeAt(0)));
            return const Scaffold();
          },
        },
      ));
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(find.byKey(ValueKey('slot-$i')));
        await tester.tap(find.byKey(ValueKey('slot-$i')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.text('儲存'));
      await tester.tap(find.text('儲存'));
      await tester.pumpAndSettle();
      expect(h.shop.shop.daily[0].price, 2475);
      expect(h.shop.shop.daily[1].price, 1275);
    });

    for (final width in [375.0, 1440.0]) {
      testWidgets('願望清單顯示價格與未擁有總計（$width）', (tester) async {
        setWidth(tester, width);
        final h = await withPrices(tester, wishlist: ['p', 'o']);
        await tester.pumpWidget(h.wrap(home: WishlistPage(now: () => now)));
        await tester.pumpAndSettle();
        expect(find.text('2475'), findsWidgets);
        expect(find.text('2 款・未擁有共 2475 VP'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('沒有定價時願望清單不顯示價格', (tester) async {
      final h = await Harness.create(tester, wishlist: ['p']);
      await tester.pumpWidget(h.wrap(home: WishlistPage(now: () => now)));
      await tester.pumpAndSettle();
      expect(find.text('1 款'), findsOneWidget);
      expect(find.text('VP'), findsNothing);
    });
  });

  group('目前裝備', () {
    Future<Harness> open(WidgetTester tester, {int status = 200}) async {
      final h = await Harness.create(tester,
          riotHttp: riotClient(loadoutStatus: status),
          progressApi: FakeProgressApi());
      await tester.runAsync(() => h.riot.login(fakeRedirect));
      await tester.pumpWidget(h.wrap(home: const CollectionPage()));
      await _settle(tester);
      // 窄螢幕時分頁列要先捲到「目前裝備」。
      await tester.ensureVisible(find.text('目前裝備'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('目前裝備'));
      await tester.pumpAndSettle();
      return h;
    }

    for (final width in [375.0, 1440.0]) {
      testWidgets('列出每把槍的造型與吊飾、噴漆、卡片、稱號（$width）', (tester) async {
        setWidth(tester, width);
        await open(tester);
        expect(find.byKey(const ValueKey('loadout-w-vandal')), findsOneWidget);
        expect(find.text('光幻 暴徒'), findsOneWidget);
        expect(find.text('暴徒・小吊飾'), findsOneWidget);
        expect(find.text('光幻 幻象'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('稱號一'), 200,
            scrollable: find.byType(Scrollable).last);
        expect(find.text('噴漆一'), findsOneWidget);
        // 參考資料找不到的表情（可能不是噴漆）不列出。
        expect(find.text('未知物品'), findsNothing);
        expect(find.text('噴漆 2'), findsNothing);
        expect(find.text('卡片一'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('讀取失敗時只有這個分頁顯示重試', (tester) async {
      setWidth(tester, 1440);
      final h = await open(tester, status: 500);
      expect(find.textContaining('取得目前裝備'), findsOneWidget);
      expect(find.text('重試'), findsOneWidget);
      expect(h.loadout.error, isNotNull);
    });
  });

  group('排隊懲罰', () {
    final clock = DateTime.utc(2026, 10, 21, 21, 15);

    Future<void> open(WidgetTester tester,
        {List<Map<String, dynamic>> penalties = const [],
        int status = 200}) async {
      final h = await Harness.create(tester,
          riotHttp: riotClient(penalties: penalties, penaltiesStatus: status),
          progressApi: FakeProgressApi());
      await tester.runAsync(() => h.riot.login(fakeRedirect));
      await tester.pumpWidget(h.wrap(home: ProgressPage(now: () => clock)));
      await _settle(tester);
    }

    testWidgets('沒有懲罰', (tester) async {
      setWidth(tester, 375);
      await open(tester);
      expect(find.text('目前沒有排隊懲罰'), findsOneWidget);
    });

    for (final width in [375.0, 1440.0]) {
      testWidgets('列出有效的懲罰，已到期的不顯示（$width）', (tester) async {
        setWidth(tester, width);
        await open(tester, penalties: [
          {
            'Expiry': '2026-10-21T23:45:00Z',
            'QueueDelayEffect': {'Seconds': 300},
          },
          {
            'GamesRemaining': 2,
            'RankedRestrictionEffect': {},
            'RMSNotificationEffect': {},
          },
          {'Expiry': '2026-10-01T00:00:00Z', 'GameBanEffect': {}},
        ]);
        expect(find.text('目前有 2 項排隊懲罰'), findsOneWidget);
        expect(find.text('排隊延遲・剩 2 小時 30 分'), findsOneWidget);
        expect(find.text('禁止競技、警告通知・還要 2 場'), findsOneWidget);
        expect(find.textContaining('禁止遊戲'), findsNothing);
        expect(find.text('格式依社群文件推測，可能不完整'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('讀取失敗時顯示重試，不影響通行證', (tester) async {
      setWidth(tester, 1440);
      await open(tester, status: 500);
      expect(find.text('無法取得排隊懲罰'), findsOneWidget);
      expect(find.byKey(const ValueKey('kpi-level')), findsOneWidget);
    });
  });
}
