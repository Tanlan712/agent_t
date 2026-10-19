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
  bool _isLoading = false;
  String? _error;
  bool _usingStaleCache = false;

  CatalogProvider(this._api, this._cache);

  SkinCatalog? get catalog => _catalog;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get usingStaleCache => _usingStaleCache;

  List<String> get weaponNames =>
      (_catalog?.skins.map((s) => s.weaponName).toSet().toList() ?? [])..sort();

  SkinInfo? skinById(String uuid) => _skins[uuid];
  BundleInfo? bundleById(String uuid) => _bundles[uuid];

  /// 先讀快取，沒有快取才下載。
  Future<void> init() async {
    final cached = await _cache.load();
    if (cached != null) {
      _setCatalog(cached);
      notifyListeners();
      return;
    }
    await refresh();
  }

  /// 強制重新下載。
  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final fresh = await _api.fetchCatalog();
      await _cache.save(fresh);
      _setCatalog(fresh);
      _usingStaleCache = false;
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
  }
}
