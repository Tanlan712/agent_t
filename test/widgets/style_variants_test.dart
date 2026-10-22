import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/responsive_grid.dart';
import 'package:valorant_shop_tracker/theme/app_style.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

Widget host(ThemeStyleId style, Widget child, {double width = 1200}) =>
    MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: buildAppTheme(
          choice: ThemeChoice(style: style), useGoogleFonts: false),
      home: Scaffold(
          body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child))),
    );

const _aToE = [
  ThemeStyleId.editorial,
  ThemeStyleId.neon,
  ThemeStyleId.airy,
  ThemeStyleId.terminal,
  ThemeStyleId.dreamy,
];

void wide(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 900);
  addTearDown(tester.view.reset);
}

/// 規格 §4.1：共用元件依風格改變形狀與排列（A～E）。
void main() {
  BoxDecoration panel(WidgetTester tester) => tester
      .widget<AnimatedContainer>(find.descendant(
          of: find.byType(PanelCard), matching: find.byType(AnimatedContainer)))
      .decoration! as BoxDecoration;

  group('PanelCard', () {
    for (final s in _aToE) {
      testWidgets('$s 圓角依風格', (tester) async {
        await tester.pumpWidget(host(s, const PanelCard(child: Text('x'))));
        expect(panel(tester).borderRadius,
            BorderRadius.circular(AppStyle.of(s).cardRadius));
      });
    }

    testWidgets('flat（A、C）沒有邊框、用 surfaceHigh 底', (tester) async {
      for (final s in [ThemeStyleId.editorial, ThemeStyleId.airy]) {
        await tester.pumpWidget(host(s, const PanelCard(child: Text('x'))));
        expect(panel(tester).border, isNull);
        expect(panel(tester).color, AppColors.surfaceHigh);
      }
    });

    testWidgets('glowTop（B）頂端 2px 主色線', (tester) async {
      await tester.pumpWidget(
          host(ThemeStyleId.neon, const PanelCard(child: Text('x'))));
      final line = find.byKey(const ValueKey('panel-top-accent'));
      expect(line, findsOneWidget);
      expect(tester.getSize(line).height, 2);
      expect(tester.widget<Container>(line).color, AppColors.primary);
    });

    testWidgets('cornerMarks（D）四角標記', (tester) async {
      await tester.pumpWidget(
          host(ThemeStyleId.terminal, const PanelCard(child: Text('x'))));
      expect(find.byKey(const ValueKey('panel-corner')), findsNWidgets(4));
    });

    testWidgets('其他風格沒有頂端線與四角標記', (tester) async {
      await tester.pumpWidget(
          host(ThemeStyleId.editorial, const PanelCard(child: Text('x'))));
      expect(find.byKey(const ValueKey('panel-top-accent')), findsNothing);
      expect(find.byKey(const ValueKey('panel-corner')), findsNothing);
    });
  });

  group('KpiStrip', () {
    const tiles = [
      KpiTile(label: '勝率', value: '54%'),
      KpiTile(label: 'ACS', value: '231'),
    ];

    testWidgets('terminalLines（D）每個 KPI 一行', (tester) async {
      await tester.pumpWidget(
          host(ThemeStyleId.terminal, const KpiStrip(tiles: tiles)));
      expect(find.byKey(const ValueKey('kpi-line')), findsNWidgets(2));
      expect(find.textContaining('> 勝率'), findsOneWidget);
      expect(find.text('54%'), findsOneWidget);
    });

    testWidgets('tiles（A）維持卡片', (tester) async {
      await tester.pumpWidget(
          host(ThemeStyleId.editorial, const KpiStrip(tiles: tiles)));
      expect(find.byKey(const ValueKey('kpi-line')), findsNothing);
      expect(find.byType(PanelCard), findsNWidgets(2));
    });
  });

  group('BentoGrid', () {
    Widget grid() => const BentoGrid(children: [
          BentoTile(span: 4, child: SizedBox(key: ValueKey('a'), height: 40)),
          BentoTile(span: 8, child: SizedBox(key: ValueKey('b'), height: 40)),
        ]);

    testWidgets('間距取 AppStyle.bentoGap', (tester) async {
      wide(tester);
      // dreamy 會把 span 8 換到下一列，另由下一個測試檢查。
      for (final s in _aToE.where((s) => s != ThemeStyleId.dreamy)) {
        await tester.pumpWidget(host(s, grid()));
        final gap = tester.getTopLeft(find.byKey(const ValueKey('b'))).dx -
            tester.getTopRight(find.byKey(const ValueKey('a'))).dx;
        expect(gap, closeTo(AppStyle.of(s).bentoGap, 1), reason: '$s');
      }
    });

    testWidgets('dreamy（E）跨欄對齊到 6 或 12', (tester) async {
      wide(tester);
      await tester.pumpWidget(host(ThemeStyleId.dreamy, grid()));
      final a = tester.getSize(find.byKey(const ValueKey('a'))).width;
      // span 4 → 6、span 8 → 12：a 佔半寬，b 換到下一列佔全寬。
      expect(a, closeTo((1200 - 20) / 2, 1));
      expect(tester.getSize(find.byKey(const ValueKey('b'))).width,
          closeTo(1200, 1));
    });
  });

  testWidgets('ResponsiveGrid 依風格調整最小寬度與間距', (tester) async {
    wide(tester);
    await tester.pumpWidget(host(
        ThemeStyleId.terminal,
        const ResponsiveGrid(
            minTileWidth: 200,
            childAspectRatio: 1,
            children: [SizedBox(), SizedBox()]),
        width: 1000));
    final delegate = tester.widget<GridView>(find.byType(GridView)).gridDelegate
        as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, columnsFor(1000, 170, spacing: 8));
    expect(delegate.crossAxisSpacing, 8);
  });

  group('PageHeader', () {
    Widget header() => const PageHeader(title: '對戰紀錄', route: '/matches');

    testWidgets('poster（A）40px w800＋斜切色帶', (tester) async {
      await tester.pumpWidget(host(ThemeStyleId.editorial, header()));
      expect(find.byKey(const ValueKey('header-slash')), findsOneWidget);
      final t = tester.widget<Text>(find.text('對戰紀錄'));
      expect(t.style!.fontSize, 40);
      expect(t.style!.fontWeight, FontWeight.w800);
    });

    testWidgets('numbered（B）兩位數導覽序號', (tester) async {
      await tester.pumpWidget(host(ThemeStyleId.neon, header()));
      final n = find.byKey(const ValueKey('header-number'));
      expect(tester.widget<Text>(n).data, '02');
    });

    testWidgets('centered（C）英文小標與浮水印', (tester) async {
      await tester.pumpWidget(host(ThemeStyleId.airy, header()));
      expect(find.byKey(const ValueKey('header-watermark')), findsOneWidget);
      expect(find.text('RECORD'), findsWidgets);
    });

    testWidgets('terminal（D）方括號小標與游標', (tester) async {
      await tester.pumpWidget(host(ThemeStyleId.terminal, header()));
      expect(find.text('[ record ]'), findsOneWidget);
      expect(find.byKey(const ValueKey('header-cursor')), findsOneWidget);
    });

    testWidgets('dreamy（E）大號頁碼', (tester) async {
      await tester.pumpWidget(host(ThemeStyleId.dreamy, header()));
      final n = find.byKey(const ValueKey('header-page-number'));
      expect(tester.widget<Text>(n).data, '02');
    });

    testWidgets('沒有 route 時仍可顯示（不在導覽中的頁面）', (tester) async {
      for (final s in _aToE) {
        await tester.pumpWidget(host(s, const PageHeader(title: '登入')));
        expect(find.text('登入'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  });

  testWidgets('StatusChip 圓角依風格', (tester) async {
    Future<double> radius(ThemeStyleId s) async {
      await tester
          .pumpWidget(host(s, StatusChip(label: '勝', color: AppColors.win)));
      final c = tester.widget<Container>(find.descendant(
          of: find.byType(StatusChip), matching: find.byType(Container)));
      return ((c.decoration! as BoxDecoration).borderRadius! as BorderRadius)
          .topLeft
          .x;
    }

    expect(await radius(ThemeStyleId.editorial), 0);
    expect(await radius(ThemeStyleId.dreamy), 999);
    expect(await radius(ThemeStyleId.neon), 2);
  });
}
