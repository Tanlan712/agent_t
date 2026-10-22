import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_shop_tracker/logic/live_mapper.dart';
import 'package:valorant_shop_tracker/models/account_progress.dart';
import 'package:valorant_shop_tracker/providers/remote_actions.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/remote_client.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../live_fixtures.dart';
import '../remote_fixtures.dart';
import '../riot_fixtures.dart';

void main() {
  late List<http.Request> requests;
  late bool allowed;

  Future<(RemoteActions, RemoteClient, RiotProvider)> setup() async {
    requests = [];
    allowed = true;
    final rc = RiotClient(client: remoteHttp(requests));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final c = RemoteClient(rc, allowed: () => allowed);
    return (RemoteActions(c, riot), c, riot);
  }

  String line(http.Request r) =>
      '${r.method} ${r.url.host.split('.').first}${r.url.path}'
      '${r.url.hasQuery ? '?${r.url.query}' : ''}';

  test('逃跑與離開對局', () async {
    final (a, _, _) = await setup();
    expect(await a.quitPregame('pre-1'), isTrue);
    expect(await a.leaveCoreGame('core-1'), isTrue);
    expect(requests.map(line), [
      'POST glz-ap-1/pregame/v1/matches/pre-1/quit',
      'POST glz-ap-1/core-game/v1/players/puuid-1/disassociate/core-1',
    ]);
  });

  test('邀請：名稱與標籤分開並編碼；格式不對時不送出', () async {
    final (a, _, _) = await setup();
    expect(await a.invite('party-1', 'no tag'), isFalse);
    expect(a.error, contains('名稱#標籤'));
    expect(requests, isEmpty);
    expect(await a.invite('party-1', 'A B#TW 1'), isTrue);
    expect(requests.single.url.path,
        '/parties/v1/parties/party-1/invites/name/A%20B/tag/TW%201');
  });

  test('踢人用 DELETE，不能踢自己', () async {
    final (a, _, _) = await setup();
    expect(await a.kick('puuid-1'), isFalse);
    expect(await a.kick('mate'), isTrue);
    expect(requests.map(line), ['DELETE glz-ap-1/parties/v1/players/mate']);
    expect(requests.single.body, isEmpty);
  });

  test('自訂對戰：建立、換地圖（保留其他設定）、換隊、開始、回到一般', () async {
    final (a, _, _) = await setup();
    await a.makeCustomGame('party-1');
    await a.setCustomMap(
        'party-1',
        {'Map': '/Game/Maps/Ascent/Ascent', 'Mode': 'bomb', 'UseBots': false},
        '/Game/Maps/Bonsai/Bonsai');
    await a.setCustomTeam('party-1', 'TeamTwo', 'mate');
    await a.startCustomGame('party-1');
    await a.makeDefault('party-1', 'unrated');
    expect(requests.map(line), [
      'POST glz-ap-1/parties/v1/parties/party-1/makecustomgame',
      'POST glz-ap-1/parties/v1/parties/party-1/customgamesettings',
      'POST glz-ap-1/parties/v1/parties/party-1/customgamemembership/TeamTwo',
      'POST glz-ap-1/parties/v1/parties/party-1/startcustomgame',
      'POST glz-ap-1/parties/v1/parties/party-1/makedefault?queueID=unrated',
    ]);
    expect(jsonDecode(requests[1].body), {
      'Map': '/Game/Maps/Bonsai/Bonsai',
      'Mode': 'bomb',
      'UseBots': false,
    });
    expect(jsonDecode(requests[2].body), {'playerToPutOnTeam': 'mate'});
  });

  test('啟用特務合約：POST 到 pd', () async {
    final (a, _, _) = await setup();
    expect(await a.activateContract('c-1'), isTrue);
    expect(requests.map(line),
        ['POST pd/contracts/v1/contracts/puuid-1/special/c-1']);
  });

  test('未同意時新的動作也不送出', () async {
    final (a, _, _) = await setup();
    allowed = false;
    for (final call in [
      () => a.quitPregame('m'),
      () => a.leaveCoreGame('m'),
      () => a.invite('p', 'a#b'),
      () => a.kick('mate'),
      () => a.makeCustomGame('p'),
      () => a.setCustomMap('p', const {}, 'x'),
      () => a.setCustomTeam('p', 'TeamOne', 'mate'),
      () => a.startCustomGame('p'),
      () => a.makeDefault('p', 'unrated'),
      () => a.activateContract('c'),
    ]) {
      expect(await call(), isFalse);
    }
    expect(requests, isEmpty);
  });

  test('隊伍資料讀出自訂對戰設定與分隊', () {
    final json = partyJson(state: 'CUSTOM_GAME_SETUP')
      ..['CustomGameData'] = {
        'Settings': {'Map': '/Game/Maps/Ascent/Ascent', 'Mode': 'bomb'},
        'Membership': {
          'teamOne': [
            {'Subject': 'puuid-1'}
          ],
          'teamTwo': [
            {'Subject': 'mate'}
          ],
          'teamSpectate': null,
        },
      };
    final p = mapParty(json, 'puuid-1');
    expect(p.isCustomGame, isTrue);
    expect(p.customSettings?['Map'], '/Game/Maps/Ascent/Ascent');
    expect(p.customTeams, {'puuid-1': 'TeamOne', 'mate': 'TeamTwo'});
  });

  test('合約資料讀出目前啟用的特務合約', () {
    final c = ContractsSnapshot.fromJson(
        {'Contracts': [], 'ActiveSpecialContract': 'C-1'});
    expect(c.activeSpecialContract, 'c-1');
    expect(ContractsSnapshot.fromJson(const {}).activeSpecialContract, isNull);
  });
}
