import 'package:flutter/foundation.dart';

import '../logic/storefront_mapper.dart';
import '../models/riot_session.dart';
import '../services/riot_auth.dart';
import '../services/riot_client.dart';
import '../services/riot_cookies.dart';
import '../storage/session_storage.dart';
import 'catalog_provider.dart';
import 'shop_provider.dart';

/// Riot 登入狀態與同步結果；有 [SessionStorage] 時會保存登入資訊（AGENTS.md 第 4 節）。
class RiotProvider with ChangeNotifier {
  static const badUrlMessage = '網址中找不到登入資訊，請貼上登入後跳轉的完整網址';
  static const expiredMessage = '登入已過期，請重新登入';
  static const invalidLoginMessage = '登入資訊無效，請重新登入並貼上完整網址';
  static const otherAccountMessage = '續期失敗：Riot 記住的是另一個帳號';

  final RiotClient _client;
  final DateTime Function() _now;
  final SessionStorage? _storage;
  final Future<void> Function()? _onLogout;
  final RiotCookieStore? _cookies;

  RiotSession? _session;
  String? _account;
  bool _expired = false;
  RiotWallet? _wallet;
  Set<String> _owned = {};
  bool _isBusy = false;

  RiotProvider(this._client,
      {DateTime Function() now = DateTime.now,
      SessionStorage? storage,
      Future<void> Function()? onLogout,
      RiotCookieStore? cookies})
      : _now = now,
        _storage = storage,
        _onLogout = onLogout,
        _cookies = cookies {
    _session = storage?.load(now());
    _account = storage?.activePuuid;
    _expired = storage?.expiredOnLoad ?? false;
  }

  /// 換成另一個帳號（含登出）時呼叫：from／to 是 puuid，沒有帳號時為 null。
  /// 用來保存與還原各帳號自己的商店。
  void Function(String? from, String? to)? onAccountChanged;

  /// 刪除不是目前使用中的帳號時呼叫（puuid）。
  void Function(String puuid)? onAccountRemoved;

  /// 保存過的帳號（多帳號切換，AGENTS.md 第 4 節）。
  List<SavedAccount> get accounts => _storage?.accounts ?? const [];

  /// 目前選用的帳號；token 過期時仍然是它，直到切換或登出。
  String? get activePuuid => _account;

  /// 帳號的 token 還有效，切換後不用重新登入。
  bool hasValidSession(SavedAccount a) => a.hasValidSession(_now());

  /// 帳號的 token 剩餘時間；過期或沒有時為 Duration.zero。
  Duration timeLeftOf(SavedAccount a) {
    final s = a.session;
    if (s == null) return Duration.zero;
    final left = s.expiresAt.difference(_now());
    return left.isNegative ? Duration.zero : left;
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
    // 重新登入一律重新同步，不留著之前的錢包與已擁有資料。
    _wallet = null;
    _owned = {};
    return _run(
      () async {
        final s = await _client.createSession(tokens, _now(),
            fallbackShard: fallbackShard);
        _changeAccount(s.puuid);
        _session = s;
        _expired = false;
        await _storage?.save(s);
        await _storage?.setAutoRenew(autoRenew);
        if (autoRenew) await _keepCookie(s.puuid);
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
      // 背景續期不能偷偷換成別的帳號（多帳號時內嵌頁可能記著另一個帳號）。
      final account = _account;
      if (account != null && s.puuid != account) return otherAccountMessage;
      _changeAccount(s.puuid);
      _session = s;
      _expired = false;
      await _storage?.save(s);
      // Riot 可能換發新的 ssid，續期後重新保存。
      await _keepCookie(s.puuid);
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

  /// 切換到保存過的帳號：token 還有效就直接使用，已過期時提示重新登入。
  Future<void> switchAccount(String puuid) async {
    final target = _storage?.account(puuid);
    if (target == null || puuid == _account) return;
    await _storage?.setActive(puuid);
    await _swapCookie(target);
    _changeAccount(puuid);
    _session = target.hasValidSession(_now()) ? target.session : null;
    _expired = _session == null;
    notifyListeners();
  }

  /// App 內新增帳號前：清除內嵌頁的 Riot 登入記錄，Riot 才會顯示登入頁，
  /// 而不是直接登入目前的帳號。
  Future<void> prepareNewLogin() async => _onLogout?.call();

  /// 使用者按「登出」：刪除目前帳號（token 與自動續期），並清除 App 內嵌頁的 Riot 登入記錄。
  void logout() {
    final puuid = _account;
    _expired = false;
    if (puuid != null) _storage?.remove(puuid);
    _onLogout?.call();
    _changeAccount(null);
    _drop();
  }

  /// 刪除保存的帳號；是目前的帳號時等於 [logout]。
  Future<void> removeAccount(String puuid) async {
    if (puuid == _account) return logout();
    await _storage?.remove(puuid);
    onAccountRemoved?.call(puuid);
    notifyListeners();
  }

  /// token 過期或被 Riot 拒絕（各頁的 401／403）：刪除登入資訊，但保留自動續期，並提示重新登入。
  void expire() {
    _expired = _expired || _session != null;
    _drop();
  }

  /// 保存內嵌頁目前的 ssid 給 [puuid]（多帳號切換，AGENTS.md 第 3 節）。
  Future<void> _keepCookie(String puuid) async {
    final cookies = _cookies;
    if (cookies == null) return;
    final ssid = await cookies.read();
    if (ssid != null && ssid.isNotEmpty)
      await _storage?.setCookies(puuid, ssid);
  }

  /// 切換帳號：清除內嵌頁的 Riot 登入記錄，放回 [target] 保存的 ssid，
  /// 背景續期就會拿到 [target] 的新 token。沒有保存的 ssid 時只清除。
  Future<void> _swapCookie(SavedAccount target) async {
    final cookies = _cookies;
    if (cookies == null) return;
    await _onLogout?.call();
    final ssid = target.cookies;
    if (ssid != null) await cookies.write(ssid);
  }

  void _changeAccount(String? puuid) {
    if (puuid == _account) return;
    final from = _account;
    _account = puuid;
    // 換帳號時不能留著前一個帳號的錢包與已擁有資料。
    _wallet = null;
    _owned = {};
    onAccountChanged?.call(from, puuid);
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
