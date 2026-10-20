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
  int maxInFlight;

  _Env(this.loader, this.riot, this.waits, this.paths, this.maxInFlight);

  int requestsFor(String fragment) =>
      paths.where((p) => p.contains(fragment)).length;
}

Future<void> _settle(RecentFormLoader l, List<String> ids) async {
  for (var i = 0; i < 200; i++) {
    if (ids.every((p) =>
        l.status(p) == FormStatus.done || l.status(p) == FormStatus.failed)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('未在時限內完成：${ids.map(l.status).toList()}');
}

void main() {
  late _Env env;

  Future<_Env> setup({
    Map<String, int> history429 = const {},
    bool retryAfter = false,
    Map<String, int> otherHistoryStatus = const {},
    int maxConcurrent = 2,
  }) async {
    final waits = <Duration>[];
    final paths = <String>[];
    var inFlight = 0;
    var maxInFlight = 0;
    late _Env e;
    final inner = riotClient(
      history429: history429,
      retryAfter: retryAfter,
      otherHistoryStatus: otherHistoryStatus,
      matchDelay: const Duration(milliseconds: 5),
    );
    final client = MockClient((req) async {
      final pd = req.url.host.startsWith('pd.');
      if (pd) {
        paths.add(req.url.path);
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
    final loader = RecentFormLoader(MatchClient(rc), riot, MatchDetailCache(),
        maxConcurrent: maxConcurrent, delay: (d) async => waits.add(d));
    e = _Env(loader, riot, waits, paths, 0);
    return e;
  }

  tearDown(() => env.loader.dispose());

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
