import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/app_routes.dart';
import 'package:valorant_shop_tracker/screens/riot_login_page.dart';
import 'package:valorant_shop_tracker/screens/settings_page.dart';
import 'package:valorant_shop_tracker/services/riot_api_key_manager.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';

import '../app_harness.dart';

/// MASTER.md 第 6 節：375／768／1024／1440 都不可以 overflow。
void main() {
  const widths = [375.0, 768.0, 1024.0, 1440.0];
  final routes = [for (final n in navItems) n.route];
  // 設定頁讀取 .env（只確認是否存在），測試用空內容，與 settings_page_test 相同。
  setUp(() => dotenv.testLoad(fileInput: ''));

  for (final width in widths) {
    for (final route in routes) {
      testWidgets('$route @ ${width.toInt()} 不 overflow', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(width, 900);
        addTearDown(tester.view.reset);
        final h = await Harness.create(tester);
        await tester.pumpWidget(h.wrap(
            home: Builder(builder: (c) {
              return Navigator(
                onGenerateRoute: (_) =>
                    onGenerateAppRoute(RouteSettings(name: route)),
              );
            }),
            onGenerateRoute: onGenerateAppRoute));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(h.wrap(home: const SizedBox()));
      });
    }
  }

  testWidgets('登入頁不用 emoji，改用警示圖示', (tester) async {
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const RiotLoginPage()));
    expect(find.textContaining('⚠️'), findsNothing);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });

  emojiTests();
}

/// MASTER.md 第 8 節：lib/ 不用 emoji 當圖示（設定頁與 API Key 說明文字）。
final _emoji =
    RegExp('[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2753}]', unicode: true);

void emojiTests() {
  testWidgets('設定頁不含 emoji', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 4000);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const SettingsPage()));
    await tester.pump();
    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where(_emoji.hasMatch)
        .toList();
    expect(texts, isEmpty);
  });

  test('API Key 說明與狀態訊息不含 emoji', () {
    for (final s in [
      RiotApiKeyManager.getRenewalInstructions(),
      RiotApiKeyManager.getAlternativeApiInfo(),
      for (final code in [200, 401, 403, 429, -1, 500])
        RiotApiKeyManager.messageFor(code),
    ]) {
      expect(_emoji.hasMatch(s), isFalse, reason: s);
    }
  });
}
