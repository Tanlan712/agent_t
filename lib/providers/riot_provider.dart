import 'package:flutter/foundation.dart';

import '../logic/storefront_mapper.dart';
import '../models/riot_session.dart';
import '../services/riot_auth.dart';
import '../services/riot_client.dart';
import '../storage/session_storage.dart';
import 'catalog_provider.dart';
import 'shop_provider.dart';

/// Riot 登入狀態與同步結果；有 [SessionStorage] 時會保存登入資訊（AGENTS.md 第 4 節）。
class RiotProvider with ChangeNotifier {
  static const badUrlMessage = '網址中找不到登入資訊，請貼上登入後跳轉的完整網址';
  static const expiredMessage = '登入已過期，請重新登入';
  static const invalidLoginMessage = '登入資訊無效，請重新登入並貼上完整網址';

  final RiotClient _client;
  final DateTime Function() _now;
  final SessionStorage? _storage;
  final Future<void> Function()? _onLogout;

  RiotSession? _session;
  bool _expired = false;
  RiotWallet? _wallet;
  Set<String> _owned = {};
  bool _isBusy = false;

  RiotProvider(this._client,
      {DateTime Function() now = DateTime.now,
      SessionStorage? storage,
      Future<void> Function()? onLogout})
      : _now = now,
        _storage = storage,
        _onLogout = onLogout {
    _session = storage?.load(now());
    _expired = storage?.expiredOnLoad ?? false;
  }

  /// 每次同步拿到 storefront 回應時呼叫（記錄造型的實際定價）。
  void Function(Map<String, dynamic> storefront)? onStorefront;

  RiotSession? get session => _session;
  bool get isLoggedIn =>
      _session != null && _now().isBefore(_session!.expiresAt);
  RiotWallet? get wallet => isLoggedIn ? _wallet : null;
  Set<String> get ownedSkinUuids =>
      isLoggedIn ? Set.unmodifiable(_owned) : const <String>{};
  bool isOwned(String skinUuid) => isLoggedIn && _owned.contains(skinUuid);
  bool get isBusy => _isBusy;

  /// 登入剩餘時間；沒有登入或已過期時為 Duration.zero。
  Duration get timeLeft {
    final s = _session;
    if (s == null) return Duration.zero;
    final left = s.expiresAt.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  /// 剩不到 5 分鐘就過期（用來提醒重新登入）。
  bool get expiresSoon => isLoggedIn && timeLeft <= const Duration(minutes: 5);

  /// 曾經登入但已過期（含重新開頁時讀到過期的登入資訊）；按「登出」後為 false。
  bool get needsRelogin => !isLoggedIn && (_session != null || _expired);

  /// 上次是在 App 內登入：可以由內嵌頁在背景自動續期（AGENTS.md 第 3 節）。
  bool get canAutoRenew => _storage?.autoRenew ?? false;

  /// 成功回傳 null，否則回傳可顯示的錯誤訊息。
  /// [autoRenew]：從 App 內嵌頁登入，之後允許背景自動續期。
  Future<String?> login(String pastedUrl,
      {String fallbackShard = 'ap', bool autoRenew = false}) async {
    final tokens = parseRiotRedirect(pastedUrl);
    if (tokens == null) return badUrlMessage;
    // 換帳號時不能留著前一個帳號的錢包與已擁有資料。
    _wallet = null;
    _owned = {};
    return _run(
      () async {
        _session = await _client.createSession(tokens, _now(),
            fallbackShard: fallbackShard);
        _expired = false;
        await _storage?.save(_session!);
        await _storage?.setAutoRenew(autoRenew);
      },
      failurePrefix: '登入失敗',
      authErrorMessage: invalidLoginMessage,
    );
  }

  /// App 背景續期：把內嵌頁拿到的跳轉網址換成新的登入資訊；成功回傳 null。
  /// 失敗時不登出，保留原本的狀態（舊 token 還沒過期就繼續用）。
  Future<String?> renew(String redirectUrl,
      {String fallbackShard = 'ap'}) async {
    final tokens = parseRiotRedirect(redirectUrl);
    if (tokens == null) return badUrlMessage;
    try {
      final s = await _client.createSession(tokens, _now(),
          fallbackShard: _session?.shard ?? fallbackShard);
      // Riot 記住的是另一個帳號時，不能留著前一個帳號的資料。
      if (s.puuid != _session?.puuid) {
        _wallet = null;
        _owned = {};
      }
      _session = s;
      _expired = false;
      await _storage?.save(s);
      notifyListeners();
      return null;
    } on RiotApiException catch (e) {
      return '續期失敗：${e.message}';
    } catch (e) {
      debugPrint('Riot 續期失敗：${e.runtimeType}');
      return '續期失敗：資料格式不符';
    }
  }

  /// 取得商店、錢包與已擁有造型；成功回傳 null。
  Future<String?> sync(
      {required ShopProvider shop, required CatalogProvider catalog}) {
    final s = _session;
    if (s == null || !isLoggedIn) {
      expire();
      return Future.value(expiredMessage);
    }
    String resolve(String id) => catalog.skinByItemId(id)?.uuid ?? id;
    return _run(() async {
      final storefront = await _client.fetchStorefront(s);
      onStorefront?.call(storefront);
      final wallet = await _client.fetchWallet(s);
      final owned = await _client.fetchOwnedSkinLevels(s);
      await shop.replaceShop(mapStorefront(storefront, resolve, _now()));
      _wallet = wallet;
      _owned = owned.map(resolve).toSet();
    });
  }

  /// 使用者按「登出」：同時停止自動續期，並清除 App 內嵌頁的 Riot 登入記錄。
  void logout() {
    _expired = false;
    _storage?.setAutoRenew(false);
    _onLogout?.call();
    _drop();
  }

  /// token 過期或被 Riot 拒絕（各頁的 401／403）：刪除登入資訊，但保留自動續期，並提示重新登入。
  void expire() {
    _expired = _expired || _session != null;
    _drop();
  }

  void _drop() {
    _session = null;
    _storage?.clear();
    _wallet = null;
    _owned = {};
    notifyListeners();
  }

  Future<String?> _run(
    Future<void> Function() body, {
    String failurePrefix = '同步失敗',
    String authErrorMessage = expiredMessage,
  }) async {
    _isBusy = true;
    notifyListeners();
    try {
      await body();
      return null;
    } on RiotApiException catch (e) {
      if (e.isAuthError) {
        expire();
        return authErrorMessage;
      }
      return '$failurePrefix：${e.message}';
    } catch (e) {
      debugPrint('Riot 資料處理失敗：${e.runtimeType}');
      return '$failurePrefix：資料格式不符';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
