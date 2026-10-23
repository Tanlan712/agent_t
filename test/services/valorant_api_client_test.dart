import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agent_t/services/valorant_api_client.dart';

void main() {
  test('同一網址同時只下載一次，之後重複使用；參數順序不影響', () async {
    final calls = <Uri>[];
    final c = SharedGetClient(MockClient((req) async {
      calls.add(req.url);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      return http.Response('{"data":[1]}', 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final a =
        Uri.parse('https://valorant-api.com/v1/agents?b=1&language=zh-TW');
    final b =
        Uri.parse('https://valorant-api.com/v1/agents?language=zh-TW&b=1');
    final res = await Future.wait([c.get(a), c.get(b)]);
    expect(calls, hasLength(1));
    expect(res.map((r) => r.body), ['{"data":[1]}', '{"data":[1]}']);
    final later = await c.get(a);
    expect(later.statusCode, 200);
    expect(later.body, '{"data":[1]}');
    expect(calls, hasLength(1));
  });

  test('失敗的回應與例外不快取，下次重新下載', () async {
    var n = 0;
    final c = SharedGetClient(MockClient((req) async {
      n++;
      if (n == 1) return http.Response('x', 503);
      if (n == 2) throw http.ClientException('offline');
      return http.Response('ok', 200);
    }));
    final u = Uri.parse('https://valorant-api.com/v1/weapons');
    expect((await c.get(u)).statusCode, 503);
    await expectLater(c.get(u), throwsA(isA<http.ClientException>()));
    expect((await c.get(u)).body, 'ok');
    expect((await c.get(u)).body, 'ok');
    expect(n, 3);
  });

  test('非 GET 請求直接轉送', () async {
    var n = 0;
    final c = SharedGetClient(MockClient((req) async {
      n++;
      return http.Response('ok', 200);
    }));
    final u = Uri.parse('https://valorant-api.com/v1/x');
    await c.post(u);
    await c.post(u);
    expect(n, 2);
  });

  test('close 不關掉共用客戶端', () async {
    final c =
        SharedGetClient(MockClient((_) async => http.Response('ok', 200)));
    c.close();
    expect(
        (await c.get(Uri.parse('https://valorant-api.com/v1/y'))).body, 'ok');
  });
}
