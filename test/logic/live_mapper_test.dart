import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/live_mapper.dart';
import 'package:agent_t/models/live_models.dart';

import '../live_fixtures.dart';
import '../match_fixtures.dart';

void main() {
  group('造型', loadoutTests);
  group('選角', pregameTests);
  group('對局', coreGameTests);
  group('玩家卡', cardUrlTests);
  test('隊伍欄位與成員，自己排第一', () {
    final p = mapParty(partyJson(), myPuuid);
    expect(p.id, testPartyId);
    expect(p.state, 'DEFAULT');
    expect(p.queueId, 'unrated');
    expect(p.isOpen, isFalse);
    expect(p.members.map((m) => m.puuid).toList(),
        [myPuuid, 'mate', 'ghost', 'shy']);
    final me = p.members.first;
    expect(me.isMe, isTrue);
    expect(me.isOwner, isTrue);
    expect(me.tier, 15);
    expect(me.cardId, 'card-$myPuuid');
    expect(me.level, 100);
  });

  test('隱私開關', () {
    final p = mapParty(partyJson(), myPuuid);
    final ghost = p.members.singleWhere((m) => m.puuid == 'ghost');
    final shy = p.members.singleWhere((m) => m.puuid == 'shy');
    expect(ghost.incognito, isTrue);
    expect(ghost.hideLevel, isFalse);
    expect(shy.hideLevel, isTrue);
    expect(shy.isReady, isFalse);
  });

  test('配對中的開始排隊時間；預設值 0001 年視為沒有', () {
    expect(mapParty(partyJson(), myPuuid).queueEntryTime, isNull);
    final p = mapParty(
        partyJson(
            state: 'MATCHMAKING', queueEntryTime: '2026-10-21T10:05:00.000Z'),
        myPuuid);
    expect(p.queueEntryTime, DateTime.utc(2026, 10, 21, 10, 5));
  });

  test('缺少欄位時不崩潰', () {
    final p = mapParty({
      'ID': 'x',
      'Members': [
        {'Subject': 'a'},
      ],
    }, myPuuid);
    expect(p.members.single.puuid, 'a');
    expect(p.members.single.incognito, isFalse);
    expect(p.members.single.cardId, isNull);
    expect(p.queueId, '');
    expect(p.isOpen, isFalse);
  });

  test('隊伍狀態文字', () {
    expect(partyStateLabel('DEFAULT'), '大廳');
    expect(partyStateLabel('MATCHMAKING'), '配對中');
    expect(partyStateLabel('MATCHMADE_GAME_STARTING'), '對戰即將開始');
    expect(partyStateLabel('CUSTOM_GAME_SETUP'), '自訂對戰設定');
    expect(partyStateLabel('SOMETHING_NEW'), 'SOMETHING_NEW');
  });
}

void cardUrlTests() {
  test('玩家卡圖片網址；沒有 ID 時為 null', () {
    expect(playerCardUrl('abc'),
        'https://media.valorant-api.com/playercards/abc/smallart.png');
    expect(playerCardUrl(null), isNull);
    expect(playerCardUrl(''), isNull);
  });
}

void coreGameTests() {
  test('對局：地圖、模式、雙方隊伍，我方在前', () {
    final m = mapCoreGame(coreMatchJson(), myPuuid);
    expect(m.matchId, testCoreMatchId);
    expect(m.state, 'IN_PROGRESS');
    expect(m.mapId, '/Game/Maps/Ascent/Ascent');
    expect(m.queueId, 'competitive');
    expect(m.myTeamId, 'Blue');
    expect(m.teamIds, ['Blue', 'Red']);
    final blue = m.team('Blue');
    expect(blue.first.puuid, myPuuid);
    expect(blue.length, 5);
    expect(m.team('Red').length, 6);
    expect(m.seasonId, 'season-1');
  });

  test('對局玩家欄位：特務、牌位、等級、隱藏名稱、教練', () {
    final m = mapCoreGame(coreMatchJson(), myPuuid);
    final r1 = m.players.singleWhere((p) => p.puuid == 'r1');
    expect(r1.agentId, 'agent-r1');
    expect(r1.tier, 18);
    expect(r1.level, 50);
    expect(r1.seasonWins, 3);
    expect(r1.isMe, isFalse);
    expect(m.players.singleWhere((p) => p.puuid == 'r2').incognito, isTrue);
    expect(m.players.singleWhere((p) => p.puuid == 'coach').isCoach, isTrue);
  });

  test('缺少欄位時不崩潰', () {
    final m = mapCoreGame({'MatchID': 'x'}, myPuuid);
    expect(m.players, isEmpty);
    expect(m.myTeamId, '');
    expect(m.teamIds, isEmpty);
  });
}

void pregameTests() {
  test('選角：地圖、佇列、剩餘時間、敵方人數與鎖定數', () {
    final p = mapPregame(pregameMatchJson(), myPuuid);
    expect(p.matchId, testPregameMatchId);
    expect(p.mapId, '/Game/Maps/Ascent/Ascent');
    expect(p.queueId, 'competitive');
    expect(p.remaining, const Duration(seconds: 53, microseconds: 255044));
    expect(p.enemySize, 5);
    expect(p.enemyLocked, 2);
    expect(p.seasonId, 'season-1');
  });

  test('我方成員：自己排第一，特務、選角狀態、牌位、等級', () {
    final p = mapPregame(pregameMatchJson(), myPuuid);
    expect(p.allies.map((a) => a.puuid).toList(),
        [myPuuid, 'mate', 'b3', 'b4', 'b5']);
    final mate = p.allies.singleWhere((a) => a.puuid == 'mate');
    expect(mate.agentId, 'agent-mate');
    expect(mate.selection, AgentSelection.locked);
    expect(mate.tier, 18);
    expect(p.allies.first.selection, AgentSelection.selected);
    final b3 = p.allies.singleWhere((a) => a.puuid == 'b3');
    expect(b3.selection, AgentSelection.none);
    expect(b3.agentId, '');
    expect(b3.level, 40);
    expect(b3.seasonWins, 0);
  });

  test('缺少欄位時不崩潰', () {
    final p = mapPregame({'ID': 'x', 'EnemyTeam': null}, myPuuid);
    expect(p.allies, isEmpty);
    expect(p.enemySize, 0);
    expect(p.remaining, Duration.zero);
  });
}

void loadoutTests() {
  test('loadouts：每位玩家的武器 → 造型 ID（小寫）', () {
    final l = mapLoadouts(coreLoadoutsJson());
    expect(l['mate']![vandalId], 'p');
    expect(l['mate']![operatorId], 'standard-operator');
    expect(l['mate']!.length, 6);
    expect(l[myPuuid]![vandalId], 'standard-vandal');
  });

  test('主要武器依序為 Vandal、Phantom、Operator、Sheriff、近戰', () {
    expect(
        mainWeaponIds, [vandalId, phantomId, operatorId, sheriffId, meleeId]);
  });

  test('缺少欄位時不崩潰', () {
    expect(mapLoadouts({}), isEmpty);
    expect(
        mapLoadouts({
          'Loadouts': [
            {'Subject': 'a'},
          ],
        })['a'],
        isEmpty);
  });

  test('伺服器名稱：取 -gp- 後的城市，第 2 台以上加編號', () {
    expect(serverName('aresriot.aws-rclusterprod-ape1-1.ap-gp-hongkong-1'),
        '香港');
    expect(serverName('aresriot.aws-rclusterprod-apne1-1.ap-gp-tokyo-2'),
        '東京 2');
    expect(serverName('aresriot.aws-x.na-gp-unknowncity-1'), 'unknowncity');
  });
}
