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
      {Object? body,
      Map<String, String>? query,
      String method = 'POST',
      required String label}) async {
    _check();
    return _riot.sendRemote(s, method, 'glz', path,
        body: body, query: query, label: label);
  }

  String _loadoutPath(RiotSession s) =>
      '/personalization/v3/players/${s.puuid}/playerloadout';

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

  /// 離開選角（等同逃跑，Riot 會給懲罰）。
  Future<void> quitPregame(RiotSession s, String matchId) =>
      _glz(s, '/pregame/v1/matches/$matchId/quit', label: '離開選角');

  /// 離開進行中的對局（Riot 會給懲罰）。
  Future<void> leaveCoreGame(RiotSession s, String matchId) => _glz(
      s, '/core-game/v1/players/${s.puuid}/disassociate/$matchId',
      label: '離開對局');

  /// 用 Riot ID 邀請玩家加入自己的隊伍。
  Future<void> invite(
          RiotSession s, String partyId, String name, String tag) =>
      _glz(
          s,
          // Uri.https 會自動編碼路徑（空白等），這裡不再編碼一次。
          '/parties/v1/parties/$partyId/invites/name/$name/tag/$tag',
          label: '邀請玩家');

  /// 隊長把成員移出隊伍。
  Future<void> kick(RiotSession s, String puuid) =>
      _glz(s, '/parties/v1/players/$puuid', method: 'DELETE', label: '踢出成員');

  Future<void> makeCustomGame(RiotSession s, String partyId) => _glz(
      s, '/parties/v1/parties/$partyId/makecustomgame',
      label: '建立自訂對戰');

  /// 自訂對戰設定：整份 `Settings`（Map、Mode、UseBots、GamePod、GameRules）。
  Future<void> setCustomGameSettings(
          RiotSession s, String partyId, Map<String, dynamic> settings) =>
      _glz(s, '/parties/v1/parties/$partyId/customgamesettings',
          body: settings, label: '變更自訂對戰設定');

  /// 把成員換到自訂對戰的隊伍（`TeamOne`、`TeamTwo`、`TeamSpectate`）。
  Future<void> setCustomTeam(
          RiotSession s, String partyId, String team, String puuid) =>
      _glz(s, '/parties/v1/parties/$partyId/customgamemembership/$team',
          body: {'playerToPutOnTeam': puuid}, label: '換隊');

  Future<void> startCustomGame(RiotSession s, String partyId) => _glz(
      s, '/parties/v1/parties/$partyId/startcustomgame',
      label: '開始自訂對戰');

  /// 從自訂對戰回到一般隊伍（指定模式）。
  Future<void> makeDefault(RiotSession s, String partyId, String queueId) =>
      _glz(s, '/parties/v1/parties/$partyId/makedefault',
          query: {'queueID': queueId}, label: '回到一般模式');

  /// 啟用特務合約（自己的合約）。
  Future<void> activateContract(RiotSession s, String contractId) async {
    _check();
    await _riot.sendRemote(
        s, 'POST', 'pd', '/contracts/v1/contracts/${s.puuid}/special/$contractId',
        label: '啟用合約');
  }
}
