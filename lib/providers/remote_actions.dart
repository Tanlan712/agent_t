import 'package:flutter/foundation.dart';

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
