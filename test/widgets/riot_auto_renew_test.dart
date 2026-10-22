import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/providers/settings_provider.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/session_storage.dart';
import 'package:valorant_shop_tracker/storage/settings_storage.dart';
import 'package:valorant_shop_tracker/widgets/riot_auto_renew.dart';

import '../riot_fixtures.dart';

/// 假的隱藏登入頁：建立時記錄次數，[redirect] 不是 null 就馬上回傳跳轉網址。
class FakeSilentLogin {
  int opened = 0;
  String? redirect;

  Widget build(void Function(String url) onRedirect) {
    opened++;
    final url = redirect;
    if (url != null) Future.microtask(() => onRedirect(url));
    return const SizedBox(key: ValueKey('silent-login'));
  }
}

void main() {
  var now = DateTime(2026, 10, 22, 12);
  late SharedPreferences prefs;
  late RiotProvider riot;
  late FakeSilentLogin silent;

  setUp(() async {
    now = DateTime(2026, 10, 22, 12);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    riot = RiotProvider(RiotClient(client: riotClient()),
        now: () => now, storage: SessionStorage(prefs));
    silent = FakeSilentLogin();
  });

  Widget app({bool enabled = true}) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: riot),
          ChangeNotifierProvider(
              create: (_) => SettingsProvider(SettingsStorage(prefs))),
        ],
        child: MaterialApp(
          home: RiotAutoRenew(
            enabled: enabled,
            silentLogin: silent.build,
            child: const Text('home'),
          ),
        ),
      );

  testWidgets('還有很久才過期：不開隱藏登入頁', (tester) async {
    await tester.runAsync(() => riot.login(fakeRedirect, autoRenew: true));
    await tester.pumpWidget(app());
    await tester.pump();
    expect(silent.opened, 0);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('快到期時在背景續期', (tester) async {
    silent.redirect = fakeRedirect;
    await tester.runAsync(() => riot.login(fakeRedirect, autoRenew: true));
    await tester.pumpWidget(app());
    now = now.add(const Duration(minutes: 52));
    await tester.pump(const Duration(minutes: 1));
    expect(silent.opened, 1);
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.runAsync(() => Future.delayed(Duration.zero));
    await tester.pump();
    expect(riot.timeLeft, const Duration(hours: 1));
    expect(find.byKey(const ValueKey('silent-login')), findsNothing);
  });

  testWidgets('貼網址登入的不自動續期', (tester) async {
    await tester.runAsync(() => riot.login(fakeRedirect));
    await tester.pumpWidget(app());
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(silent.opened, 0);
  });

  testWidgets('網頁版不自動續期', (tester) async {
    await tester.runAsync(() => riot.login(fakeRedirect, autoRenew: true));
    await tester.pumpWidget(app(enabled: false));
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(silent.opened, 0);
  });

  testWidgets('Riot 要求輸入密碼（沒有跳轉）：逾時放棄，失敗 3 次後停止', (tester) async {
    await tester.runAsync(() => riot.login(fakeRedirect, autoRenew: true));
    await tester.pumpWidget(app());
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(minutes: 1));
    expect(silent.opened, 1);
    await tester.pump(RiotAutoRenew.timeout);
    expect(find.byKey(const ValueKey('silent-login')), findsNothing);
    for (var i = 0; i < 4; i++) {
      await tester.pump(RiotAutoRenew.retryAfter);
      await tester.pump(RiotAutoRenew.timeout);
    }
    expect(silent.opened, RiotAutoRenew.maxFailures);
    expect(riot.needsRelogin, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
}
