import 'dart:async';

import 'catalog_provider.dart';
import 'riot_provider.dart';
import 'shop_provider.dart';

/// 商店自動刷新（使用者決定 2026-10-22）：網頁開著且已登入時，每日商店到期或夜市結束後
/// [delayAfter] 自動同步一次；同步後仍是舊商店（Riot 還沒換新或同步失敗）時每 [retryEvery]
/// 再試，最多 [maxRetries] 次。沿用「從 Riot 同步」的端點，不新增請求種類。
class ShopAutoRefresher {
  static const delayAfter = Duration(seconds: 30);
  static const retryEvery = Duration(minutes: 1);
  static const maxRetries = 3;

  final RiotProvider _riot;
  final ShopProvider _shop;
  final CatalogProvider _catalog;
  final DateTime Function() _now;

  Timer? _timer;

  /// 已經處理過的到期時間（每個只自動同步一輪）。
  final Set<DateTime> _handled = {};
  bool _retrying = false;
  bool _disposed = false;

  ShopAutoRefresher(this._riot, this._shop, this._catalog,
      {DateTime Function() now = DateTime.now})
      : _now = now {
    _riot.addListener(_schedule);
    _shop.addListener(_schedule);
    _schedule();
  }

  /// 目前的到期時間：每日商店與夜市（有資料時）。
  List<DateTime> _ends() => [
        if (_shop.shop.dailyExpiresAt case final d?) d,
        if (_shop.shop.nightMarket.isNotEmpty)
          if (_shop.shop.nightMarketEndsAt case final n?) n,
      ];

  void _schedule() {
    if (_disposed || _retrying) return;
    _timer?.cancel();
    _timer = null;
    if (!_riot.isLoggedIn) return;
    final pending = _ends().where((e) => !_handled.contains(e)).toList()
      ..sort();
    if (pending.isEmpty) return;
    final end = pending.first;
    var wait = end.add(delayAfter).difference(_now());
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait, () => _fire(end));
  }

  void _fire(DateTime end) {
    _handled.add(end);
    _retrying = true;
    _sync(end, 0);
  }

  /// 這個到期時間對應的商店還沒換新。
  bool _stillOld(DateTime end) =>
      _ends().any((e) => e == end || !e.isAfter(_now()));

  Future<void> _sync(DateTime end, int attempt) async {
    if (_disposed) return;
    if (!_riot.isLoggedIn) {
      _retrying = false;
      return;
    }
    if (!_riot.isBusy) {
      await _riot.sync(shop: _shop, catalog: _catalog);
      if (_disposed) return;
    }
    if (_riot.isLoggedIn && _stillOld(end) && attempt < maxRetries) {
      _timer = Timer(retryEvery, () => _sync(end, attempt + 1));
      return;
    }
    _retrying = false;
    _schedule();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _riot.removeListener(_schedule);
    _shop.removeListener(_schedule);
  }
}
