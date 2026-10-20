import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/providers/match_detail_cache.dart';
import 'package:valorant_shop_tracker/providers/recent_form_loader.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/match_client.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../riot_fixtures.dart';

class _Env {
  final RecentFormLoader loader;
  final RiotProvider riot;
  final List<Duration> waits;
  final List<String> paths;
  final List<Uri> calls;
  int maxInFlight;

  _Env(this.loader, this.riot, this.waits, this.paths, this.calls,
      this.maxInFlight);

  int requestsFor(String fragment) =>
      paths.where((p) => p.contains(fragment)).length;
}

Future<void> _settle(RecentFormLoader l, List<String> ids,
    {String? queue}) async {
  FormStatus st(String p) => l.status(p, queue: queue);
  for (var i = 0; i < 200; i++) {
    if (ids
        .every((p) => st(p) == FormStatus.done || st(p) == FormStatus.failed)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('未在時限內完成：${ids.map(st).toList()}');
}

void main() {
  late _Env env;

  Future<_Env> setup({
    Map<String, int> history429 = const {},
    bool retryAfter = false,
    Map<String, int> otherHistoryStatus = const {},
    Map<String, int> historyConnectionFail = const {},
    Map<String, int> otherMmrStatus = const {},
    int maxConcurrent = 2,
  }) async {
    final waits = <Duration>[];
    final paths = <String>[];
    final calls = <Uri>[];
    var inFlight = 0;
    var maxInFlight = 0;
    late _Env e;
    final inner = riotClient(
      history429: history429,
      retryAfter: retryAfter,
      otherHistoryStatus: otherHistoryStatus,
      historyConnectionFail: historyConnectionFail,
      otherMmrStatus: otherMmrStatus,
      matchDelay: const Duration(milliseconds: 5),
    );
    final client = MockClient((req) async {
      final pd = req.url.host.startsWith('pd.');
      if (pd) {
        paths.add(req.url.path);
        calls.add(req.url);
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        e.maxInFlight = maxInFlight;
      }
      try {
        await Future<void>.delayed(const Duration(milliseconds: 2));
        final copy = http.Request(req.method, req.url)
          ..headers.addAll(req.headers)
          ..bodyBytes = req.bodyBytes;
        return await inner.send(copy).then(http.Response.fromStream);
      } finally {
        if (pd) inFlight--;
      }
    });
    final rc = RiotClient(client: client);
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    paths.clear();
    calls.clear();
    final loader = RecentFormLoader(MatchClient(rc), riot, MatchDetailCache(),
        maxConcurrent: maxConcurrent, delay: (d) async => waits.add(d));
    e = _Env(loader, riot, waits, paths, calls, 0);
    return e;
  }

  tearDown(() => env.loader.dispose());
  group('賽季牌位', () {
    test('牌位未知的玩家另外查 MMR，同一季只查一次', () async {
      env = await setup();
      env.loader.request(['r1', 'mate'],
          queue: 'unrated', seasonId: 'season-1', rankFor: {'r1'});
      await _settle(env.loader, ['r1', 'mate'], queue: 'unrated');
      expect(env.loader.rankTier('r1', 'season-1'), 21);
      expect(env.loader.rankTier('mate', 'season-1'), isNull);
      expect(env.requestsFor('/mmr/v1/players/r1'), 1);
      expect(env.requestsFor('/mmr/v1/players/mate'), 0);
      env.loader.request(['r1'],
          queue: 'swiftplay', seasonId: 'season-1', rankFor: {'r1'});
      await _settle(env.loader, ['r1'], queue: 'swiftplay');
      expect(env.requestsFor('/mmr/v1/players/r1'), 1);
    });

    test('MMR 403 時牌位維持未知，最近戰績照常完成', () async {
      env = await setup(otherMmrStatus: {'r1': 403});
      env.loader.request(['r1'],
          queue: 'unrated', seasonId: 'season-1', rankFor: {'r1'});
      await _settle(env.loader, ['r1'], queue: 'unrated');
      expect(env.loader.rankTier('r1', 'season-1'), isNull);
      expect(env.loader.status('r1', queue: 'unrated'), FormStatus.done);
      expect(env.riot.isLoggedIn, isTrue);
    });
  });
  group('審查修正', () {
    test('B 頁取消只影響 B 自己要求的玩家，A 的玩家照常載完', () async {
      env = await setup(maxConcurrent: 1);
      final a = Object(), b = Object();
      env.loader.request(['r1', 'mate', 'r2'], owner: a);
      env.loader.request(['mate', 'r3', 'r4'], owner: b);
      env.loader.cancelPending(owner: b);
      await _settle(env.loader, ['r1', 'mate', 'r2']);
      expect(env.loader.status('mate'), FormStatus.done);
      expect(env.loader.status('r2'), FormStatus.done);
      expect(env.requestsFor('/history/r3'), 0);
      expect(env.requestsFor('/history/r4'), 0);
    });

    test('後要求的頁面玩家排到佇列前面', () async {
      env = await setup(maxConcurrent: 1);
      env.loader.request(['r1', 'mate', 'r2'], owner: 1);
      env.loader.request(['r3'], owner: 2);
      await _settle(env.loader, ['r1', 'mate', 'r2', 'r3']);
      final order = [
        for (final p in env.paths)
          if (p.startsWith('/match-history/v1/history/')) p.split('/').last,
      ];
      expect(order, ['r1', 'r3', 'mate', 'r2']);
    });

    test('失敗的玩家再次 request 會重新載入', () async {
      env = await setup(history429: {'r1': 4});
      env.loader.request(['r1']);
      await _settle(env.loader, ['r1']);
      expect(env.loader.status('r1'), FormStatus.failed);
      env.loader.request(['r1']);
      await _settle(env.loader, ['r1']);
      expect(env.loader.status('r1'), FormStatus.done);
    });

    test('連線失敗（沒有狀態碼）也會退避重試', () async {
      env = await setup(historyConnectionFail: {'r1': 2});
      env.loader.request(['r1']);
      await _settle(env.loader, ['r1']);
      expect(env.loader.status('r1'), FormStatus.done);
      expect(env.waits, const [Duration(seconds: 2), Duration(seconds: 4)]);
    });

    test('只查詢與這場相同的模式，不同模式分開快取', () async {
      env = await setup();
      env.loader.request(['r1'], queue: 'competitive');
      await _settle(env.loader, ['r1'], queue: 'competitive');
      final h = env.calls
          .where((u) => u.path.endsWith('/history/r1'))
          .map((u) => u.queryParameters['queue'])
          .toList();
      expect(h, ['competitive']);
      expect(env.loader.status('r1', queue: 'competitive'), FormStatus.done);
      expect(env.loader.status('r1', queue: 'swiftplay'), FormStatus.pending);
      env.loader.request(['r1'], queue: 'swiftplay');
      await _settle(env.loader, ['r1'], queue: 'swiftplay');
      expect(env.loader.form('r1', queue: 'swiftplay'), isNotNull);
      expect(
          env.calls
              .where((u) => u.path.endsWith('/history/r1'))
              .map((u) => u.queryParameters['queue'])
              .toList(),
          ['competitive', 'swiftplay']);
    });
  });

  test('同時進行中的請求最多 2 個，每位玩家 5 場與平均 ACS', () async {
    env = await setup();
    final l = env.loader;
    l.request(['r1', 'mate', 'r2']);
    await _settle(l, ['r1', 'mate', 'r2']);
    expect(env.maxInFlight, lessThanOrEqualTo(2));
    for (final p in ['r1', 'mate', 'r2']) {
      expect(l.status(p), FormStatus.done);
      expect(l.form(p)!.games.length, 5);
    }
    // fixture 每場都是同一份資料：r1 每場 5000 ÷ 22 回合。
    expect(l.form('r1')!.games.first.acs, 227);
    expect(l.form('r1')!.avgAcs, closeTo(227, 0.01));
    expect(l.form('r1')!.games.first.won, isFalse);
    expect(l.form('mate')!.games.first.won, isTrue);
    expect(l.form('r1')!.games.first.agentId, 'agent-r1');
  });

  test('多位玩家共用的場次只抓一次詳情', () async {
    env = await setup();
    env.loader.request(['r1', 'mate']);
    await _settle(env.loader, ['r1', 'mate']);
    expect(env.requestsFor('/match-details/v1/matches/m1'), 1);
  });

  test('已有結果的玩家再次 request 會略過', () async {
    env = await setup();
    env.loader.request(['r1']);
    await _settle(env.loader, ['r1']);
    final before = env.paths.length;
    env.loader.request(['r1']);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(env.paths.length, before);
  });

  test('429 依 Retry-After 等待後成功', () async {
    env = await setup(history429: {'r1': 2}, retryAfter: true);
    env.loader.request(['r1']);
    await _settle(env.loader, ['r1']);
    expect(env.loader.status('r1'), FormStatus.done);
    expect(env.waits, [const Duration(seconds: 1), const Duration(seconds: 1)]);
  });

  test('沒有 Retry-After 時退避 2s、4s、8s 後標成失敗，其他人不受影響', () async {
    env = await setup(history429: {'r1': 10});
    env.loader.request(['r1', 'mate']);
    await _settle(env.loader, ['r1', 'mate']);
    expect(env.loader.status('r1'), FormStatus.failed);
    expect(env.loader.form('r1'), isNull);
    expect(env.loader.status('mate'), FormStatus.done);
    expect(env.waits, const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ]);
    expect(env.requestsFor('/match-history/v1/history/r1'), 4);
  });

  test('403 立即失敗不重試', () async {
    env = await setup(otherHistoryStatus: {'r2': 403});
    env.loader.request(['r2']);
    await _settle(env.loader, ['r2']);
    expect(env.loader.status('r2'), FormStatus.failed);
    expect(env.requestsFor('/match-history/v1/history/r2'), 1);
    expect(env.riot.isLoggedIn, isTrue);
  });

  test('401 登出，剩下的玩家都標成失敗', () async {
    env = await setup(otherHistoryStatus: {'r1': 401}, maxConcurrent: 1);
    env.loader.request(['r1', 'mate', 'r2']);
    await _settle(env.loader, ['r1', 'mate', 'r2']);
    expect(env.riot.isLoggedIn, isFalse);
    expect(env.loader.status('mate'), FormStatus.failed);
    expect(env.loader.status('r2'), FormStatus.failed);
    expect(env.requestsFor('/history/mate'), 0);
  });

  test('cancelPending 之後尚未開始的玩家不發出請求', () async {
    env = await setup(maxConcurrent: 1);
    env.loader.request(['r1', 'mate', 'r2']);
    env.loader.cancelPending();
    await _settle(env.loader, ['r1']);
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(env.requestsFor('/history/mate'), 0);
    expect(env.requestsFor('/history/r2'), 0);
    expect(env.loader.status('mate'), FormStatus.pending);
  });

  test('dispose 後進行中的請求完成也不會丟出例外', () async {
    final errors = <Object>[];
    await runZonedGuarded(() async {
      env = await setup();
      env.loader.request(['r1']);
      await Future<void>.delayed(const Duration(milliseconds: 3));
      env.loader.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }, (e, _) => errors.add(e));
    expect(errors, isEmpty);
    env = await setup(); // 讓 tearDown 有新的 loader 可以 dispose。
  });
}
