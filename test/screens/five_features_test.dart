import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/app_routes.dart';
import 'package:agent_t/models/current_shop.dart';
import 'package:agent_t/models/skin_info.dart';
import 'package:agent_t/models/tier.dart';
import 'package:agent_t/screens/match_history_page.dart';
import 'package:agent_t/screens/my_shop_page.dart';
import 'package:agent_t/screens/settings_page.dart';
import 'package:agent_t/services/file_share.dart';
import 'package:agent_t/widgets/backup_card.dart';
import 'package:agent_t/widgets/reset_countdown_card.dart';

import '../app_harness.dart';
import '../catalog_helpers.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  test('倒數文字', () {
    final now = DateTime(2026, 11, 1, 10);
    expect(
        countdownLabel(
            now.add(const Duration(hours: 3, minutes: 4, seconds: 5)), now),
        '03:04:05');
    expect(countdownLabel(now.add(const Duration(days: 2, hours: 1)), now),
        '2 天 01:00:00');
    expect(
        countdownLabel(now.subtract(const Duration(seconds: 1)), now), isNull);
  });

  test('重置列：沒有同步資料時每日商店依設定推算', () {
    final now = DateTime(2026, 11, 1, 10);
    final rows = resetRows(const CurrentShop(), now, 8, 0);
    expect(rows.first.estimated, isTrue);
    expect(rows.first.target, DateTime(2026, 11, 2, 8));
    expect(rows[1].target, isNull);
    final synced = resetRows(
        CurrentShop(
          daily: const [ShopEntry(skinUuid: 'a', price: 1)],
          dailyExpiresAt: DateTime(2026, 11, 1, 18),
          accessoryEndsAt: DateTime(2026, 11, 3),
        ),
        now,
        8,
        0);
    expect(synced.first.estimated, isFalse);
    expect(synced.first.target, DateTime(2026, 11, 1, 18));
    expect(synced[2].target, DateTime(2026, 11, 3));
  });

  testWidgets('同步後顯示重置倒數、記下商店歷史，並可查詢造型', (tester) async {
    setWidth(tester, 1440);
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
    await tester.pumpWidget(
        h.wrap(home: const MyShopPage(), onGenerateRoute: onGenerateAppRoute));
    await tester.pumpAndSettle();
    await tester.tap(find.text('從 Riot 同步'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('reset-countdown')), findsOneWidget);
    expect(find.text('每日商店刷新'), findsOneWidget);
    final history = h.shopHistory.historyOf(h.riot.session!.puuid);
    expect(history.days.length, 1);
    expect(history.days.single.skins, contains('skin-odin'));

    await tester.ensureVisible(find.byKey(const ValueKey('open-shop-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-shop-history')));
    await tester.pumpAndSettle();
    expect(find.text('商店歷史'), findsWidgets);
    expect(find.text('凌空之志 奧丁'), findsWidgets);

    await tester.enterText(
        find.byKey(const ValueKey('shop-history-search')), '奧丁');
    await tester.pumpAndSettle();
    expect(find.textContaining('每日商店 1 次'), findsOneWidget);
  });

  testWidgets('對戰紀錄頁：今天有打時顯示今日小結與分享按鈕', (tester) async {
    setWidth(tester, 1400);
    tester.view.physicalSize = const Size(1400, 2400);
    final h =
        await Harness.create(tester, riotHttp: riotClient(historyTotal: 3));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    final now = DateTime.fromMillisecondsSinceEpoch(1760900000000)
        .add(const Duration(minutes: 30));
    await tester.pumpWidget(h.wrap(home: MatchHistoryPage(now: () => now)));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-summary')), findsOneWidget);
    expect(find.text('今日小結'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('today-share')));
    await tester.pumpAndSettle();
    expect(find.text('分享今日小結'), findsOneWidget);
    expect(find.textContaining('勝'), findsWidgets);
  });

  testWidgets('今天沒打時不顯示今日小結', (tester) async {
    setWidth(tester, 1400);
    final h =
        await Harness.create(tester, riotHttp: riotClient(historyTotal: 3));
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpWidget(
        h.wrap(home: MatchHistoryPage(now: () => DateTime(2030, 1, 1))));
    await tester.pump();
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('today-summary')), findsNothing);
  });

  testWidgets('備份：複製後從剪貼簿還原，登入資訊不在備份裡', (tester) async {
    String? clip;
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clip = (call.arguments as Map)['text'] as String?;
        return null;
      }
      if (call.method == 'Clipboard.getData') return {'text': clip};
      return null;
    });
    final h = await Harness.create(tester);
    await h.prefs.setString('riotAccounts', '[{"token":"fake-token"}]');
    await h.prefs.setString('encounters_v1', '{"a":{}}');
    await tester.pumpWidget(h.wrap(
        home: const Scaffold(
            body: SingleChildScrollView(
                child: BackupCard(files: NoFileShare())))));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backup-export')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backup-copy')));
    await tester.pumpAndSettle();
    expect(clip, isNotNull);
    expect(clip!.contains('fake-token'), isFalse);
    expect((jsonDecode(clip!) as Map)['data'], contains('encounters_v1'));

    await h.prefs.setString('encounters_v1', '{}');
    await tester.tap(find.byKey(const ValueKey('backup-paste')));
    await tester.pumpAndSettle();
    expect(find.text('還原備份？'), findsOneWidget);
    expect(find.text('・同場紀錄（遇過 N）'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('backup-restore-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('已還原'), findsOneWidget);
    expect(h.prefs.getString('encounters_v1'), '{"a":{}}');
  });

  testWidgets('主題排程：開啟後依時間覆蓋明暗', (tester) async {
    final h = await Harness.create(tester);
    final m = DateTime.now().hour * 60 + DateTime.now().minute;
    // 白天從一小時後才開始 → 現在是晚上 → 深色。
    await h.settings.setTheme(brightness: 'light');
    await h.settings.setThemeSchedule(
        enabled: true, dayStart: (m + 60) % 1440, nightStart: (m + 120) % 1440);
    await tester
        .pumpWidget(h.wrap(home: const SettingsPage(), useSettingsTheme: true));
    await tester.pumpAndSettle();
    final ctx = tester.element(find.byType(SettingsPage));
    expect(Theme.of(ctx).brightness, Brightness.dark);

    await h.settings.setThemeSchedule(enabled: false);
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.byType(SettingsPage))).brightness,
        Brightness.light);
  });
}
