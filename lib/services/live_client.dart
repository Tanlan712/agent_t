import '../models/riot_session.dart';
import 'riot_client.dart';

/// 即時對局（glz）的讀取端點；只有 GET，欄位見 docs/api-fields.md。
class LiveClient {
  final RiotClient _riot;

  LiveClient(this._riot);

  /// 目前隊伍 ID；遊戲沒開或不在大廳（404）時回傳 null。
  Future<String?> fetchPartyId(RiotSession s) async {
    try {
      final json = await _riot.getGlz(s, '/parties/v1/players/${s.puuid}',
          label: '取得隊伍');
      return json['CurrentPartyID'] as String?;
    } on RiotApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> fetchParty(RiotSession s, String partyId) =>
      _riot.getGlz(s, '/parties/v1/parties/$partyId', label: '取得隊伍');

  /// 對局中的場次 ID；不在對局（404）時回傳 null。
  Future<String?> fetchCoreMatchId(RiotSession s) =>
      _matchId(s, '/core-game/v1/players/${s.puuid}', '取得對局');

  Future<Map<String, dynamic>> fetchCoreMatch(RiotSession s, String matchId) =>
      _riot.getGlz(s, '/core-game/v1/matches/$matchId', label: '取得對局');

  /// 選角中的場次 ID；不在選角（404）時回傳 null。
  Future<String?> fetchPregameMatchId(RiotSession s) =>
      _matchId(s, '/pregame/v1/players/${s.puuid}', '取得選角');

  Future<Map<String, dynamic>> fetchPregameMatch(
          RiotSession s, String matchId) =>
      _riot.getGlz(s, '/pregame/v1/matches/$matchId', label: '取得選角');

  Future<String?> _matchId(RiotSession s, String path, String label) async {
    try {
      final json = await _riot.getGlz(s, path, label: label);
      return json['MatchID'] as String?;
    } on RiotApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
