import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/screens/settings_page.dart';
import 'package:valorant_shop_tracker/widgets/my_shop_settings_card.dart';

import '../app_harness.dart';
import '../catalog_helpers.dart';

void main() {
  setUp(() => dotenv.testLoad(fileInput: ''));

  Widget card(Harness h) => h.wrap(
      home: const Scaffold(
          body: SingleChildScrollView(child: MyShopSettingsCard())));

  testWidgets('顯示刷新時間、標示開關、重新下載與上次下載時間', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(card(h));
    expect(find.text('我的商店'), findsOneWidget);
    expect(find.text('商店刷新時間 08:00'), findsOneWidget);
    expect(find.text('標示願望清單'), findsOneWidget);
    expect(find.text('重新下載造型目錄'), findsOneWidget);
    expect(find.text('上次下載：2026-10-19 12:00'), findsOneWidget);
  });

  testWidgets('關閉標示願望清單', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(card(h));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(h.settings.settings.highlightWishlist, isFalse);
  });

  testWidgets('重新下載造型目錄會呼叫 API', (tester) async {
    var requests = 0;
    final client = MockClient((_) async {
      requests++;
      return http.Response('', 503);
    });
    final h = await Harness.create(tester,
        catalog: await loadedCatalog(tester, client: client));
    await tester.pumpWidget(card(h));
    await tester.tap(find.text('重新下載造型目錄'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(requests, greaterThan(0));
  });

  testWidgets('設定頁包含我的商店區塊', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const SettingsPage()));
    await tester.scrollUntilVisible(find.byType(MyShopSettingsCard), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(MyShopSettingsCard), findsOneWidget);
  });
}
