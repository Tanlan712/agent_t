import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/app_settings.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/theme/theme_ids.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_documents.dart';

import '../../../app_harness.dart';
import '../../../match_fixtures.dart';

/// 規格 §4.7：機密文件庫（E12）。
void main() {
  const data = EvaDocData(
    shopCount: 4,
    matched: 1,
    sync: 0.54,
    refresh: '08:00',
    completion: 0.375,
    matchesLoaded: 10,
    winRate: 0.6,
    avgAcs: 231,
    openDays: 12,
    angelCount: 2,
  );

  List<String> ids(AppSettings s) =>
      [for (final d in availableDocuments(s, data)) d.id];

  test('一開始有報告書、附錄 B、附錄 C', () {
    expect(ids(const AppSettings()), ['report', 'B', 'C']);
  });

  test('附錄依劇集解鎖：5、10、15、20、26 話', () {
    expect(ids(const AppSettings(evaEpisodeDays: 4)), isNot(contains('D')));
    expect(ids(const AppSettings(evaEpisodeDays: 5)), contains('D'));
    expect(ids(const AppSettings(evaEpisodeDays: 10)), contains('E'));
    expect(ids(const AppSettings(evaEpisodeDays: 15)), contains('F'));
    expect(ids(const AppSettings(evaEpisodeDays: 20)), contains('G'));
    expect(
        ids(const AppSettings(evaEpisodeDays: 25)), isNot(contains('final')));
    expect(ids(const AppSettings(evaEpisodeDays: 26)), contains('final'));
  });

  test('附錄 Z 要全部彩蛋', () {
    expect(ids(const AppSettings()), isNot(contains('Z')));
    final all =
        AppSettings(evaFoundEggs: [for (var i = 1; i <= 20; i++) 'E$i']);
    expect(ids(all), contains('Z'));
  });

  test('附錄 C 只列已發現的彩蛋', () {
    final c =
        availableDocuments(const AppSettings(evaFoundEggs: ['E1', 'E5']), data)
            .firstWhere((d) => d.id == 'C');
    final text = c.plainText;
    expect(text, contains('E1'));
    expect(text, contains('E5'));
    expect(text, isNot(contains('E2 ')));
    expect(text, contains('18 項未解密'));
  });

  test('每份文件都有隱私提示，且不含 PUUID', () {
    final all = availableDocuments(
        AppSettings(
            evaEpisodeDays: 26,
            evaFoundEggs: [for (var i = 1; i <= 20; i++) 'E$i']),
        data);
    expect(all.length, 9);
    for (final d in all) {
      expect(d.plainText, contains('本文件所載他人資料，請勿公開或分享'), reason: d.id);
      expect(d.plainText, isNot(contains(myPuuid)));
      expect(d.footer, startsWith('VAL-SYS ARCHIVE · DOC-'));
      expect(d.footer, isNot(contains('NERV')));
    }
  });

  test('報告書的真實數字是塗黑的', () {
    final report = availableDocuments(const AppSettings(), data).first;
    final redacted = report.lines
        .expand((l) => l)
        .whereType<DocRedacted>()
        .map((r) => r.text)
        .toList();
    expect(redacted, containsAll(['4 件', '1 件', '54.0%', '08:00', '37.5%']));
  });

  test('沒有資料時顯示資料未取得', () {
    const empty = EvaDocData(
        shopCount: 0,
        matched: 0,
        sync: null,
        refresh: '08:00',
        completion: null,
        matchesLoaded: 0,
        winRate: null,
        avgAcs: null,
        openDays: 1,
        angelCount: 0);
    final report = availableDocuments(const AppSettings(), empty).first;
    expect(report.plainText, contains('資料未取得'));
  });

  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('Redacted：預設黑條，hover 或聚焦後顯示', (tester) async {
    await tester.pumpWidget(host(const Redacted(text: '54.0%')));
    expect(find.text('54.0%'), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.byType(Redacted)));
    await tester.pump();
    expect(find.text('54.0%'), findsOneWidget);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('54.0%'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(find.text('54.0%'), findsOneWidget);
    await mouse.removePointer();
  });

  testWidgets('Redacted 有語意標籤', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(const Redacted(text: '54.0%')));
    expect(find.bySemanticsLabel('已塗黑，聚焦以顯示'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('品牌字按右鍵開啟文件庫，可翻頁，Esc 關閉', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1440, 900);
    addTearDown(tester.view.reset);
    final h = await Harness.create(tester);
    await tester.pumpWidget(h.wrap(
        choice: const ThemeChoice(style: ThemeStyleId.evaFusion),
        home: const AppShell(currentRoute: '/', title: 't', child: Text('x'))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('eva-brand')),
        buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(find.byType(EvaArchive), findsOneWidget);
    expect(find.textContaining('中間報告書'), findsOneWidget);
    expect(h.settings.settings.evaFoundEggs, contains('E12'));
    await tester.tap(find.byKey(const ValueKey('doc-page-B')));
    await tester.pump();
    expect(find.textContaining('更新記錄'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(find.byType(EvaArchive), findsNothing);
  });
}
