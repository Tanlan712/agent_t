import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/screens/settings_page.dart';
import 'package:agent_t/services/app_icon_service.dart';
import 'package:agent_t/widgets/app_icon_picker.dart';

import '../app_harness.dart';
import '../shell/app_shell_test.dart' show setWidth;

class _FakeIcons implements AppIconService {
  AppIconId icon;
  bool fail;
  final sets = <AppIconId>[];
  _FakeIcons(this.icon, {this.fail = false});

  @override
  Future<AppIconId> current() async => icon;

  @override
  Future<void> set(AppIconId id) async {
    if (fail) throw Exception('nope');
    sets.add(id);
    icon = id;
  }
}

/// 規格 2026-10-22-switchable-app-icons-design.md §4：設定頁的 App 圖示選擇器。
void main() {
  Future<void> pump(WidgetTester tester, _FakeIcons icons) async {
    setWidth(tester, 1200);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        useSettingsTheme: true,
        home: Scaffold(
            body:
                SingleChildScrollView(child: AppIconPicker(service: icons)))));
    await tester.pumpAndSettle();
  }

  testWidgets('列出所有圖示並標出目前的', (tester) async {
    await pump(tester, _FakeIcons(AppIconId.airy));
    for (final i in AppIconId.values) {
      expect(find.byKey(ValueKey('app-icon-${i.key}')), findsOneWidget);
      expect(find.text(i.label), findsOneWidget);
    }
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('app-icon-airy')),
            matching: find.byIcon(Icons.check_circle)),
        findsOneWidget);
  });

  testWidgets('點選後切換', (tester) async {
    final icons = _FakeIcons(AppIconId.defaultIcon);
    await pump(tester, icons);
    await tester.tap(find.byKey(const ValueKey('app-icon-eva_monitor')));
    await tester.pumpAndSettle();
    expect(icons.sets, [AppIconId.evaMonitor]);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('app-icon-eva_monitor')),
            matching: find.byIcon(Icons.check_circle)),
        findsOneWidget);
  });

  testWidgets('點目前的圖示不做事', (tester) async {
    final icons = _FakeIcons(AppIconId.terminal);
    await pump(tester, icons);
    await tester.tap(find.byKey(const ValueKey('app-icon-terminal')));
    await tester.pumpAndSettle();
    expect(icons.sets, isEmpty);
  });

  testWidgets('失敗時顯示訊息、保留原本的選擇', (tester) async {
    final icons = _FakeIcons(AppIconId.defaultIcon, fail: true);
    await pump(tester, icons);
    await tester.tap(find.byKey(const ValueKey('app-icon-editorial')));
    await tester.pumpAndSettle();
    expect(find.text('無法更換圖示'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('app-icon-default')),
            matching: find.byIcon(Icons.check_circle)),
        findsOneWidget);
  });

  final settingsList = find
      .descendant(
          of: find.byKey(const ValueKey('settings-list')),
          matching: find.byType(Scrollable))
      .first;

  Future<void> pumpSettings(WidgetTester tester) async {
    setWidth(tester, 1400);
    dotenv.testLoad(fileInput: '');
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(home: const SettingsPage()));
    await tester.pumpAndSettle();
  }

  testWidgets('手機 App 的設定頁有 App 圖示', (tester) async {
    await pumpSettings(tester);
    await tester.scrollUntilVisible(find.byType(AppIconPicker), 300,
        scrollable: settingsList);
    expect(find.byType(AppIconPicker), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('其他平台的設定頁沒有 App 圖示', (tester) async {
    await pumpSettings(tester);
    await tester.drag(settingsList, const Offset(0, -5000));
    await tester.pumpAndSettle();
    expect(find.byType(AppIconPicker), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
}
