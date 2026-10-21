import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';

void main() {
  test('使用注入的 client；getThemes 讀 /v1/themes（zh-TW）', () async {
    final seen = <Uri>[];
    final api = ValorantApiService(
        client: MockClient((req) async {
      seen.add(req.url);
      return http.Response(
          jsonEncode({
            'status': 200,
            'data': [
              {'uuid': 't', 'displayName': 'RGX 11z Pro'}
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final themes = await api.getThemes();
    expect(themes.single['displayName'], 'RGX 11z Pro');
    expect(seen.single.host, 'valorant-api.com');
    expect(seen.single.path, '/v1/themes');
    expect(seen.single.queryParameters['language'], 'zh-TW');
  });

  test('非 200 丟出例外', () async {
    final api = ValorantApiService(
        client: MockClient((_) async => http.Response('', 500)));
    expect(api.getThemes(), throwsException);
  });
}
