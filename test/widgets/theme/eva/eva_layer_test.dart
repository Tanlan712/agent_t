import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_layer.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_overlays.dart';

import '../../../app_harness.dart';

/// 規格 §4.4：輸入觸發的彩蛋與 R2／R3。
void main() {
  Future<Harness> pump(WidgetTester tester,
      {ThemeStyleId style = ThemeStyleId.evaFusion,
      Widget? child,
      CurrentShop shop = const CurrentShop(),
      List<String> wishlist = const [],
      bool routes = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, shop: shop, wishlist: wishlist);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style),
        useAppRoutes: routes,
        home: routes
            ? null
            : AppShell(
                currentRoute: '/matches',
                title: '對戰紀錄',
                child: child ?? const Center(child: Text('空白內容')))));
    await tester.pumpAndSettle();
    return h;
  }

  Future<void> type(WidgetTester tester, String text) async {
    for (final c in text.split('')) {
      await tester.sendKeyEvent(
          LogicalKeyboardKey(
              LogicalKeyboardKey.keyA.keyId + c.codeUnitAt(0) - 97),
          character: c);
    }
    await tester.pump();
  }

  Future<void> konami(WidgetTester tester) async {
    for (final k in [
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
    ]) {
      await tester.sendKeyEvent(k);
    }
    await type(tester, 'ba');
  }

  testWidgets('EVA 風格才有 EvaLayer', (tester) async {
    await pump(tester);
    expect(find.byType(EvaLayer), findsOneWidget);
    await pump(tester, style: ThemeStyleId.editorial);
    expect(find.byType(EvaLayer), findsNothing);
  });

  testWidgets('鍵入 sync：沒有載入場次時 NO DATA，並記錄 E5', (tester) async {
    final h = await pump(tester);
    await type(tester, 'sync');
    expect(find.byType(SyncOverlay), findsOneWidget);
    expect(find.text('NO DATA'), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E5'));
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(SyncOverlay), findsNothing);
  });

  testWidgets('輸入框聚焦時打字不觸發彩蛋', (tester) async {
    await pump(tester,
        child: const Center(child: SizedBox(width: 200, child: TextField())));
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await type(tester, 'sync');
    expect(find.byType(SyncOverlay), findsNothing);
  });

  testWidgets('Esc 關閉覆蓋畫面', (tester) async {
    await pump(tester);
    await type(tester, 'sync');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(SyncOverlay), findsNothing);
  });

  testWidgets('彩蛋關閉時不觸發', (tester) async {
    final h = await pump(tester);
    await h.settings.updateEva((s) => s.copyWith(evaEnabled: false));
    await tester.pump();
    await type(tester, 'sync');
    expect(find.byType(SyncOverlay), findsNothing);
  });

  testWidgets('Konami 碼：判定中 → 誤報', (tester) async {
    final h = await pump(tester);
    await konami(tester);
    expect(find.byType(PatternOverlay), findsOneWidget);
    expect(find.text('判定中'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('誤報 FALSE ALARM'), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E1'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(PatternOverlay), findsNothing);
  });

  testWidgets('Konami 後再按 B A：今天日期的標題卡（E20）', (tester) async {
    final h = await pump(tester);
    await konami(tester);
    await type(tester, 'ba');
    expect(find.byType(EpisodeOverlay), findsOneWidget);
    expect(find.text('第 拾捌 話'), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E20'));
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('品牌字連點 5 下：MAGI 依願望清單命中數表決', (tester) async {
    final h = await pump(tester,
        shop: CurrentShop(
          daily: const [
            ShopEntry(skinUuid: 'o', price: 1775),
            ShopEntry(skinUuid: 'p', price: 1775),
          ],
          dailyExpiresAt: DateTime(2099),
        ),
        wishlist: const ['o']);
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const ValueKey('eva-brand')));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(MagiOverlay), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.textContaining('可決 2:1'), findsOneWidget);
    expect(find.textContaining('命中 1 件'), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E2'));
    await tester.pump(const Duration(seconds: 3));
  });

  test('MAGI 表決結果', () {
    expect(magiVotes(0), [false, false, false]);
    expect(magiVotes(1), [true, true, false]);
    expect(magiVotes(3), [true, true, true]);
  });

  test('同步率：最近 20 場、平手不計', () {
    expect(syncRatioOf(const []), isNull);
    expect(syncRatioOf(const [null, null]), isNull);
    expect(syncRatioOf(const [true, false, null, true]), closeTo(2 / 3, 1e-9));
    expect(syncRatioOf([for (var i = 0; i < 30; i++) i < 10]), 0.5);
  });

  testWidgets('閒置 60 秒顯示假人系統，移動滑鼠解除', (tester) async {
    final h = await pump(tester);
    await tester.pump(const Duration(seconds: 61));
    expect(find.byType(DummyOverlay), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E4'));
    await tester.tapAt(const Offset(700, 450));
    await tester.pump();
    expect(find.byType(DummyOverlay), findsNothing);
  });

  testWidgets('點空白處出現 AT 力場波紋；點按鈕不會', (tester) async {
    var taps = 0;
    await pump(tester,
        child: Column(children: [
          const Text('空白內容'),
          TextButton(onPressed: () => taps++, child: const Text('按鈕')),
        ]));
    await tester.tap(find.text('空白內容'));
    await tester.pump();
    expect(find.byType(AtFieldRipple), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AtFieldRipple), findsNothing);
    await tester.tap(find.text('按鈕'));
    await tester.pump();
    expect(taps, 1);
    expect(find.byType(AtFieldRipple), findsNothing);
  });

  testWidgets('連點兩下空白處：六角格翻成 REFUSED（E7）', (tester) async {
    final h = await pump(tester, style: ThemeStyleId.evaAlert);
    await tester.tap(find.text('空白內容'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('空白內容'));
    await tester.pump();
    expect(find.byType(RefusedHex), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E7'));
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(RefusedHex), findsNothing);
  });

  testWidgets('從導覽切頁顯示標題卡 0.6 秒', (tester) async {
    await pump(tester, routes: true);
    await tester.tap(find.byKey(const ValueKey('nav-/matches')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TitleCardOverlay), findsOneWidget);
    // 話數是劇集進度（新設定為第 1 話），不是導覽順序。
    expect(find.text('第 壱 話'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TitleCardOverlay), findsNothing);
  });

  testWidgets('關閉切頁標題卡時不顯示', (tester) async {
    final h = await pump(tester, routes: true);
    await h.settings.updateEva((s) => s.copyWith(evaTitleCards: false));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('nav-/matches')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TitleCardOverlay), findsNothing);
  });

  testWidgets('減少動態效果時覆蓋畫面直接顯示最終狀態', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.evaFusion),
        home: const MediaQuery(
            data:
                MediaQueryData(size: Size(1440, 900), disableAnimations: true),
            child: AppShell(
                currentRoute: '/matches', title: '對戰紀錄', child: Text('x')))));
    await tester.pump();
    await konami(tester);
    expect(find.text('誤報 FALSE ALARM'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
  });
}
