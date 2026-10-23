import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/screens/riot_login_page.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

void main() {
  Future<void> settle(WidgetTester tester) async {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  testWidgets('收到分享的跳轉網址時自動登入', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: RiotLoginPage(takeShared: () async => 'VALORANT\n$fakeRedirect')));
    await settle(tester);
    expect(h.riot.isLoggedIn, isTrue);
    expect(find.text('已登入：Tester#TW1（ap）'), findsOneWidget);
  });

  testWidgets('分享的內容沒有登入資訊時顯示提示、不登入', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        home: RiotLoginPage(
            takeShared: () async => 'https://playvalorant.com/opt_in')));
    await settle(tester);
    expect(h.riot.isLoggedIn, isFalse);
    expect(find.text(RiotLoginPage.sharedBadMessage), findsOneWidget);
  });

  testWidgets('沒有分享內容時不做任何事，重建畫面也不重複檢查', (tester) async {
    final h = await Harness.create(tester);
    var calls = 0;
    Future<String?> take() async {
      calls++;
      return null;
    }

    await tester.pumpWidget(h.wrap(home: RiotLoginPage(takeShared: take)));
    await settle(tester);
    await tester.pumpWidget(h.wrap(home: RiotLoginPage(takeShared: take)));
    await settle(tester);
    expect(calls, 1);
    expect(h.riot.isLoggedIn, isFalse);
    expect(find.text(RiotLoginPage.sharedBadMessage), findsNothing);
  });

  testWidgets('登入頁說明可用 Android 分享登入', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
    expect(find.textContaining('「分享」'), findsOneWidget);
  });
}
