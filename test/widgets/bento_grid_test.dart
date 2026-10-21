import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

Widget host(double width, Widget child) => MaterialApp(
      theme: buildAppTheme(useGoogleFonts: false),
      home: Scaffold(
          body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(width: width, child: child))),
    );

void wide(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1600, 900);
  addTearDown(tester.view.reset);
}

void main() {
  test('bentoColumns', () {
    expect(bentoColumns(1440), 12);
    expect(bentoColumns(1024), 12);
    expect(bentoColumns(1023), 6);
    expect(bentoColumns(600), 6);
    expect(bentoColumns(599), 1);
  });

  test('bentoSpan', () {
    expect(bentoSpan(8, 12), 8);
    expect(bentoSpan(8, 6), 4);
    expect(bentoSpan(4, 6), 2);
    expect(bentoSpan(3, 6), 2);
    expect(bentoSpan(13, 12), 12);
    expect(bentoSpan(5, 1), 1);
    expect(bentoSpan(0, 12), 1);
  });

  Widget grid() => const BentoGrid(children: [
        BentoTile(span: 8, child: SizedBox(key: ValueKey('a'), height: 40)),
        BentoTile(span: 4, child: SizedBox(key: ValueKey('b'), height: 40)),
      ]);

  Offset at(WidgetTester t, String k) => t.getTopLeft(find.byKey(ValueKey(k)));
  double w(WidgetTester t, String k) =>
      t.getSize(find.byKey(ValueKey(k))).width;

  for (final width in [1200.0, 800.0]) {
    testWidgets('${width.toInt()} 寬 span 8＋4 同一列、寬度 2:1', (tester) async {
      wide(tester);
      await tester.pumpWidget(host(width, grid()));
      expect(at(tester, 'a').dy, at(tester, 'b').dy);
      expect(w(tester, 'a') + 16, closeTo(2 * (w(tester, 'b') + 16), 1));
      expect(w(tester, 'a') + w(tester, 'b') + 16, closeTo(width, 1));
    });
  }

  test('bentoSpan 6 欄時使用 medium', () {
    expect(bentoSpan(2, 6, medium: 2), 2);
    expect(bentoSpan(4, 6, medium: 6), 6);
    expect(bentoSpan(4, 12, medium: 6), 4);
  });

  testWidgets('400 寬每個 tile 一列、寬度等於容器寬', (tester) async {
    wide(tester);
    await tester.pumpWidget(host(400, grid()));
    expect(at(tester, 'b').dy, greaterThan(at(tester, 'a').dy));
    expect(w(tester, 'a'), 400);
    expect(w(tester, 'b'), 400);
  });

  testWidgets('放不下就換列', (tester) async {
    wide(tester);
    await tester.pumpWidget(host(
        1200,
        const BentoGrid(children: [
          BentoTile(span: 8, child: SizedBox(key: ValueKey('a'), height: 40)),
          BentoTile(span: 8, child: SizedBox(key: ValueKey('b'), height: 40)),
        ])));
    expect(at(tester, 'b').dy, greaterThan(at(tester, 'a').dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('PageHeader 標題 28px，actions 在右側', (tester) async {
    wide(tester);
    await tester.pumpWidget(host(
        1000,
        const PageHeader(
            title: '我的商店',
            subtitle: '刷新倒數 3 小時',
            actions: [Icon(Icons.edit, key: ValueKey('act'))])));
    expect(tester.widget<Text>(find.text('我的商店')).style?.fontSize, 28);
    expect(find.text('刷新倒數 3 小時'), findsOneWidget);
    expect(at(tester, 'act').dx, greaterThan(950));
  });
}
