import 'package:flutter/foundation.dart';

import '../logic/storefront_mapper.dart';
import '../models/riot_session.dart';
import '../services/riot_auth.dart';
import '../services/riot_client.dart';
import 'catalog_provider.dart';
import 'shop_provider.dart';

/// Riot 登入狀態與同步結果；session 只存在記憶體。
class RiotProvider with ChangeNotifier {
  static const badUrlMessage = '網址中找不到登入資訊，請貼上登入後跳轉的完整網址';
  static const expiredMessage = '登入已過期，請重新登入';

  final RiotClient _client;
  final DateTime Function() _now;

  RiotSession? _session;
  RiotWallet? _wallet;
  Set<String> _owned = {};
  bool _isBusy = false;

  RiotProvider(this._client, {DateTime Function() now = DateTime.now})
      : _now = now;

  RiotSession? get session => _session;
  bool get isLoggedIn =>
      _session != null && _now().isBefore(_session!.expiresAt);
  RiotWallet? get wallet => _wallet;
  Set<String> get ownedSkinUuids => Set.unmodifiable(_owned);
  bool isOwned(String skinUuid) => _owned.contains(skinUuid);
  bool get isBusy => _isBusy;

  /// 成功回傳 null，否則回傳可顯示的錯誤訊息。
  Future<String?> login(String pastedUrl) async {
    final tokens = parseRiotRedirect(pastedUrl);
    if (tokens == null) return badUrlMessage;
    return _run(() async {
      _session = await _client.createSession(tokens, _now());
    });
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
    _wallet = null;
    _owned = {};
    notifyListeners();
  }

  Future<String?> _run(Future<void> Function() body) async {
    _isBusy = true;
    notifyListeners();
    try {
      await body();
      return null;
    } on RiotApiException catch (e) {
      if (e.isAuthError) {
        logout();
        return expiredMessage;
      }
      return '同步失敗：${e.message}';
    } catch (e) {
      debugPrint('Riot 資料處理失敗：${e.runtimeType}');
      return '同步失敗：資料格式不符';
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
