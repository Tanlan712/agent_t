import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:valorant_shop_tracker/providers/match_history_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/match_client.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

import '../riot_fixtures.dart';

/// 包一層計數：記錄每個 match-details 請求與同時進行中的最大數量。
class _Counting {
  int matchRequests = 0;
  int historyRequests = 0;
  int inFlight = 0;
  int maxInFlight = 0;

  http.Client wrap(http.Client inner) => MockClient((req) async {
        if (req.url.path.contains('match-history')) historyRequests++;
        final isMatch = req.url.path.contains('match-details');
        if (isMatch) {
          matchRequests++;
          inFlight++;
          if (inFlight > maxInFlight) maxInFlight = inFlight;
        }
        try {
          // MockClient 已 finalize 原請求，轉送前要複製一份。
          final copy = http.Request(req.method, req.url)
            ..headers.addAll(req.headers)
            ..bodyBytes = req.bodyBytes;
          return await inner.send(copy).then(http.Response.fromStream);
        } finally {
          if (isMatch) inFlight--;
        }
      });
}

void main() {
  group('第二階段修正', phase2FixTests);
  group('名稱補查', nameTests);
  group('審查修正', reviewFixTests);
  Future<(MatchHistoryProvider, RiotProvider, _Counting)> setup({
    int historyTotal = 25,
    int historyStatus = 200,
    Set<String> failMatchIds = const {},
    Duration matchDelay = Duration.zero,
    int pageSize = 10,
    int maxConcurrent = 4,
    bool login = true,
  }) async {
    final counting = _Counting();
    final client = counting.wrap(riotClient(
      historyTotal: historyTotal,
      historyStatus: historyStatus,
      failMatchIds: failMatchIds,
      matchDelay: matchDelay,
    ));
    final riotClientObj = RiotClient(client: client);
    final riot = RiotProvider(riotClientObj);
    if (login) await riot.login(fakeRedirect);
    final p = MatchHistoryProvider(MatchClient(riotClientObj), riot,
        pageSize: pageSize, maxConcurrent: maxConcurrent);
    return (p, riot, counting);
  }

  test('第一頁：每筆都有詳情、hasMore、牌位與 RR', () async {
    final (p, _, _) = await setup(pageSize: 3);
    await p.loadFirstPage();
    expect(p.entries.length, 3);
    expect(p.entries.every((e) => e.detail != null && !e.failed), isTrue);
    expect(p.hasMore, isTrue);
    expect(p.rank!.tier, 18);
    expect(p.rank!.rr, 45);
    expect(p.recentRr, [18, -15]);
    expect(p.entries.first.detail!.summary.rrChange, 18);
    expect(p.detail('m1'), isNotNull);
    expect(p.error, isNull);
    expect(p.isLoading, isFalse);
  });

  test('Total 已全部載入時 hasMore 為 false 且 loadMore 不再請求', () async {
    final (p, _, c) = await setup(historyTotal: 3, pageSize: 10);
    await p.loadFirstPage();
    expect(p.entries.length, 3);
    expect(p.hasMore, isFalse);
    final before = c.historyRequests;
    await p.loadMore();
    expect(c.historyRequests, before);
  });

  test('loadMore 接續下一頁', () async {
    final (p, _, _) = await setup(historyTotal: 25, pageSize: 10);
    await p.loadFirstPage();
    await p.loadMore();
    expect(p.entries.length, 20);
    expect(p.entries[10].ref.matchId, 'm11');
  });

  test('單場詳情 500 只標記該筆失敗', () async {
    final (p, _, _) = await setup(pageSize: 3, failMatchIds: {'m2'});
    await p.loadFirstPage();
    expect(p.entries[1].failed, isTrue);
    expect(p.entries[1].detail, isNull);
    expect(p.entries[0].detail, isNotNull);
    expect(p.entries[2].detail, isNotNull);
    expect(p.error, isNull);
  });

  test('並行上限', () async {
    final (p, _, c) = await setup(
        pageSize: 10,
        maxConcurrent: 2,
        matchDelay: const Duration(milliseconds: 20));
    await p.loadFirstPage();
    expect(c.matchRequests, 10);
    expect(c.maxInFlight, lessThanOrEqualTo(2));
    expect(c.maxInFlight, 2);
  });

  test('401 時登出並顯示訊息', () async {
    final (p, riot, _) = await setup(historyStatus: 401);
    await p.loadFirstPage();
    expect(riot.isLoggedIn, isFalse);
    expect(p.error, '登入已過期，請重新登入');
    expect(p.isLoading, isFalse);
  });

  test('未登入時不發出請求', () async {
    final (p, _, c) = await setup(login: false);
    await p.loadFirstPage();
    expect(p.error, '請先登入 Riot');
    expect(c.historyRequests, 0);
    expect(c.matchRequests, 0);
  });
}

void reviewFixTests() {
  Future<(MatchHistoryProvider, RiotProvider)> make(http.Client client) async {
    final rc = RiotClient(client: client);
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    return (MatchHistoryProvider(MatchClient(rc), riot, pageSize: 3), riot);
  }

  test('歷史格式不符時顯示錯誤而非丟出例外', () async {
    final (p, _) = await make(riotClient(brokenHistory: true));
    await p.loadFirstPage();
    expect(p.error, '資料格式不符');
    expect(p.isLoading, isFalse);
  });

  test('牌位請求失敗不影響列表', () async {
    final (p, riot) = await make(riotClient(mmrStatus: 500));
    await p.loadFirstPage();
    expect(p.entries.length, 3);
    expect(p.rank, isNull);
    expect(p.error, isNull);
    expect(riot.isLoggedIn, isTrue);
  });

  test('重複呼叫 loadFirstPage 不會產生重複資料', () async {
    final (p, _) =
        await make(riotClient(matchDelay: const Duration(milliseconds: 20)));
    final first = p.loadFirstPage();
    final second = p.loadFirstPage();
    await Future.wait([first, second]);
    expect(p.entries.length, 3);
    expect(p.entries.map((e) => e.ref.matchId).toSet().length, 3);
  });

  test('loadMore 進行中被 loadFirstPage 取代時不混入舊頁', () async {
    final (p, _) =
        await make(riotClient(matchDelay: const Duration(milliseconds: 20)));
    await p.loadFirstPage();
    final more = p.loadMore();
    final reset = p.loadFirstPage();
    await Future.wait([more, reset]);
    expect(p.entries.map((e) => e.ref.matchId).toList(), ['m1', 'm2', 'm3']);
  });
}

void nameTests() {
  Future<MatchHistoryProvider> make(http.Client client) async {
    final rc = RiotClient(client: client);
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    return MatchHistoryProvider(MatchClient(rc), riot, pageSize: 2);
  }

  test('詳情沒有名稱時改用 name-service 補上', () async {
    final p = await make(riotClient(blankNames: true));
    await p.loadFirstPage();
    final lines =
        p.entries.first.detail!.teams.values.expand((t) => t).toList();
    expect(lines.singleWhere((l) => l.isMe).riotId, 'N-puuid-1#TW1');
    expect(lines.singleWhere((l) => l.puuid == 'r1').riotId, 'N-r1#TW1');
    expect(lines.singleWhere((l) => l.puuid == 'r5').riotId, '未知玩家');
    expect(p.detail('m2')!.teams['Blue']!.first.riotId, startsWith('N-'));
  });

  test('name-service 失敗時仍顯示列表，名稱維持未知玩家', () async {
    final p = await make(riotClient(blankNames: true, nameStatus: 500));
    await p.loadFirstPage();
    expect(p.entries.length, 2);
    expect(p.error, isNull);
    final me = p.entries.first.detail!.teams.values
        .expand((t) => t)
        .singleWhere((l) => l.isMe);
    expect(me.riotId, '未知玩家');
  });
}

void phase2FixTests() {
  Future<(MatchHistoryProvider, RiotProvider)> make(http.Client client) async {
    final rc = RiotClient(client: client);
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    return (MatchHistoryProvider(MatchClient(rc), riot, pageSize: 2), riot);
  }

  test('401 後清除 loadedFor，同帳號重新登入時會重新載入', () async {
    final (p, riot) = await make(riotClient(historyStatus: 401));
    await p.loadFirstPage();
    expect(riot.isLoggedIn, isFalse);
    expect(p.loadedFor, isNull);
  });

  test('name-service 回應格式不符時保留列表', () async {
    final (p, _) =
        await make(riotClient(blankNames: true, nameMalformed: true));
    await p.loadFirstPage();
    expect(p.entries.length, 2);
    expect(p.error, isNull);
  });
}
