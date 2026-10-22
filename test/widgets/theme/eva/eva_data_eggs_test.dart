import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart'
    show wishlistEnabled;
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_data_eggs.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_header.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_status.dart';

import '../../../app_harness.dart';

/// 規格 §4.4：資料觸發的彩蛋（E3、E6、E8、E10、E13～E19）與 R4。
void main() {
  group('純函式', () {
    test('E6／E19 代碼行：紀念日優先於夜間', () {
      expect(
          codeLineOverride(DateTime(2026, 10, 21, 3)), '夜間警戒態勢 / NIGHT WATCH');
      expect(codeLineOverride(DateTime(2026, 10, 4, 3)), 'ANNIVERSARY / 放送紀念日');
      expect(
          codeLineOverride(DateTime(2026, 10, 4, 12)), 'ANNIVERSARY / 放送紀念日');
      expect(codeLineOverride(DateTime(2026, 10, 21, 5)), isNull);
    });

    test('E13 印章：前 3 場都勝或都敗；不足 3 場不蓋', () {
      expect(stampFor(const [true, true, true, false]), StampKind.win);
      expect(stampFor(const [false, false, false]), StampKind.loss);
      expect(stampFor(const [true, false, true]), isNull);
      expect(stampFor(const [true, true]), isNull);
      expect(stampFor(const [true, null, true]), isNull);
    });

    test('E14 四件全部在願望清單', () {
      expect(
          allWishlisted(const ['a', 'b', 'c', 'd'], {'a', 'b', 'c', 'd', 'e'}),
          isTrue);
      expect(
          allWishlisted(const ['a', 'b', 'c', 'd'], {'a', 'b', 'c'}), isFalse);
      expect(allWishlisted(const [], {'a'}), isFalse);
    });

    test('E3 使徒：今日商店最高的 Ultra／Exclusive', () {
      expect(angelTier(const [Tier.select, Tier.exclusive]), Tier.exclusive);
      expect(angelTier(const [Tier.exclusive, Tier.ultra, null]), Tier.ultra);
      expect(angelTier(const [Tier.premium, null]), isNull);
    });

    test('E8 倒數階段', () {
      expect(countdownPhase(const Duration(minutes: 5)), CountdownPhase.normal);
      expect(
          countdownPhase(const Duration(seconds: 59)), CountdownPhase.last60);
      expect(
          countdownPhase(const Duration(hours: 23, minutes: 59, seconds: 30)),
          CountdownPhase.reboot);
    });

    test('E16 連續失敗計數：成功一次就歸零', () {
      final c = FailureCounter();
      c.update(loading: true, error: null);
      c.update(loading: false, error: 'x');
      c.update(loading: true, error: null);
      c.update(loading: false, error: 'x');
      c.update(loading: true, error: null);
      c.update(loading: false, error: 'y');
      expect(c.count, 3);
      c.update(loading: false, error: null);
      expect(c.count, 0);
    });
  });

  Future<Harness> pumpShell(WidgetTester tester, String route,
      {ThemeStyleId style = ThemeStyleId.evaFusion,
      CurrentShop shop = const CurrentShop(),
      List<String> wishlist = const [],
      BrightnessMode mode = BrightnessMode.auto,
      Widget? child}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, shop: shop, wishlist: wishlist);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style, mode: mode),
        home: AppShell(
            currentRoute: route,
            title: '頁面',
            child: child ?? const Text('x'))));
    await tester.pump();
    return h;
  }

  testWidgets('E10 每天第一次開啟：開機自檢（不擋點擊），隔天才再出現', (tester) async {
    final h = await pumpShell(tester, '/matches');
    await tester.pump();
    expect(find.byType(BootOverlay), findsOneWidget);
    expect(find.textContaining('> CATALOG'), findsOneWidget);
    expect(h.settings.settings.evaBootDate, isNotNull);
    expect(h.settings.settings.evaFoundEggs, contains('E10'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(BootOverlay), findsNothing);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.evaFusion),
        home: const AppShell(
            currentRoute: '/maps', title: 't', child: Text('y'))));
    await tester.pump();
    await tester.pump();
    expect(find.byType(BootOverlay), findsNothing);
  });

  testWidgets('E3 今日有 Ultra：使徒接近標題卡，同一天只一次', (tester) async {
    final shop = CurrentShop(
        daily: const [ShopEntry(skinUuid: 'r', price: 2175)],
        dailyExpiresAt: DateTime(2099));
    final h = await pumpShell(tester, '/', shop: shop);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AngelOverlay), findsOneWidget);
    expect(find.textContaining('使徒'), findsWidgets);
    expect(find.textContaining('PATTERN: ULTRA'), findsOneWidget);
    expect(h.settings.settings.evaAngelCount, 1);
    expect(h.settings.settings.evaFoundEggs, contains('E3'));
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.evaFusion),
        home: const AppShell(currentRoute: '/', title: 't', child: Text('y'))));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(AngelOverlay), findsNothing);
    expect(h.settings.settings.evaAngelCount, 1);
  });

  testWidgets('E14 四件全命中：補完達成橫幅', (tester) async {
    final shop = CurrentShop(daily: [
      for (final id in ['o', 'p', 'i', 'r']) ShopEntry(skinUuid: id, price: 1)
    ], dailyExpiresAt: DateTime(2099));
    final h = await pumpShell(tester, '/',
        shop: shop, wishlist: const ['o', 'p', 'i', 'r']);
    expect(find.byKey(const ValueKey('banner-complete')), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E14'));
  }, skip: !wishlistEnabled);

  testWidgets('E14 願望清單暫時關閉時不觸發', (tester) async {
    final shop = CurrentShop(daily: [
      for (final id in ['o', 'p', 'i', 'r']) ShopEntry(skinUuid: id, price: 1)
    ], dailyExpiresAt: DateTime(2099));
    final h = await pumpShell(tester, '/',
        shop: shop, wishlist: const ['o', 'p', 'i', 'r']);
    expect(find.byKey(const ValueKey('banner-complete')), findsNothing);
    expect(h.settings.settings.evaFoundEggs, isNot(contains('E14')));
  }, skip: wishlistEnabled);

  testWidgets('E15 夜市開放：非常事態橫幅', (tester) async {
    final shop = CurrentShop(nightMarket: const [
      NightMarketEntry(skinUuid: 'o', originalPrice: 1775, discountedPrice: 900)
    ], nightMarketEndsAt: DateTime(2099));
    await pumpShell(tester, '/', shop: shop);
    expect(find.byKey(const ValueKey('banner-night')), findsOneWidget);
    await pumpShell(tester, '/');
    expect(find.byKey(const ValueKey('banner-night')), findsNothing);
  });

  testWidgets('E13 印章元件', (tester) async {
    await pumpShell(tester, '/matches',
        child: const Center(child: EvaStamp(results: [true, true, true])));
    expect(find.byKey(const ValueKey('stamp-win')), findsOneWidget);
    await pumpShell(tester, '/matches',
        child: const Center(child: EvaStamp(results: [false, false, false])));
    expect(find.byKey(const ValueKey('stamp-loss')), findsOneWidget);
    await pumpShell(tester, '/matches',
        child: const Center(child: EvaStamp(results: [true, true])));
    expect(find.byKey(const ValueKey('stamp-win')), findsNothing);
    expect(find.byKey(const ValueKey('stamp-loss')), findsNothing);
  });

  testWidgets('E17 捲到最底：液面升起，往回捲消退', (tester) async {
    await pumpShell(tester, '/matches',
        child: ListView(key: const ValueKey('content-list'), children: [
          for (var i = 0; i < 60; i++)
            SizedBox(height: 40, child: Text('row $i'))
        ]));
    expect(find.byKey(const ValueKey('lcl-fill')), findsNothing);
    await tester.drag(
        find.byKey(const ValueKey('content-list')), const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lcl-fill')), findsOneWidget);
    await tester.drag(
        find.byKey(const ValueKey('content-list')), const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('lcl-fill')), findsNothing);
  });

  testWidgets('E18 機密文件：雙擊標題切換德文副標', (tester) async {
    final h = await pumpShell(tester, '/matches',
        style: ThemeStyleId.evaMonitor, mode: BrightnessMode.light);
    expect(find.text('作戰記錄'), findsOneWidget);
    expect(find.text('Einsatzprotokoll'), findsNothing);
    final title = find.byKey(const ValueKey('classified-title'));
    await tester.tap(title);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(title);
    await tester.pump();
    expect(find.text('Einsatzprotokoll'), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E18'));
  });

  testWidgets('E8 最後 60 秒放大，刷新後 60 秒內顯示 REBOOT', (tester) async {
    await pumpShell(tester, '/matches',
        child: Center(
            child: RefreshCountdown(
                now: () => DateTime(2026, 10, 21, 7, 59, 30))));
    expect(find.byKey(const ValueKey('countdown-final')), findsOneWidget);
    await pumpShell(tester, '/matches',
        child: Center(
            child:
                RefreshCountdown(now: () => DateTime(2026, 10, 21, 8, 0, 20))));
    expect(find.text('再起動 REBOOT'), findsOneWidget);
    expect(find.text('請按重新整理'), findsOneWidget);
  });

  testWidgets('R4 心理圖表：沒有資料顯示 NO SIGNAL，有資料畫線', (tester) async {
    // F1 的頁首沒有心理圖表，只會找到測試放的這一個。
    await pumpShell(tester, '/matches',
        style: ThemeStyleId.evaAlert,
        child: const Center(child: Psychograph(values: [])));
    expect(find.text('NO SIGNAL'), findsOneWidget);
    await pumpShell(tester, '/matches',
        style: ThemeStyleId.evaAlert,
        child: const Center(child: Psychograph(values: [180, 240, 210])));
    expect(find.text('NO SIGNAL'), findsNothing);
    expect(find.byKey(const ValueKey('psychograph-line')), findsOneWidget);
  });

  testWidgets('E16 連續失敗 3 次顯示 CONNECTION LOST', (tester) async {
    await pumpShell(tester, '/matches',
        child: const Center(child: ConnectionLostBar(failures: 3)));
    expect(find.text('CONNECTION LOST'), findsOneWidget);
    await pumpShell(tester, '/matches',
        child: const Center(child: ConnectionLostBar(failures: 2)));
    expect(find.text('CONNECTION LOST'), findsNothing);
  });

  testWidgets('代碼行在夜間顯示夜間警戒態勢', (tester) async {
    EvaCodeLine.now = () => DateTime(2026, 10, 21, 2);
    addTearDown(() => EvaCodeLine.now = DateTime.now);
    await pumpShell(tester, '/matches', style: ThemeStyleId.evaAlert);
    expect(find.text('夜間警戒態勢 / NIGHT WATCH'), findsOneWidget);
  });
}
