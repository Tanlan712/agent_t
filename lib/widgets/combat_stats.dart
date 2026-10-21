import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/combat_stats.dart';
import '../providers/match_reference_provider.dart';
import '../providers/recent_form_loader.dart';
import '../theme/app_theme.dart';
import 'skin_tile.dart' show SkinIcon;

/// 帳號列讀最近 20 場（含總覽），隊伍卡片讀 5 場（只用最近一場）。
const selfStatsGames = 20;
const memberStatsGames = 5;

/// 向 [RecentFormLoader] 要求玩家的一般／競技場次與 MMR。
void requestCombatStats(BuildContext context, List<String> puuids,
        {required int games, Object? owner}) =>
    context.read<RecentFormLoader>().request(puuids,
        owner: owner,
        queue: standardQueues,
        games: games,
        profileFor: puuids.toSet());

String _queueLabel(String queueId) => switch (queueId) {
      'competitive' => '競技',
      'unrated' => '一般',
      _ => queueId,
    };

String _pct(double v) => '${v.round()}%';

/// 一位玩家的戰鬥數據：目前牌位與 RR、歷史最高與賽季、最近一場，
/// [summary] 時另外顯示最近幾場的總覽。
class CombatStatsView extends StatelessWidget {
  final String puuid;
  final int games;
  final bool summary;

  /// 隊伍卡片用的小字版。
  final bool dense;

  /// 測試可替換的時鐘（判斷本幕）。
  final DateTime Function() now;

  const CombatStatsView({
    super.key,
    required this.puuid,
    required this.games,
    this.summary = false,
    this.dense = false,
    this.now = DateTime.now,
  });

  @override
  Widget build(BuildContext context) {
    final loader = context.watch<RecentFormLoader>();
    final ref = context.watch<MatchReferenceProvider>();
    final seasons = ref.reference?.seasons ?? const {};
    final formStatus =
        loader.status(puuid, queue: standardQueues, games: games);
    final form = loader.form(puuid, queue: standardQueues, games: games);
    final profileStatus = loader.profileStatus(puuid);
    final mmr = loader.mmr(puuid);

    String loading(FormStatus s) => s == FormStatus.failed ? '無法取得' : '讀取中…';

    final current =
        mmr == null ? null : currentRank(mmr, currentActId(seasons, now()));
    final peak = mmr == null ? null : peakRank(mmr, seasons);
    final last = form?.games.firstOrNull;

    final items = <Widget>[
      _Stat(
        key: ValueKey('stats-current-$puuid'),
        label: '目前牌位',
        iconUrl: current == null ? null : ref.tier(current.tier).iconUrl,
        value: mmr == null
            ? loading(profileStatus)
            : current == null
                ? '未定級'
                : '${ref.tier(current.tier).name}・${current.rr} RR',
        dense: dense,
      ),
      _Stat(
        key: ValueKey('stats-peak-$puuid'),
        label: '歷史最高（推算）',
        iconUrl: peak == null ? null : ref.tier(peak.tier).iconUrl,
        value: mmr == null
            ? loading(profileStatus)
            : peak == null
                ? '—'
                : '${ref.tier(peak.tier).name}・${seasonLabel(seasons, peak.seasonId)}',
        dense: dense,
      ),
      _Stat(
        key: ValueKey('stats-last-$puuid'),
        label: last == null ? '最近一場' : '最近一場・${_queueLabel(last.queueId)}',
        value: form == null
            ? loading(formStatus)
            : last == null
                ? '最近沒有一般或競技場次'
                : [
                    '${last.kills} / ${last.deaths} / ${last.assists}',
                    if (last.rating case final r?) '表現 ${r.round()}',
                    'ACS ${last.acs}',
                    if (last.headshotPercent case final h?) '爆頭 ${_pct(h)}',
                  ].join('・'),
        dense: dense,
      ),
      if (summary)
        _Stat(
          key: ValueKey('stats-summary-$puuid'),
          label: form == null
              ? '最近 $games 場（一般＋競技）'
              : '最近 ${form.games.length} 場（一般＋競技）',
          value: form == null
              ? loading(formStatus)
              : form.games.isEmpty
                  ? '—'
                  : [
                      if (form.winRate case final w?) '勝率 ${_pct(w * 100)}',
                      if (form.avgKd case final kd?)
                        'K/D ${kd.toStringAsFixed(2)}',
                      if (form.avgAcs case final a?) 'ACS ${a.round()}',
                      if (form.avgHeadshot case final h?) '爆頭 ${_pct(h)}',
                    ].join('・'),
          dense: dense,
        ),
    ];
    return Wrap(
      spacing: dense ? 12 : 24,
      runSpacing: dense ? 6 : 10,
      children: items,
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final String? iconUrl;
  final bool dense;

  const _Stat({
    super.key,
    required this.label,
    required this.value,
    this.iconUrl,
    required this.dense,
  });

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
                  TextStyle(color: AppColors.muted, fontSize: dense ? 11 : 12)),
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            if (iconUrl != null) ...[
              SizedBox.square(
                  dimension: dense ? 16 : 20, child: SkinIcon(url: iconUrl)),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(value,
                  style: AppText.tabular(TextStyle(
                      fontSize: dense ? 12 : 14, fontWeight: FontWeight.w600))),
            ),
          ]),
        ],
      );
}
