import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/bundle_info.dart';
import 'package:valorant_shop_tracker/models/skin_catalog.dart';
import 'package:valorant_shop_tracker/models/skin_info.dart';
import 'package:valorant_shop_tracker/models/tier.dart';
import 'package:valorant_shop_tracker/storage/catalog_cache.dart';

void main() {
  late Directory dir;
  late CatalogCache cache;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('catalog_cache_test');
    cache = CatalogCache(() async => dir);
  });

  tearDown(() => dir.deleteSync(recursive: true));

  test('存入後讀出一致', () async {
    final catalog = SkinCatalog(
      skins: const [
        SkinInfo(uuid: 'a', name: '凌空之志 奧丁', weaponName: '奧丁', tier: Tier.deluxe),
      ],
      bundles: const [BundleInfo(uuid: 'b', name: 'RGX')],
      fetchedAt: DateTime(2026, 10, 19, 12),
    );
    await cache.save(catalog);
    final loaded = await cache.load();
    expect(loaded!.skins.single.name, '凌空之志 奧丁');
    expect(loaded.bundles.single.uuid, 'b');
    expect(loaded.fetchedAt, DateTime(2026, 10, 19, 12));
  });

  test('沒有檔案時回傳 null', () async {
    expect(await cache.load(), isNull);
  });

  test('內容損壞時回傳 null', () async {
    File('${dir.path}/catalog.json').writeAsStringSync('{bad');
    expect(await cache.load(), isNull);
  });
}
