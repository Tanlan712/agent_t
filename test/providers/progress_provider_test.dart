import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:valorant_shop_tracker/models/progress_reference.dart';
import 'package:valorant_shop_tracker/providers/progress_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/progress_reference_api.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../riot_fixtures.dart';

class _FakeRefApi implements ProgressReferenceApi {
  int calls = 0;
  bool fail = false;

  @override
  Future<ProgressReference> fetch() async {
    calls++;
    if (fail) throw Exception('down');
    return const ProgressReference();
  }
}

void main() {
  Future<(ProgressProvider, RiotProvider, _FakeRefApi, List<http.Request>)>
      make({int contractsStatus = 200}) async {
    final requests = <http.Request>[];
    final client = RiotClient(
        client:
            riotClient(requests: requests, contractsStatus: contractsStatus));
    final riot = RiotProvider(client);
    await riot.login(fakeRedirect);
    final api = _FakeRefApi();
    final p = ProgressProvider(riot, client, api, delay: (_) async {});
    return (p, riot, api, requests);
  }

  test('載入等級、合約與參考資料', () async {
    final (p, _, api, _) = await make();
    await p.load();
    expect(p.xp!.level, 4);
    expect(p.contracts!.missions, hasLength(2));
    expect(p.ref, isNotNull);
    expect(api.calls, 1);
    expect(p.error, isNull);
  });

  test('只對 pd 送 GET', () async {
    final (p, _, _, requests) = await make();
    await p.load();
    final pd = requests.where((r) => r.url.host == 'pd.ap.a.pvp.net');
    expect(pd, isNotEmpty);
    expect(pd.every((r) => r.method == 'GET'), isTrue);
  });

  test('合約失敗時記錄錯誤，等級仍顯示', () async {
    final (p, _, _, _) = await make(contractsStatus: 500);
    await p.load();
    expect(p.error, isNotNull);
    expect(p.xp, isNotNull);
    expect(p.contracts, isNull);
  });

  test('已載入時不重抓；refresh 重抓 Riot 資料，參考資料沿用', () async {
    final (p, _, api, requests) = await make();
    await p.load();
    final n = requests.length;
    await p.load();
    expect(requests.length, n);
    await p.refresh();
    expect(requests.length, n + 2);
    expect(api.calls, 1);
  });

  test('登出時清空 Riot 資料', () async {
    final (p, riot, _, _) = await make();
    await p.load();
    riot.logout();
    expect(p.xp, isNull);
    expect(p.contracts, isNull);
  });
}
