import 'dart:async';
import 'dart:convert';
import '../models/account_progress.dart';
import '../models/penalty_status.dart';
import '../models/player_loadout.dart';

import 'package:http/http.dart' as http;

import '../models/riot_session.dart';
import 'riot_auth.dart';

/// 收藏的 ItemTypeID（AGENTS.md 第 3 節核准，只能 GET）。
abstract final class ItemTypes {
  static const skinLevel = 'e7c63390-eda7-46e0-bb7a-a6abdacd2433';
  static const skinChroma = '3ad1b2b2-acdb-4524-852f-954a76ddae0a';
  static const agent = '01bb38e1-da47-4e6a-9b3d-945fe4655707';
  static const buddyLevel = 'dd3bf334-87f3-40bd-b043-682a57a8dc3a';
  static const spray = 'd5f120f8-ff8c-4aac-92ea-f2b5acbe9475';
  static const playerCard = '3f296c07-64c3-494c-923b-fe692a4fa1bd';
  static const title = 'de7caa6b-adf7-4588-bbd1-143831e786c6';
}

class RiotApiException implements Exception {
  final int? statusCode;

  /// 不含任何 token，可直接顯示給使用者。
  final String message;

  /// 429 回應的 Retry-After（秒）；沒有這個標頭時為 null。
  final Duration? retryAfter;

  RiotApiException(this.statusCode, this.message, {this.retryAfter});

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

  /// 對 Riot 遊戲伺服器（*.a.pvp.net）的請求全部經過同一個限流：
  /// 不論哪個頁面或 provider 發出，同時最多 [maxPvpConcurrent] 個（AGENTS.md 第 3 節）。
  RiotClient({http.Client? client, int maxPvpConcurrent = 2})
      : _client = _PvpLimitedClient(client ?? http.Client(), maxPvpConcurrent);

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
          () => _client.get(Uri.https(s.pdHost, path, query),
              headers: _pdHeaders(s)));

  /// 即時對局（glz）端點的 GET；依 AGENTS.md 只允許讀取。
  Future<Map<String, dynamic>> getGlz(
    RiotSession s,
    String path, {
    required String label,
  }) =>
      _json(
          label,
          () =>
              _client.get(Uri.https(s.glzHost, path), headers: _pdHeaders(s)));

  /// 遠端操作的寫入（使用者同意後，規格 2026-10-22-remote-control-design.md）。
  /// [host] 是 `pd` 或 `glz`；回應不是 JSON 物件（例如空的）時回傳 null。
  /// 不自動重試：寫入重送可能重複排隊或重複鎖定。
  Future<Map<String, dynamic>?> sendRemote(
    RiotSession s,
    String method,
    String host,
    String path, {
    Object? body,
    Map<String, String>? query,
    required String label,
  }) async {
    final uri = Uri.https(host == 'glz' ? s.glzHost : s.pdHost, path, query);
    final request = http.Request(method, uri)
      ..headers.addAll({..._pdHeaders(s), 'Content-Type': 'application/json'});
    if (method != 'DELETE') {
      request.body = body == null ? '{}' : jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw RiotApiException(null, '$label：連線失敗');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RiotApiException(
          response.statusCode, '$label：伺服器回應 ${response.statusCode}');
    }
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  /// pd 端點的 PUT，回應為 JSON 陣列（例如 name-service）。
  Future<List<dynamic>> putPdList(
    RiotSession s,
    String path,
    Object body, {
    required String label,
  }) async {
    final http.Response response;
    try {
      response = await _client.put(Uri.https(s.pdHost, path),
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

  /// 自己擁有的某類物品（ItemID 轉小寫）；只能 GET。
  Future<Set<String>> fetchEntitlements(
      RiotSession s, String itemTypeId) async {
    final json = await getPd(s, '/store/v1/entitlements/${s.puuid}/$itemTypeId',
        label: '取得收藏');
    return {
      for (final e in (json['Entitlements'] as List<dynamic>? ?? const []))
        ((e as Map<String, dynamic>)['ItemID'] as String).toLowerCase(),
    };
  }

  /// 自己的帳號等級與經驗；只能 GET。
  Future<AccountXp> fetchAccountXp(RiotSession s) async => AccountXp.fromJson(
      await getPd(s, '/account-xp/v1/players/${s.puuid}', label: '取得帳號等級'));

  /// 自己的合約（通行證）與任務進度；只能 GET，不得啟用合約。
  Future<ContractsSnapshot> fetchContracts(RiotSession s) async =>
      ContractsSnapshot.fromJson(await getPd(
          s, '/contracts/v1/contracts/${s.puuid}',
          label: '取得通行證與任務'));

  /// 自己目前裝備的造型與外觀（「目前裝備」分頁，只 GET）。
  /// 實測（2026-10-22）v2 回 404，v3 回 200。
  Future<PlayerLoadout> fetchLoadout(RiotSession s) async =>
      PlayerLoadout.fromJson(await getPd(
          s, '/personalization/v3/players/${s.puuid}/playerloadout',
          label: '取得目前裝備'));

  /// 自己的排隊懲罰；只能 GET。
  Future<PenaltyStatus> fetchPenalties(RiotSession s) async =>
      PenaltyStatus.fromJson(
          await getPd(s, '/restrictions/v3/penalties', label: '取得排隊懲罰'));

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

  Uri _pd(RiotSession s, String path) => Uri.https(s.pdHost, path);

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
      final seconds = int.tryParse(response.headers['retry-after'] ?? '');
      throw RiotApiException(
          response.statusCode, '$label：伺服器回應 ${response.statusCode}',
          retryAfter: seconds == null ? null : Duration(seconds: seconds));
    }
    try {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw RiotApiException(response.statusCode, '$label：回應格式不符');
    }
  }
}

/// 限制 *.a.pvp.net 同時進行中的請求數；其他主機（登入、valorant-api）不受影響。
class _PvpLimitedClient extends http.BaseClient {
  final http.Client _inner;
  final int _max;
  int _running = 0;
  final _waiting = <Completer<void>>[];

  _PvpLimitedClient(this._inner, this._max);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.url.host.endsWith('.a.pvp.net')) return _inner.send(request);
    if (_running < _max) {
      _running++;
    } else {
      // 等前面的請求把名額直接交給這裡（名額數不變），避免中間被插隊。
      final slot = Completer<void>();
      _waiting.add(slot);
      await slot.future;
    }
    try {
      // 等回應內容讀完才釋放名額，避免串流還沒讀完就送出下一個請求。
      final res = await _inner.send(request);
      final bytes = await res.stream.toBytes();
      return http.StreamedResponse(Stream.value(bytes), res.statusCode,
          contentLength: bytes.length,
          request: res.request,
          headers: res.headers,
          isRedirect: res.isRedirect,
          persistentConnection: res.persistentConnection,
          reasonPhrase: res.reasonPhrase);
    } finally {
      if (_waiting.isNotEmpty) {
        _waiting.removeAt(0).complete();
      } else {
        _running--;
      }
    }
  }

  @override
  void close() => _inner.close();
}
