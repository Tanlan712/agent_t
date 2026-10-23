import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/app_routes.dart';
import 'package:agent_t/logic/purchase_history.dart';
import 'package:agent_t/screens/wallet_page.dart';
import 'package:agent_t/shell/nav_items.dart';

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
    expect(find.text('登入 Riot 以匯入購買紀錄'), findsOneWidget);
  });

  testWidgets('按鈕打開 Riot 官方購買紀錄', (tester) async {
    setWidth(tester, 1400);
    final h = await Harness.create(tester);
    final launched = <Uri>[];
    await tester.pumpWidget(h.wrap(home: WalletPage(launch: (u) async {
      launched.add(u);
      return true;
    })));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('wallet-official-open')));
    expect(launched, [officialPurchaseHistory]);
    expect(officialPurchaseHistory.host, 'support.riotgames.com');
  });

  group('匯入官方購買紀錄', () {
    Future<Harness> loggedIn(WidgetTester tester) async {
      setWidth(tester, 1400);
      final h = await Harness.create(tester);
      await tester.runAsync(() => h.riot.login(fakeRedirect));
      return h;
    }

    testWidgets('網頁版不顯示匯入按鈕', (tester) async {
      final h = await loggedIn(tester);
      await tester.pumpWidget(h.wrap(home: const WalletPage(canImport: false)));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('wallet-official-open')), findsOneWidget);
      expect(
          find.byKey(const ValueKey('wallet-official-import')), findsNothing);
    });

    testWidgets('按匯入後顯示清單並存下來', (tester) async {
      final h = await loggedIn(tester);
      Uri? opened;
      await tester.pumpWidget(h.wrap(
          home: WalletPage(
              canImport: true,
              importOfficial: (_, url) async {
                opened = url;
                return [
                  PurchaseRecord(
                      date: DateTime(2026, 10, 1),
                      item: '1000 VP',
                      vp: 1000,
                      price: 'NT\$ 330'),
                  PurchaseRecord(
                      date: DateTime(2026, 9, 1), item: '2050 VP', vp: 2050),
                ];
              })));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wallet-official-import')));
      await tester.pumpAndSettle();
      expect(opened, officialPurchaseHistory);
      expect(find.text('官方購買紀錄（2 筆）'), findsOneWidget);
      expect(find.textContaining('合計 3050 VP'), findsOneWidget);
      expect(find.text('+1000 VP\nNT\$ 330'), findsOneWidget);
      expect(find.text('2026-10-01'), findsOneWidget);
      final puuid = h.riot.session!.puuid;
      expect(h.purchaseHistory.purchases(puuid)!.records, hasLength(2));
    });

    testWidgets('關掉匯入頁時不改變紀錄', (tester) async {
      final h = await loggedIn(tester);
      await tester.pumpWidget(h.wrap(
          home: WalletPage(
              canImport: true, importOfficial: (_, __) async => null)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('wallet-official-import')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('wallet-purchases')), findsNothing);
    });
  });
}
