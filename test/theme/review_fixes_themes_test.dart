import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/eva_progress.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_overlays.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;

/// 最終審查的 Important 項目。
void main() {
  testWidgets('跨風格家族切換主題時，頁面捲動位置保留', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        useSettingsTheme: true,
        home: AppShell(
          currentRoute: '/settings',
          title: '設定',
          child: ListView(
            key: const ValueKey('page-list'),
            children: [for (var i = 0; i < 100; i++) Text('row $i')],
          ),
        )));
    await tester.pumpAndSettle();
    ScrollPosition pos() => tester
        .state<ScrollableState>(find.descendant(
            of: find.byKey(const ValueKey('page-list')),
            matching: find.byType(Scrollable)))
        .position;
    pos().jumpTo(400);
    await tester.pump();
    for (final style in [
      'neon',
      'evaAlert',
      'airy',
      'evaMonitor',
      'editorial'
    ]) {
      await h.settings.setTheme(style: style);
      await tester.pumpAndSettle();
      expect(pos().pixels, 400, reason: style);
    }
  });

  testWidgets('在輸入框打字算鍵盤活動，不會跳出假人待機畫面', (tester) async {
    setWidth(tester, 1440);
    final h = await Harness.create(tester);
    await h.settings.setTheme(style: 'evaFusion');
    await tester.pumpWidget(h.wrap(
        useSettingsTheme: true,
        home: const AppShell(
            currentRoute: '/matches',
            title: 't',
            child: Center(child: SizedBox(width: 200, child: TextField())))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 10));
      // 在下一個按鍵之前檢查（按鍵本身會關閉待機畫面）。
      expect(find.byType(DummyOverlay), findsNothing,
          reason: '${(i + 1) * 10}s');
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: 'a');
    }
  });

  testWidgets('沒有改變的 updateEva 不通知，也不重建主題', (tester) async {
    final h = await Harness.create(tester);
    var n = 0;
    h.settings.addListener(() => n++);
    await h.settings.updateEva((s) => s);
    expect(n, 0);
    await h.settings.updateEva((s) => recordEgg(s, 'E1'));
    await h.settings.updateEva((s) => recordEgg(s, 'E1'));
    expect(n, 1);
  });

  testWidgets('與主題無關的設定改變時，ThemeData 物件不重建', (tester) async {
    final h = await Harness.create(tester);
    final seen = <ThemeData>[];
    await tester.pumpWidget(h.wrap(
        useSettingsTheme: true,
        home: Builder(builder: (c) {
          seen.add(Theme.of(c));
          return const SizedBox();
        })));
    await h.settings.setHighlightWishlist(false);
    await tester.pump();
    expect(seen.length, greaterThanOrEqualTo(1));
    expect(identical(seen.first, seen.last), isTrue);
  });

  test('clearEva 保留所有非 EVA 欄位（含日後新增的欄位）', () {
    final s = AppSettings.fromJson({
      ...const AppSettings(
        resetHour: 9,
        resetMinute: 30,
        highlightWishlist: false,
        loginShard: 'na',
        themeStyle: 'evaAlert',
        themeAccent: 'green',
        themeBrightness: 'light',
        backgroundMotion: false,
        evaEnabled: false,
        evaTitleCards: false,
        evaEpisodeDays: 9,
        evaFoundEggs: ['E1'],
      ).toJson(),
    });
    final before = s.toJson();
    final after = clearEva(s).toJson();
    for (final k in before.keys) {
      if (k.startsWith('eva') && k != 'evaEnabled' && k != 'evaTitleCards') {
        continue;
      }
      expect(after[k], before[k], reason: k);
    }
    expect(after['evaEpisodeDays'], 0);
    expect(after['evaFoundEggs'], isEmpty);
  });
}
