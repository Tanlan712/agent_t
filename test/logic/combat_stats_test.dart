import 'package:flutter_test/flutter_test.dart';
import 'package:valorant_shop_tracker/logic/combat_stats.dart';
import 'package:valorant_shop_tracker/models/match_models.dart';

Map<String, dynamic> mmr(Map<String, Map<String, dynamic>> seasons) => {
      'QueueSkills': {
        'competitive': {'SeasonalInfoBySeasonID': seasons},
      },
    };

void main() {
  final seasons = {
    'old': SeasonRef(
        name: '第四章 第一幕',
        start: DateTime.utc(2022, 1, 11),
        end: DateTime.utc(2022, 3, 1),
        isAct: true),
    'a5': SeasonRef(
        name: 'V25 第五幕',
        start: DateTime.utc(2025, 8, 1),
        end: DateTime.utc(2025, 10, 1),
        isAct: true),
    'now': SeasonRef(
        name: 'V26 第六幕',
        start: DateTime.utc(2026, 10, 14),
        end: DateTime.utc(2027, 1, 6),
        isAct: true),
    'ep': SeasonRef(
        name: 'V26',
        start: DateTime.utc(2026, 6, 24),
        end: DateTime.utc(2027, 1, 6),
        isAct: false),
  };
  final now = DateTime.utc(2026, 10, 22);

  test('本幕：現在時間所在的 Act（不是上層賽季）', () {
    expect(currentActId(seasons, now), 'now');
    expect(currentActId(seasons, DateTime.utc(2020)), isNull);
  });

  test('目前牌位與 RR；沒有本幕資料或 tier 0 時為 null', () {
    final m = mmr({
      'now': {'CompetitiveTier': 15, 'RankedRating': 47},
    });
    final r = currentRank(m, 'now')!;
    expect(r.tier, 15);
    expect(r.rr, 47);
    expect(currentRank(m, 'a5'), isNull);
    expect(
        currentRank(
            mmr({
              'now': {'CompetitiveTier': 0}
            }),
            'now'),
        isNull);
    expect(currentRank(const {}, 'now'), isNull);
    expect(currentRank(m, null), isNull);
  });

  test('最高牌位：WinsByTier 有勝場的最高 tier，沒有時用 CompetitiveTier', () {
    final m = mmr({
      'a5': {
        'CompetitiveTier': 15,
        'WinsByTier': {'14': 3, '18': 1, '19': 0},
      },
      'now': {'CompetitiveTier': 16},
    });
    final p = peakRank(m, seasons)!;
    expect(p.tier, 18);
    expect(p.seasonId, 'a5');
  });

  test('最高牌位：第五章以前的舊制神話（21）換算成新制（24），不會被當成超凡', () {
    final m = mmr({
      'old': {
        'CompetitiveTier': 21,
        'WinsByTier': {'21': 2}
      },
      'now': {
        'CompetitiveTier': 23,
        'WinsByTier': {'23': 1}
      },
    });
    final p = peakRank(m, seasons)!;
    expect(p.tier, 24);
    expect(p.seasonId, 'old');
    expect(normalizeTier(24, DateTime.utc(2021)), 27);
    expect(normalizeTier(20, DateTime.utc(2021)), 20);
    expect(normalizeTier(21, DateTime.utc(2023)), 21);
    expect(normalizeTier(21, null), 21);
    // 第五章第一幕 2022-06-21 開始（valorant-api 實測）：當天起是新制。
    expect(normalizeTier(21, DateTime.utc(2022, 6, 21)), 21);
    expect(normalizeTier(26, DateTime.utc(2022, 6, 21)), 26);
    // 第四章第三幕（舊制）。
    expect(normalizeTier(21, DateTime.utc(2022, 4, 27)), 24);
  });

  test('最高牌位同分時取較新的一季；沒有任何牌位時為 null', () {
    final m = mmr({
      'a5': {'CompetitiveTier': 18},
      'now': {'CompetitiveTier': 18},
    });
    expect(peakRank(m, seasons)!.seasonId, 'now');
    expect(
        peakRank(
            mmr({
              'a5': {'CompetitiveTier': 0}
            }),
            seasons),
        isNull);
    expect(peakRank(const {}, seasons), isNull);
  });

  test('本幕查不到時，改用 MMR 最近一次競技更新的賽季', () {
    expect(
        latestSeasonId({
          'LatestCompetitiveUpdate': {'SeasonID': 'NOW'}
        }),
        'now');
    expect(latestSeasonId(const {}), isNull);
  });

  test('賽季名稱：查不到時顯示「未知賽季」', () {
    expect(seasonLabel(seasons, 'a5'), 'V25 第五幕');
    expect(seasonLabel(seasons, 'zzz'), '未知賽季');
  });
}
