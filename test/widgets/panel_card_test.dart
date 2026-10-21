import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(useGoogleFonts: false),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: Center(child: child)),
      ),
    );

/// Bento 改版 B1：圓角卡片取代 HUD 斜切。
void main() {
  BoxDecoration decorationOf(WidgetTester tester) => tester
      .widget<AnimatedContainer>(find.descendant(
          of: find.byType(PanelCard), matching: find.byType(AnimatedContainer)))
      .decoration! as BoxDecoration;

  testWidgets('PanelCard 圓角 12、outline 邊框', (tester) async {
    await tester.pumpWidget(host(const PanelCard(child: Text('卡片'))));
    final d = decorationOf(tester);
    expect(d.borderRadius, BorderRadius.circular(AppRadius.card));
    expect((d.border! as Border).top.color, AppColors.outline);
  });

  testWidgets('PanelCard 有強調色時左側 3px 色條', (tester) async {
    await tester.pumpWidget(
        host(const PanelCard(accent: AppColors.win, child: Text('卡片'))));
    final bar =
        tester.widget<Container>(find.byKey(const ValueKey('panel-accent')));
    expect(bar.color, AppColors.win);
    expect(tester.getSize(find.byKey(const ValueKey('panel-accent'))).width, 3);
  });

  testWidgets('PanelCard 可點擊時能用鍵盤聚焦並以 Enter 觸發', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
        host(PanelCard(onTap: () => taps++, child: const Text('卡片'))));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(taps, 1);
    await tester.tap(find.text('卡片'));
    expect(taps, 2);
  });

  testWidgets('PanelCard 減少動態時 hover 沒有動畫', (tester) async {
    await tester.pumpWidget(host(
        PanelCard(onTap: () {}, child: const Text('卡片')),
        reduceMotion: true));
    final c = tester.widget<AnimatedContainer>(find.descendant(
        of: find.byType(PanelCard), matching: find.byType(AnimatedContainer)));
    expect(c.duration, Duration.zero);
  });

  testWidgets('不可點擊的 PanelCard 也提供透明 Material，子元件的焦點與水波看得到', (tester) async {
    await tester.pumpWidget(
        host(PanelCard(child: ListTile(title: const Text('列'), onTap: () {}))));
    final material = find.descendant(
        of: find.byType(PanelCard), matching: find.byType(Material));
    expect(material, findsWidgets);
    expect(find.ancestor(of: find.byType(ListTile), matching: material.first),
        findsOneWidget);
  });

  testWidgets('減少動態時 PanelCard 的 InkWell 沒有淡入與水波', (tester) async {
    await tester.pumpWidget(host(
        PanelCard(onTap: () {}, child: const Text('卡片')),
        reduceMotion: true));
    final ink = tester.widget<InkWell>(find.descendant(
        of: find.byType(PanelCard), matching: find.byType(InkWell)));
    expect(ink.hoverDuration, Duration.zero);
    expect(ink.splashFactory, NoSplash.splashFactory);
  });

  testWidgets('有強調色時左側不圓角，色條不被裁掉', (tester) async {
    await tester.pumpWidget(
        host(const PanelCard(accent: AppColors.win, child: Text('卡片'))));
    final r = decorationOf(tester).borderRadius! as BorderRadius;
    expect(r.topLeft, Radius.zero);
    expect(r.bottomLeft, Radius.zero);
    expect(r.topRight, const Radius.circular(AppRadius.card));
  });

  testWidgets('可點擊的 PanelCard 是按鈕語意', (tester) async {
    final handle = tester.ensureSemantics();
    await tester
        .pumpWidget(host(PanelCard(onTap: () {}, child: const Text('卡片'))));
    final node = tester.getSemantics(find.text('卡片'));
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    handle.dispose();
  });

  testWidgets('StatusChip 在 60px 寬不 overflow', (tester) async {
    await tester.pumpWidget(host(const SizedBox(
        width: 60,
        child: StatusChip(
            label: '這是一段很長的狀態文字',
            color: AppColors.warn,
            icon: Icons.warning_amber))));
    expect(tester.takeException(), isNull);
  });

  test('CardTheme 是 12px 圓角', () {
    final shape = buildAppTheme(useGoogleFonts: false).cardTheme.shape;
    expect(shape, isA<RoundedRectangleBorder>());
    expect((shape! as RoundedRectangleBorder).borderRadius,
        BorderRadius.circular(12));
  });

  testWidgets('EmptyState 顯示標題、說明與按鈕', (tester) async {
    var done = false;
    await tester.pumpWidget(host(EmptyState(
        icon: Icons.inbox,
        title: '還沒有資料',
        message: '登入後會自動同步',
        actionLabel: '登入 Riot',
        onAction: () => done = true)));
    expect(find.text('還沒有資料'), findsOneWidget);
    expect(find.text('登入後會自動同步'), findsOneWidget);
    await tester.tap(find.text('登入 Riot'));
    expect(done, isTrue);
  });
}
