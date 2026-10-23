import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/logic/loadout_logic.dart';
import 'package:agent_t/models/app_settings.dart';
import 'package:agent_t/providers/loadout_provider.dart';
import 'package:agent_t/providers/remote_actions.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/providers/settings_provider.dart';
import 'package:agent_t/services/remote_client.dart';
import 'package:agent_t/services/riot_client.dart';
import 'package:agent_t/storage/settings_storage.dart';

import '../remote_fixtures.dart';
import '../riot_fixtures.dart';

void main() {
  late List<http.Request> requests;
  late bool allowed;

  Future<(RemoteClient, RiotProvider)> setup(
      {Map<String, int> status = const {}}) async {
    requests = [];
    allowed = true;
    final rc = RiotClient(client: remoteHttp(requests, status: status));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    return (RemoteClient(rc, allowed: () => allowed), riot);
  }

  group('AppSettings 遠端欄位', () {
    test('預設未同意', () {
      const s = AppSettings();
      expect(s.remoteControl, isFalse);
      expect(s.remoteControlSince, isNull);
      expect(s.preferredAgent, isNull);
      expect(AppSettings.fromJson(const {}).remoteControl, isFalse);
    });

    test('JSON 來回一致；只有明確的 true 才算同意', () {
      final s = const AppSettings().withRemote(
          enabled: true, since: '2026-10-22T10:00:00', preferredAgent: 'a');
      final r = AppSettings.fromJson(s.toJson());
      expect(r.remoteControl, isTrue);
      expect(r.remoteControlSince, '2026-10-22T10:00:00');
      expect(r.preferredAgent, 'a');
      final bad = AppSettings.fromJson(
          {'remoteControl': 'true', 'preferredAgent': 'a'});
      expect(bad.remoteControl, isFalse);
      expect(bad.preferredAgent, isNull);
    });

    test('copyWith 保留遠端欄位', () {
      final s = const AppSettings()
          .withRemote(enabled: true, since: 'x', preferredAgent: 'a')
          .copyWith(resetHour: 9);
      expect(s.remoteControl, isTrue);
      expect(s.preferredAgent, 'a');
    });
  });

  group('SettingsProvider 遠端操作', () {
    late SharedPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('同意時記下時間；撤回時清除時間與預選特務', () async {
      final p = SettingsProvider(SettingsStorage(prefs));
      await p.setRemoteControl(true, now: DateTime(2026, 10, 22, 18));
      await p.setPreferredAgent('AGENT-A');
      expect(SettingsStorage(prefs).load().remoteControl, isTrue);
      expect(p.settings.remoteControlSince, '2026-10-22T18:00:00.000');
      expect(p.settings.preferredAgent, 'agent-a');
      await p.setRemoteControl(false);
      final loaded = SettingsStorage(prefs).load();
      expect(loaded.remoteControl, isFalse);
      expect(loaded.remoteControlSince, isNull);
      expect(loaded.preferredAgent, isNull);
    });

    test('未同意時不能預選特務', () async {
      final p = SettingsProvider(SettingsStorage(prefs));
      await p.setPreferredAgent('agent-a');
      expect(p.settings.preferredAgent, isNull);
    });
  });

  group('RemoteActions', () {
    test('成功時回傳 true；隊伍代碼依隊伍保存', () async {
      final (c, riot) = await setup();
      final a = RemoteActions(c, riot);
      expect(await a.fetchInviteCode('party-1'), isTrue);
      expect(a.inviteCode('party-1'), 'ABC123');
      expect(a.inviteCode('party-2'), isNull);
      expect(await a.lockAgent('pre-1', 'agent-a'), isTrue);
      expect(a.error, isNull);
      expect(a.busy, isFalse);
    });

    test('失敗時顯示錯誤、不重試', () async {
      final (c, riot) = await setup(status: {'/matchmaking/join': 429});
      final a = RemoteActions(c, riot);
      expect(await a.joinQueue('party-1'), isFalse);
      expect(requests.length, 1);
      expect(a.error, contains('429'));
      expect(riot.isLoggedIn, isTrue);
    });

    test('401 時登入過期', () async {
      final (c, riot) = await setup(status: {'/setReady': 401});
      final a = RemoteActions(c, riot);
      expect(await a.setReady('party-1', true), isFalse);
      expect(riot.isLoggedIn, isFalse);
    });

    test('未同意時不送請求並顯示原因', () async {
      final (c, riot) = await setup();
      allowed = false;
      final a = RemoteActions(c, riot);
      expect(await a.leaveQueue('party-1'), isFalse);
      expect(requests, isEmpty);
      expect(a.error, contains('同意'));
    });

    test('上一個動作還沒完成時不送第二個', () async {
      final (c, riot) = await setup();
      final a = RemoteActions(c, riot);
      final first = a.joinQueue('party-1');
      expect(await a.leaveQueue('party-1'), isFalse);
      expect(await first, isTrue);
      expect(requests.length, 1);
    });
  });

  group('LoadoutProvider', () {
    const skin = SkinEquip(
        weaponUuid: 'weapon-v',
        skinUuid: 'skin-v',
        levelUuid: 'lv-2',
        chromas: [ChromaChoice(uuid: 'ch-base')]);

    test('讀取裝備並顯示目前造型', () async {
      final (c, riot) = await setup();
      final p = LoadoutProvider(c, riot);
      await p.load();
      await p.load();
      expect(p.equipped('weapon-v'), 'skin-std');
      expect(requests.length, 1);
    });

    test('裝備：先讀最新的裝備，只改這把槍再寫回', () async {
      final (c, riot) = await setup();
      final p = LoadoutProvider(c, riot);
      expect(await p.equip(skin, 'ch-base'), isTrue);
      expect([for (final r in requests) r.method], ['GET', 'PUT']);
      expect(p.equipped('weapon-v'), 'skin-v');
      expect(p.equipped('weapon-p'), 'skin-p');
    });

    test('寫入失敗時保留錯誤、不重試', () async {
      requests = [];
      final rc = RiotClient(client: remoteHttp(requests));
      final riot = RiotProvider(rc);
      await riot.login(fakeRedirect);
      // 裝備端點回 500：讀取就失敗，也不會重試。
      final failing = RiotClient(
          client: remoteHttp(requests, status: {'/playerloadout': 500}));
      final p =
          LoadoutProvider(RemoteClient(failing, allowed: () => true), riot);
      expect(await p.equip(skin, 'ch-base'), isFalse);
      expect(requests.length, 1);
      expect(p.error, contains('500'));
    });

    test('未同意時不送請求', () async {
      final (c, riot) = await setup();
      allowed = false;
      final p = LoadoutProvider(c, riot);
      await p.load();
      expect(await p.equip(skin, 'ch-base'), isFalse);
      expect(requests, isEmpty);
    });

    test('登出後清除裝備資料', () async {
      final (c, riot) = await setup();
      final p = LoadoutProvider(c, riot);
      await p.load();
      riot.logout();
      expect(p.equipped('weapon-v'), isNull);
    });
  });
}
