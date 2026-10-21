import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/theme/app_palette.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

import '../app_harness.dart';

/// 規格 §4.1：EVA 系列的頁首、卡片、KPI、區塊標題、狀態標籤。
void main() {
  Future<void> pump(WidgetTester tester, ThemeStyleId style, Widget child,
      {BrightnessMode mode = BrightnessMode.auto,
      bool reduceMotion = false,
      double width = 1200}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style, mode: mode),
        home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, 900), disableAnimations: reduceMotion),
          child: Scaffold(
              body: Padding(padding: const EdgeInsets.all(16), child: child)),
        )));
  }

  const header = PageHeader(title: '對戰紀錄', route: '/matches');

  group('PageHeader', () {
    testWidgets('F1 主色色塊、代碼行、斜向編號列', (tester) async {
      await pump(tester, ThemeStyleId.evaAlert, header);
      final block = find.byKey(const ValueKey('eva-alert-block'));
      expect(block, findsOneWidget);
      final p = AppPalette.current;
      expect(
          (tester.widget<Container>(block).decoration! as BoxDecoration).color,
          p.primary);
      expect(find.byKey(const ValueKey('eva-code-line')), findsOneWidget);
      expect(find.textContaining('CODE:0800'), findsOneWidget);
      expect(find.byKey(const ValueKey('eva-ticker')), findsOneWidget);
      expect(find.text('作戰記錄'), findsOneWidget);
    });

    testWidgets('F2 深色：英文標題＋故事名副標', (tester) async {
      await pump(tester, ThemeStyleId.evaMonitor, header);
      expect(find.text('OPERATION LOG:'), findsOneWidget);
      expect(find.textContaining('作戰記錄'), findsOneWidget);
      expect(find.byKey(const ValueKey('eva-alert-block')), findsNothing);
    });

    testWidgets('F2 淺色：機密印章與報告書標題、德文副標', (tester) async {
      await pump(tester, ThemeStyleId.evaMonitor, header,
          mode: BrightnessMode.light);
      expect(find.byKey(const ValueKey('eva-stamp')), findsOneWidget);
      expect(find.text('對戰紀錄報告書'), findsOneWidget);
      expect(find.text('Einsatzprotokoll'), findsOneWidget);
    });

    testWidgets('F3 色塊頁首＋右側欄位', (tester) async {
      await pump(tester, ThemeStyleId.evaFusion, header);
      expect(find.byKey(const ValueKey('eva-alert-block')), findsOneWidget);
      expect(find.byKey(const ValueKey('eva-header-side')), findsOneWidget);
    });

    testWidgets('375 寬 F1 頁首 20 字不 overflow', (tester) async {
      await pump(tester, ThemeStyleId.evaAlert,
          const PageHeader(title: '一二三四五六七八九十一二三四五六七八九十', route: '/'),
          width: 375);
      expect(tester.takeException(), isNull);
    });
  });

  group('PanelCard', () {
    testWidgets('F1 主色框與左上標籤', (tester) async {
      await pump(
          tester, ThemeStyleId.evaAlert, const PanelCard(child: Text('x')));
      expect(find.byKey(const ValueKey('panel-eva-tab')), findsOneWidget);
    });

    testWidgets('F2／F3 四角十字', (tester) async {
      for (final s in [ThemeStyleId.evaMonitor, ThemeStyleId.evaFusion]) {
        await pump(tester, s, const PanelCard(child: Text('x')));
        expect(find.byKey(const ValueKey('eva-crosshair')), findsNWidgets(4),
            reason: '$s');
      }
    });
  });

  group('KpiTile', () {
    const tile = KpiTile(label: '錢包', value: '5350', code: 'VP BALANCE');

    testWidgets('F1 純數字從 0 數到實際值', (tester) async {
      await pump(tester, ThemeStyleId.evaAlert, tile);
      expect(find.text('0'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('5350'), findsOneWidget);
      expect(find.text('VP BALANCE'), findsOneWidget);
    });

    testWidgets('含逗號與百分比也會計數，格式不變', (tester) async {
      await pump(
          tester,
          ThemeStyleId.evaAlert,
          const Column(children: [
            KpiTile(label: 'a', value: '1,775'),
            KpiTile(label: 'b', value: '54%'),
          ]));
      await tester.pumpAndSettle();
      expect(find.text('1,775'), findsOneWidget);
      expect(find.text('54%'), findsOneWidget);
    });

    testWidgets('非數字不計數', (tester) async {
      await pump(tester, ThemeStyleId.evaAlert,
          const KpiTile(label: '牌位', value: '鑽石 2'));
      expect(find.text('鑽石 2'), findsOneWidget);
    });

    testWidgets('減少動態效果時第一幀就是實際值', (tester) async {
      await pump(tester, ThemeStyleId.evaAlert, tile, reduceMotion: true);
      expect(find.text('5350'), findsOneWidget);
    });

    testWidgets('F2 數字放在括號框', (tester) async {
      await pump(tester, ThemeStyleId.evaMonitor, tile);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('kpi-bracket')), findsOneWidget);
    });

    testWidgets('A 不計數', (tester) async {
      await pump(tester, ThemeStyleId.editorial, tile);
      expect(find.text('5350'), findsOneWidget);
    });
  });

  testWidgets('SectionHeader F2：Monitored Object 括號框', (tester) async {
    await pump(
        tester, ThemeStyleId.evaMonitor, const SectionHeader(title: '每日商店'));
    expect(find.text('Monitored Object:'), findsOneWidget);
    expect(find.byKey(const ValueKey('eva-bracket-title')), findsOneWidget);
  });

  testWidgets('StatusChip EVA：直角實心底', (tester) async {
    final win =
        AppPalette.resolve(const ThemeChoice(style: ThemeStyleId.evaFusion))
            .win;
    await pump(
        tester, ThemeStyleId.evaFusion, StatusChip(label: 'LIVE', color: win));
    final c = tester.widget<Container>(find.descendant(
        of: find.byType(StatusChip), matching: find.byType(Container)));
    final d = c.decoration! as BoxDecoration;
    expect(d.color, win);
    expect((d.borderRadius! as BorderRadius).topLeft.x, 0);
  });
}
