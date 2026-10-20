import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/screens/riot_login_page.dart';
import 'package:valorant_shop_tracker/screens/wishlist_page.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

/// 模擬系統剪貼簿（Flutter Web 一樣走 Clipboard 平台通道）。
void mockClipboard(WidgetTester tester, String? text) {
  tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') {
      return text == null ? null : {'text': text};
    }
    return null;
  });
}

Future<void> settle(WidgetTester tester) async {
  await tester
      .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

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

  group('從剪貼簿貼上並登入', () {
    testWidgets('剪貼簿有登入網址時一鍵完成登入，且不保存 token', (tester) async {
      final h = await Harness.create(tester);
      mockClipboard(tester, fakeRedirect);
      await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
      await tester.tap(find.text('從剪貼簿貼上並登入'));
      await settle(tester);
      expect(h.riot.isLoggedIn, isTrue);
      expect(find.text('已登入：Tester#TW1（ap）'), findsOneWidget);
      // AGENTS.md 第 4 節：token 不得寫入 localStorage。
      final prefs = await SharedPreferences.getInstance();
      for (final k in prefs.getKeys()) {
        expect('${prefs.get(k)}', isNot(contains(fakeAccessToken)), reason: k);
      }
    });

    testWidgets('剪貼簿沒有登入網址時提示，不登入', (tester) async {
      final h = await Harness.create(tester);
      mockClipboard(tester, 'hello');
      await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
      await tester.tap(find.text('從剪貼簿貼上並登入'));
      await settle(tester);
      expect(h.riot.isLoggedIn, isFalse);
      expect(find.text(RiotLoginPage.clipboardMissingMessage), findsOneWidget);
    });

    testWidgets('提示在 Riot 登入頁勾選保持登入', (tester) async {
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
      expect(find.textContaining('保持登入'), findsOneWidget);
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
