import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/match_mapper.dart';
import 'package:agent_t/screens/match_detail_page.dart';

import '../app_harness.dart';
import '../logic/match_highlights_test.dart' show matchJson;
import '../shell/app_shell_test.dart' show setWidth;

void main() {
  for (final width in [390.0, 1400.0]) {
    testWidgets('${width.toInt()} 寬：對戰詳情顯示多殺與殘局、回合時間軸、熱區圖與武器', (tester) async {
      setWidth(tester, width);
      final h = await Harness.create(tester);
      final d = mapMatchDetail(matchJson(), 'me');
      await tester.pumpWidget(
          h.wrap(home: MatchDetailPage(matchId: 'm', detail: d)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('round-timeline')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const ValueKey('match-highlights')), findsOneWidget);
      expect(find.text('3 殺 × 1'), findsOneWidget);
      expect(find.text('1v3 殘局 × 1'), findsOneWidget);
      // 預設選第 1 回合：清光、下包者是自己。
      expect(find.byKey(const ValueKey('round-detail-0')), findsOneWidget);
      expect(find.textContaining('我方勝・清光'), findsOneWidget);
      expect(find.textContaining('我方裝備 11700（全起）'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('round-chip-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('round-chip-2')));
      await tester.pumpAndSettle();
      expect(find.textContaining('敵方勝・爆炸'), findsOneWidget);
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('kill-heatmap')), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('擊殺 4'), findsOneWidget);
      expect(find.text('陣亡 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
