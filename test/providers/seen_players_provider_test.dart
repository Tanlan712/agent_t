import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/logic/match_mapper.dart';
import 'package:agent_t/providers/seen_players_provider.dart';
import 'package:agent_t/storage/seen_players_storage.dart';

import '../match_fixtures.dart';

void main() {
  group('舊資料轉移', migrationTests);
  late SharedPreferences prefs;
  // fixture 的 gameStartMillis。
  final t0 = DateTime.fromMillisecondsSinceEpoch(1760900000000);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  SeenPlayersProvider make({int max = 500}) =>
      SeenPlayersProvider(SeenPlayersStorage(prefs), max: max);

  /// 在 [at] 開始的場次 [id]；[edit] 可修改原始 JSON。
  Map<String, dynamic> matchAt(DateTime at, String id,
      [void Function(Map<String, dynamic>)? edit]) {
    final m = matchDetailsJson();
    final info = m['matchInfo'] as Map<String, dynamic>;
    info['matchId'] = id;
    info['gameStartMillis'] = at.millisecondsSinceEpoch;
    edit?.call(m);
    return m;
  }

  test('記錄同場其他 9 位玩家（不含自己與觀戰者），時間是那場的開始時間', () async {
    final p = make();
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    final ids = p.players.map((e) => e.puuid).toSet();
    expect(ids.length, 9);
    expect(ids.contains(myPuuid), isFalse);
    expect(ids.contains('obs'), isFalse);
    final r1 = p.players.singleWhere((e) => e.puuid == 'r1');
    expect(r1.riotId, 'Foxtrot#TW1');
    expect(r1.lastSeen, t0);
    expect(r1.matchId, 'm1');
  });

  test('較新的場次更新名稱與時間；未知名稱不覆蓋已知名稱', () async {
    final p = make();
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    final t1 = t0.add(const Duration(hours: 1));
    final renamed = applyNames(
        mapMatchDetail(matchAt(t1, 'm2'), myPuuid), {'mate': 'Renamed#TW2'});
    final blank = matchAt(t1, 'm3', (m) {
      for (final pl in (m['players'] as List).cast<Map<String, dynamic>>()) {
        if (pl['subject'] == 'r1' || pl['subject'] == 'mate') {
          pl['gameName'] = '';
        }
      }
    });
    await p.recordAll([renamed, mapMatchDetail(blank, myPuuid)]);
    expect(p.players.first.lastSeen, t1);
    final mate = p.players.singleWhere((e) => e.puuid == 'mate');
    expect(mate.riotId, 'Renamed#TW2');
    expect(p.players.singleWhere((e) => e.puuid == 'r1').riotId, 'Foxtrot#TW1');
    expect(p.players.length, 9);
  });

  test('之後才載入的較舊場次不會覆蓋較新的時間與名稱', () async {
    final p = make();
    final t1 = t0.add(const Duration(days: 1));
    await p.recordAll([
      applyNames(
          mapMatchDetail(matchAt(t1, 'new'), myPuuid), {'mate': 'Newer#TW2'})
    ]);
    await p.recordAll([mapMatchDetail(matchAt(t0, 'old'), myPuuid)]);
    final mate = p.players.singleWhere((e) => e.puuid == 'mate');
    expect(mate.lastSeen, t1);
    expect(mate.matchId, 'new');
    expect(mate.riotId, 'Newer#TW2');
  });

  test('依最後遇到時間排序，超過上限刪掉最舊的', () async {
    final p = make(max: 9);
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    final other = matchAt(t0.add(const Duration(minutes: 40)), 'm2', (m) {
      (m['players'] as List).removeWhere((pl) => pl['subject'] == 'r4');
      (m['players'] as List).add({
        'subject': 'new1',
        'gameName': 'Newbie',
        'tagLine': 'TW1',
        'teamId': 'Red',
        'stats': {'score': 100, 'roundsPlayed': 22},
      });
    });
    await p.recordAll([mapMatchDetail(other, myPuuid)]);
    expect(p.players.length, 9);
    expect(p.players.first.lastSeen, t0.add(const Duration(minutes: 40)));
    expect(p.players.any((e) => e.puuid == 'new1'), isTrue);
    expect(p.players.any((e) => e.puuid == 'r4'), isFalse);
  });

  test('寫入 localStorage，重新建立後仍在', () async {
    await make().recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    expect(make().players.length, 9);
  });

  test('刪除單筆與全部清除', () async {
    final p = make();
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    await p.remove('r1');
    expect(p.players.any((e) => e.puuid == 'r1'), isFalse);
    expect(make().players.length, 8);
    await p.clear();
    expect(p.players, isEmpty);
    expect(make().players, isEmpty);
  });

  test('搜尋 Riot ID 不分大小寫', () async {
    final p = make();
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    expect(p.search('fox').map((e) => e.puuid), ['r1']);
    expect(p.search('').length, 9);
  });
}

void migrationTests() {
  test('舊格式（載入時間）轉成時間未知，下次遇到改用場次時間', () async {
    SharedPreferences.setMockInitialValues({
      'seen_players':
          '[{"puuid":"r1","riotId":"Foxtrot#TW1","lastSeen":"2026-10-21T01:01:00.000","matchId":"m9"}]',
    });
    final prefs = await SharedPreferences.getInstance();
    final p = SeenPlayersProvider(SeenPlayersStorage(prefs));
    expect(p.players.single.riotId, 'Foxtrot#TW1');
    expect(p.players.single.lastSeenKnown, isFalse);
    // 新 key 寫入完成後才移除舊 key。
    await pumpEventQueue();
    expect(prefs.getString('seen_players'), isNull);
    expect(prefs.getString('seen_players_v2'), isNotNull);
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    final r1 = p.players.singleWhere((e) => e.puuid == 'r1');
    expect(r1.lastSeenKnown, isTrue);
    expect(r1.lastSeen, DateTime.fromMillisecondsSinceEpoch(1760900000000));
  });
}
