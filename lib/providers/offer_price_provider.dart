import 'package:flutter/foundation.dart';

import '../models/offer_prices.dart';
import '../models/skin_info.dart';
import '../services/riot_client.dart';
import '../storage/offer_price_storage.dart';
import 'riot_provider.dart';
import 'riot_retry.dart';

/// 全物品的實際定價（只讀 GET `/store/v1/offers/`）：存在這個瀏覽器，
/// 登入後超過 [maxAge] 才重抓；失敗時保留上次的價格。
class OfferPriceProvider with ChangeNotifier {
  static const maxAge = Duration(hours: 24);

  final RiotProvider _riot;
  final RiotClient _client;
  final OfferPriceStorage _storage;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;

  OfferPrices? _prices;
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;

  OfferPriceProvider(this._riot, this._client, this._storage,
      {DateTime Function() now = DateTime.now,
      Future<void> Function(Duration)? delay})
      : _now = now,
        _delay = delay ?? Future<void>.delayed,
        _prices = _storage.load();

  OfferPrices? get prices => _prices;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 造型的 VP 定價（用第一個造型等級查）；沒有定價時回傳 null。
  int? priceOf(SkinInfo? skin) => _prices?.priceOf(skin?.levelUuid);

  bool get _stale {
    final p = _prices;
    return p == null || _now().difference(p.fetchedAt) >= maxAge;
  }

  /// 已登入且快取過期（或 [force]）時重抓。
  Future<void> load({bool force = false}) async {
    final s = _riot.session;
    if (!_riot.isLoggedIn || s == null || _isLoading) return;
    if (!force && !_stale) return;
    _isLoading = true;
    _error = null;
    _notify();
    try {
      final p = await withRiotRetry(() => _client.fetchOffers(s, _now()),
          delay: _delay);
      // 回應是空的（格式改變）時不蓋掉舊價格。
      if (p.vp.isNotEmpty) {
        _prices = p;
        await _storage.save(p);
      } else {
        _error = '取得定價：回應格式不符';
      }
    } on RiotApiException catch (e) {
      if (e.isAuthError) {
        _riot.expire();
      } else {
        _error = e.message;
      }
    } catch (_) {
      _error = '取得定價：回應格式不符';
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
