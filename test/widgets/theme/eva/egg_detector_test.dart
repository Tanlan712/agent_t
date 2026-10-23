import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/widgets/theme/eva/egg_detector.dart';

/// 規格 §4.4：E1、E2、E4、E5、E11、E20 的觸發偵測。
void main() {
  late List<EggEvent> events;
  late DateTime now;
  late EggDetector d;

  setUp(() {
    events = [];
    now = DateTime(2026, 10, 21, 12);
    d = EggDetector(onEgg: events.add, now: () => now);
  });
  tearDown(() => d.dispose());

  const konami = [
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.keyB,
    LogicalKeyboardKey.keyA,
  ];
  void typeKeys(List<LogicalKeyboardKey> keys) {
    for (final k in keys) {
      d.key(k, k.keyLabel.length == 1 ? k.keyLabel.toLowerCase() : null);
    }
  }

  test('完整 Konami 碼觸發一次', () {
    typeKeys(konami);
    expect(events, [EggEvent.konami]);
  });

  test('中途打錯要重來；重來後仍可觸發', () {
    typeKeys(konami.sublist(0, 5));
    typeKeys([LogicalKeyboardKey.keyX]);
    typeKeys(konami.sublist(5));
    expect(events, isEmpty);
    typeKeys(konami);
    expect(events, [EggEvent.konami]);
  });

  test('↑↑↑↓↓… 多按一次 ↑ 仍可觸發', () {
    typeKeys([LogicalKeyboardKey.arrowUp, ...konami]);
    expect(events, [EggEvent.konami]);
  });

  test('Konami 後 10 秒內再按 B A → konamiBA；超過 10 秒不觸發', () {
    typeKeys(konami);
    now = now.add(const Duration(seconds: 5));
    typeKeys([LogicalKeyboardKey.keyB, LogicalKeyboardKey.keyA]);
    expect(events, [EggEvent.konami, EggEvent.konamiBA]);
    events.clear();
    typeKeys(konami);
    now = now.add(const Duration(seconds: 11));
    typeKeys([LogicalKeyboardKey.keyB, LogicalKeyboardKey.keyA]);
    expect(events, [EggEvent.konami]);
  });

  test('鍵入 sync（前面有其他字也可以）', () {
    for (final c in 'xsync'.split('')) {
      d.key(LogicalKeyboardKey.keyS, c);
    }
    expect(events, [EggEvent.sync]);
  });

  test('` 開終端機', () {
    d.key(LogicalKeyboardKey.backquote, '`');
    expect(events, [EggEvent.terminal]);
  });

  test('品牌字 1.2 秒內連點 5 下 → MAGI；太慢不算', () {
    for (var i = 0; i < 5; i++) {
      d.tapBrand();
      now = now.add(const Duration(milliseconds: 200));
    }
    expect(events, [EggEvent.magi]);
    events.clear();
    for (var i = 0; i < 5; i++) {
      d.tapBrand();
      now = now.add(const Duration(milliseconds: 400));
    }
    expect(events, isEmpty);
  });

  testWidgets('閒置 60 秒 → idle；期間有活動就重新計時', (tester) async {
    final e = <EggEvent>[];
    final det = EggDetector(onEgg: e.add);
    await tester.pump(const Duration(seconds: 50));
    det.activity();
    await tester.pump(const Duration(seconds: 50));
    expect(e, isEmpty);
    await tester.pump(const Duration(seconds: 11));
    expect(e, [EggEvent.idle]);
    det.dispose();
  });
}
