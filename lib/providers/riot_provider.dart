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

  RiotSession? _session;
  RiotWallet? _wallet;
  Set<String> _owned = {};
  bool _isBusy = false;

  RiotProvider(this._client,
      {DateTime Function() now = DateTime.now, SessionStorage? storage})
      : _now = now,
        _storage = storage {
    _session = storage?.load(now());
  }

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

  /// 成功回傳 null，否則回傳可顯示的錯誤訊息。
  Future<String?> login(String pastedUrl, {String fallbackShard = 'ap'}) async {
    final tokens = parseRiotRedirect(pastedUrl);
    if (tokens == null) return badUrlMessage;
    // 換帳號時不能留著前一個帳號的錢包與已擁有資料。
    _wallet = null;
    _owned = {};
    return _run(
      () async {
        _session = await _client.createSession(tokens, _now(),
            fallbackShard: fallbackShard);
        await _storage?.save(_session!);
      },
      failurePrefix: '登入失敗',
      authErrorMessage: invalidLoginMessage,
    );
  }

  /// 取得商店、錢包與已擁有造型；成功回傳 null。
  Future<String?> sync(
      {required ShopProvider shop, required CatalogProvider catalog}) {
    final s = _session;
    if (s == null || !isLoggedIn) {
      logout();
      return Future.value(expiredMessage);
    }
    String resolve(String id) => catalog.skinByItemId(id)?.uuid ?? id;
    return _run(() async {
      final storefront = await _client.fetchStorefront(s);
      final wallet = await _client.fetchWallet(s);
      final owned = await _client.fetchOwnedSkinLevels(s);
      await shop.replaceShop(mapStorefront(storefront, resolve, _now()));
      _wallet = wallet;
      _owned = owned.map(resolve).toSet();
    });
  }

  void logout() {
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
        logout();
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
