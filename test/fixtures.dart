import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 依 valorant-api.com 實際格式精簡的測試資料。
const tiersJson = '''
{"status":200,"data":[
  {"uuid":"tier-deluxe","devName":"Deluxe","displayName":"奢華"},
  {"uuid":"tier-ultra","devName":"Ultra","displayName":"究極"}
]}''';

const weaponsJson = '''
{"status":200,"data":[
  {"uuid":"w-odin","displayName":"奧丁","skins":[
    {"uuid":"skin-odin","displayName":"凌空之志 奧丁","contentTierUuid":"tier-deluxe",
     "displayIcon":"https://x/odin.png","levels":[{"displayIcon":"https://x/odin-l0.png"}]},
    {"uuid":"skin-standard","displayName":"標準 奧丁","contentTierUuid":null,
     "displayIcon":"https://x/std.png","levels":[]},
    {"uuid":"skin-noicon","displayName":"究極 奧丁","contentTierUuid":"tier-ultra",
     "displayIcon":null,"levels":[{"displayIcon":"https://x/level0.png"}]}
  ]}
]}''';

const bundlesJson = '''
{"status":200,"data":[
  {"uuid":"bundle-rgx","displayName":"RGX 11z Pro","displayIcon":"https://x/rgx.png"}
]}''';

MockClient fixtureClient() => MockClient(fixtureHandler);

Future<http.Response> fixtureHandler(http.Request req) async {
  switch (req.url.path) {
    case '/v1/contenttiers':
      return http.Response.bytes(_utf8(tiersJson), 200);
    case '/v1/weapons':
      return http.Response.bytes(_utf8(weaponsJson), 200);
    case '/v1/bundles':
      return http.Response.bytes(_utf8(bundlesJson), 200);
  }
  return http.Response('not found', 404);
}

List<int> _utf8(String s) => utf8.encode(s);
