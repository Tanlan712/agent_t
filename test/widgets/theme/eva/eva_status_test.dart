import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/app_activity.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_status.dart';

import '../../../app_harness.dart';
import '../../../riot_fixtures.dart';

/// 規格 §4.3：EVA 狀態元件只顯示真實資料。
void main() {
  Future<Harness> pump(WidgetTester tester, Widget child,
      {ThemeStyleId style = ThemeStyleId.evaFusion,
      DateTime Function()? now,
      bool reduceMotion = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, now: now);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style),
        home: MediaQuery(
            data: MediaQueryData(
                size: const Size(1440, 900), disableAnimations: reduceMotion),
            child: Scaffold(body: Center(child: child)))));
    return h;
  }

  group('RefreshCountdown', () {
    testWidgets('7:55、刷新 8:00 → 剩 5 分鐘，顯示緊急狀態', (tester) async {
      await pump(
          tester, RefreshCountdown(now: () => DateTime(2026, 10, 21, 7, 55)),
          style: ThemeStyleId.evaAlert);
      expect(find.text('00:05:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('countdown-urgent')), findsOneWidget);
    });

    testWidgets('跨日：23:00 → 09:00:00，不是緊急', (tester) async {
      await pump(
          tester, RefreshCountdown(now: () => DateTime(2026, 10, 21, 23)),
          style: ThemeStyleId.evaAlert);
      expect(find.text('09:00:00'), findsOneWidget);
      expect(find.byKey(const ValueKey('countdown-urgent')), findsNothing);
    });

    testWidgets('每秒更新', (tester) async {
      var t = DateTime(2026, 10, 21, 7);
      await pump(tester, RefreshCountdown(now: () => t),
          style: ThemeStyleId.evaAlert);
      expect(find.text('01:00:00'), findsOneWidget);
      t = t.add(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:59:59'), findsOneWidget);
    });

    testWidgets('F2／F3 用括號框', (tester) async {
      await pump(
          tester, RefreshCountdown(now: () => DateTime(2026, 10, 21, 7)));
      expect(find.byKey(const ValueKey('countdown-bracket')), findsOneWidget);
    });
  });

  group('來源判定', () {
    test('未登入時商店與錢包是「未連線」而不是失敗', () {
      final s = computeSources(
          loggedIn: false,
          dailyActive: false,
          walletLoaded: false,
          collectionErrors: const {},
          progressError: null);
      expect(s.map((e) => e.label), ['商店', '錢包', '收藏', '通行證']);
      expect(s[0].level, SourceLevel.off);
      expect(s[1].level, SourceLevel.off);
      expect(s.any((e) => e.level == SourceLevel.failed), isFalse);
    });

    test('登入後收藏有錯誤 → 收藏失敗', () {
      final s = computeSources(
          loggedIn: true,
          dailyActive: true,
          walletLoaded: true,
          collectionErrors: const {'skins': '429'},
          progressError: null);
      expect(s[0].level, SourceLevel.ok);
      expect(s[2].level, SourceLevel.failed);
      expect(s[3].level, SourceLevel.ok);
    });

    testWidgets('F1 逐行顯示可／否；F2 顯示 All Sources', (tester) async {
      const failed = [
        SourceState('商店', SourceLevel.ok),
        SourceState('收藏', SourceLevel.failed),
      ];
      await pump(tester,
          const SourceStatus(style: ThemeStyleId.evaAlert, sources: failed),
          style: ThemeStyleId.evaAlert);
      expect(find.text('商店 可'), findsOneWidget);
      expect(find.text('收藏 否'), findsOneWidget);
      await pump(tester,
          const SourceStatus(style: ThemeStyleId.evaMonitor, sources: failed),
          style: ThemeStyleId.evaMonitor);
      expect(find.textContaining('REFUSED: 收藏'), findsOneWidget);
      await pump(
          tester,
          const SourceStatus(
              style: ThemeStyleId.evaMonitor,
              sources: [SourceState('商店', SourceLevel.ok)]),
          style: ThemeStyleId.evaMonitor);
      expect(find.text('All Sources: Normal'), findsOneWidget);
    });

    testWidgets('失敗行會閃爍，但 pumpAndSettle 可以結束', (tester) async {
      await pump(
          tester,
          const SourceStatus(
              style: ThemeStyleId.evaAlert,
              sources: [SourceState('收藏', SourceLevel.failed)]),
          style: ThemeStyleId.evaAlert);
      await tester.pumpAndSettle();
      double opacity() => tester
          .widget<Opacity>(find.ancestor(
              of: find.text('收藏 否'), matching: find.byType(Opacity)))
          .opacity;
      final first = opacity();
      await tester.pump(const Duration(milliseconds: 500));
      expect(opacity(), isNot(first));
    });
  });

  group('PowerIndicator', () {
    testWidgets('未登入 CABLE OFF、登入 EXTERNAL、快過期 INTERNAL', (tester) async {
      var now = DateTime(2026, 10, 21, 12);
      final h = await pump(tester, const PowerIndicator(), now: () => now);
      expect(find.text('CABLE OFF'), findsOneWidget);
      await tester.runAsync(() => h.riot.login(fakeRedirect));
      await tester.pump();
      expect(find.text('外部 EXTERNAL'), findsOneWidget);
      now = now.add(const Duration(minutes: 57));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('內部 INTERNAL 03:00'), findsOneWidget);
    });
  });

  testWidgets('StandardClock 顯示 LIVE 與本地時間', (tester) async {
    await pump(
        tester, StandardClock(now: () => DateTime(2026, 10, 21, 9, 5, 7)));
    expect(find.text('LIVE'), findsOneWidget);
    expect(find.text('09:05:07'), findsOneWidget);
  });

  testWidgets('AlertStripe 只在 moving 時動', (tester) async {
    await pump(
        tester, const SizedBox(width: 300, child: AlertStripe(moving: false)));
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
    await pump(
        tester, const SizedBox(width: 300, child: AlertStripe(moving: true)));
    await tester.pump(const Duration(milliseconds: 16));
    expect(tester.binding.hasScheduledFrame, isTrue);
  });

  testWidgets('AlertStripe 減少動態效果時不動', (tester) async {
    await pump(
        tester, const SizedBox(width: 300, child: AlertStripe(moving: true)),
        reduceMotion: true);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('TransferBar 不顯示百分比', (tester) async {
    await pump(
        tester, const SizedBox(width: 300, child: TransferBar(active: false)));
    expect(find.text('TRANSFER'), findsOneWidget);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('EVA 的到期提醒是 EMERGENCY 樣式', (tester) async {
    var now = DateTime(2026, 10, 21, 12);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester, now: () => now);
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    now = now.add(const Duration(minutes: 57));
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.evaAlert),
        home: const AppShell(
            currentRoute: '/', title: '我的商店', child: Text('x'))));
    await tester.pump();
    expect(find.byKey(const ValueKey('eva-emergency')), findsOneWidget);
    expect(find.text('EMERGENCY'), findsOneWidget);
  });

  testWidgets('首頁頁首有倒數，其他頁沒有', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    for (final (route, count) in [('/', 1), ('/matches', 0)]) {
      await tester.pumpWidget(h.wrap(
          choice: const ThemeChoice(style: ThemeStyleId.evaFusion),
          home: AppShell(
              currentRoute: route, title: 't', child: const Text('x'))));
      await tester.pump();
      expect(find.byType(RefreshCountdown), findsNWidgets(count),
          reason: route);
      expect(find.byType(PowerIndicator), findsOneWidget);
      expect(find.byType(SourceStatus), findsOneWidget);
    }
  });

  testWidgets('F2 淺色（機密文件）首頁仍有倒數與進度條', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(
            style: ThemeStyleId.evaMonitor, mode: BrightnessMode.light),
        home: const AppShell(
            currentRoute: '/', title: '我的商店', child: Text('x'))));
    await tester.pump();
    expect(find.byKey(const ValueKey('eva-stamp')), findsOneWidget);
    expect(find.byType(RefreshCountdown), findsOneWidget);
    expect(find.byType(TransferBar), findsOneWidget);
  });
}
