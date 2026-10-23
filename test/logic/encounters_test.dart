import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/encounters.dart';
import 'package:agent_t/logic/match_mapper.dart';

import '../match_fixtures.dart';

void main() {
  test('自己的場次：其他 9 人都記下，分隊友與對手，勝負是自己的', () {
    final e = encountersIn(mapMatchDetail(matchDetailsJson(), myPuuid));
    expect(e.length, 9);
    expect(e.containsKey(myPuuid), isFalse);
    expect(e.containsKey('obs'), isFalse);
    expect(e['mate']!.ally, isTrue);
    expect(e['r1']!.ally, isFalse);
    expect(e['r1']!.won, isTrue);
    expect(e['r1']!.matchId, 'm1');
    expect(e['r1']!.mapId, '/Game/Maps/Ascent/Ascent');
  });

  test('玩家頁查看對手的場次：勝負換算成自己的角度', () {
    final d = mapMatchDetail(matchDetailsJson(), 'r1', selfPuuid: myPuuid);
    expect(d.summary.won, isFalse);
    final e = encountersIn(d);
    expect(e['r1']!.won, isTrue);
    expect(e['r1']!.ally, isFalse);
  });

  test('自己不在場的場次不算遇過', () {
    final d = mapMatchDetail(matchDetailsJson(), 'r1', selfPuuid: 'someone');
    expect(encountersIn(d), isEmpty);
  });

  test('摘要：當隊友與當對手各自的勝敗', () {
    final e = encountersIn(mapMatchDetail(matchDetailsJson(), myPuuid));
    final s = EncounterSummary.of([e['r1']!, e['mate']!]);
    expect(s.total, 2);
    expect((s.allyGames, s.allyWins, s.allyLosses), (1, 1, 0));
    expect((s.enemyGames, s.enemyWins, s.enemyLosses), (1, 1, 0));
  });
}
