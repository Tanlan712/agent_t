import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/logic/match_mapper.dart';
import 'package:valorant_shop_tracker/providers/seen_players_provider.dart';
import 'package:valorant_shop_tracker/storage/seen_players_storage.dart';

import '../match_fixtures.dart';

void main() {
  late SharedPreferences prefs;
  var clock = DateTime(2026, 10, 20, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    clock = DateTime(2026, 10, 20, 12);
  });

  SeenPlayersProvider make({int max = 500}) =>
      SeenPlayersProvider(SeenPlayersStorage(prefs),
          max: max, now: () => clock);

  test('記錄同場其他 9 位玩家（不含自己與觀戰者）', () async {
    final p = make();
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    final ids = p.players.map((e) => e.puuid).toSet();
    expect(ids.length, 9);
    expect(ids.contains(myPuuid), isFalse);
    expect(ids.contains('obs'), isFalse);
    final r1 = p.players.singleWhere((e) => e.puuid == 'r1');
    expect(r1.riotId, 'Foxtrot#TW1');
    expect(r1.lastSeen, clock);
    expect(r1.matchId, 'm1');
  });

  test('再次遇到時更新名稱與時間並排到最前面；未知名稱不覆蓋已知名稱', () async {
    final p = make();
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    clock = clock.add(const Duration(hours: 1));
    final again = applyNames(
        mapMatchDetail(matchDetailsJson(), myPuuid), {'mate': 'Renamed#TW2'});
    final blank = matchDetailsJson();
    for (final pl in (blank['players'] as List).cast<Map<String, dynamic>>()) {
      if (pl['subject'] == 'r1' || pl['subject'] == 'mate') pl['gameName'] = '';
    }
    await p.recordAll([again, mapMatchDetail(blank, myPuuid)]);
    expect(p.players.first.lastSeen, clock);
    expect(
        p.players.singleWhere((e) => e.puuid == 'mate').riotId, 'Renamed#TW2');
    expect(p.players.singleWhere((e) => e.puuid == 'r1').riotId, 'Foxtrot#TW1');
    expect(p.players.length, 9);
  });

  test('依最後遇到時間排序，超過上限刪掉最舊的', () async {
    final p = make(max: 9);
    await p.recordAll([mapMatchDetail(matchDetailsJson(), myPuuid)]);
    clock = clock.add(const Duration(minutes: 5));
    final other = matchDetailsJson();
    (other['players'] as List).add({
      'subject': 'new1',
      'gameName': 'Newbie',
      'tagLine': 'TW1',
      'teamId': 'Red',
      'stats': {'score': 100, 'roundsPlayed': 22},
    });
    (other['matchInfo'] as Map<String, dynamic>)['matchId'] = 'm2';
    await p.recordAll([mapMatchDetail(other, myPuuid)]);
    expect(p.players.length, 9);
    expect(p.players.any((e) => e.puuid == 'new1'), isTrue);
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
