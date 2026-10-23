import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/models/bundle_info.dart';
import 'package:agent_t/models/skin_catalog.dart';
import 'package:agent_t/models/skin_info.dart';
import 'package:agent_t/models/tier.dart';
import 'package:agent_t/storage/catalog_cache.dart';

Future<CatalogCache> cacheWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return CatalogCache(await SharedPreferences.getInstance());
}

void main() {
  test('存入後讀出一致', () async {
    final cache = await cacheWith({});
    await cache.save(SkinCatalog(
      skins: const [
        SkinInfo(
            uuid: 'a', name: '凌空之志 奧丁', weaponName: '奧丁', tier: Tier.deluxe),
      ],
      bundles: const [BundleInfo(uuid: 'b', name: 'RGX')],
      fetchedAt: DateTime(2026, 10, 19, 12),
    ));
    final loaded = cache.load();
    expect(loaded!.skins.single.name, '凌空之志 奧丁');
    expect(loaded.bundles.single.uuid, 'b');
    expect(loaded.fetchedAt, DateTime(2026, 10, 19, 12));
  });

  test('寫入時刪除舊版快取', () async {
    final cache = await cacheWith({'catalog': '{"old":true}'});
    await cache.save(SkinCatalog(
        skins: const [], bundles: const [], fetchedAt: DateTime(2026)));
    expect((await SharedPreferences.getInstance()).containsKey('catalog'),
        isFalse);
  });

  test('沒有資料時回傳 null', () async {
    expect((await cacheWith({})).load(), isNull);
  });

  test('內容損壞時回傳 null', () async {
    expect((await cacheWith({'catalog_v2': '{bad'})).load(), isNull);
  });
}
