import 'dart:async';

import 'catalog_provider.dart';
import 'collection_provider.dart';
import 'progress_provider.dart';
import 'riot_provider.dart';
import 'shop_provider.dart';

/// 登入後（包括重新開頁時恢復登入）在背景預先讀取一次：
/// 商店、錢包與已擁有造型（給了 [shop] 與 [catalog] 時），再讀收藏、等級、通行證與任務。
/// 依序執行，Riot 請求同時最多 2 個（AGENTS.md 第 3 節）。
class LoginPrefetcher {
  final RiotProvider _riot;
  final CollectionProvider _collection;
  final ProgressProvider _progress;
  final ShopProvider? _shop;
  final CatalogProvider? _catalog;
  String? _prefetchedFor;

  LoginPrefetcher(this._riot, this._collection, this._progress,
      {ShopProvider? shop, CatalogProvider? catalog})
      : _shop = shop,
        _catalog = catalog {
    _riot.addListener(_onRiot);
    _onRiot();
  }

  void _onRiot() {
    final puuid = _riot.isLoggedIn ? _riot.session?.puuid : null;
    if (puuid == null) {
      _prefetchedFor = null;
      return;
    }
    if (puuid == _prefetchedFor) return;
    _prefetchedFor = puuid;
    _run();
  }

  Future<void> _run() async {
    final shop = _shop, catalog = _catalog;
    if (shop != null && catalog != null) {
      // 商店的 ItemID 要靠造型目錄換成造型；目錄還在下載時先等它。
      await _catalogSettled(catalog);
      if (_riot.isLoggedIn) await _riot.sync(shop: shop, catalog: catalog);
    }
    await _collection.load();
    await _progress.load();
  }

  /// 目錄已載入、或下載結束（失敗也算，錢包仍可同步）時完成。
  static Future<void> _catalogSettled(CatalogProvider catalog) {
    bool done() => catalog.catalog != null || catalog.error != null;
    if (done()) return Future.value();
    final c = Completer<void>();
    void check() {
      if (!done() || c.isCompleted) return;
      catalog.removeListener(check);
      c.complete();
    }

    catalog.addListener(check);
    return c.future;
  }

  void dispose() => _riot.removeListener(_onRiot);
}
