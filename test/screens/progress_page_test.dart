import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/screens/progress_page.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

import '../account_fixtures.dart';
import '../app_harness.dart';
import '../progress_fixtures.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  final now = DateTime.utc(2026, 10, 21, 21, 15);

  Future<Harness> loggedIn(WidgetTester tester,
      {Map<String, dynamic>? contracts, DateTime? seasonEnd}) async {
    final h = await Harness.create(tester,
        riotHttp: riotClient(contracts: contracts),
        progressApi: FakeProgressApi(testProgressRef(seasonEnd: seasonEnd)));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    return h;
  }

  Future<void> open(WidgetTester tester, Harness h) async {
    await tester.pumpWidget(h.wrap(home: ProgressPage(now: () => now)));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Finder inKey(String key, Finder f) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: f);

  test('導覽「主要」組有通行證與任務', () {
    expect(
        navItems.any((n) =>
            n.route == '/progress' &&
            n.label == '通行證與任務' &&
            n.group == NavGroup.shop),
        isTrue);
  });

  testWidgets('未登入時顯示空狀態與登入按鈕', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester, progressApi: FakeProgressApi());
    await tester.pumpWidget(h.wrap(home: ProgressPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.byType(EmptyState), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '登入 Riot'), findsOneWidget);
  });

  testWidgets('KPI：等級、本級經驗、通行證階級、每週刷新倒數', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester);
    await open(tester, h);
    expect(inKey('kpi-level', find.text('4')), findsOneWidget);
    expect(inKey('kpi-xp', find.text('855')), findsOneWidget);
    expect(inKey('kpi-pass', find.text('2 / 3')), findsOneWidget);
    expect(inKey('kpi-weekly', find.text('5 天 0 小時')), findsOneWidget);
  });

  for (final width in [375.0, 560.0]) {
    testWidgets('${width.toInt()} 寬 KPI 每列 2 張，不會每張佔滿整列', (tester) async {
      setWidth(tester, width);
      final h = await loggedIn(tester);
      await open(tester, h);
      final level = tester.getTopLeft(find.byKey(const ValueKey('kpi-level')));
      final xp = tester.getTopLeft(find.byKey(const ValueKey('kpi-xp')));
      final pass = tester.getTopLeft(find.byKey(const ValueKey('kpi-pass')));
      final weekly =
          tester.getTopLeft(find.byKey(const ValueKey('kpi-weekly')));
      expect(xp.dy, level.dy);
      expect(weekly.dy, pass.dy);
      expect(pass.dy, greaterThan(level.dy));
    });
  }

  testWidgets('通行證：進度條、已達成打勾、下一階外框、獎勵名稱', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester);
    await open(tester, h);
    expect(find.text('第九幕通行證'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('bp-progress')));
    expect(bar.value, closeTo(500 / 4000, 1e-9));
    expect(find.text('下一階 500 / 4000 XP'), findsOneWidget);
    expect(inKey('tier-1', find.byIcon(Icons.check_circle)), findsOneWidget);
    expect(inKey('tier-2', find.byIcon(Icons.check_circle)), findsOneWidget);
    expect(inKey('tier-3', find.byIcon(Icons.check_circle)), findsNothing);
    expect(find.byKey(const ValueKey('tier-next')), findsOneWidget);
    expect(inKey('tier-1', find.text('噴漆一')), findsOneWidget);
    expect(inKey('tier-2', find.text('貨幣 ×10')), findsOneWidget);
  });

  testWidgets('已到最後一階時顯示已完成全部階級', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester,
        contracts: contractsJson(contracts: [
          {
            'ContractDefinitionID': 'bp-now',
            'ProgressionLevelReached': 3,
            'ProgressionTowardsNextLevel': 0,
          },
        ]));
    await open(tester, h);
    expect(find.text('已完成全部階級'), findsOneWidget);
    expect(find.byKey(const ValueKey('tier-next')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('沒有進行中的通行證時顯示空狀態', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester, seasonEnd: DateTime.utc(2026, 2, 1));
    await open(tester, h);
    expect(find.text('目前沒有進行中的通行證'), findsOneWidget);
    expect(inKey('kpi-pass', find.text('—')), findsOneWidget);
  });

  testWidgets('任務依每日／每週分組，有進度、經驗與完成標籤', (tester) async {
    setWidth(tester, 1440);
    final h = await loggedIn(tester);
    await open(tester, h);
    expect(inKey('missions-daily', find.text('擊殺 3 名敵人')), findsOneWidget);
    expect(inKey('missions-daily', find.text('2 / 3')), findsOneWidget);
    expect(inKey('missions-daily', find.text('+2000 XP')), findsOneWidget);
    expect(inKey('missions-weekly', find.text('完成 15 回合')), findsOneWidget);
    expect(inKey('missions-weekly', find.widgetWithText(StatusChip, '完成')),
        findsOneWidget);
  });

  for (final width in [375.0, 768.0, 1024.0, 1440.0]) {
    testWidgets('已登入：${width.toInt()} 寬不 overflow', (tester) async {
      setWidth(tester, width);
      final h = await loggedIn(tester);
      await open(tester, h);
      expect(tester.takeException(), isNull);
    });
  }

  for (final (width, sideBySide) in [(1440.0, true), (768.0, false)]) {
    testWidgets('${width.toInt()} 寬任務卡${sideBySide ? '同列' : '上下排'}',
        (tester) async {
      setWidth(tester, width);
      final h = await loggedIn(tester);
      await open(tester, h);
      final d = tester.getTopLeft(find.byKey(const ValueKey('missions-daily')));
      final w =
          tester.getTopLeft(find.byKey(const ValueKey('missions-weekly')));
      if (sideBySide) {
        expect(w.dy, d.dy);
      } else {
        expect(w.dy, greaterThan(d.dy));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
