import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/screens/shop_edit_page.dart';

import '../app_harness.dart';
import '../catalog_helpers.dart';

void main() {
  final now = DateTime(2026, 10, 19, 10);

  /// 假的 '/skin-picker'：依序回傳 [picks] 中的造型。
  Map<String, WidgetBuilder> pickerReturning(List<SkinInfo> picks) {
    final queue = [...picks];
    return {
      '/skin-picker': (context) {
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => Navigator.pop(context, queue.removeAt(0)));
        return const Scaffold();
      },
    };
  }

  Future<Harness> openDaily(WidgetTester tester, List<SkinInfo> picks) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
      home: ShopEditPage(section: ShopSection.daily, now: () => now),
      routes: pickerReturning(picks),
    ));
    for (var i = 0; i < picks.length; i++) {
      await tester.ensureVisible(find.byKey(ValueKey('slot-$i')));
      await tester.tap(find.byKey(ValueKey('slot-$i')));
      await tester.pumpAndSettle();
    }
    return h;
  }

  Future<void> save(WidgetTester tester) async {
    await tester.ensureVisible(find.text('儲存'));
    await tester.tap(find.text('儲存'));
    await tester.pumpAndSettle();
  }

  testWidgets('只選 3 格時提示需要 4 個', (tester) async {
    final h = await openDaily(tester, [odin, prime, ion]);
    await save(tester);
    expect(find.text('每日商店需要 4 個造型'), findsOneWidget);
    expect(h.shop.shop.daily, isEmpty);
  });

  testWidgets('價格為 0 時顯示請輸入正整數且不儲存', (tester) async {
    final h = await openDaily(tester, [odin, prime, ion, reaver]);
    await tester.enterText(find.byKey(const ValueKey('price-1')), '0');
    await save(tester);
    expect(find.text('請輸入正整數'), findsOneWidget);
    expect(h.shop.shop.daily, isEmpty);
  });

  testWidgets('畫面外最後一格價格不合法也會被驗證', (tester) async {
    final h = await openDaily(tester, [odin, prime, ion, reaver]);
    await tester.ensureVisible(find.byKey(const ValueKey('price-3')));
    await tester.enterText(find.byKey(const ValueKey('price-3')), 'abc');
    await save(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('請輸入正整數'), findsOneWidget);
    expect(h.shop.shop.daily, isEmpty);
  });

  testWidgets('重複造型時提示不能重複', (tester) async {
    final h = await openDaily(tester, [odin, odin, ion, reaver]);
    await save(tester);
    expect(find.text('同一造型不能重複'), findsOneWidget);
    expect(h.shop.shop.daily, isEmpty);
  });

  testWidgets('正常儲存：到期時間與預設價格', (tester) async {
    final h = await openDaily(tester, [prime, odin, ion, reaver]);
    await save(tester);
    expect(h.shop.shop.dailyExpiresAt, DateTime(2026, 10, 20, 8, 0));
    expect(h.shop.shop.daily.first.skinUuid, 'p');
    expect(h.shop.shop.daily.first.price, 1775);
    expect(h.shop.shop.daily[1].price, 1275);
  });
}
