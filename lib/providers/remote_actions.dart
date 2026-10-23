import 'package:flutter/foundation.dart';

import '../logic/custom_game.dart';
import '../models/riot_session.dart';
import '../services/remote_client.dart';
import '../services/riot_client.dart';
import 'riot_provider.dart';

/// 即時對局頁的遠端操作（選角、隊伍）。每次都由使用者按下按鈕觸發，
/// 同時只送一個寫入、失敗不重試（規格 2026-10-22-remote-control-design.md）。
class RemoteActions with ChangeNotifier {
  final RemoteClient _client;
  final RiotProvider _riot;

  bool _busy = false;
  String? _error;
  String? _inviteCode;
  String? _inviteCodeParty;
  bool _disposed = false;

  RemoteActions(this._client, this._riot);

  bool get busy => _busy;

  /// 上一個動作的錯誤；成功後清除。
  String? get error => _error;

  /// [partyId] 的隊伍代碼；還沒取得或換了隊伍時為 null。
  String? inviteCode(String partyId) =>
      _inviteCodeParty == partyId ? _inviteCode : null;

  Future<bool> selectAgent(String matchId, String agentId) =>
      _run((s) => _client.selectAgent(s, matchId, agentId));

  Future<bool> lockAgent(String matchId, String agentId) =>
      _run((s) => _client.lockAgent(s, matchId, agentId));

  Future<bool> setReady(String partyId, bool ready) =>
      _run((s) => _client.setReady(s, partyId, ready));

  Future<bool> fetchInviteCode(String partyId) => _run((s) async {
        final code = await _client.generateInviteCode(s, partyId);
        if (code == null) throw RiotApiException(null, '取得隊伍代碼：回應沒有代碼');
        _inviteCode = code;
        _inviteCodeParty = partyId;
      });

  Future<bool> joinQueue(String partyId) =>
      _run((s) => _client.joinQueue(s, partyId));

  Future<bool> leaveQueue(String partyId) =>
      _run((s) => _client.leaveQueue(s, partyId));

  Future<bool> changeQueue(String partyId, String queueId) =>
      _run((s) => _client.changeQueue(s, partyId, queueId));

  Future<bool> setAccessibility(String partyId, bool open) =>
      _run((s) => _client.setAccessibility(s, partyId, open));

  /// 逃跑：離開選角（畫面上先確認）。
  Future<bool> quitPregame(String matchId) =>
      _run((s) => _client.quitPregame(s, matchId));

  /// 離開進行中的對局（畫面上先確認）。
  Future<bool> leaveCoreGame(String matchId) =>
      _run((s) => _client.leaveCoreGame(s, matchId));

  /// 用「名稱#標籤」邀請玩家；格式不對時不送出。
  Future<bool> invite(String partyId, String riotId) {
    final i = riotId.lastIndexOf('#');
    final name = i < 0 ? '' : riotId.substring(0, i).trim();
    final tag = i < 0 ? '' : riotId.substring(i + 1).trim();
    if (name.isEmpty || tag.isEmpty) {
      _error = '請輸入「名稱#標籤」';
      _notify();
      return Future.value(false);
    }
    return _run((s) => _client.invite(s, partyId, name, tag));
  }

  /// 隊長把成員移出隊伍；不能踢自己。
  Future<bool> kick(String puuid) {
    if (puuid == _riot.session?.puuid) return Future.value(false);
    return _run((s) => _client.kick(s, puuid));
  }

  Future<bool> makeCustomGame(String partyId) =>
      _run((s) => _client.makeCustomGame(s, partyId));

  /// 寫回整份自訂對戰設定（地圖、模式、伺服器、規則；見 logic/custom_game.dart）。
  Future<bool> setCustomSettings(
          String partyId, Map<String, dynamic> settings) =>
      _run((s) => _client.setCustomGameSettings(s, partyId, settings));

  /// 換自訂對戰的地圖：其他設定原樣帶回。
  Future<bool> setCustomMap(
          String partyId, Map<String, dynamic> settings, String mapId) =>
      setCustomSettings(partyId, withCustomSetting(settings, 'Map', mapId));

  /// 自訂對戰可用的選項；還沒讀到或讀取失敗時為 null。
  CustomGameConfig? get customConfig => _customConfig;
  CustomGameConfig? _customConfig;
  bool _configRequested = false;

  /// 頁面開著時只讀一次自訂對戰選項（GET）；失敗也不重送，畫面改用預設清單。
  Future<void> loadCustomConfig() async {
    final s = _riot.session;
    if (_configRequested || s == null) return;
    _configRequested = true;
    try {
      _customConfig = await _client.fetchCustomGameConfigs(s);
      _notify();
    } on RemoteDisabledException {
      // 未同意時不讀。
    } on RiotApiException catch (e) {
      if (e.isAuthError) _riot.expire();
    }
  }

  Future<bool> setCustomTeam(String partyId, String team, String puuid) =>
      _run((s) => _client.setCustomTeam(s, partyId, team, puuid));

  Future<bool> startCustomGame(String partyId) =>
      _run((s) => _client.startCustomGame(s, partyId));

  Future<bool> makeDefault(String partyId, String queueId) =>
      _run((s) => _client.makeDefault(s, partyId, queueId));

  Future<bool> activateContract(String contractId) =>
      _run((s) => _client.activateContract(s, contractId));

  Future<bool> _run(Future<void> Function(RiotSession) action) async {
    final s = _riot.session;
    if (_busy || s == null || !_riot.isLoggedIn) return false;
    _busy = true;
    _error = null;
    _notify();
    try {
      await action(s);
      return true;
    } on RemoteDisabledException catch (e) {
      _error = e.toString();
    } on RiotApiException catch (e) {
      // AGENTS.md 第 4 節：授權失敗時刪除登入資訊，提示重新登入。
      if (e.isAuthError) _riot.expire();
      _error = e.message;
    } finally {
      _busy = false;
      _notify();
    }
    return false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
