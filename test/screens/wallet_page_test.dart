import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/app_routes.dart';
import 'package:valorant_shop_tracker/models/riot_session.dart';
import 'package:valorant_shop_tracker/screens/wallet_page.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';

import '../app_harness.dart';
import '../riot_fixtures.dart';
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  Future<void> open(WidgetTester tester, Harness h) async {
    await tester.pumpWidget(
        h.wrap(home: const WalletPage(), onGenerateRoute: onGenerateAppRoute));
    await tester.pumpAndSettle();
  }

  test('側邊導覽有「錢包紀錄」', () {
    expect(
        navItems.any((n) => n.route == '/wallet' && n.label == '錢包紀錄'), isTrue);
  });

  testWidgets('未登入時提示登入', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await open(tester, h);
    expect(find.text('登入 Riot 以記錄錢包'), findsOneWidget);
  });

  testWidgets('同步商店時記下錢包餘額', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    await tester.runAsync(() async {
      await h.riot.login(fakeRedirect);
      await h.riot.sync(shop: h.shop, catalog: h.catalog);
    });
    final s = h.walletLog.snapshots('puuid-1');
    expect(s, hasLength(1));
    expect(s.single.vp, 1500);
    await open(tester, h);
    expect(find.text('目前還沒有變化'), findsOneWidget);
    expect(find.textContaining('開始記錄'), findsOneWidget);
  });

  testWidgets('列出儲值與花費，並標出新買的造型', (tester) async {
    for (final width in [390.0, 1440.0]) {
      setWidth(tester, width);
      final h = await Harness.create(tester);
      await tester.runAsync(() async {
        await h.riot.login(fakeRedirect);
        const kept = {'lvl-x'};
        await h.walletLog.record('puuid-1',
            const RiotWallet(vp: 100, radianite: 0, kingdom: 0), kept);
        await h.walletLog.record('puuid-1',
            const RiotWallet(vp: 2100, radianite: 0, kingdom: 0), kept);
        await h.walletLog.record(
            'puuid-1',
            const RiotWallet(vp: 825, radianite: 0, kingdom: 0),
            {...kept, 'o'});
      });
      await open(tester, h);
      expect(find.text('儲值 +2000 VP'), findsOneWidget);
      expect(find.text('花費 1275 VP'), findsOneWidget);
      expect(find.text('新造型：凌空之志 奧丁'), findsOneWidget);
      expect(find.text('2000'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}
