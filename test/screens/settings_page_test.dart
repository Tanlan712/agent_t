import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/screens/settings_page.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart'
    show wishlistEnabled;
import 'package:valorant_shop_tracker/widgets/my_shop_settings_card.dart';

import '../app_harness.dart';
import '../catalog_helpers.dart';
import '../theme/contrast.dart';

/// 設定頁本身的捲動清單（頁內的選單順序清單也是 Scrollable，不能用 .last）。
final settingsScrollable = find
    .descendant(
        of: find.byKey(const ValueKey('settings-list')),
        matching: find.byType(Scrollable))
    .first;

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
    // 願望清單暫時關閉時不顯示標示開關。
    expect(
        find.text('標示願望清單'), wishlistEnabled ? findsOneWidget : findsNothing);
    expect(find.text('重新下載造型目錄'), findsOneWidget);
    expect(find.text('上次下載：2026-10-19 12:00'), findsOneWidget);
  });

  testWidgets('關閉標示願望清單', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(card(h));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(h.settings.settings.highlightWishlist, isFalse);
  }, skip: !wishlistEnabled);

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

  testWidgets('複製網址按鈕的文字在深色主題下清楚可讀', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const SettingsPage()));
    final label = find.text('複製 valorant-api.com 網址');
    await tester.scrollUntilVisible(label, 300, scrollable: settingsScrollable);
    final fg = tester.renderObject<RenderParagraph>(label).text.style!.color!;
    final bg = tester
        .widget<Material>(
            find.ancestor(of: label, matching: find.byType(Material)).first)
        .color!;
    expect(contrast(fg, bg), greaterThanOrEqualTo(4.5));
  });

  testWidgets('設定頁包含我的商店區塊', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const SettingsPage()));
    await tester.scrollUntilVisible(find.byType(MyShopSettingsCard), 300,
        scrollable: settingsScrollable);
    expect(find.byType(MyShopSettingsCard), findsOneWidget);
  });
}
