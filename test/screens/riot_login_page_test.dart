import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/screens/riot_login_page.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

void main() {
  group('區域選單', regionTests);
  group('App 內登入', inAppLoginTests);
  testWidgets('顯示免責聲明與操作按鈕', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(
        h.wrap(home: const RiotLoginPage(inAppLoginAvailable: false)));
    expect(find.textContaining('使用 Riot 未公開 API，可能違反服務條款'), findsOneWidget);
    expect(find.text('開啟 Riot 登入頁'), findsOneWidget);
    expect(find.text('複製登入網址'), findsOneWidget);
    expect(find.text('完成登入'), findsOneWidget);
  });

  testWidgets('貼錯網址顯示提示', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(
        h.wrap(home: const RiotLoginPage(inAppLoginAvailable: false)));
    await tester.enterText(find.byKey(const ValueKey('redirect-field')),
        'https://playvalorant.com/');
    await tester.tap(find.text('完成登入'));
    await tester.pumpAndSettle();
    expect(find.text(RiotProvider.badUrlMessage), findsOneWidget);
    expect(h.riot.isLoggedIn, isFalse);
  });

  testWidgets('貼上正確網址後登入並顯示帳號', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(
        h.wrap(home: const RiotLoginPage(inAppLoginAvailable: false)));
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

void regionTests() {
  testWidgets('區域選單預設亞太，可切換', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(
        h.wrap(home: const RiotLoginPage(inAppLoginAvailable: false)));
    expect(find.text('亞太（ap）'), findsOneWidget);
    await tester.tap(find.text('亞太（ap）'));
    await tester.pumpAndSettle();
    expect(find.text('韓國（kr）').last, findsOneWidget);
  });
}

void inAppLoginTests() {
  testWidgets('網頁版不顯示 App 內登入', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(
        h.wrap(home: const RiotLoginPage(inAppLoginAvailable: false)));
    expect(find.text('在 App 內登入 Riot'), findsNothing);
    expect(find.text('開啟 Riot 登入頁'), findsOneWidget);
  });

  testWidgets('Android App 取得跳轉網址後自動登入', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: RiotLoginPage(
      inAppLoginAvailable: true,
      openInAppLogin: (_) async => fakeRedirect,
    )));
    await tester.tap(find.text('在 App 內登入 Riot'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(h.riot.isLoggedIn, isTrue);
    expect(find.text('已登入：Tester#TW1（ap）'), findsOneWidget);
  });

  testWidgets('關掉內嵌登入頁時不登入、不顯示錯誤', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: RiotLoginPage(
      inAppLoginAvailable: true,
      openInAppLogin: (_) async => null,
    )));
    await tester.tap(find.text('在 App 內登入 Riot'));
    await tester.pumpAndSettle();
    expect(h.riot.isLoggedIn, isFalse);
    expect(find.text(RiotProvider.badUrlMessage), findsNothing);
  });

  testWidgets('Riot 回傳錯誤時顯示提示', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: RiotLoginPage(
      inAppLoginAvailable: true,
      openInAppLogin: (_) async =>
          'https://playvalorant.com/opt_in#error=access_denied',
    )));
    await tester.tap(find.text('在 App 內登入 Riot'));
    await tester.pumpAndSettle();
    expect(h.riot.isLoggedIn, isFalse);
    expect(find.text(RiotProvider.badUrlMessage), findsOneWidget);
  });
}
