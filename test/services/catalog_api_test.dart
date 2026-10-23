import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agent_t/models/tier.dart';
import 'package:agent_t/services/catalog_api.dart';

import '../fixtures.dart';

void main() {
  final fetchedAt = DateTime(2026, 10, 19, 12, 0);

  test('精簡目錄：排除無稀有度、圖示 fallback、武器名稱', () async {
    final api = CatalogApi(client: fixtureClient(), now: () => fetchedAt);
    final catalog = await api.fetchCatalog();

    expect(catalog.skins.length, 2);
    expect(catalog.skins.any((s) => s.uuid == 'skin-standard'), isFalse);
    final odin = catalog.skins.firstWhere((s) => s.uuid == 'skin-odin');
    expect(odin.name, '凌空之志 奧丁');
    expect(odin.weaponName, '奧丁');
    expect(odin.tier, Tier.deluxe);
    expect(odin.iconUrl, 'https://x/odin.png');
    final noIcon = catalog.skins.firstWhere((s) => s.uuid == 'skin-noicon');
    expect(noIcon.iconUrl, 'https://x/level0.png');
    expect(noIcon.tier, Tier.ultra);
    expect(odin.levelUuid, 'lvl-odin');
    expect(noIcon.levelUuid, 'lvl-noicon');
    expect(catalog.bundles.length, 1);
    expect(catalog.bundles.single.name, 'RGX 11z Pro');
    expect(catalog.fetchedAt, fetchedAt);
  });

  test('使用 zh-TW 語言參數', () async {
    final urls = <Uri>[];
    final client = MockClient((req) {
      urls.add(req.url);
      return fixtureHandler(req);
    });
    await CatalogApi(client: client).fetchCatalog();
    expect(urls.map((u) => u.path),
        containsAll(['/v1/contenttiers', '/v1/weapons', '/v1/bundles']));
    expect(urls.every((u) => u.queryParameters['language'] == 'zh-TW'), isTrue);
  });

  test('非 200 回應丟出 CatalogFetchException', () async {
    final client = MockClient((req) async {
      if (req.url.path == '/v1/weapons') return http.Response('err', 500);
      return fixtureHandler(req);
    });
    expect(CatalogApi(client: client).fetchCatalog(),
        throwsA(isA<CatalogFetchException>()));
  });

  test('fixture 格式合理', () {
    expect(jsonDecode(weaponsJson)['data'], isList);
  });
}
