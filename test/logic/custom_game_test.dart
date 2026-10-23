import 'package:flutter_test/flutter_test.dart';
import 'package:agent_t/logic/custom_game.dart';
import 'package:agent_t/logic/live_mapper.dart';
import 'package:agent_t/models/riot_session.dart';

import '../live_fixtures.dart';
import '../match_fixtures.dart';
import '../remote_fixtures.dart';

RiotSession _session(String region) => RiotSession(
      accessToken: 'a',
      idToken: 'i',
      entitlementsToken: 'e',
      puuid: 'p',
      gameName: 'n',
      tagLine: 't',
      shard: region,
      clientVersion: 'v',
      expiresAt: DateTime.utc(2030),
    );

void main() {
  test('customgameconfigs：地圖、模式、伺服器', () {
    final c = CustomGameConfig.fromJson(customGameConfigsJson());
    expect(c.maps, ['/Game/Maps/Ascent/Ascent', '/Game/Maps/Bonsai/Bonsai']);
    expect(c.modes.length, 2);
    expect(c.pods, [
      'aresriot.aws-rclusterprod-ape1-1.ap-gp-hongkong-1',
      'aresriot.aws-rclusterprod-apne1-1.ap-gp-tokyo-1',
    ]);
    expect(CustomGameConfig.fromJson(const {}).pods, isEmpty);
  });

  test('模式名稱', () {
    expect(customModeName('/Game/GameModes/Bomb/BombGameMode.BombGameMode_C'),
        '標準');
    expect(
        customModeName(
            '/Game/GameModes/QuickBomb/QuickBombGameMode.QuickBombGameMode_C'),
        '超速衝點');
    expect(
        customModeName(
            '/Game/GameModes/Deathmatch/DeathmatchGameMode.DeathmatchGameMode_C'),
        '死鬥');
    expect(customModeName('/Game/GameModes/Mystery/Mystery.Mystery_C'),
        'Mystery');
  });

  test('伺服器名稱', () {
    expect(customPodName('aresriot.aws-rclusterprod-ape1-1.ap-gp-hongkong-1'),
        '香港 1');
    expect(customPodName('aresriot.x.na-gp-moon-2'), 'moon 2');
    expect(customPodName('weird'), 'weird');
  });

  test('規則開關：其他欄位與規則原樣帶回', () {
    final s = {
      'Map': 'm',
      'GameRules': {'TournamentMode': 'true'},
    };
    expect(customRuleOn(s, 'TournamentMode'), isTrue);
    expect(customRuleOn(s, 'PlayOutAllRounds'), isFalse);
    expect(withCustomRule(s, 'PlayOutAllRounds', true), {
      'Map': 'm',
      'GameRules': {'TournamentMode': 'true', 'PlayOutAllRounds': 'true'},
    });
    expect(withCustomRule({'Map': 'm', 'GameRules': null}, 'X', false), {
      'Map': 'm',
      'GameRules': {'X': 'false'},
    });
    expect(withCustomSetting(s, 'Map', 'n')['GameRules'], s['GameRules']);
  });

  test('glz 主機用區域，pd 用 shard（拉丁美洲、巴西走 na）', () {
    expect(_session('ap').pdHost, 'pd.ap.a.pvp.net');
    expect(_session('ap').glzHost, 'glz-ap-1.ap.a.pvp.net');
    expect(_session('latam').pdHost, 'pd.na.a.pvp.net');
    expect(_session('latam').glzHost, 'glz-latam-1.na.a.pvp.net');
    expect(_session('br').glzHost, 'glz-br-1.na.a.pvp.net');
  });

  test('隊伍代碼：空字串視為沒有', () {
    expect(mapParty(partyJson(), myPuuid).inviteCode, isNull);
    expect(
        mapParty(partyJson()..['InviteCode'] = 'AB12', myPuuid).inviteCode,
        'AB12');
  });
}
