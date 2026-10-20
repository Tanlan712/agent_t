import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/screens/wishlist_page.dart';

import '../app_harness.dart';

void main() {
  final now = DateTime(2026, 10, 19, 10);

  testWidgets('空清單顯示提示', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: WishlistPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('願望清單是空的，按 ＋ 加入造型'), findsOneWidget);
  });

  testWidgets('顯示名稱、未知造型與上架中', (tester) async {
    final h = await Harness.create(
      tester,
      wishlist: ['o', 'zzz'],
      shop: CurrentShop(
        daily: const [
          ShopEntry(skinUuid: 'o', price: 1275),
          ShopEntry(skinUuid: 'p', price: 1775),
          ShopEntry(skinUuid: 'i', price: 1775),
          ShopEntry(skinUuid: 'r', price: 2475),
        ],
        dailyExpiresAt: DateTime(2026, 10, 20, 8),
      ),
    );
    await tester.pumpWidget(h.wrap(home: WishlistPage(now: () => now)));
    await tester.pumpAndSettle();
    expect(find.text('凌空之志 奧丁'), findsOneWidget);
    expect(find.text('未知造型'), findsOneWidget);
    expect(find.text('現在上架中'), findsOneWidget);
  });

  testWidgets('左滑刪除', (tester) async {
    final h = await Harness.create(tester, wishlist: ['o']);
    await tester.pumpWidget(h.wrap(home: WishlistPage(now: () => now)));
    await tester.pumpAndSettle();
    await tester.drag(find.text('凌空之志 奧丁'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(h.wishlist.contains('o'), isFalse);
  });

  testWidgets('點刪除鈕移出願望清單', (tester) async {
    final h = await Harness.create(tester, wishlist: ['o']);
    await tester.pumpWidget(h.wrap(home: WishlistPage(now: () => now)));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('移出願望清單'));
    await tester.pumpAndSettle();
    expect(h.wishlist.contains('o'), isFalse);
  });

  testWidgets('＋ 加入造型', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
      home: WishlistPage(now: () => now),
      routes: {
        '/skin-picker': (context) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pop(context, h.catalog.skinById('p')));
          return const Scaffold();
        },
      },
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(h.wishlist.contains('p'), isTrue);
    expect(find.text('Prime 幻象'), findsOneWidget);
  });

  group('戰術 HUD', () {
    testWidgets('空清單用 EmptyState，按鈕可加入造型', (tester) async {
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: WishlistPage(now: () => now)));
      await tester.pumpAndSettle();
      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '加入造型'), findsOneWidget);
    });

    testWidgets('上架中的造型排第一，標籤是 StatusChip', (tester) async {
      final h = await Harness.create(
        tester,
        wishlist: ['p', 'o'],
        shop: CurrentShop(
          daily: const [ShopEntry(skinUuid: 'o', price: 1275)],
          dailyExpiresAt: DateTime(2026, 10, 20, 8),
        ),
      );
      await tester.pumpWidget(h.wrap(home: WishlistPage(now: () => now)));
      await tester.pumpAndSettle();
      final odin = tester.getTopLeft(find.text('凌空之志 奧丁'));
      final prime = tester.getTopLeft(find.text('Prime 幻象'));
      expect(odin.dy < prime.dy || odin.dx < prime.dx, isTrue);
      expect(find.widgetWithText(StatusChip, '現在上架中'), findsOneWidget);
    });
  });
}
