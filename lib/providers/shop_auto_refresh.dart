import 'dart:async';

import 'catalog_provider.dart';
import 'riot_provider.dart';
import 'shop_provider.dart';

/// 商店自動刷新（使用者決定 2026-10-22）：網頁開著且已登入時，每日商店到期或夜市結束後
/// [delayAfter] 自動同步一次；同步後仍是舊商店時每 [retryEvery] 再試，最多 [maxRetries] 次，
/// 用完仍是舊商店就 [cooldown] 內不再自動同步。沿用「從 Riot 同步」的端點，不新增請求種類。
///
/// 到期時間每次同步都依「現在＋剩餘秒數」重算，所以不能用到期時間本身判斷是否處理過；
/// 一律用「商店現在是不是過期了」判斷，並在一輪結束後設定安靜期。
class ShopAutoRefresher {
  static const delayAfter = Duration(seconds: 30);
  static const retryEvery = Duration(minutes: 1);
  static const maxRetries = 3;
  static const cooldown = Duration(minutes: 30);

  /// 有其他同步進行中時，隔這麼久再檢查（不算一次嘗試）。
  static const busyRecheck = Duration(seconds: 5);

  final RiotProvider _riot;
  final ShopProvider _shop;
  final CatalogProvider _catalog;
  final DateTime Function() _now;

  Timer? _timer;
  bool _inCycle = false;

  /// 在這之前不自動同步（一輪結束後的安靜期）。
  DateTime? _quietUntil;
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

  /// 商店（每日或夜市）已經過期，需要同步。
  bool _stale() => _ends().any((e) => !e.isAfter(_now()));

  void _schedule() {
    if (_disposed || _inCycle) return;
    _timer?.cancel();
    _timer = null;
    if (!_riot.isLoggedIn) return;
    final ends = _ends()..sort();
    if (ends.isEmpty) return;
    var at = ends.first.add(delayAfter);
    final quiet = _quietUntil;
    if (quiet != null && at.isBefore(quiet)) at = quiet;
    var wait = at.difference(_now());
    if (wait.isNegative) wait = Duration.zero;
    _timer = Timer(wait, () {
      _inCycle = true;
      _attempt(0);
    });
  }

  Future<void> _attempt(int n) async {
    if (_disposed) return;
    // 每次嘗試前都重新檢查：可能已被手動同步或登入後的預先讀取更新。
    if (!_riot.isLoggedIn || !_stale()) return _endCycle(gaveUp: false);
    if (_riot.isBusy) {
      _timer = Timer(busyRecheck, () => _attempt(n));
      return;
    }
    await _riot.sync(shop: _shop, catalog: _catalog);
    if (_disposed) return;
    if (_riot.isLoggedIn && _stale() && n < maxRetries) {
      _timer = Timer(retryEvery, () => _attempt(n + 1));
      return;
    }
    _endCycle(gaveUp: _riot.isLoggedIn && _stale());
  }

  void _endCycle({required bool gaveUp}) {
    _inCycle = false;
    // 重試用完仍是舊商店（Riot 還沒換新或一直失敗）：安靜一段時間，避免反覆送出請求。
    _quietUntil = _now().add(gaveUp ? cooldown : delayAfter);
    _schedule();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _riot.removeListener(_schedule);
    _shop.removeListener(_schedule);
  }
}
