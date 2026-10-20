import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../providers/match_history_provider.dart';
import '../providers/match_reference_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/skin_tile.dart' show SkinIcon;
import 'match_history_page.dart' show formatMatchTime, resultColor, resultLabel;

/// 單場兩隊計分板。
class MatchDetailPage extends StatelessWidget {
  final String matchId;

  const MatchDetailPage({super.key, required this.matchId});

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<MatchHistoryProvider>().detail(matchId);
    final ref = context.watch<MatchReferenceProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('對戰詳情')),
      body: detail == null
          ? const Center(child: Text('找不到這場對戰'))
          : _DetailBody(detail: detail, ref: ref),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final MatchDetail detail;
  final MatchReferenceProvider ref;

  const _DetailBody({required this.detail, required this.ref});

  /// 人數大於 1 的組隊依出現順序分配顏色；單排玩家不顯示標記。
  Map<String, Color> _partyColors() {
    final counts = <String, int>{};
    for (final p in detail.teams.values.expand((t) => t)) {
      counts[p.partyId] = (counts[p.partyId] ?? 0) + 1;
    }
    final colors = <String, Color>{};
    for (final e in counts.entries) {
      if (e.value > 1) {
        colors[e.key] =
            AppColors.partyColors[colors.length % AppColors.partyColors.length];
      }
    }
    return colors;
  }

  @override
  Widget build(BuildContext context) {
    final s = detail.summary;
    final parties = _partyColors();
    // 自己的隊伍排前面。
    final teamIds = detail.teams.keys.toList()
      ..sort((a, b) =>
          a == s.myTeamId ? -1 : (b == s.myTeamId ? 1 : a.compareTo(b)));
    final tables = [
      for (final id in teamIds)
        _TeamTable(
            key: ValueKey('team-$id'),
            teamId: id,
            players: detail.teams[id]!,
            ref: ref,
            parties: parties),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(ref.map(s.mapId).name,
                    style: Theme.of(context).textTheme.titleLarge),
                Text(queueName(s.queueId)),
                Text('${resultLabel(s.won)}  ${s.myScore} : ${s.enemyScore}',
                    style: TextStyle(
                        color: resultColor(s.won),
                        fontWeight: FontWeight.bold)),
                Text('${(s.durationMs / 60000).round()} 分鐘',
                    style: const TextStyle(color: AppColors.muted)),
                Text(formatMatchTime(s.startTime),
                    style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, c) => c.maxWidth >= 1000
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < tables.length; i++) ...[
                      if (i > 0) const SizedBox(width: 16),
                      Expanded(child: tables[i]),
                    ],
                  ],
                )
              : Column(
                  children: [
                    for (var i = 0; i < tables.length; i++) ...[
                      if (i > 0) const SizedBox(height: 16),
                      tables[i],
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text('名稱資料來自 Riot，請勿公開或分享他人資訊',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

class _TeamTable extends StatelessWidget {
  final String teamId;
  final List<PlayerLine> players;
  final MatchReferenceProvider ref;
  final Map<String, Color> parties;

  const _TeamTable({
    super.key,
    required this.teamId,
    required this.players,
    required this.ref,
    required this.parties,
  });

  static const _headers = ['特務', 'Riot ID', '牌位', 'K/D/A', 'ACS', '爆頭率', '等級'];

  @override
  Widget build(BuildContext context) {
    const muted = TextStyle(color: AppColors.muted, fontSize: 12);
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 16,
          headingRowHeight: 36,
          columns: [
            for (final h in _headers) DataColumn(label: Text(h, style: muted))
          ],
          rows: [
            for (final p in players)
              DataRow(
                color: p.isMe
                    ? const WidgetStatePropertyAll(AppColors.surfaceHigh)
                    : null,
                cells: [
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: 6, child: _partyDot(p)),
                      const SizedBox(width: 6),
                      SizedBox(
                          width: 28,
                          height: 28,
                          child: SkinIcon(url: ref.agent(p.agentId).iconUrl)),
                      const SizedBox(width: 6),
                      Text(ref.agent(p.agentId).name),
                    ],
                  )),
                  DataCell(Text(p.riotId,
                      key: p.isMe ? const ValueKey('player-row-me') : null,
                      style: TextStyle(
                          fontWeight:
                              p.isMe ? FontWeight.bold : FontWeight.normal))),
                  DataCell(Text(ref.tier(p.tier).name)),
                  DataCell(Text('${p.kills} / ${p.deaths} / ${p.assists}')),
                  DataCell(Text('${p.acs}')),
                  DataCell(Text(p.headshotPercent == null
                      ? '—'
                      : '${p.headshotPercent!.round()}%')),
                  DataCell(Text('${p.accountLevel}')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget? _partyDot(PlayerLine p) {
    final color = parties[p.partyId];
    if (color == null) return null;
    return Container(
      key: ValueKey('party-dot-${p.puuid}'),
      width: 6,
      height: 6,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
