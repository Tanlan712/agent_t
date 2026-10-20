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
