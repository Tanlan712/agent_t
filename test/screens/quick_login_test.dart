import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/screens/riot_login_page.dart';
import 'package:valorant_shop_tracker/screens/wishlist_page.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/session_storage.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

Future<SharedPreferences> freshPrefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

RiotProvider riotWith(SharedPreferences prefs, DateTime Function() now) =>
    RiotProvider(RiotClient(client: riotClient()),
        now: now, storage: SessionStorage(prefs));

void main() {
  group('記住區域', () {
    test('AppSettings 保存登入區域，預設 ap', () {
      expect(const AppSettings().loginShard, 'ap');
      final s = AppSettings.fromJson({'loginShard': 'kr'});
      expect(s.loginShard, 'kr');
      expect(s.toJson()['loginShard'], 'kr');
    });

    testWidgets('切換區域會記住，下次打開登入頁自動選好', (tester) async {
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
      await tester.tap(find.text('亞太（ap）'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('韓國（kr）').last);
      await tester.pumpAndSettle();
      expect(h.settings.settings.loginShard, 'kr');

      await tester.pumpWidget(h.wrap(home: const SizedBox()));
      await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
      expect(find.text('韓國（kr）'), findsOneWidget);
    });
  });

  group('保持登入', () {
    final start = DateTime(2026, 10, 21, 12);

    testWidgets('登入頁沒有「從剪貼簿貼上並登入」，並提示會保存登入資訊', (tester) async {
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
      expect(find.text('從剪貼簿貼上並登入'), findsNothing);
      expect(find.textContaining('保存在這個瀏覽器'), findsOneWidget);
    });

    test('登入成功後保存，重新開啟時自動還原登入', () async {
      final prefs = await freshPrefs();
      final riot = riotWith(prefs, () => start);
      expect(await riot.login(fakeRedirect), isNull);
      expect(prefs.getString(SessionStorage.key), contains(fakeAccessToken));

      final reopened =
          riotWith(prefs, () => start.add(const Duration(minutes: 30)));
      expect(reopened.isLoggedIn, isTrue);
      expect(reopened.session!.displayName, 'Tester#TW1');
      expect(reopened.session!.accessToken, fakeAccessToken);
      expect(reopened.session!.shard, riot.session!.shard);
      expect(reopened.session!.expiresAt, riot.session!.expiresAt);
    });

    test('重新開啟時已過期：不登入並刪除保存的資料', () async {
      final prefs = await freshPrefs();
      await riotWith(prefs, () => start).login(fakeRedirect);

      final reopened = riotWith(prefs, () => start.add(const Duration(hours: 2)));
      expect(reopened.isLoggedIn, isFalse);
      expect(prefs.containsKey(SessionStorage.key), isFalse);
    });

    test('登出時刪除保存的資料', () async {
      final prefs = await freshPrefs();
      final riot = riotWith(prefs, () => start);
      await riot.login(fakeRedirect);
      riot.logout();
      expect(prefs.containsKey(SessionStorage.key), isFalse);
    });

    test('保存的資料損毀時不登入並刪除', () async {
      final prefs = await freshPrefs({SessionStorage.key: '{bad'});
      final riot = riotWith(prefs, () => start);
      expect(riot.isLoggedIn, isFalse);
      expect(prefs.containsKey(SessionStorage.key), isFalse);
    });

    test('網址無效時不保存', () async {
      final prefs = await freshPrefs();
      final riot = riotWith(prefs, () => start);
      expect(await riot.login('https://example.com'), isNotNull);
      expect(prefs.containsKey(SessionStorage.key), isFalse);
    });
  });

  group('到期前提醒', () {
    test('剩 5 分鐘以內 expiresSoon 為 true', () async {
      var now = DateTime(2026, 10, 21, 12);
      final riot =
          RiotProvider(RiotClient(client: riotClient()), now: () => now);
      await riot.login(fakeRedirect);
      expect(riot.expiresSoon, isFalse);
      now = now.add(const Duration(minutes: 56));
      expect(riot.expiresSoon, isTrue);
      expect(riot.timeLeft, const Duration(minutes: 4));
      now = now.add(const Duration(minutes: 5));
      expect(riot.expiresSoon, isFalse);
      expect(riot.isLoggedIn, isFalse);
    });

    testWidgets('快到期時頁面上方顯示提醒與重新登入按鈕', (tester) async {
      var now = DateTime(2026, 10, 21, 12);
      final h = await Harness.create(tester, now: () => now);
      await tester.runAsync(() => h.riot.login(fakeRedirect));
      await tester.pumpWidget(h.wrap(home: const WishlistPage()));
      await tester.pump();
      expect(find.byKey(const ValueKey('expiry-banner')), findsNothing);
      now = now.add(const Duration(minutes: 57));
      // 提醒列每 30 秒重新檢查一次。
      await tester.pump(const Duration(seconds: 31));
      expect(find.byKey(const ValueKey('expiry-banner')), findsOneWidget);
      expect(find.textContaining('分鐘後過期'), findsOneWidget);
      expect(find.text('重新登入'), findsOneWidget);
      await tester.pumpWidget(h.wrap(home: const SizedBox()));
    });
  });
}
