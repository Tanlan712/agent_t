import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../app_harness.dart';
import 'app_shell_test.dart' show setWidth;

/// 計算路由事件次數。
class _CountingObserver extends NavigatorObserver {
  int pushes = 0;
  int replaces = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushes++;

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      replaces++;
}

void main() {
  testWidgets('初始頁面 / 是我的商店', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(useAppRoutes: true));
    await tester.pumpAndSettle();
    expect(find.text('我的商店'), findsWidgets);
    expect(find.text('登入 Riot 以自動同步'), findsOneWidget);
  });

  testWidgets('點導覽換頁、沒有返回鍵；再點同一項不重複換頁', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    final observer = _CountingObserver();
    await tester.pumpWidget(h.wrap(useAppRoutes: true, observers: [observer]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('願望清單'));
    await tester.pumpAndSettle();
    expect(find.text('願望清單是空的，按 ＋ 加入造型'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(observer.replaces, 1);

    await tester.tap(find.text('願望清單').first);
    await tester.pumpAndSettle();
    expect(observer.replaces, 1);
  });

  testWidgets('手機寬度：更多 → 角色，選單關閉並換頁', (tester) async {
    setWidth(tester, 400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(useAppRoutes: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('更多'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('角色'));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.widgetWithText(AppBar, '角色'), findsOneWidget);
  });

  testWidgets('子頁面（造型搜尋器）有返回鍵', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(useAppRoutes: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('願望清單'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('加入造型'));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsOneWidget);
    expect(find.text('選擇造型'), findsOneWidget);
  });
}
