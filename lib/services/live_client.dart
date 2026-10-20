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
}
