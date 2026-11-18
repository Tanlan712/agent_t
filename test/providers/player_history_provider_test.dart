import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:agent_t/models/match_models.dart';
import 'package:agent_t/providers/match_detail_cache.dart';
import 'package:agent_t/providers/match_history_provider.dart';
import 'package:agent_t/providers/player_history_provider.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/services/match_client.dart';
import 'package:agent_t/services/riot_client.dart';

import '../match_fixtures.dart';
import '../riot_fixtures.dart';

void main() {
  Future<(PlayerHistoryProvider, RiotProvider)> setup(
      {Map<String, int> otherHistoryStatus = const {}}) async {
    final rc = RiotClient(
        client: riotClient(
            otherHistoryStatus: otherHistoryStatus, blankNames: true));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1', pageSize: 3);
    return (p, riot);
  }

  test('第一頁 3 筆，摘要以該玩家為主，isMe 仍是自己', () async {
    final (p, _) = await setup();
    await p.loadFirstPage();
    expect(p.entries.length, 3);
    expect(p.hasMore, isTrue);
    final d = p.entries.first.detail!;
    expect(d.summary.myAgentId, 'agent-r1');
    expect(d.summary.myTeamId, 'Red');
    expect(d.summary.acs, 227);
    // 他的每場 RR 由他的競技更新算出（m1 是第 0 場：+20）。
    expect(d.summary.rrChange, 20);
    final me = d.teams.values.expand((t) => t).singleWhere((l) => l.isMe);
    expect(me.puuid, myPuuid);
    // 名稱由 name-service 補上。
    expect(d.teams['Red']!.first.riotId, 'N-r1#TW1');
    expect(p.rank!.tier, 21);
    expect(p.rank!.rr, 40);
    expect(p.mmr, isNotNull);
    expect(p.recentRr, [20, -15, 20, -15, 20]);
  });

  test('載入超過 20 場時補讀競技更新，後面的場次也有 RR', () async {
    final requests = <http.Request>[];
    final rc = RiotClient(client: riotClient(requests: requests));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1', pageSize: 20);
    await p.loadFirstPage();
    await p.loadMore();
    expect(p.entries.length, 30);
    expect(p.entries.last.detail!.summary.rrChange, -15);
    final updates = requests
        .where((r) => r.url.path.endsWith('/r1/competitiveupdates'))
        .map((r) => r.url.queryParameters['startIndex'])
        .toList();
    expect(updates, ['0', '20']);
  });

  test('他的 MMR 與競技更新 403 時列表照常、沒有牌位', () async {
    final rc = RiotClient(client: riotClient(otherMmrStatus: {'r1': 403}));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1', pageSize: 3);
    await p.loadFirstPage();
    expect(p.error, isNull);
    expect(p.entries.length, 3);
    expect(p.rank, isNull);
    expect(p.entries.first.detail!.summary.rrChange, isNull);
    expect(riot.isLoggedIn, isTrue);
  });

  test('載入更多接在後面', () async {
    final (p, _) = await setup();
    await p.loadFirstPage();
    await p.loadMore();
    expect(p.entries.map((e) => e.ref.matchId).toList(),
        ['m1', 'r1-g1', 'r1-g2', 'r1-g3', 'r1-g4', 'r1-g5']);
  });

  test('網頁上限流只看到連線失敗時退避重試，之後成功載入', () async {
    final inner = riotClient(blankNames: true);
    var historyFailures = 0;
    final waits = <Duration>[];
    final rc = RiotClient(client: MockClient((req) async {
      if (req.url.path.startsWith('/match-history/') && historyFailures < 2) {
        historyFailures++;
        throw http.ClientException('XMLHttpRequest error.');
      }
      final copy = http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes;
      return http.Response.fromStream(await inner.send(copy));
    }));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1', pageSize: 3, delay: (d) async => waits.add(d));
    await p.loadFirstPage();
    expect(p.error, isNull);
    expect(p.entries.length, 3);
    expect(waits, [const Duration(seconds: 2), const Duration(seconds: 4)]);
  });

  test('第一頁 500 時有錯誤訊息', () async {
    final (p, riot) = await setup(otherHistoryStatus: {'r1': 500});
    await p.loadFirstPage();
    expect(p.error, isNotNull);
    expect(p.entries, isEmpty);
    expect(riot.isLoggedIn, isTrue);
  });

  test('403 只顯示錯誤，不登出', () async {
    final (p, riot) = await setup(otherHistoryStatus: {'r1': 403});
    await p.loadFirstPage();
    expect(p.error, MatchHistoryProvider.notProvidedMessage);
    expect(MatchHistoryProvider.notProvidedMessage, 'Riot 不提供這位玩家的紀錄');
    expect(riot.isLoggedIn, isTrue);
  });

  test('401 登出', () async {
    final (p, riot) = await setup(otherHistoryStatus: {'r1': 401});
    await p.loadFirstPage();
    expect(riot.isLoggedIn, isFalse);
    expect(p.error, MatchHistoryProvider.expiredMessage);
  });

  test('沒有指定 pageSize 時每頁 10 場（減少一次送出的請求）', () async {
    final rc = RiotClient(client: riotClient());
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1');
    await p.loadFirstPage();
    expect(p.error, isNull);
    expect(p.entries.length, 10);
    expect(p.entries.map((e) => e.ref.matchId).toSet().length, 10);
  });

  test('每頁載入完成後把補上名稱的詳情交給 onDetails', () async {
    final rc = RiotClient(client: riotClient(blankNames: true));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final seen = <MatchDetail>[];
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1', pageSize: 3, onDetails: seen.addAll);
    await p.loadFirstPage();
    expect(seen.length, 3);
    expect(seen.first.teams['Red']!.first.riotId, 'N-r1#TW1');
  });

  test('對戰詳情逐場顯示：還在讀時先有骨架，不用等整頁', () async {
    final rc = RiotClient(
        client: riotClient(matchDelay: const Duration(milliseconds: 30)));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1', pageSize: 6);
    final snapshots = <(int, int)>[];
    p.addListener(() => snapshots.add((
          p.entries.length,
          p.entries.where((e) => e.detail != null).length,
        )));
    await p.loadFirstPage();
    // 列表一拿到就有 6 張骨架，之後逐場換上。
    expect(snapshots, contains((6, 0)));
    expect(snapshots, contains((6, 1)));
    expect(p.entries.every((e) => e.detail != null), isTrue);
    expect(p.entries.first.detail!.summary.rrChange, 20);
  });

  test('單場失敗後可以重試失敗的場次', () async {
    final fail = {'r1-g1', 'r1-g2'};
    final inner = riotClient(blankNames: true);
    final rc = RiotClient(
        pvpCooldown: false,
        client: MockClient((req) async {
          if (fail.contains(req.url.pathSegments.last)) {
            return http.Response('{}', 500);
          }
          final copy = http.Request(req.method, req.url)
            ..headers.addAll(req.headers)
            ..bodyBytes = req.bodyBytes;
          return http.Response.fromStream(await inner.send(copy));
        }));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1', pageSize: 3);
    await p.loadFirstPage();
    expect(p.failedCount, 2);
    fail.clear();
    await p.retryFailed();
    expect(p.failedCount, 0);
    expect(p.entries.every((e) => e.detail != null), isTrue);
    expect(p.entries[1].detail!.teams['Red']!.first.riotId, 'N-r1#TW1');
  });

  test('牌位讀不到時標成失敗（不是未定級）', () async {
    final rc = RiotClient(client: riotClient(otherMmrStatus: {'r1': 500}));
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1', pageSize: 3);
    await p.loadFirstPage();
    expect(p.rank, isNull);
    expect(p.rankFailed, isTrue);
    expect(p.rankLoading, isFalse);
  });

  test('載入中 dispose 不會丟出例外', () async {
    final (p, _) = await setup();
    final f = p.loadFirstPage();
    p.dispose();
    await f;
  });
}
