import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../providers/match_history_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/recent_form_loader.dart';
import '../theme/app_theme.dart';
import '../widgets/skin_tile.dart' show SkinIcon;
import 'match_history_page.dart' show formatMatchTime, resultColor, resultLabel;

/// 單場兩隊計分板；打開後在背景載入每位玩家的最近 5 場。
class MatchDetailPage extends StatefulWidget {
  final String matchId;

  const MatchDetailPage({super.key, required this.matchId});

  @override
  State<MatchDetailPage> createState() => _MatchDetailPageState();
}

class _MatchDetailPageState extends State<MatchDetailPage> {
  late final RecentFormLoader _loader;

  @override
  void initState() {
    super.initState();
    _loader = context.read<RecentFormLoader>();
    // 畫面先出現，下一個 frame 才開始排隊載入。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final detail =
          context.read<MatchHistoryProvider>().detail(widget.matchId);
      if (detail == null) return;
      final me = detail.summary.myTeamId;
      final ids = detail.teams.keys.toList()
        ..sort((a, b) => a == me ? -1 : (b == me ? 1 : a.compareTo(b)));
      _loader.request([
        for (final id in ids) ...detail.teams[id]!.map((p) => p.puuid),
      ]);
    });
  }

  @override
  void dispose() {
    // 離開時取消尚未開始的玩家；已完成的結果留在記憶體。
    _loader.cancelPending();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = context.watch<MatchHistoryProvider>().detail(widget.matchId);
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

  static const _headers = [
    '特務',
    'Riot ID',
    '牌位',
    '表現分數',
    'K/D/A',
    'K/D',
    'ACS',
    'ADR',
    '爆頭率',
    '首殺',
    '等級',
    '最近 5 場',
  ];

  /// 點其他玩家進入他的頁面；點自己切到自己的對戰紀錄。
  void _open(BuildContext context, PlayerLine p) {
    final nav = Navigator.of(context);
    if (p.isMe) {
      nav.pushNamedAndRemoveUntil('/matches', (_) => false);
    } else {
      nav.pushNamed('/players/detail',
          arguments: PlayerRef(puuid: p.puuid, riotId: p.riotId));
    }
  }

  DataCell _cell(String key, String text) =>
      DataCell(Text(text, key: ValueKey(key)));

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
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(p.riotId,
                            key:
                                p.isMe ? const ValueKey('player-row-me') : null,
                            style: TextStyle(
                                fontWeight: p.isMe
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                        if (p.mvp != MvpKind.none) ...[
                          const SizedBox(width: 6),
                          _MvpTag(key: ValueKey('mvp-${p.puuid}'), kind: p.mvp),
                        ],
                      ],
                    ),
                    onTap: () => _open(context, p),
                  ),
                  DataCell(Text(ref.tier(p.tier).name)),
                  _cell('rating-${p.puuid}',
                      p.rating == null ? '—' : '${p.rating!.round()}'),
                  DataCell(Text('${p.kills} / ${p.deaths} / ${p.assists}')),
                  _cell('kd-${p.puuid}', p.kd.toStringAsFixed(2)),
                  _cell('acs-${p.puuid}', '${p.acs}'),
                  _cell('adr-${p.puuid}', '${p.adr}'),
                  DataCell(Text(p.headshotPercent == null
                      ? '—'
                      : '${p.headshotPercent!.round()}%')),
                  _cell('fk-${p.puuid}', '${p.firstKills}'),
                  DataCell(Text('${p.accountLevel}')),
                  DataCell(_FormCell(
                      key: ValueKey('form-${p.puuid}'), puuid: p.puuid)),
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

class _MvpTag extends StatelessWidget {
  final MvpKind kind;

  const _MvpTag({super.key, required this.kind});

  @override
  Widget build(BuildContext context) {
    final color =
        kind == MvpKind.match ? AppColors.wishlistGold : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(kind == MvpKind.match ? '全場 MVP' : '隊伍 MVP',
          style: TextStyle(color: color, fontSize: 11)),
    );
  }
}

/// 最近 5 場：勝敗顏色的小方塊（寫 ACS）與平均 ACS。
class _FormCell extends StatelessWidget {
  final String puuid;

  const _FormCell({super.key, required this.puuid});

  @override
  Widget build(BuildContext context) {
    final loader = context.watch<RecentFormLoader>();
    const muted = TextStyle(color: AppColors.muted);
    switch (loader.status(puuid)) {
      case FormStatus.pending:
      case FormStatus.loading:
        return const Text('…', style: muted);
      case FormStatus.failed:
        return const Text('—', style: muted);
      case FormStatus.done:
        break;
    }
    final form = loader.form(puuid);
    if (form == null || form.games.isEmpty) {
      return const Text('—', style: muted);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < form.games.length; i++)
          Container(
            key: ValueKey('form-$puuid-$i'),
            width: 30,
            margin: const EdgeInsets.only(right: 3),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: resultColor(form.games[i].won).withOpacity(0.25),
              border: Border(
                  bottom: BorderSide(
                      color: resultColor(form.games[i].won), width: 2)),
            ),
            child: Text('${form.games[i].acs}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11)),
          ),
        const SizedBox(width: 6),
        Text('平均 ${form.avgAcs!.round()}', style: muted),
      ],
    );
  }
}
