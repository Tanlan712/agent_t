import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/session_storage.dart';

import '../riot_fixtures.dart';

void main() {
  final start = DateTime(2026, 10, 22, 12);
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  RiotProvider riotWith(DateTime Function() now,
          {http.Client? client, Future<void> Function()? onLogout}) =>
      RiotProvider(RiotClient(client: client ?? riotClient()),
          now: now, storage: SessionStorage(prefs), onLogout: onLogout);

  test('App 內登入才允許自動續期，貼網址登入不允許', () async {
    final riot = riotWith(() => start);
    await riot.login(fakeRedirect, autoRenew: true);
    expect(riot.canAutoRenew, isTrue);
    await riot.login(fakeRedirect);
    expect(riot.canAutoRenew, isFalse);
  });

  test('續期成功：換成新的到期時間並保存', () async {
    var now = start;
    final riot = riotWith(() => now);
    await riot.login(fakeRedirect, autoRenew: true);
    now = start.add(const Duration(minutes: 55));
    expect(await riot.renew(fakeRedirect), isNull);
    expect(riot.timeLeft, const Duration(hours: 1));
    expect(riot.session!.displayName, 'Tester#TW1');
    expect(prefs.getString(SessionStorage.key), contains(fakeAccessToken));
  });

  test('續期網址無效或失敗時不登出', () async {
    final riot = riotWith(() => start);
    await riot.login(fakeRedirect, autoRenew: true);
    expect(await riot.renew('https://playvalorant.com/opt_in'),
        RiotProvider.badUrlMessage);
    // 重新開頁讀回同一份登入資訊，但 Riot 拒絕新的 token。
    final failing = riotWith(() => start,
        client: MockClient((_) async => http.Response('', 401)));
    expect(await failing.renew(fakeRedirect), startsWith('續期失敗'));
    expect(failing.isLoggedIn, isTrue);
    expect(failing.canAutoRenew, isTrue);
    expect(prefs.containsKey(SessionStorage.key), isTrue);
  });

  test('過期後提示重新登入，但保留自動續期', () async {
    var now = start;
    final riot = riotWith(() => now);
    await riot.login(fakeRedirect, autoRenew: true);
    expect(riot.needsRelogin, isFalse);
    now = start.add(const Duration(hours: 2));
    expect(riot.needsRelogin, isTrue);
    riot.expire();
    expect(riot.needsRelogin, isTrue);
    expect(riot.canAutoRenew, isTrue);
  });

  test('重新開頁讀到過期的登入資訊：刪除 token 並提示重新登入', () async {
    var now = start;
    await riotWith(() => now).login(fakeRedirect, autoRenew: true);
    now = start.add(const Duration(hours: 2));
    final reopened = riotWith(() => now);
    expect(reopened.isLoggedIn, isFalse);
    expect(reopened.needsRelogin, isTrue);
    expect(reopened.canAutoRenew, isTrue);
    // 帳號留在清單裡方便切換，token 已刪除。
    expect(prefs.getString(SessionStorage.key), isNot(contains(fakeAccessToken)));
  });

  test('從沒登入過不提示重新登入', () {
    expect(riotWith(() => start).needsRelogin, isFalse);
  });

  test('登出：停止自動續期、清除內嵌頁登入記錄、不再提示', () async {
    var cleared = 0;
    final riot = riotWith(() => start, onLogout: () async => cleared++);
    await riot.login(fakeRedirect, autoRenew: true);
    riot.logout();
    expect(riot.canAutoRenew, isFalse);
    expect(riot.needsRelogin, isFalse);
    expect(cleared, 1);
    expect(prefs.containsKey(SessionStorage.key), isFalse);
  });
}
