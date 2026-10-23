import 'package:flutter/material.dart';

import '../logic/match_highlights.dart';
import '../models/match_models.dart';
import '../providers/match_reference_provider.dart';
import '../theme/app_theme.dart';
import 'skin_tile.dart' show SkinIcon;

String roundEndLabel(RoundEnd e) => switch (e) {
      RoundEnd.elimination => '清光',
      RoundEnd.detonate => '爆炸',
      RoundEnd.defuse => '拆包',
      RoundEnd.timer => '時間到',
      RoundEnd.surrender => '投降',
      RoundEnd.unknown => '—',
    };

IconData roundEndIcon(RoundEnd e) => switch (e) {
      RoundEnd.elimination => Icons.close,
      RoundEnd.detonate => Icons.local_fire_department,
      RoundEnd.defuse => Icons.content_cut,
      RoundEnd.timer => Icons.timer_outlined,
      RoundEnd.surrender => Icons.flag_outlined,
      RoundEnd.unknown => Icons.remove,
    };

String _short(String riotId) => riotId.split('#').first;

Widget _card(BuildContext context, String title, Widget child, {Key? key}) =>
    Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );

/// 主角這場的多殺與殘局（Ace、4K、3K、1vX）。
class MatchHighlightsCard extends StatelessWidget {
  final MatchDetail detail;
  final String puuid;

  const MatchHighlightsCard(
      {super.key, required this.detail, required this.puuid});

  @override
  Widget build(BuildContext context) {
    final h = matchHighlights(detail, puuid);
    return _card(
      context,
      '多殺與殘局',
      key: const ValueKey('match-highlights'),
      h.isEmpty
          ? Text('這場沒有 3 殺以上或殘局勝利', style: TextStyle(color: AppColors.muted))
          : HighlightChips(h),
    );
  }
}

/// Ace／4K／3K／1vX 的小標籤列。
class HighlightChips extends StatelessWidget {
  final PlayerHighlights h;

  const HighlightChips(this.h, {super.key});

  @override
  Widget build(BuildContext context) {
    final keys = h.clutches.keys.toList()..sort((a, b) => b.compareTo(a));
    final items = [
      if (h.aces > 0) ('Ace', h.aces, AppColors.warn),
      if (h.fourKs > 0) ('4 殺', h.fourKs, AppColors.primary),
      if (h.threeKs > 0) ('3 殺', h.threeKs, AppColors.info),
      for (final k in keys) ('1v$k 殘局', h.clutches[k]!, AppColors.win),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (label, n, color) in items)
        Container(
          key: ValueKey('highlight-$label'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text('$label × $n',
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}

/// 回合時間軸：每回合勝方與結束方式；點一回合看下包者與各人經濟。
class RoundTimeline extends StatefulWidget {
  final MatchDetail detail;
  final MatchReferenceProvider ref;

  const RoundTimeline({super.key, required this.detail, required this.ref});

  @override
  State<RoundTimeline> createState() => _RoundTimelineState();
}

class _RoundTimelineState extends State<RoundTimeline> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final d = widget.detail;
    final rounds = d.rounds;
    if (rounds.isEmpty) return const SizedBox.shrink();
    final myTeam = d.summary.myTeamId;
    final sel = rounds[_selected.clamp(0, rounds.length - 1)];
    return _card(
      context,
      '回合時間軸',
      key: const ValueKey('round-timeline'),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final (i, r) in rounds.indexed) ...[
              // 第 12 回合後換邊。
              if (i == 12) const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: _RoundChip(
                  key: ValueKey('round-chip-${r.number}'),
                  round: r,
                  won: r.winningTeam.isEmpty ? null : r.winningTeam == myTeam,
                  selected: identical(r, sel),
                  onTap: () => setState(() => _selected = i),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        _RoundDetail(round: sel, detail: d, ref: widget.ref),
      ]),
    );
  }
}

class _RoundChip extends StatelessWidget {
  final RoundInfo round;
  final bool? won;
  final bool selected;
  final VoidCallback onTap;

  const _RoundChip(
      {super.key,
      required this.round,
      required this.won,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color =
        won == null ? AppColors.muted : (won! ? AppColors.win : AppColors.loss);
    return Tooltip(
      message: '第 ${round.number + 1} 回合・${roundEndLabel(round.end)}',
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          width: 34,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(selected ? 0.35 : 0.15),
            border: Border.all(
                color: selected ? color : color.withOpacity(0), width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(children: [
            Text('${round.number + 1}',
                style: AppText.tabular(TextStyle(
                    fontSize: 11, color: AppColors.muted, height: 1.1))),
            const SizedBox(height: 2),
            Icon(roundEndIcon(round.end), size: 16, color: color),
          ]),
        ),
      ),
    );
  }
}

class _RoundDetail extends StatelessWidget {
  final RoundInfo round;
  final MatchDetail detail;
  final MatchReferenceProvider ref;

  const _RoundDetail(
      {required this.round, required this.detail, required this.ref});

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final myTeam = d.summary.myTeamId;
    final teamOf = d.teamOf;
    final lines = {
      for (final p in d.teams.values.expand((t) => t)) p.puuid: p,
    };
    String name(String? id) =>
        id == null ? '—' : _short(lines[id]?.riotId ?? '未知玩家');
    final eco = teamEconomy(round, teamOf, myTeam);
    final myCount =
        round.players.keys.where((id) => teamOf[id] == myTeam).length;
    final enemyCount = round.players.keys
        .where((id) => teamOf[id] != null && teamOf[id] != myTeam)
        .length;
    final won = round.winningTeam == myTeam;
    final muted = TextStyle(color: AppColors.muted, fontSize: 13);

    final teamIds = d.teams.keys.toList()
      ..sort((a, b) => a == myTeam ? -1 : (b == myTeam ? 1 : a.compareTo(b)));

    return Column(
      key: ValueKey('round-detail-${round.number}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(spacing: 16, runSpacing: 6, children: [
          Text('第 ${round.number + 1} 回合',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(
              round.winningTeam.isEmpty
                  ? roundEndLabel(round.end)
                  : '${won ? '我方' : '敵方'}勝・${roundEndLabel(round.end)}',
              style: TextStyle(
                  color: won ? AppColors.win : AppColors.loss,
                  fontWeight: FontWeight.w600)),
          if (round.planter != null) Text('下包：${name(round.planter)}'),
          if (round.defuser != null) Text('拆包：${name(round.defuser)}'),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 4, children: [
          Text(
              '我方裝備 ${eco.myLoadout}（${buyLabel(eco.myLoadout, myCount)}）・花費 ${eco.mySpent}',
              style: AppText.tabular(muted)),
          Text(
              '敵方裝備 ${eco.enemyLoadout}（${buyLabel(eco.enemyLoadout, enemyCount)}）・花費 ${eco.enemySpent}',
              style: AppText.tabular(muted)),
        ]),
        const SizedBox(height: 8),
        // 寬螢幕撐滿卡片寬度；窄螢幕放不下時可以左右捲動。
        LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: c.maxWidth),
              child: DataTable(
                columnSpacing: 16,
                headingRowHeight: 32,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 40,
                columns: [
                  for (final h in ['玩家', '武器', '裝備價值', '花費', '剩餘', '擊殺', '傷害'])
                    DataColumn(label: Text(h, style: muted)),
                ],
                rows: [
                  for (final team in teamIds)
                    for (final p in d.teams[team]!)
                      if (round.players[p.puuid] case final rp?)
                        DataRow(
                          color: p.isMe
                              ? WidgetStatePropertyAll(AppColors.surfaceHigh)
                              : null,
                          cells: [
                            DataCell(
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Container(
                                  width: 4,
                                  height: 20,
                                  color: team == myTeam
                                      ? AppColors.win
                                      : AppColors.loss),
                              const SizedBox(width: 6),
                              SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: SkinIcon(
                                      url: ref.agent(p.agentId).iconUrl)),
                              const SizedBox(width: 6),
                              Text(_short(p.riotId)),
                            ])),
                            DataCell(Text(ref.weapon(rp.weapon)?.name ?? '—')),
                            DataCell(Text('${rp.loadout}',
                                style: AppText.tabular(null))),
                            DataCell(Text('${rp.spent}',
                                style: AppText.tabular(null))),
                            DataCell(Text('${rp.remaining}',
                                style: AppText.tabular(null))),
                            DataCell(Text('${rp.kills}',
                                style: AppText.tabular(null))),
                            DataCell(Text('${rp.damage}',
                                style: AppText.tabular(null))),
                          ],
                        ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 擊殺位置熱區圖：主角擊殺對手（對手倒下處）與自己陣亡的位置，畫在小地圖上。
class KillHeatmap extends StatefulWidget {
  final List<(MapPoint, bool)> points;
  final MinimapRef? minimap;
  final String title;

  const KillHeatmap(
      {super.key,
      required this.points,
      required this.minimap,
      this.title = '擊殺熱區圖'});

  @override
  State<KillHeatmap> createState() => _KillHeatmapState();
}

enum _HeatFilter { all, kills, deaths }

class _KillHeatmapState extends State<KillHeatmap> {
  _HeatFilter _filter = _HeatFilter.all;

  @override
  Widget build(BuildContext context) {
    final m = widget.minimap;
    if (widget.points.isEmpty) return const SizedBox.shrink();
    final kills = widget.points.where((p) => p.$2).length;
    final deaths = widget.points.length - kills;
    final shown = widget.points.where((p) => switch (_filter) {
          _HeatFilter.all => true,
          _HeatFilter.kills => p.$2,
          _HeatFilter.deaths => !p.$2,
        });
    return _card(
      context,
      widget.title,
      key: const ValueKey('kill-heatmap'),
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (f, label) in [
            (_HeatFilter.all, '全部'),
            (_HeatFilter.kills, '擊殺 $kills'),
            (_HeatFilter.deaths, '陣亡 $deaths'),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _filter == f,
              onSelected: (_) => setState(() => _filter = f),
            ),
        ]),
        const SizedBox(height: 12),
        if (m == null)
          Text('還沒有這張地圖的小地圖資料', style: TextStyle(color: AppColors.muted))
        else
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AspectRatio(
                aspectRatio: 1,
                child: LayoutBuilder(builder: (context, c) {
                  final size = c.maxWidth;
                  return Stack(children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.85,
                        child: Image.network(m.imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                Container(color: AppColors.surfaceHigh)),
                      ),
                    ),
                    for (final (p, kill) in shown)
                      if (m.project(p) case (final x, final y)
                          when x >= 0 && x <= 1 && y >= 0 && y <= 1)
                        Positioned(
                          left: x * size - 5,
                          top: y * size - 5,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: (kill ? AppColors.win : AppColors.loss)
                                  .withOpacity(0.8),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: AppColors.background, width: 1),
                            ),
                          ),
                        ),
                  ]);
                }),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.circle, size: 10, color: AppColors.win),
          const SizedBox(width: 4),
          Text('擊殺（對手倒下處）',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(width: 16),
          Icon(Icons.circle, size: 10, color: AppColors.loss),
          const SizedBox(width: 4),
          Text('陣亡', style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ]),
      ]),
    );
  }
}

/// 武器統計表：擊殺、爆頭率、勝率（依每回合主武器推算）。
class WeaponStatsTable extends StatelessWidget {
  final List<WeaponStat> stats;
  final MatchReferenceProvider ref;
  final int limit;

  const WeaponStatsTable(
      {super.key, required this.stats, required this.ref, this.limit = 8});

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: AppColors.muted, fontSize: 12);
    final rows = stats.where((s) => ref.weapon(s.weapon) != null).take(limit);
    if (rows.isEmpty) {
      return Text('還沒有武器資料', style: TextStyle(color: AppColors.muted));
    }
    return Column(
      key: const ValueKey('weapon-stats'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text('武器', style: muted)),
          SizedBox(
              width: 52,
              child: Text('擊殺', textAlign: TextAlign.end, style: muted)),
          SizedBox(
              width: 60,
              child: Text('爆頭率', textAlign: TextAlign.end, style: muted)),
          SizedBox(
              width: 60,
              child: Text('勝率', textAlign: TextAlign.end, style: muted)),
        ]),
        const SizedBox(height: 4),
        for (final s in rows)
          Padding(
            key: ValueKey('weapon-row-${s.weapon}'),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              SizedBox(
                  width: 56,
                  height: 22,
                  child: SkinIcon(url: ref.weapon(s.weapon)?.iconUrl)),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(ref.weapon(s.weapon)!.name,
                      overflow: TextOverflow.ellipsis)),
              SizedBox(
                  width: 52,
                  child: Text('${s.kills}',
                      textAlign: TextAlign.end, style: AppText.tabular(null))),
              SizedBox(
                  width: 60,
                  child: Text(
                      s.headshotPercent == null
                          ? '—'
                          : '${s.headshotPercent!.round()}%',
                      textAlign: TextAlign.end,
                      style: AppText.tabular(null))),
              SizedBox(
                  width: 60,
                  child: Text(
                      s.winRate == null ? '—' : '${s.winRate!.round()}%',
                      textAlign: TextAlign.end,
                      style: AppText.tabular(null))),
            ]),
          ),
        const SizedBox(height: 4),
        Text('爆頭率與勝率以每回合的主武器推算', style: muted),
      ],
    );
  }
}
