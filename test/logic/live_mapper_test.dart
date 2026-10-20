import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/live_mapper.dart';

import '../live_fixtures.dart';
import '../match_fixtures.dart';

void main() {
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
