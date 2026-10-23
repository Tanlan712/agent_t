import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:agent_t/models/progress_reference.dart';
import 'package:agent_t/providers/progress_provider.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/services/progress_reference_api.dart';
import 'package:agent_t/services/riot_client.dart';

import '../riot_fixtures.dart';

class _FakeRefApi implements ProgressReferenceApi {
  int calls = 0;
  bool fail = false;

  /// 下載所需時間（用來重現兩邊同時下載）。
  Duration delay = Duration.zero;

  @override
  Future<ProgressReference> fetch() async {
    calls++;
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    if (fail) throw Exception('down');
    return const ProgressReference();
  }
}

/// 卡住路徑含 [match] 的請求，直到 [gate] 完成。
class _Gated extends http.BaseClient {
  final http.Client inner;
  final String match;
  final Completer<void> gate = Completer<void>();
  _Gated(this.inner, this.match);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.contains(match)) await gate.future;
    return inner.send(request);
  }
}

/// 回應格式不符：其他請求照常轉給假伺服器。
class _Malformed extends http.BaseClient {
  final http.Client inner = riotClient();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.startsWith('/contracts/v1/contracts/')) {
      return http.StreamedResponse(
          Stream.value(utf8.encode('{"Contracts":[42]}')), 200);
    }
    return inner.send(request);
  }
}

http.Client _malformed() => _Malformed();

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

  test('收藏頁的 ensureReference 與 load 同時開始時，參考資料只下載一次', () async {
    final (p, _, api, _) = await make();
    api.delay = const Duration(milliseconds: 200);
    await Future.wait([p.ensureReference(), p.load()]);
    expect(api.calls, 1);
    expect(p.ref, isNotNull);
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

  test('ensureReference 只下載公開參考資料，不送 Riot 請求', () async {
    final (p, _, api, requests) = await make();
    final n = requests.length;
    await p.ensureReference();
    await p.ensureReference();
    expect(p.ref, isNotNull);
    expect(api.calls, 1);
    expect(requests.length, n);
  });

  Future<(ProgressProvider, RiotProvider)> makeWith(http.Client c) async {
    final client = RiotClient(client: c);
    final riot = RiotProvider(client);
    await riot.login(fakeRedirect);
    return (
      ProgressProvider(riot, client, _FakeRefApi(), delay: (_) async {}),
      riot
    );
  }

  test('載入中按重新整理：重新抓取等級與合約', () async {
    final requests = <http.Request>[];
    final gated = _Gated(riotClient(requests: requests), '/contracts/');
    final (p, _) = await makeWith(gated);
    final first = p.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = p.refresh();
    gated.gate.complete();
    await first;
    await second;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(
        requests.where((r) => r.url.path.startsWith('/account-xp/')).length, 2);
    expect(p.isLoading, isFalse);
    expect(p.contracts, isNotNull);
  });

  test('401 時登出（刪除保存的登入資訊）', () async {
    final (p, riot) = await makeWith(riotClient(contractsStatus: 401));
    await p.load();
    expect(riot.isLoggedIn, isFalse);
  });

  test('回應格式不符時不會卡在載入中', () async {
    final (p, _) = await makeWith(_malformed());
    await p.load();
    expect(p.isLoading, isFalse);
    expect(p.error, contains('格式'));
  });

  test('登出時清空 Riot 資料', () async {
    final (p, riot, _, _) = await make();
    await p.load();
    riot.logout();
    expect(p.xp, isNull);
    expect(p.contracts, isNull);
  });
}
