import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agent_t/providers/match_detail_cache.dart';
import 'package:agent_t/providers/recent_form_loader.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/services/match_client.dart';
import 'package:agent_t/services/riot_client.dart';
import 'package:agent_t/storage/form_game_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:agent_t/logic/match_mapper.dart';

import '../match_fixtures.dart';
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
    {String? queue, int? games}) async {
  FormStatus st(String p) => l.status(p, queue: queue, games: games);
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
    Set<String> otherMmrHidden = const {},
    int maxConcurrent = 2,
    bool mixedQueues = false,
    FormGameStorage? store,
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
      otherMmrHidden: otherMmrHidden,
      matchDelay: const Duration(milliseconds: 5),
      mixedQueues: mixedQueues,
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
        maxConcurrent: maxConcurrent,
        store: store,
        delay: (d) async => waits.add(d));
    e = _Env(loader, riot, waits, paths, calls, 0);
    return e;
  }

  tearDown(() => env.loader.dispose());

  group('戰鬥數據', () {
    test('一般＋競技：不帶 queue 讀紀錄，略過其他模式，不讀它們的詳細資料', () async {
      env = await setup(mixedQueues: true);
      env.loader.request(['r1'], queue: standardQueues, games: 5);
      await _settle(env.loader, ['r1'], queue: standardQueues);
      final form = env.loader.form('r1', queue: standardQueues, games: 5)!;
      expect(form.games.map((g) => g.queueId),
          ['competitive', 'unrated', 'competitive', 'competitive']);
      final history =
          env.calls.where((u) => u.path.contains('/match-history/')).toList();
      expect(history, isNotEmpty);
      expect(history.every((u) => !u.queryParameters.containsKey('queue')),
          isTrue);
      expect(env.requestsFor('/match-details/v1/matches/r1-g1'), 0);
    });

    test('每場帶 K/D/A、表現分數、ACS、爆頭率、模式與時間', () async {
      env = await setup();
      env.loader.request(['r1'], queue: standardQueues, games: 1);
      await _settle(env.loader, ['r1'], queue: standardQueues, games: 1);
      final g =
          env.loader.form('r1', queue: standardQueues, games: 1)!.games.single;
      expect((g.kills, g.deaths, g.assists), (10, 10, 5));
      expect(g.rating, 452);
      expect(g.acs, 227);
      // 爆頭率與對戰詳細頁算法相同（mapMatchDetail）。
      final line = mapMatchDetail(matchDetailsJson(), 'r1')
          .teams
          .values
          .expand((t) => t)
          .firstWhere((l) => l.puuid == 'r1');
      expect(g.headshotPercent, line.headshotPercent);
      expect(g.queueId, 'competitive');
      expect(g.startTime, DateTime.fromMillisecondsSinceEpoch(1760900000000));
    });

    test('總覽：勝率、平均 K/D、平均 ACS、平均爆頭率', () async {
      env = await setup();
      FormGame g(bool? won, int k, int d, int acs, double? hs) => FormGame(
          matchId: 'x',
          won: won,
          acs: acs,
          agentId: 'a',
          kills: k,
          deaths: d,
          headshotPercent: hs);
      final f = RecentForm([
        g(true, 20, 10, 300, 30),
        g(false, 10, 10, 200, null),
        g(null, 6, 0, 100, 20),
      ]);
      expect(f.winRate, closeTo(0.5, 1e-9));
      expect(f.avgKd, closeTo(36 / 20, 1e-9));
      expect(f.avgAcs, closeTo(200, 1e-9));
      expect(f.avgHeadshot, closeTo(25, 1e-9));
      expect(const RecentForm([]).winRate, isNull);
      expect(const RecentForm([]).avgKd, isNull);
    });

    test('個人資料：讀一次 MMR；失敗時標成 failed，不影響戰績', () async {
      env = await setup(otherMmrStatus: {'r2': 500});
      env.loader.request(['r1', 'r2'],
          queue: standardQueues, games: 1, profileFor: {'r1', 'r2'});
      await _settle(env.loader, ['r1', 'r2'], queue: standardQueues, games: 1);
      expect(env.loader.profileStatus('r1'), FormStatus.done);
      expect(env.loader.mmr('r1'), isNotNull);
      expect(env.loader.profileStatus('r2'), FormStatus.failed);
      expect(env.loader.mmr('r2'), isNull);
      expect(env.loader.status('r2', queue: standardQueues, games: 1),
          FormStatus.done);
      // 同一位不重查。
      env.loader
          .request(['r1'], queue: standardQueues, games: 1, profileFor: {'r1'});
      await _settle(env.loader, ['r1'], queue: standardQueues, games: 1);
      expect(env.requestsFor('/mmr/v1/players/r1'), 1);
    });

    Future<void> profileSettled(String p) async {
      for (var i = 0; i < 400; i++) {
        final st = env.loader.profileStatus(p);
        if (st == FormStatus.done || st == FormStatus.failed) return;
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      fail('MMR 未在時限內完成：${env.loader.profileStatus(p)}');
    }

    test('卡住修正：離開頁面取消後，其他頁面用不同場數要求仍會讀 MMR', () async {
      env = await setup(maxConcurrent: 1);
      final page = Object();
      // 先佔住唯一的名額，r1 的工作才會排在佇列裡。
      env.loader.request(['r2'], queue: 'unrated');
      env.loader.request(['r1'],
          owner: page, queue: standardQueues, profileFor: {'r1'});
      env.loader.cancelPending(owner: page);
      env.loader
          .request(['r1'], queue: standardQueues, games: 1, profileFor: {'r1'});
      await profileSettled('r1');
      expect(env.loader.profileStatus('r1'), FormStatus.done);
      expect(env.loader.mmr('r1'), isNotNull);
    });

    test('卡住修正：MMR 回 401 時標成失敗，不會一直讀取中', () async {
      env = await setup(otherMmrStatus: {'r1': 401});
      env.loader
          .request(['r1'], queue: standardQueues, games: 1, profileFor: {'r1'});
      await profileSettled('r1');
      expect(env.loader.profileStatus('r1'), FormStatus.failed);
    });

    test('卡住修正：戰績還在讀取時按同步（forget）後，MMR 仍會重讀', () async {
      env = await setup();
      env.loader.request(['r1'],
          queue: standardQueues, games: 10, profileFor: {'r1'});
      await profileSettled('r1');
      // 戰績（10 場）可能還在讀取；這時清掉並重新要求。
      env.loader.forget('r1');
      env.loader.request(['r1'],
          queue: standardQueues, games: 10, profileFor: {'r1'});
      await profileSettled('r1');
      expect(env.loader.profileStatus('r1'), FormStatus.done);
      expect(env.requestsFor('/mmr/v1/players/r1'), 2);
    });

    test('重新讀取：清掉這位玩家的結果後再要求會重抓', () async {
      env = await setup();
      env.loader
          .request(['r1'], queue: standardQueues, games: 1, profileFor: {'r1'});
      await _settle(env.loader, ['r1'], queue: standardQueues, games: 1);
      final before = env.requestsFor('/match-history/');
      env.loader.forget('r1');
      expect(env.loader.status('r1', queue: standardQueues, games: 1),
          FormStatus.pending);
      expect(env.loader.mmr('r1'), isNull);
      env.loader
          .request(['r1'], queue: standardQueues, games: 1, profileFor: {'r1'});
      await _settle(env.loader, ['r1'], queue: standardQueues, games: 1);
      expect(env.requestsFor('/match-history/'), before + 1);
      expect(env.requestsFor('/mmr/v1/players/r1'), 2);
    });
  });
  group('賽季牌位', () {
    test('牌位未知的玩家另外查 MMR，同一季只查一次', () async {
      env = await setup();
      env.loader.request(['r1', 'mate'],
          queue: 'unrated', seasonId: 'season-1', rankFor: {'r1'});
      await _settle(env.loader, ['r1', 'mate'], queue: 'unrated');
      final r1 = env.loader.rank('r1', 'season-1');
      expect(r1.status, RankStatus.visible);
      expect(r1.seasonTier, 21);
      expect(env.loader.rank('mate', 'season-1').status, RankStatus.pending);
      expect(env.requestsFor('/mmr/v1/players/r1'), 1);
      expect(env.requestsFor('/mmr/v1/players/mate'), 0);
      env.loader.request(['r1'],
          queue: 'swiftplay', seasonId: 'season-1', rankFor: {'r1'});
      await _settle(env.loader, ['r1'], queue: 'swiftplay');
      expect(env.requestsFor('/mmr/v1/players/r1'), 1);
    });

    test('使用者決定：對方隱藏牌位也直接提供這季牌位', () async {
      env = await setup(otherMmrHidden: {'r1'});
      env.loader.request(['r1'],
          queue: 'unrated', seasonId: 'season-1', rankFor: {'r1'});
      await _settle(env.loader, ['r1'], queue: 'unrated');
      final r1 = env.loader.rank('r1', 'season-1');
      expect(r1.status, RankStatus.visible);
      expect(r1.seasonTier, 21);
    });

    test('MMR 403 時無法確認（unavailable），最近戰績照常完成', () async {
      env = await setup(otherMmrStatus: {'r1': 403});
      env.loader.request(['r1'],
          queue: 'unrated', seasonId: 'season-1', rankFor: {'r1'});
      await _settle(env.loader, ['r1'], queue: 'unrated');
      expect(env.loader.rank('r1', 'season-1').status, RankStatus.unavailable);
      expect(env.loader.rank('r1', 'season-1').seasonTier, isNull);
      expect(env.loader.status('r1', queue: 'unrated'), FormStatus.done);
      expect(env.riot.isLoggedIn, isTrue);
    });
  });
  group('多讀場次', () {
    test('指定 games: 10 時另外快取 10 場，預設 5 場不受影響', () async {
      env = await setup();
      env.loader.request(['r1'], queue: 'competitive', games: 10);
      for (var i = 0; i < 200; i++) {
        if (env.loader.status('r1', queue: 'competitive', games: 10) ==
            FormStatus.done) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(
          env.loader.form('r1', queue: 'competitive', games: 10)!.games.length,
          10);
      expect(env.loader.status('r1', queue: 'competitive'), FormStatus.pending);
      final h = env.calls.where((u) => u.path.endsWith('/history/r1')).single;
      expect(h.queryParameters['endIndex'], '10');
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

  group('已結束場次快取', () {
    test('自己的場次存成摘要，重開後不再抓 match-details', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FormGameStorage(await SharedPreferences.getInstance());
      env = await setup(store: store);
      env.loader.request([myPuuid], queue: standardQueues, games: 3);
      await _settle(env.loader, [myPuuid], queue: standardQueues, games: 3);
      final first =
          env.loader.form(myPuuid, queue: standardQueues, games: 3)!.games;
      expect(first, hasLength(3));
      expect(env.requestsFor('/match-details/'), 3);
      env.loader.dispose();

      // 模擬重開網頁：新的載入器與記憶體快取，只剩本機的摘要。
      env = await setup(store: store);
      env.loader.request([myPuuid], queue: standardQueues, games: 3);
      await _settle(env.loader, [myPuuid], queue: standardQueues, games: 3);
      final again =
          env.loader.form(myPuuid, queue: standardQueues, games: 3)!.games;
      expect(env.requestsFor('/match-details/'), 0);
      expect(env.requestsFor('/match-history/'), 1);
      expect([for (final g in again) g.matchId],
          [for (final g in first) g.matchId]);
      expect(
          [for (final g in again) (g.acs, g.kills, g.won, '${g.weaponKills}')],
          [for (final g in first) (g.acs, g.kills, g.won, '${g.weaponKills}')]);
    });

    test('其他玩家不寫入快取', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FormGameStorage(await SharedPreferences.getInstance());
      env = await setup(store: store);
      env.loader.request(['r1']);
      await _settle(env.loader, ['r1']);
      expect(store.load('r1'), isEmpty);
    });

    test('每位玩家最多保留 60 場，丟掉最舊的', () async {
      SharedPreferences.setMockInitialValues({});
      final store = FormGameStorage(await SharedPreferences.getInstance());
      env = await setup();
      await store.save('p', [
        for (var i = 0; i < 70; i++)
          FormGame(
              matchId: 'g$i',
              won: i.isEven,
              acs: i,
              agentId: 'a',
              startTime: DateTime.utc(2026, 1, 1).add(Duration(hours: i))),
      ]);
      final kept = store.load('p');
      expect(kept, hasLength(FormGameStorage.maxPerPlayer));
      expect(kept.containsKey('g69'), isTrue);
      expect(kept.containsKey('g9'), isFalse);
      expect(kept['g10']!.won, isTrue);
    });
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
