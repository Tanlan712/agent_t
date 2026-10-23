import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/models/current_shop.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/providers/shop_provider.dart';
import 'package:agent_t/screens/riot_login_page.dart';
import 'package:agent_t/services/riot_client.dart';
import 'package:agent_t/services/riot_cookies.dart';
import 'package:agent_t/storage/session_storage.dart';
import 'package:agent_t/storage/shop_storage.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';

/// 第二個帳號的跳轉網址（假 token）。
final otherRedirect = 'https://playvalorant.com/opt_in'
    '#access_token=${fakeJwt({'sub': 'puuid-2'})}'
    '&id_token=${fakeJwt({
      'sub': 'puuid-2',
      'acct': {'game_name': 'Other', 'tag_line': 'TW2'},
    })}&expires_in=3600';

/// 假的內嵌頁 cookie：模擬 WebView 目前記著哪個帳號的 ssid。
class FakeCookies implements RiotCookieStore {
  String? current;
  final written = <String>[];

  @override
  Future<String?> read() async => current;

  @override
  Future<void> write(String ssid) async {
    written.add(ssid);
    current = ssid;
  }
}

void main() {
  final start = DateTime(2026, 10, 22, 12);
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  RiotProvider riotWith(DateTime Function() now,
          {Future<void> Function()? onLogout}) =>
      RiotProvider(RiotClient(client: riotClient()),
          now: now, storage: SessionStorage(prefs), onLogout: onLogout);

  test('登入兩個帳號都會保存，後登入的是目前帳號', () async {
    final riot = riotWith(() => start);
    await riot.login(fakeRedirect);
    await riot.login(otherRedirect);
    expect(
        riot.accounts.map((a) => a.displayName), ['Tester#TW1', 'Other#TW2']);
    expect(riot.session!.puuid, 'puuid-2');
    expect(riot.activePuuid, 'puuid-2');
  });

  test('token 還有效：切換不用重新登入，重新開頁也記得目前帳號', () async {
    final riot = riotWith(() => start);
    await riot.login(fakeRedirect);
    await riot.login(otherRedirect);
    await riot.switchAccount('puuid-1');
    expect(riot.isLoggedIn, isTrue);
    expect(riot.session!.displayName, 'Tester#TW1');
    expect(riot.wallet, isNull);

    final reopened = riotWith(() => start.add(const Duration(minutes: 10)));
    expect(reopened.session!.puuid, 'puuid-1');
    expect(reopened.accounts, hasLength(2));
  });

  test('切換到已過期的帳號：提示重新登入，帳號保留', () async {
    var now = start;
    final riot = riotWith(() => now);
    await riot.login(fakeRedirect);
    now = start.add(const Duration(minutes: 50));
    await riot.login(otherRedirect);
    now = start.add(const Duration(minutes: 70));
    await riot.switchAccount('puuid-1');
    expect(riot.isLoggedIn, isFalse);
    expect(riot.needsRelogin, isTrue);
    expect(riot.activePuuid, 'puuid-1');
    expect(riot.accounts, hasLength(2));
  });

  test('重新開頁：過期帳號的 token 刪除，帳號名稱保留', () async {
    var now = start;
    final riot = riotWith(() => now);
    await riot.login(fakeRedirect);
    now = start.add(const Duration(minutes: 50));
    await riot.login(otherRedirect);

    final reopened = riotWith(() => start.add(const Duration(minutes: 70)));
    expect(reopened.session!.puuid, 'puuid-2');
    final raw = prefs.getString(SessionStorage.key)!;
    expect(raw, isNot(contains(fakeAccessToken)));
    expect(raw, contains('Tester'));
  });

  test('登出只刪除目前帳號，並清除內嵌頁登入記錄', () async {
    var cleared = 0;
    final riot = riotWith(() => start, onLogout: () async => cleared++);
    await riot.login(fakeRedirect);
    await riot.login(otherRedirect);
    riot.logout();
    expect(riot.isLoggedIn, isFalse);
    expect(riot.needsRelogin, isFalse);
    expect(riot.accounts.single.puuid, 'puuid-1');
    expect(cleared, 1);
    await riot.switchAccount('puuid-1');
    expect(riot.isLoggedIn, isTrue);
  });

  test('刪除不是目前的帳號：目前登入不受影響', () async {
    final removed = <String>[];
    final riot = riotWith(() => start)..onAccountRemoved = removed.add;
    await riot.login(fakeRedirect);
    await riot.login(otherRedirect);
    await riot.removeAccount('puuid-1');
    expect(riot.session!.puuid, 'puuid-2');
    expect(riot.accounts.single.puuid, 'puuid-2');
    expect(removed, ['puuid-1']);
  });

  test('背景續期拿到別的帳號：拒絕，不偷偷換帳號', () async {
    final riot = riotWith(() => start);
    await riot.login(fakeRedirect, autoRenew: true);
    expect(await riot.renew(otherRedirect), RiotProvider.otherAccountMessage);
    expect(riot.session!.puuid, 'puuid-1');
    expect(riot.accounts, hasLength(1));
  });

  test('舊版單一帳號資料轉成帳號清單', () async {
    final session = {
      'accessToken': 'fake-access',
      'idToken': 'fake-id',
      'entitlementsToken': 'fake-ent',
      'puuid': 'puuid-1',
      'gameName': 'Tester',
      'tagLine': 'TW1',
      'shard': 'ap',
      'clientVersion': 'v',
      'expiresAt':
          start.add(const Duration(minutes: 30)).toUtc().toIso8601String(),
    };
    SharedPreferences.setMockInitialValues({
      SessionStorage.legacyKey: jsonEncode(session),
      SessionStorage.legacyAutoRenewKey: true,
    });
    prefs = await SharedPreferences.getInstance();
    final riot = riotWith(() => start);
    expect(riot.isLoggedIn, isTrue);
    expect(riot.canAutoRenew, isTrue);
    expect(riot.accounts.single.displayName, 'Tester#TW1');
    expect(prefs.containsKey(SessionStorage.legacyKey), isFalse);
    expect(prefs.containsKey(SessionStorage.legacyAutoRenewKey), isFalse);
  });

  test('每個帳號記住自己的商店', () async {
    final shop = ShopProvider(ShopStorage(prefs));
    final riot = riotWith(() => start)..onAccountChanged = shop.switchAccount;
    await riot.login(fakeRedirect);
    const shopA = CurrentShop(daily: [ShopEntry(skinUuid: 'a', price: 1)]);
    await shop.replaceShop(shopA);
    await riot.login(otherRedirect);
    // 新帳號還沒同步：不顯示前一個帳號的商店。
    await Future<void>.delayed(Duration.zero);
    expect(shop.shop.daily, isEmpty);
    await shop.replaceShop(
        const CurrentShop(daily: [ShopEntry(skinUuid: 'b', price: 2)]));
    await riot.switchAccount('puuid-1');
    await Future<void>.delayed(Duration.zero);
    expect(shop.shop.daily.single.skinUuid, 'a');
    await riot.switchAccount('puuid-2');
    await Future<void>.delayed(Duration.zero);
    expect(shop.shop.daily.single.skinUuid, 'b');
  });

  testWidgets('帳號頁列出保存的帳號，點一下切換', (tester) async {
    final h = await Harness.create(tester, storeSession: true);
    await tester.runAsync(() async {
      await h.riot.login(fakeRedirect);
      await h.riot.login(otherRedirect);
    });
    await tester.pumpWidget(
        h.wrap(home: const RiotLoginPage(inAppLoginAvailable: false)));
    expect(find.text('已保存的帳號'), findsOneWidget);
    expect(find.text('已登入：Other#TW2（ap）'), findsOneWidget);
    await tester.tap(find.text('Tester#TW1（ap）'));
    await tester.pumpAndSettle();
    expect(h.riot.session!.puuid, 'puuid-1');
    expect(find.text('已登入：Tester#TW1（ap）'), findsOneWidget);
  });

  testWidgets('已登入時按「新增其他帳號」顯示登入方式', (tester) async {
    final h = await Harness.create(tester, storeSession: true);
    await tester.runAsync(() => h.riot.login(fakeRedirect));
    await tester.pumpWidget(
        h.wrap(home: const RiotLoginPage(inAppLoginAvailable: false)));
    expect(find.text('完成登入'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('add-account')));
    await tester.pumpAndSettle();
    expect(find.textContaining('無痕視窗'), findsOneWidget);
    // 頁面裡有不只一個捲動區（輸入框也是），指定頁面本身的清單。
    await tester.scrollUntilVisible(find.text('完成登入'), 200,
        scrollable: find
            .descendant(
                of: find.byType(ListView), matching: find.byType(Scrollable))
            .first);
    expect(find.text('完成登入'), findsOneWidget);
  });

  testWidgets('App 新增帳號前先清除內嵌頁登入記錄', (tester) async {
    var cleared = 0;
    final h = await Harness.create(tester,
        storeSession: true, onLogout: () async => cleared++);
    final riot = h.riot;
    await tester.runAsync(() => riot.login(fakeRedirect, autoRenew: true));
    await tester.pumpWidget(h.wrap(
      home: RiotLoginPage(
        inAppLoginAvailable: true,
        openInAppLogin: (_) async => otherRedirect,
      ),
    ));
    await tester.tap(find.byKey(const ValueKey('add-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('在 App 內登入 Riot'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(cleared, 1);
    expect(riot.session!.puuid, 'puuid-2');
    expect(riot.accounts, hasLength(2));
  });

  group('保存各帳號的 Riot cookie（方案 A）', () {
    late FakeCookies cookies;
    var cleared = 0;

    RiotProvider riotA(DateTime Function() now) =>
        RiotProvider(RiotClient(client: riotClient()),
            now: now, storage: SessionStorage(prefs), onLogout: () async {
          cleared++;
          cookies.current = null;
        }, cookies: cookies);

    setUp(() {
      cookies = FakeCookies();
      cleared = 0;
    });

    test('App 內登入後保存該帳號的 ssid；貼網址登入不保存', () async {
      final riot = riotA(() => start);
      cookies.current = 'ssid-1';
      await riot.login(fakeRedirect, autoRenew: true);
      cookies.current = 'ssid-2';
      await riot.login(otherRedirect);
      final saved = {for (final a in riot.accounts) a.puuid: a.cookies};
      expect(saved, {'puuid-1': 'ssid-1', 'puuid-2': null});
    });

    test('切換帳號：清除內嵌頁再放回目標帳號的 ssid，之後可背景續期', () async {
      var now = start;
      final riot = riotA(() => now);
      cookies.current = 'ssid-1';
      await riot.login(fakeRedirect, autoRenew: true);
      await riot.prepareNewLogin();
      cookies.current = 'ssid-2';
      await riot.login(otherRedirect, autoRenew: true);
      now = start.add(const Duration(hours: 2));
      cleared = 0;
      await riot.switchAccount('puuid-1');
      expect(cleared, 1);
      expect(cookies.current, 'ssid-1');
      expect(riot.needsRelogin, isTrue);
      expect(riot.canAutoRenew, isTrue);
      // 續期拿到的是 puuid-1：接受，並保存（可能換發的）新 ssid。
      cookies.current = 'ssid-1b';
      expect(await riot.renew(fakeRedirect), isNull);
      expect(riot.isLoggedIn, isTrue);
      expect(riot.accounts.firstWhere((a) => a.puuid == 'puuid-1').cookies,
          'ssid-1b');
    });

    test('沒有保存 ssid 的帳號：切換時只清除，不放回別人的', () async {
      final riot = riotA(() => start);
      await riot.login(fakeRedirect);
      cookies.current = 'ssid-2';
      await riot.login(otherRedirect, autoRenew: true);
      await riot.switchAccount('puuid-1');
      expect(cookies.current, isNull);
      expect(cookies.written, isEmpty);
    });

    test('登出刪除該帳號保存的 ssid', () async {
      final riot = riotA(() => start);
      cookies.current = 'ssid-1';
      await riot.login(fakeRedirect, autoRenew: true);
      await riot.removeAccount('puuid-1');
      final reopened = riotA(() => start);
      expect(reopened.accounts, isEmpty);
      expect(prefs.getString(SessionStorage.key), isNull);
    });

    test('ssid 不出現在 log 或錯誤訊息裡（只在儲存中）', () async {
      final riot = riotA(() => start);
      cookies.current = 'secret-ssid';
      await riot.login(fakeRedirect, autoRenew: true);
      expect(riot.accounts.single.toString(), isNot(contains('secret-ssid')));
    });
  });
}
