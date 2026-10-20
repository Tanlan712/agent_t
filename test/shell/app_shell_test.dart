import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

void setWidth(WidgetTester tester, double width) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
}

Widget shell() => const AppShell(
      currentRoute: '/wishlist',
      title: '願望清單',
      child: Text('內容'),
    );

void main() {
  testWidgets('400 寬：漢堡選單、沒有 NavigationRail', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('內容'), findsOneWidget);
  });

  testWidgets('900 寬：窄導覽列', (tester) async {
    setWidth(tester, 900);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isFalse);
    expect(find.byIcon(Icons.menu), findsNothing);
  });

  testWidgets('1400 寬：展開導覽列，看得到完整名稱', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.extended, isTrue);
    expect(find.text('玩家卡片'), findsOneWidget);
    expect(find.text('VALORANT 商店追蹤'), findsOneWidget);
    expect(find.text('願望清單'), findsWidgets);
  });

  testWidgets('從 1400 縮到 400 不丟例外', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    tester.view.physicalSize = const Size(400, 900);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('導覽底部顯示 Riot 登入狀態', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: shell()));
    expect(find.text('登入 Riot'), findsOneWidget);
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpAndSettle();
    expect(find.text('Tester#TW1'), findsOneWidget);
  });
}
