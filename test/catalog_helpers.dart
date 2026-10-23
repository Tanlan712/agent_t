import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/models/bundle_info.dart';
import 'package:agent_t/models/skin_catalog.dart';
import 'package:agent_t/models/skin_info.dart';
import 'package:agent_t/models/tier.dart';
import 'package:agent_t/providers/catalog_provider.dart';
import 'package:agent_t/services/catalog_api.dart';
import 'package:agent_t/storage/catalog_cache.dart';

const odin =
    SkinInfo(uuid: 'o', name: '凌空之志 奧丁', weaponName: '奧丁', tier: Tier.deluxe);
const prime =
    SkinInfo(uuid: 'p', name: 'Prime 幻象', weaponName: '幻象', tier: Tier.premium);
const ion =
    SkinInfo(uuid: 'i', name: '離子 幻象', weaponName: '幻象', tier: Tier.premium);
const reaver =
    SkinInfo(uuid: 'r', name: '掠奪者 暴徒', weaponName: '暴徒', tier: Tier.ultra);
const rgx = BundleInfo(uuid: 'b', name: 'RGX 11z Pro');

final catalogFetchedAt = DateTime(2026, 10, 19, 12);

MockClient _downClient() => MockClient((_) async => http.Response('', 503));

/// 建立已載入 [skins] 的 CatalogProvider（預先寫入 prefs 快取，不連網）。
/// 會重設 SharedPreferences 的 mock 值，所以要在其他 prefs 設定之前呼叫。
Future<CatalogProvider> loadedCatalog(
  WidgetTester tester, {
  List<SkinInfo> skins = const [odin, prime, ion, reaver],
  List<BundleInfo> bundles = const [rgx],
  http.Client? client,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final cache = CatalogCache(prefs);
  await cache.save(
      SkinCatalog(skins: skins, bundles: bundles, fetchedAt: catalogFetchedAt));
  final provider =
      CatalogProvider(CatalogApi(client: client ?? _downClient()), cache);
  await tester.runAsync(provider.init);
  return provider;
}

/// 沒有快取、下載失敗的 CatalogProvider。
Future<CatalogProvider> failedCatalog(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final provider = CatalogProvider(
    CatalogApi(client: _downClient()),
    CatalogCache(await SharedPreferences.getInstance()),
  );
  await tester.runAsync(provider.init);
  return provider;
}
