import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';

import '../shell/app_shell_test.dart' show setWidth;

Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
      theme: buildAppTheme(useGoogleFonts: false),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Scaffold(body: child),
      ),
    );

void main() {
  group('KpiTile', () {
    testWidgets('上升顯示箭頭與勝利色', (tester) async {
      await tester.pumpWidget(host(
          const KpiTile(label: 'RR', value: '52', delta: '+29', up: true)));
      expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
      final delta = tester.widget<Text>(find.text('+29'));
      expect(delta.style?.color, AppColors.win);
    });

    testWidgets('沒有方向時不顯示箭頭', (tester) async {
      await tester.pumpWidget(
          host(const KpiTile(label: 'VP', value: '1500', delta: '同步中')));
      expect(find.byIcon(Icons.arrow_upward), findsNothing);
      expect(find.byIcon(Icons.arrow_downward), findsNothing);
    });
  });

  testWidgets('KpiStrip：375 寬放 4 個不 overflow，排成兩列', (tester) async {
    setWidth(tester, 375);
    await tester.pumpWidget(host(const KpiStrip(tiles: [
      KpiTile(key: ValueKey('k0'), label: 'A', value: '1'),
      KpiTile(key: ValueKey('k1'), label: 'B', value: '2'),
      KpiTile(key: ValueKey('k2'), label: 'C', value: '3'),
      KpiTile(key: ValueKey('k3'), label: 'D', value: '4'),
    ])));
    expect(tester.takeException(), isNull);
    final first = tester.getTopLeft(find.byKey(const ValueKey('k0')));
    final third = tester.getTopLeft(find.byKey(const ValueKey('k2')));
    expect(third.dy, greaterThan(first.dy));
  });

  testWidgets('StatusChip：不換行、有提示', (tester) async {
    await tester.pumpWidget(host(
        const StatusChip(label: '疑似小號', color: AppColors.warn, tooltip: '推測')));
    expect(tester.widget<Text>(find.text('疑似小號')).softWrap, isFalse);
    expect(find.byType(Tooltip), findsOneWidget);
  });

  testWidgets('HudCard：切角與點擊', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(
        HudCard(notched: true, onTap: () => taps++, child: const Text('卡片'))));
    expect(find.byType(ClipPath), findsOneWidget);
    await tester.tap(find.text('卡片'));
    expect(taps, 1);
  });

  testWidgets('EmptyState：按下動作按鈕', (tester) async {
    var done = false;
    await tester.pumpWidget(host(EmptyState(
        icon: Icons.inbox,
        message: '沒有資料',
        actionLabel: '重試',
        onAction: () => done = true)));
    expect(find.text('沒有資料'), findsOneWidget);
    await tester.tap(find.text('重試'));
    expect(done, isTrue);
  });

  group('FadeInList', () {
    double opacityOf(WidgetTester tester, String text) => tester
        .widget<Opacity>(find
            .ancestor(of: find.text(text), matching: find.byType(Opacity))
            .first)
        .opacity;

    testWidgets('一般情況下淡入', (tester) async {
      await tester
          .pumpWidget(host(const FadeInList(children: [Text('a'), Text('b')])));
      expect(opacityOf(tester, 'a'), lessThan(1));
      await tester.pumpAndSettle();
      expect(opacityOf(tester, 'a'), 1);
      expect(opacityOf(tester, 'b'), 1);
    });

    testWidgets('減少動態效果時直接顯示', (tester) async {
      await tester.pumpWidget(host(
          const FadeInList(children: [Text('a'), Text('b')]),
          reduceMotion: true));
      expect(find.byType(Opacity), findsNothing);
      expect(find.text('b'), findsOneWidget);
    });
  });

  testWidgets('SectionHeader 與 SkeletonBox', (tester) async {
    await tester.pumpWidget(host(const Column(children: [
      SectionHeader(title: '每日商店', trailing: Text('編輯')),
      SkeletonBox(width: 80),
    ])));
    expect(find.text('每日商店'), findsOneWidget);
    expect(find.text('編輯'), findsOneWidget);
    expect(find.byType(SkeletonBox), findsOneWidget);
  });
}
