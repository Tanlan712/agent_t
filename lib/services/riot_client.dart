import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/riot_session.dart';
import 'riot_auth.dart';

class RiotApiException implements Exception {
  final int? statusCode;

  /// 不含任何 token，可直接顯示給使用者。
  final String message;

  RiotApiException(this.statusCode, this.message);

  bool get isAuthError => statusCode == 401 || statusCode == 403;

  @override
  String toString() => 'RiotApiException($statusCode): $message';
}

/// 呼叫 Riot 的登入後端點與 VALORANT 商店（pd）端點。
/// pd 端點為 Riot 未公開的 API，格式依社群文件。
class RiotClient {
  static const _vp = '85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741';
  static const _radianite = 'e59aa87c-4cbf-517a-5983-6e81511be9b7';
  static const _kingdom = '85ca954a-41f2-ce94-9b45-8ca3dd39a00d';
  static const _skinLevelType = 'e7c63390-eda7-46e0-bb7a-a6abdacd2433';

  /// 社群通用的平台描述（PC／Windows）。
  static final _clientPlatform = base64Encode(utf8.encode(jsonEncode({
    'platformType': 'PC',
    'platformOS': 'Windows',
    'platformOSVersion': '10.0.19042.1.256.64bit',
    'platformChipset': 'Unknown',
  })));

  final http.Client _client;

  RiotClient({http.Client? client}) : _client = client ?? http.Client();

  /// 瀏覽器實測：userinfo 與 riot-geo 的實際回應沒有 CORS 標頭會被擋下，
  /// 所以 puuid 從 access_token（JWT）解出，名稱優先取 id_token 的 acct，
  /// 區域偵測失敗時使用 [fallbackShard]。
  Future<RiotSession> createSession(
    RiotTokens tokens,
    DateTime now, {
    String fallbackShard = 'ap',
  }) async {
    final access = _jwtPayload(tokens.accessToken);
    final puuid = access?['sub'] as String?;
    if (puuid == null) throw RiotApiException(null, '登入資訊格式不符');
    final bearer = {'Authorization': 'Bearer ${tokens.accessToken}'};

    final ent = await _json(
        '取得授權',
        () => _client.post(
              Uri.https('entitlements.auth.riotgames.com', '/api/token/v1'),
              headers: {...bearer, 'Content-Type': 'application/json'},
              body: '{}',
            ));

    var acct = _jwtPayload(tokens.idToken)?['acct'] as Map<String, dynamic>?;
    if (acct == null) {
      final user = await _optionalJson(() => _client
          .get(Uri.https('auth.riotgames.com', '/userinfo'), headers: bearer));
      acct = user?['acct'] as Map<String, dynamic>?;
    }
    final geo = await _optionalJson(() => _client.put(
          Uri.https(
              'riot-geo.pas.si.riotgames.com', '/pas/v1/product/valorant'),
          headers: {...bearer, 'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': tokens.idToken}),
        ));
    final version = await _json('取得遊戲版本',
        () => _client.get(Uri.https('valorant-api.com', '/v1/version')));

    return RiotSession(
      accessToken: tokens.accessToken,
      idToken: tokens.idToken,
      entitlementsToken: ent['entitlements_token'] as String,
      puuid: puuid,
      gameName: acct?['game_name'] as String? ?? '',
      tagLine: acct?['tag_line'] as String? ?? '',
      shard:
          (geo?['affinities'] as Map<String, dynamic>?)?['live'] as String? ??
              fallbackShard,
      clientVersion: (version['data']
          as Map<String, dynamic>)['riotClientVersion'] as String,
      expiresAt: now.add(Duration(seconds: tokens.expiresIn)),
    );
  }

  Future<Map<String, dynamic>> fetchStorefront(RiotSession s) async {
    try {
      return await _json(
          '取得商店',
          () => _client.post(
                _pd(s, '/store/v3/storefront/${s.puuid}'),
                headers: {..._pdHeaders(s), 'Content-Type': 'application/json'},
                body: '{}',
              ));
    } on RiotApiException catch (e) {
      if (e.statusCode != 404 && e.statusCode != 405) rethrow;
      return _json(
          '取得商店',
          () => _client.get(_pd(s, '/store/v2/storefront/${s.puuid}'),
              headers: _pdHeaders(s)));
    }
  }

  /// pd 端點的共用 GET：帶齊 4 個標頭；非 2xx 丟出 [RiotApiException]。
  Future<Map<String, dynamic>> getPd(
    RiotSession s,
    String path, {
    Map<String, String>? query,
    required String label,
  }) =>
      _json(
          label,
          () => _client.get(Uri.https('pd.${s.shard}.a.pvp.net', path, query),
              headers: _pdHeaders(s)));

  /// pd 端點的 PUT，回應為 JSON 陣列（例如 name-service）。
  Future<List<dynamic>> putPdList(
    RiotSession s,
    String path,
    Object body, {
    required String label,
  }) async {
    final http.Response response;
    try {
      response = await _client.put(Uri.https('pd.${s.shard}.a.pvp.net', path),
          headers: {..._pdHeaders(s), 'Content-Type': 'application/json'},
          body: jsonEncode(body));
    } catch (_) {
      throw RiotApiException(null, '$label：連線失敗');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RiotApiException(
          response.statusCode, '$label：伺服器回應 ${response.statusCode}');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    } catch (_) {
      throw RiotApiException(response.statusCode, '$label：回應格式不符');
    }
  }

  Future<RiotWallet> fetchWallet(RiotSession s) async {
    final json = await getPd(s, '/store/v1/wallet/${s.puuid}', label: '取得錢包');
    final balances = json['Balances'] as Map<String, dynamic>? ?? const {};
    int balance(String id) => (balances[id] as num?)?.toInt() ?? 0;
    return RiotWallet(
        vp: balance(_vp),
        radianite: balance(_radianite),
        kingdom: balance(_kingdom));
  }

  Future<Set<String>> fetchOwnedSkinLevels(RiotSession s) async {
    final json = await getPd(
        s, '/store/v1/entitlements/${s.puuid}/$_skinLevelType',
        label: '取得已擁有造型');
    return {
      for (final e in (json['Entitlements'] as List<dynamic>? ?? const []))
        (e as Map<String, dynamic>)['ItemID'] as String,
    };
  }

  /// 解碼 JWT 的 payload（不驗證簽章，只讀取欄位）；格式不符回傳 null。
  static Map<String, dynamic>? _jwtPayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final json = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// 失敗也不影響登入的請求（例如被瀏覽器 CORS 擋下）；失敗回傳 null。
  Future<Map<String, dynamic>?> _optionalJson(
      Future<http.Response> Function() send) async {
    try {
      return await _json('', send);
    } on RiotApiException {
      return null;
    }
  }

  Uri _pd(RiotSession s, String path) =>
      Uri.https('pd.${s.shard}.a.pvp.net', path);

  Map<String, String> _pdHeaders(RiotSession s) => {
        'Authorization': 'Bearer ${s.accessToken}',
        'X-Riot-Entitlements-JWT': s.entitlementsToken,
        'X-Riot-ClientVersion': s.clientVersion,
        'X-Riot-ClientPlatform': _clientPlatform,
      };

  Future<Map<String, dynamic>> _json(
      String label, Future<http.Response> Function() send) async {
    final http.Response response;
    try {
      response = await send();
    } catch (_) {
      throw RiotApiException(null, '$label：連線失敗');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RiotApiException(
          response.statusCode, '$label：伺服器回應 ${response.statusCode}');
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw RiotApiException(response.statusCode, '$label：回應格式不符');
    }
  }
}
