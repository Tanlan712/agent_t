import 'package:shared_preferences/shared_preferences.dart';

import '../models/skin_catalog.dart';
import 'prefs_json.dart';

/// 把精簡後的造型目錄存在 shared_preferences（網頁上為 localStorage）。
class CatalogCache {
  /// v3：造型圖改用炫彩 fullRender（舊快取的圖可能是缺圖佔位圖）。
  static const _key = 'catalog_v3';
  static const _legacyKeys = ['catalog', 'catalog_v2'];

  final SharedPreferences _prefs;

  CatalogCache(this._prefs);

  SkinCatalog? load() => readPrefsJson<SkinCatalog?>(
        _prefs,
        _key,
        (json) => SkinCatalog.fromJson(json as Map<String, dynamic>),
        null,
      );

  /// 寫入失敗（例如超過容量）時會丟出例外，由呼叫端決定如何處理。
  Future<void> save(SkinCatalog catalog) async {
    // 舊版快取刪掉以免佔用 localStorage 容量。
    for (final k in _legacyKeys) {
      await _prefs.remove(k);
    }
    final ok = await writePrefsJson(_prefs, _key, catalog.toJson());
    if (!ok) throw StateError('造型目錄寫入失敗');
  }
}
