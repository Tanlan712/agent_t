import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/screens/riot_login_page.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

void main() {
  testWidgets('顯示免責聲明與操作按鈕', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
    expect(find.textContaining('使用 Riot 未公開 API，可能違反服務條款'), findsOneWidget);
    expect(find.text('開啟 Riot 登入頁'), findsOneWidget);
    expect(find.text('複製登入網址'), findsOneWidget);
    expect(find.text('完成登入'), findsOneWidget);
  });

  testWidgets('貼錯網址顯示提示', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
    await tester.enterText(find.byKey(const ValueKey('redirect-field')),
        'https://playvalorant.com/');
    await tester.tap(find.text('完成登入'));
    await tester.pumpAndSettle();
    expect(find.text(RiotProvider.badUrlMessage), findsOneWidget);
    expect(h.riot.isLoggedIn, isFalse);
  });

  testWidgets('貼上正確網址後登入並顯示帳號', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
    await tester.enterText(
        find.byKey(const ValueKey('redirect-field')), fakeRedirect);
    await tester.tap(find.text('完成登入'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(h.riot.isLoggedIn, isTrue);
    expect(find.text('已登入：Tester#TW1（ap）'), findsOneWidget);
    expect(find.text('登出'), findsOneWidget);
  });
}
