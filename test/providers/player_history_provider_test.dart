import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';
import 'package:valorant_shop_tracker/providers/match_detail_cache.dart';
import 'package:valorant_shop_tracker/providers/match_history_provider.dart';
import 'package:valorant_shop_tracker/providers/player_history_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/services/match_client.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';

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
    expect(d.summary.rrChange, isNull);
    final me = d.teams.values.expand((t) => t).singleWhere((l) => l.isMe);
    expect(me.puuid, myPuuid);
    // 名稱由 name-service 補上。
    expect(d.teams['Red']!.first.riotId, 'N-r1#TW1');
    expect(p.rank, isNull);
  });

  test('載入更多接在後面', () async {
    final (p, _) = await setup();
    await p.loadFirstPage();
    await p.loadMore();
    expect(p.entries.map((e) => e.ref.matchId).toList(),
        ['m1', 'r1-g1', 'r1-g2', 'r1-g3', 'r1-g4', 'r1-g5']);
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

  test('沒有指定 pageSize 時每頁 20 場', () async {
    final rc = RiotClient(client: riotClient());
    final riot = RiotProvider(rc);
    await riot.login(fakeRedirect);
    final p = PlayerHistoryProvider(MatchClient(rc), riot, MatchDetailCache(),
        puuid: 'r1');
    await p.loadFirstPage();
    expect(p.entries.length, 20);
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

  test('載入中 dispose 不會丟出例外', () async {
    final (p, _) = await setup();
    final f = p.loadFirstPage();
    p.dispose();
    await f;
  });
}
