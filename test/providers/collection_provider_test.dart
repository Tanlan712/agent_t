import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/providers/collection_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../riot_fixtures.dart';

/// 包一層：記錄同時進行中的 entitlements 請求數。
class _Counting extends http.BaseClient {
  final http.Client inner;
  int inFlight = 0;
  int maxInFlight = 0;
  _Counting(this.inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final ent = request.url.path.startsWith('/store/v1/entitlements/');
    if (ent) {
      inFlight++;
      if (inFlight > maxInFlight) maxInFlight = inFlight;
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    try {
      return await inner.send(request);
    } finally {
      if (ent) inFlight--;
    }
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
    if (request.url.path.startsWith('/store/v1/entitlements/')) {
      return http.StreamedResponse(
          Stream.value(utf8
              .encode('{"ItemTypeID":"x","Entitlements":[{"TypeID":"x"}]}')),
          200);
    }
    return inner.send(request);
  }
}

http.Client _malformed() => _Malformed();

void main() {
  Future<(CollectionProvider, RiotProvider, List<Duration>)> make(
      http.Client c) async {
    final client = RiotClient(client: c);
    final riot = RiotProvider(client);
    await riot.login(fakeRedirect);
    final delays = <Duration>[];
    final p =
        CollectionProvider(riot, client, delay: (d) async => delays.add(d));
    return (p, riot, delays);
  }

  test('載入七類收藏，同時最多 2 個請求', () async {
    final counting = _Counting(riotClient(entitlements: {
      ItemTypes.spray: ['spray-1'],
      ItemTypes.agent: ['a-paid'],
    }));
    final (p, _, _) = await make(counting);
    await p.load();
    expect(p.owned.keys, containsAll(CollectionProvider.types));
    expect(p.owned[ItemTypes.spray], {'spray-1'});
    expect(p.owned[ItemTypes.agent], {'a-paid'});
    expect(counting.maxInFlight, lessThanOrEqualTo(2));
    expect(counting.maxInFlight, 2);
    expect(p.isLoading, isFalse);
  });

  test('429 依 Retry-After 退避後成功', () async {
    final (p, _, delays) =
        await make(riotClient(retryAfter: true, entitlement429: {
      ItemTypes.title: 2
    }, entitlements: {
      ItemTypes.title: ['title-1'],
    }));
    await p.load();
    expect(p.owned[ItemTypes.title], {'title-1'});
    expect(delays, [const Duration(seconds: 1), const Duration(seconds: 1)]);
    expect(p.errors, isEmpty);
  });

  test('沒有 Retry-After 時 2s／4s／8s，超過 3 次記錄錯誤', () async {
    final (p, _, delays) =
        await make(riotClient(entitlement429: {ItemTypes.spray: 10}));
    await p.load();
    expect(delays, const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ]);
    expect(p.errors.keys, [ItemTypes.spray]);
    // 其他分類照常載入。
    expect(p.owned.containsKey(ItemTypes.agent), isTrue);
  });

  test('單一分類失敗只影響該分類', () async {
    final (p, _, _) =
        await make(riotClient(entitlementStatus: {ItemTypes.playerCard: 500}));
    await p.load();
    expect(p.errors.keys, [ItemTypes.playerCard]);
    expect(p.owned.containsKey(ItemTypes.playerCard), isFalse);
    expect(p.owned.containsKey(ItemTypes.spray), isTrue);
  });

  test('已載入時不重抓；refresh 會重抓', () async {
    var calls = 0;
    final (p, _, _) = await make(riotClient(onEntitlement: (_) => calls++));
    await p.load();
    await p.load();
    expect(calls, CollectionProvider.types.length);
    await p.refresh();
    expect(calls, CollectionProvider.types.length * 2);
  });

  test('有分類失敗時，再次 load 不會反覆請求（重試要用 refresh）', () async {
    var calls = 0;
    final (p, _, _) = await make(riotClient(
        entitlementStatus: {ItemTypes.spray: 500},
        onEntitlement: (_) => calls++));
    await p.load();
    await p.load();
    expect(calls, CollectionProvider.types.length);
    expect(p.errors.keys, [ItemTypes.spray]);
  });

  test('載入中按重新整理：重新載入全部分類，不會只剩一部分', () async {
    final gated = _Gated(
        riotClient(entitlements: {
          ItemTypes.spray: ['spray-1'],
          ItemTypes.title: ['title-1'],
        }),
        ItemTypes.title);
    final (p, _, _) = await make(gated);
    final first = p.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final second = p.refresh();
    gated.gate.complete();
    await first;
    await second;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(p.owned.keys, containsAll(CollectionProvider.types));
    expect(p.owned[ItemTypes.spray], {'spray-1'});
    expect(p.isLoading, isFalse);
  });

  test('載入中登出再登入：會為新的登入重新載入', () async {
    final gated = _Gated(
        riotClient(entitlements: {
          ItemTypes.spray: ['spray-1'],
        }),
        ItemTypes.title);
    final (p, riot, _) = await make(gated);
    final first = p.load();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    riot.logout();
    await riot.login(fakeRedirect);
    final second = p.load();
    gated.gate.complete();
    await first;
    await second;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(p.owned.keys, containsAll(CollectionProvider.types));
    expect(p.isLoading, isFalse);
  });

  test('401 時登出（刪除保存的登入資訊）', () async {
    final (p, riot, _) =
        await make(riotClient(entitlementStatus: {ItemTypes.spray: 401}));
    await p.load();
    expect(riot.isLoggedIn, isFalse);
  });

  test('回應格式不符時不會卡在載入中', () async {
    final (p, _, _) = await make(_malformed());
    await p.load();
    expect(p.isLoading, isFalse);
    expect(p.errors, isNotEmpty);
    expect(p.errors.values.first, contains('格式'));
  });

  test('登出時清空，不留前一個帳號的資料', () async {
    final (p, riot, _) = await make(riotClient(entitlements: {
      ItemTypes.spray: ['spray-1'],
    }));
    await p.load();
    expect(p.owned, isNotEmpty);
    riot.logout();
    expect(p.owned, isEmpty);
    expect(p.errors, isEmpty);
  });

  test('未登入時 load 不送出請求', () async {
    var calls = 0;
    final client = RiotClient(client: MockClient((r) async {
      calls++;
      return http.Response('{}', 200);
    }));
    final p = CollectionProvider(RiotProvider(client), client);
    await p.load();
    expect(calls, 0);
    expect(p.owned, isEmpty);
  });
}
