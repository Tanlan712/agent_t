import 'package:flutter/foundation.dart';

import '../models/bundle_info.dart';
import '../models/skin_catalog.dart';
import '../models/skin_info.dart';
import '../services/catalog_api.dart';
import '../storage/catalog_cache.dart';

class CatalogProvider with ChangeNotifier {
  static const downloadError = '無法下載造型資料，請檢查網路後重試';

  final CatalogApi _api;
  final CatalogCache _cache;

  SkinCatalog? _catalog;
  Map<String, SkinInfo> _skins = {};
  Map<String, BundleInfo> _bundles = {};
  Map<String, SkinInfo> _skinsByLevel = {};
  bool _isLoading = false;
  String? _error;
  bool _usingStaleCache = false;

  final DateTime Function() _now;

  /// 本次執行是否已因為對不到資料自動重新下載過（只試一次，避免一直下載）。
  bool _autoRefreshed = false;

  /// 快取超過這麼久，開啟時在背景重新下載（新組合包、新造型才會出現）。
  static const staleAfter = Duration(days: 3);

  CatalogProvider(this._api, this._cache, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  SkinCatalog? get catalog => _catalog;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get usingStaleCache => _usingStaleCache;

  List<String> get weaponNames =>
      (_catalog?.skins.map((s) => s.weaponName).toSet().toList() ?? [])..sort();

  SkinInfo? skinById(String uuid) => _skins[uuid];
  BundleInfo? bundleById(String uuid) => _bundles[uuid];

  /// Riot API 的 ItemID 可能是造型 uuid 或第一個等級的 uuid。
  SkinInfo? skinByItemId(String id) => _skins[id] ?? _skinsByLevel[id];

  /// 先讀快取，沒有快取才下載；快取太舊時先顯示快取，再在背景更新。
  Future<void> init() async {
    final cached = _cache.load();
    if (cached != null) {
      _setCatalog(cached);
      notifyListeners();
      if (_now().difference(cached.fetchedAt) > staleAfter) {
        _autoRefreshed = true;
        await refresh();
      }
      return;
    }
    await refresh();
  }

  /// 商店裡有目錄對不到的組合包（通常是快取之後才上架的新組合包）時，
  /// 在背景重新下載一次。每次執行最多一次。
  void refreshIfMissingBundles(Iterable<String> bundleUuids) {
    if (_autoRefreshed || _isLoading || _catalog == null) return;
    if (bundleUuids.every(_bundles.containsKey)) return;
    _autoRefreshed = true;
    refresh();
  }

  /// 強制重新下載。
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final fresh = await _api.fetchCatalog();
      _setCatalog(fresh);
      _usingStaleCache = false;
      try {
        await _cache.save(fresh);
      } catch (e) {
        debugPrint('造型目錄無法寫入快取，僅保留在記憶體：$e');
      }
    } catch (e) {
      debugPrint('下載造型目錄失敗：$e');
      if (_catalog != null) {
        _usingStaleCache = true;
      } else {
        _error = downloadError;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setCatalog(SkinCatalog catalog) {
    _catalog = catalog;
    _skins = {for (final s in catalog.skins) s.uuid: s};
    _bundles = {for (final b in catalog.bundles) b.uuid: b};
    _skinsByLevel = {
      for (final s in catalog.skins)
        if (s.levelUuid case final level?) level: s,
    };
  }
}
