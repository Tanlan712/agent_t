import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_background.dart';
import 'package:valorant_shop_tracker/widgets/theme/style_background.dart';

import '../../../app_harness.dart';

/// 規格 §4.2：EVA 互動背景與動態控制。
void main() {
  Future<Harness> pump(WidgetTester tester, ThemeStyleId style,
      {bool motion = true,
      bool reduceMotion = false,
      bool tickers = true,
      BrightnessMode mode = BrightnessMode.auto}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await h.settings.setBackgroundMotion(motion);
    await tester.pumpWidget(h.wrap(
        choice: ThemeChoice(style: style, mode: mode),
        home: TickerMode(
          enabled: tickers,
          child: MediaQuery(
            data: MediaQueryData(
                size: const Size(1440, 900), disableAnimations: reduceMotion),
            child: const AppShell(
                currentRoute: '/matches', title: '對戰紀錄', child: Text('內容')),
          ),
        )));
    return h;
  }

  for (final (style, keys) in [
    (ThemeStyleId.evaAlert, ['bg-eva-hex']),
    (ThemeStyleId.evaMonitor, ['bg-eva-lattice']),
    (ThemeStyleId.evaFusion, ['bg-eva-hex', 'bg-eva-lattice']),
  ]) {
    testWidgets('$style 背景圖層', (tester) async {
      await pump(tester, style);
      expect(find.byType(EvaBackground), findsOneWidget);
      for (final k in keys) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: k);
      }
    });
  }

  testWidgets('F2 淺色（機密文件）沒有格線', (tester) async {
    await pump(tester, ThemeStyleId.evaMonitor, mode: BrightnessMode.light);
    expect(find.byKey(const ValueKey('bg-eva-lattice')), findsNothing);
  });

  testWidgets('動態背景開啟時掃描線在動，掃完一輪後停下', (tester) async {
    await pump(tester, ThemeStyleId.evaFusion);
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('停下後計時器會再啟動下一輪', (tester) async {
    await pump(tester, ThemeStyleId.evaAlert);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 9));
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpAndSettle();
  });

  for (final (name, motion, reduce, tickers) in [
    ('動態背景關閉', false, false, true),
    ('減少動態效果', true, true, true),
    ('頁面不在前景（TickerMode）', true, false, false),
  ]) {
    testWidgets('$name時完全不動', (tester) async {
      await pump(tester, ThemeStyleId.evaFusion,
          motion: motion, reduceMotion: reduce, tickers: tickers);
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.pump(const Duration(seconds: 20));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  }

  testWidgets('滑鼠移動時記錄位置（亮起附近的格子）', (tester) async {
    await pump(tester, ThemeStyleId.evaAlert);
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 500));
    await mouse.moveTo(const Offset(720, 520));
    await tester.pump();
    final state =
        tester.state<StyleBackgroundState>(find.byType(StyleBackground));
    expect(state.pointer.value, isNotNull);
    await mouse.removePointer();
    await tester.pump();
    expect(state.pointer.value, isNull);
  });

  testWidgets('背景不攔截點擊', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    var taps = 0;
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.evaFusion),
        home: AppShell(
            currentRoute: '/matches',
            title: '對戰紀錄',
            child: TextButton(
                key: const ValueKey('tap-me'),
                onPressed: () => taps++,
                child: const Text('按我')))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tap-me')));
    expect(taps, 1);
  });
}
