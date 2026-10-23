import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/app_routes.dart';
import 'package:agent_t/screens/riot_login_page.dart';
import 'package:agent_t/screens/settings_page.dart';
import 'package:agent_t/services/riot_api_key_manager.dart';
import 'package:agent_t/shell/nav_items.dart';

import 'package:agent_t/theme/theme_ids.dart';

import '../app_harness.dart';

/// MASTER.md 第 6 節：375／768／1024／1440 都不可以 overflow。
void main() {
  const widths = [375.0, 768.0, 1024.0, 1440.0];
  final routes = [for (final n in navItems) n.route];
  // 設定頁讀取 .env（只確認是否存在），測試用空內容，與 settings_page_test 相同。
  setUp(() => dotenv.testLoad(fileInput: ''));

  // 規格 §0：每種風格（各自的預設明暗）都要通過。
  for (final style in ThemeStyleId.values) {
    for (final width in widths) {
      for (final route in routes) {
        testWidgets('${style.name} $route @ ${width.toInt()} 不 overflow',
            (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = Size(width, 900);
          addTearDown(tester.view.reset);
          final h = await Harness.create(tester);
          await tester.pumpWidget(h.wrap(
              choice: ThemeChoice(style: style),
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
  }

  testWidgets('矮視窗 1024×500 各頁不 overflow', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 500);
    addTearDown(tester.view.reset);
    for (final route in routes) {
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(
          home: Navigator(
              onGenerateRoute: (_) =>
                  onGenerateAppRoute(RouteSettings(name: route))),
          onGenerateRoute: onGenerateAppRoute));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(tester.takeException(), isNull, reason: route);
      await tester.pumpWidget(h.wrap(home: const SizedBox()));
    }
  });

  for (final (name, page) in [
    ('設定', const SettingsPage() as Widget),
    ('登入', const RiotLoginPage() as Widget),
  ]) {
    testWidgets('$name頁 1440 寬內容不超過 760 且置中', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1440, 900);
      addTearDown(tester.view.reset);
      final h = await Harness.create(tester);
      await tester.pumpWidget(h.wrap(home: page));
      await tester.pump();
      final box = find
          .ancestor(
              of: find.byType(ListView).last,
              matching: find.byType(ConstrainedBox))
          .first;
      final rect = tester.getRect(box);
      expect(rect.width, lessThanOrEqualTo(760));
      // 置中：內容區（扣掉側欄）的中線。
      // 有側欄時以內容區（Expanded）為準；登入頁沒有側欄，以整個 Scaffold 為準。
      final area = find.ancestor(of: box, matching: find.byType(Expanded));
      final scaffold = tester.getRect(
          area.evaluate().isEmpty ? find.byType(Scaffold).first : area.first);
      expect(rect.center.dx, closeTo(scaffold.center.dx, 40));
    });
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
