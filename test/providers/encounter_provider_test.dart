import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/logic/match_mapper.dart';
import 'package:agent_t/models/match_models.dart';
import 'package:agent_t/providers/encounter_provider.dart';
import 'package:agent_t/storage/encounter_storage.dart';

import '../match_fixtures.dart';

void main() {
  late SharedPreferences prefs;
  final t0 = DateTime.fromMillisecondsSinceEpoch(1760900000000);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  EncounterProvider make({int maxPlayers = 1000, int maxPerPlayer = 5}) =>
      EncounterProvider(EncounterStorage(prefs),
          maxPlayers: maxPlayers, maxPerPlayer: maxPerPlayer);

  MatchDetail matchAt(int hours, String id, {String self = myPuuid}) {
    final m = matchDetailsJson();
    final info = m['matchInfo'] as Map<String, dynamic>;
    info['matchId'] = id;
    info['gameStartMillis'] =
        t0.add(Duration(hours: hours)).millisecondsSinceEpoch;
    if (self != myPuuid) {
      for (final p in (m['players'] as List).cast<Map<String, dynamic>>()) {
        if (p['subject'] == myPuuid) p['subject'] = self;
      }
    }
    return mapMatchDetail(m, self);
  }

  test('同一場重複記錄只算一次；由新到舊；保存後重新讀回', () async {
    final p = make();
    await p.recordAll([matchAt(0, 'm1'), matchAt(1, 'm2')]);
    await p.recordAll([matchAt(0, 'm1')]);
    expect(p.withPlayer(myPuuid, 'r1').map((e) => e.matchId), ['m2', 'm1']);
    final again = make();
    expect(again.withPlayer(myPuuid, 'r1').map((e) => e.matchId), ['m2', 'm1']);
    expect(again.withPlayer(myPuuid, 'r1').first.won, isTrue);
  });

  test('排除正在進行的場次', () async {
    final p = make();
    await p.recordAll([matchAt(0, 'm1')]);
    expect(p.withPlayer(myPuuid, 'r1', exclude: 'm1'), isEmpty);
  });

  test('每位玩家只留最近幾場；更舊的場次不會被加回去', () async {
    final p = make(maxPerPlayer: 2);
    await p.recordAll([matchAt(1, 'm1'), matchAt(2, 'm2'), matchAt(3, 'm3')]);
    expect(p.withPlayer(myPuuid, 'r1').map((e) => e.matchId), ['m3', 'm2']);
    var notified = 0;
    p.addListener(() => notified++);
    await p.recordAll([matchAt(0, 'm0')]);
    expect(notified, 0);
  });

  test('各帳號分開記錄', () async {
    final p = make();
    await p.recordAll([matchAt(0, 'm1'), matchAt(1, 'm2', self: 'alt')]);
    expect(p.withPlayer(myPuuid, 'r1').map((e) => e.matchId), ['m1']);
    expect(p.withPlayer('alt', 'r1').map((e) => e.matchId), ['m2']);
  });

  test('超過玩家上限時保留最近遇到的', () async {
    final p = make(maxPlayers: 9);
    await p.recordAll([matchAt(0, 'm1')]);
    final d = matchAt(1, 'm2');
    // 只換掉一位對手：r5 → new1。
    final renamed = MatchDetail(summary: d.summary, teams: {
      for (final t in d.teams.entries)
        t.key: [
          for (final l in t.value)
            l.puuid == 'r5'
                ? PlayerLine(
                    puuid: 'new1',
                    riotId: l.riotId,
                    teamId: l.teamId,
                    partyId: l.partyId,
                    agentId: l.agentId,
                    tier: l.tier,
                    accountLevel: l.accountLevel,
                    kills: l.kills,
                    deaths: l.deaths,
                    assists: l.assists,
                    score: l.score,
                    acs: l.acs,
                    headshotPercent: l.headshotPercent,
                    isMe: l.isMe)
                : l,
        ],
    });
    await p.recordAll([renamed]);
    expect(p.withPlayer(myPuuid, 'new1'), isNotEmpty);
    expect(p.withPlayer(myPuuid, 'r5'), isEmpty);
  });

  test('清除', () async {
    final p = make();
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    await p.clear();
    expect(p.withPlayer(myPuuid, 'r1'), isEmpty);
    expect(make().withPlayer(myPuuid, 'r1'), isEmpty);
  });
}
