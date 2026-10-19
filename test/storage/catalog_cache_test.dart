import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/models/bundle_info.dart';
import 'package:valorant_shop_tracker/models/skin_catalog.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/storage/catalog_cache.dart';

Future<CatalogCache> cacheWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return CatalogCache(await SharedPreferences.getInstance());
}

void main() {
  test('存入後讀出一致', () async {
    final cache = await cacheWith({});
    await cache.save(SkinCatalog(
      skins: const [
        SkinInfo(uuid: 'a', name: '凌空之志 奧丁', weaponName: '奧丁', tier: Tier.deluxe),
      ],
      bundles: const [BundleInfo(uuid: 'b', name: 'RGX')],
      fetchedAt: DateTime(2026, 10, 19, 12),
    ));
    final loaded = cache.load();
    expect(loaded!.skins.single.name, '凌空之志 奧丁');
    expect(loaded.bundles.single.uuid, 'b');
    expect(loaded.fetchedAt, DateTime(2026, 10, 19, 12));
  });

  test('沒有資料時回傳 null', () async {
    expect((await cacheWith({})).load(), isNull);
  });

  test('內容損壞時回傳 null', () async {
    expect((await cacheWith({'catalog': '{bad'})).load(), isNull);
  });
}
