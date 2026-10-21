import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/shell/nav_items.dart';
import 'package:valorant_shop_tracker/theme/eva_names.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_mincho.dart';

/// 規格 §4.5、§4.6：EVA 明朝體與故事名稱。
void main() {
  test('kanjiNumber', () {
    expect(kanjiNumber(1), '壱');
    expect(kanjiNumber(2), '弐');
    expect(kanjiNumber(9), '玖');
    expect(kanjiNumber(10), '拾');
    expect(kanjiNumber(14), '拾肆');
    expect(kanjiNumber(18), '拾捌');
    expect(kanjiNumber(20), '弐拾');
    expect(kanjiNumber(26), '弐拾陸');
  });

  test('故事名稱涵蓋所有導覽頁面', () {
    for (final n in navItems) {
      expect(evaStoryNames.containsKey(n.route), isTrue, reason: n.route);
    }
    expect(evaStoryNames['/']!.$1, '補給線');
    expect(evaStoryNames['/matches']!.$2, 'OPERATION LOG');
  });

  test('26 話標題、德文副標涵蓋導覽', () {
    expect(evaEpisodeTitles.length, 26);
    for (final n in navItems) {
      expect(navLabelsDe.containsKey(n.route), isTrue, reason: n.route);
    }
  });

  testWidgets('EvaMincho 在窄空間不 overflow', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: SizedBox(
                width: 100,
                child: EvaMincho('補給線補給線補給線補給線補給線補給線補給線', size: 38)))));
    expect(tester.takeException(), isNull);
    expect(
        tester.getSize(find.byType(EvaMincho)).width, lessThanOrEqualTo(100));
  });

  testWidgets('EvaMincho 水平壓縮', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Center(child: EvaMincho('今日', size: 38, squeeze: 0.8)))));
    final t = tester.widget<Transform>(find.descendant(
        of: find.byType(EvaMincho), matching: find.byType(Transform)));
    expect(t.transform.getMaxScaleOnAxis(), 1);
    expect(t.transform.storage[0], closeTo(0.8, 0.001));
  });

  testWidgets('EvaTitleCard 顯示第 N 話與大小兩個詞', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: EvaTitleCard(episode: '第 壱 話', big: '起動', small: 'する日'))));
    expect(find.text('第 壱 話'), findsOneWidget);
    expect(find.text('起動'), findsOneWidget);
    expect(find.text('する日'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
