import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/live_mapper.dart';

import '../live_fixtures.dart';
import '../match_fixtures.dart';

void main() {
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
