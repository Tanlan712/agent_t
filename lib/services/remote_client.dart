import '../models/riot_session.dart';
import 'riot_client.dart';

/// 未同意遠端操作時呼叫寫入方法。
class RemoteDisabledException implements Exception {
  @override
  String toString() => '尚未在設定中同意遠端操作';
}

/// 遠端操作：會改變遊戲或帳號狀態的 pd／glz 端點（規格 2026-10-22-remote-control-design.md）。
/// 每個方法送出前都檢查 [allowed]（設定頁的同意）；未同意時丟出 [RemoteDisabledException]，不發請求。
/// 路徑與內容依社群文件，沒有用真實帳號驗證過。
class RemoteClient {
  final RiotClient _riot;
  final bool Function() allowed;

  RemoteClient(this._riot, {required this.allowed});

  void _check() {
    if (!allowed()) throw RemoteDisabledException();
  }

  Future<Map<String, dynamic>?> _glz(RiotSession s, String path,
      {Object? body, required String label}) async {
    _check();
    return _riot.sendRemote(s, 'POST', 'glz', path, body: body, label: label);
  }

  String _loadoutPath(RiotSession s) =>
      '/personalization/v2/players/${s.puuid}/playerloadout';

  /// 目前的裝備（武器造型、噴漆、名片等）。
  Future<Map<String, dynamic>> fetchLoadout(RiotSession s) async {
    _check();
    return _riot.getPd(s, _loadoutPath(s), label: '取得裝備');
  }

  /// 寫回整份裝備；回傳 Riot 更新後的裝備（沒有內容時為 null）。
  Future<Map<String, dynamic>?> putLoadout(
      RiotSession s, Map<String, dynamic> loadout) async {
    _check();
    return _riot.sendRemote(s, 'PUT', 'pd', _loadoutPath(s),
        body: loadout, label: '設定造型');
  }

  Future<void> selectAgent(RiotSession s, String matchId, String agentId) =>
      _glz(s, '/pregame/v1/matches/$matchId/select/$agentId', label: '選擇特務');

  Future<void> lockAgent(RiotSession s, String matchId, String agentId) =>
      _glz(s, '/pregame/v1/matches/$matchId/lock/$agentId', label: '鎖定特務');

  Future<void> setReady(RiotSession s, String partyId, bool ready) =>
      _glz(s, '/parties/v1/parties/$partyId/members/${s.puuid}/setReady',
          body: {'ready': ready}, label: ready ? '設為準備' : '設為未準備');

  /// 產生隊伍代碼；回應沒有代碼時回傳 null。
  Future<String?> generateInviteCode(RiotSession s, String partyId) async {
    final json = await _glz(s, '/parties/v1/parties/$partyId/invitecode',
        label: '取得隊伍代碼');
    final code = json?['InviteCode'];
    return code is String && code.isNotEmpty ? code : null;
  }

  Future<void> joinQueue(RiotSession s, String partyId) =>
      _glz(s, '/parties/v1/parties/$partyId/matchmaking/join', label: '開始排隊');

  Future<void> leaveQueue(RiotSession s, String partyId) =>
      _glz(s, '/parties/v1/parties/$partyId/matchmaking/leave', label: '取消排隊');

  Future<void> changeQueue(RiotSession s, String partyId, String queueId) =>
      _glz(s, '/parties/v1/parties/$partyId/queue',
          body: {'queueID': queueId}, label: '變更模式');

  Future<void> setAccessibility(RiotSession s, String partyId, bool open) =>
      _glz(s, '/parties/v1/parties/$partyId/accessibility',
          body: {'accessibility': open ? 'OPEN' : 'CLOSED'},
          label: open ? '開放隊伍' : '鎖定隊伍');
}
