import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';
import 'package:valorant_shop_tracker/theme/app_palette.dart';
import 'package:valorant_shop_tracker/theme/eva_names.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_header.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_overlays.dart';
import 'package:valorant_shop_tracker/widgets/theme/theme_picker.dart';

import '../../../app_harness.dart';

/// 規格 §4.5：故事層、終劇、暴走主色（E9）。
void main() {
  Future<Harness> pump(WidgetTester tester,
      {String route = '/matches',
      bool routes = false,
      ThemeStyleId style = ThemeStyleId.evaFusion,
      Widget? home}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style),
        useAppRoutes: routes,
        home: routes
            ? null
            : home ??
                AppShell(
                    currentRoute: route, title: '頁面', child: const Text('x'))));
    await tester.pumpAndSettle();
    return h;
  }

  test('每一頁都有對應內容的專屬標題，彼此不同', () {
    final routes = [for (final n in navItems) n.route];
    for (final r in routes) {
      expect(evaPageTitles[r], isNotNull, reason: r);
    }
    expect(
        {for (final r in routes) evaPageTitles[r]}, hasLength(routes.length));
    // 即時對局是迎擊，不是夜市。
    expect(evaPageTitles['/live']!.$1, '迎擊');
    expect(evaPageTitles['/matches']!.$1, '交戰');
  });

  testWidgets('標題卡的話數跟左側導覽的編號一致，標題對應頁面', (tester) async {
    final h = await pump(tester, routes: true);
    await h.settings.updateEva((s) => s.copyWith(evaEpisodeDays: 12));
    await tester.tap(find.byKey(const ValueKey('nav-/live')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(TitleCardOverlay), findsOneWidget);
    // 即時對局在導覽第 3 項（願望清單暫時關閉）。
    expect(find.text('第 参 話'), findsOneWidget);
    expect(find.text('迎擊'), findsOneWidget);
    expect(find.text('EPISODE:03 / INTERCEPT'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('自訂選單順序後，話數跟著左側的新編號', (tester) async {
    final h = await pump(tester, routes: true);
    await h.settings.setNavOrder(const ['/live', '/']);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav-/live')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('第 壱 話'), findsOneWidget);
    expect(find.text('EPISODE:01 / INTERCEPT'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('第 26 話之後是終劇', (tester) async {
    final h = await pump(tester, routes: true);
    await h.settings.updateEva((s) => s.copyWith(evaEpisodeDays: 26));
    await tester.tap(find.byKey(const ValueKey('nav-/maps')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('終劇'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  test('補完率', () {
    expect(
        completionRatio({'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'},
            (u) => {'a', 'b', 'c'}.contains(u)),
        0.375);
    expect(completionRatio(const {}, (_) => true), isNull);
  });

  testWidgets('願望清單頁首有補完計畫進捗；未登入是 — %', (tester) async {
    await pump(tester, route: '/wishlist');
    expect(find.byKey(const ValueKey('eva-completion')), findsOneWidget);
    expect(find.textContaining('— %'), findsOneWidget);
    await pump(tester, route: '/matches');
    expect(find.byKey(const ValueKey('eva-completion')), findsNothing);
  });

  testWidgets('EVA 的 Riot 狀態：適格者 未登錄', (tester) async {
    await pump(tester);
    expect(find.text('適格者 未登錄'), findsOneWidget);
    await pump(tester, style: ThemeStyleId.editorial);
    expect(find.text('適格者 未登錄'), findsNothing);
  });

  testWidgets('全部彩蛋發現時顯示一次補完完了', (tester) async {
    final h = await pump(tester);
    await h.settings.updateEva(
        (s) => s.copyWith(evaFoundEggs: [for (var i = 1; i <= 20; i++) 'E$i']));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FinaleOverlay), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('FINALE'));
    await tester.pump(const Duration(seconds: 5));
    expect(find.byType(FinaleOverlay), findsNothing);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.evaFusion),
        home: const AppShell(
            currentRoute: '/maps', title: 't', child: Text('y'))));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FinaleOverlay), findsNothing);
  });

  group('暴走主色（E9）', () {
    test('只在 EVA 風格有效，其他風格退回紅', () {
      final c = ThemeChoice.fromSettings(
          const AppSettings(themeStyle: 'editorial', themeAccent: 'berserk'));
      expect(c.accent, AccentId.red);
      final e = ThemeChoice.fromSettings(
          const AppSettings(themeStyle: 'evaAlert', themeAccent: 'berserk'));
      expect(e.accent, AccentId.berserk);
      final p = AppPalette.resolve(e);
      expect(p.primary, const Color(0xFF9D6BFF));
      expect(p.decor, contains(const Color(0xFF7CFF4F)));
    });

    testWidgets('設定頁 1.5 秒內連點 F 縮圖 7 下解鎖', (tester) async {
      final h = await pump(tester,
          home: const Scaffold(
              body: SingleChildScrollView(child: ThemePicker())));
      expect(find.byKey(const ValueKey('theme-accent-berserk')), findsNothing);
      for (var i = 0; i < 7; i++) {
        await tester.tap(find.byKey(const ValueKey('theme-style-evaAlert')));
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.pumpAndSettle();
      expect(h.settings.settings.evaBerserkUnlocked, isTrue);
      expect(h.settings.settings.evaFoundEggs, contains('E9'));
      expect(
          find.byKey(const ValueKey('theme-accent-berserk')), findsOneWidget);
      expect(find.text('暴走'), findsOneWidget);
    });

    testWidgets('非 EVA 風格不顯示暴走色塊（即使已解鎖）', (tester) async {
      final h = await pump(tester,
          style: ThemeStyleId.editorial,
          home: const Scaffold(
              body: SingleChildScrollView(child: ThemePicker())));
      await h.settings.updateEva((s) => s.copyWith(evaBerserkUnlocked: true));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('theme-accent-berserk')), findsNothing);
    });
  });
}
