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

  /// 從玩家頁打開時直接帶入（不在自己的紀錄裡）；null 時查自己的紀錄。
  final MatchDetail? detail;

  const MatchDetailPage({super.key, required this.matchId, this.detail});

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
      final detail = widget.detail ??
          context.read<MatchHistoryProvider>().detail(widget.matchId);
      if (detail == null) return;
      final me = detail.summary.myTeamId;
      final ids = detail.teams.keys.toList()
        ..sort((a, b) => a == me ? -1 : (b == me ? 1 : a.compareTo(b)));
      // 只比較同一個模式（例如競技就看最近 5 場競技）。
      _loader.request(
          [
            for (final id in ids) ...detail.teams[id]!.map((p) => p.puuid),
          ],
          owner: this,
          queue: detail.summary.queueId,
          // 一般、超速衝點等場次沒有牌位資料，另外查這季的牌位。
          seasonId: detail.summary.seasonId,
          rankFor: {
            for (final p in detail.teams.values.expand((t) => t))
              if (p.tier == 0) p.puuid,
          });
    });
  }

  @override
  void dispose() {
    // 離開時取消尚未開始的玩家；已完成的結果留在記憶體。
    _loader.cancelPending(owner: this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail ??
        context.watch<MatchHistoryProvider>().detail(widget.matchId);
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
            parties: parties,
            queueId: s.queueId,
            seasonId: s.seasonId,
            mine: id == s.myTeamId,
            won: id == s.myTeamId ? s.won : (s.won == null ? null : !s.won!)),
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
        // 每隊 12 欄，並排會被截斷，所以一律上下排列、各自撐滿寬度。
        for (var i = 0; i < tables.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          tables[i],
        ],
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

  final String queueId;
  final String seasonId;

  /// 是否為 summary 主角（自己或查看中的玩家）那一隊。
  final bool mine;
  final bool? won;

  const _TeamTable({
    super.key,
    required this.teamId,
    required this.players,
    required this.ref,
    required this.parties,
    required this.queueId,
    required this.seasonId,
    required this.mine,
    required this.won,
  });

  static const _headers = [
    '特務',
    'Riot ID',
    '表現分數',
    'K/D/A',
    'K/D',
    'ACS',
    '爆頭率',
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
    final result = won == null ? '平手' : (won! ? '勝利' : '落敗');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            decoration: BoxDecoration(
              border:
                  Border(left: BorderSide(color: resultColor(won), width: 4)),
            ),
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Text('${mine ? '我方' : '敵方'}・$result',
                style: TextStyle(
                    color: resultColor(won), fontWeight: FontWeight.bold)),
          ),
          LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 36,
                  columns: [
                    for (final h in _headers)
                      DataColumn(label: Text(h, style: muted))
                  ],
                  rows: [
                    for (final p in players)
                      DataRow(
                        color: p.isMe
                            ? const WidgetStatePropertyAll(
                                AppColors.surfaceHigh)
                            : null,
                        cells: [
                          DataCell(Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 牌位與特務只顯示圖示，名稱放在提示裡。
                              _RankIcon(
                                  key: ValueKey('rank-icon-${p.puuid}'),
                                  player: p,
                                  seasonId: seasonId,
                                  ref: ref),
                              const SizedBox(width: 6),
                              SizedBox(width: 6, child: _partyDot(p)),
                              const SizedBox(width: 6),
                              Tooltip(
                                message: ref.agent(p.agentId).name,
                                child: SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: SkinIcon(
                                        url: ref.agent(p.agentId).iconUrl)),
                              ),
                            ],
                          )),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(p.riotId,
                                    key: p.isMe
                                        ? const ValueKey('player-row-me')
                                        : null,
                                    style: TextStyle(
                                        fontWeight: p.isMe
                                            ? FontWeight.bold
                                            : FontWeight.normal)),
                                const SizedBox(width: 6),
                                Text('Lv ${p.accountLevel}',
                                    key: ValueKey('level-${p.puuid}'),
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                                if (p.mvp != MvpKind.none) ...[
                                  const SizedBox(width: 6),
                                  _MvpTag(
                                      key: ValueKey('mvp-${p.puuid}'),
                                      kind: p.mvp),
                                ],
                              ],
                            ),
                            onTap: () => _open(context, p),
                          ),
                          _cell('rating-${p.puuid}',
                              p.rating == null ? '—' : '${p.rating!.round()}'),
                          DataCell(
                              Text('${p.kills} / ${p.deaths} / ${p.assists}')),
                          _cell('kd-${p.puuid}', p.kd.toStringAsFixed(2)),
                          _cell('acs-${p.puuid}', '${p.acs}'),
                          DataCell(Text(p.headshotPercent == null
                              ? '—'
                              : '${p.headshotPercent!.round()}%')),
                          DataCell(_FormCell(
                              key: ValueKey('form-${p.puuid}'),
                              puuid: p.puuid,
                              queue: queueId)),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
  final String queue;

  const _FormCell({super.key, required this.puuid, required this.queue});

  @override
  Widget build(BuildContext context) {
    final loader = context.watch<RecentFormLoader>();
    const muted = TextStyle(color: AppColors.muted);
    switch (loader.status(puuid, queue: queue)) {
      case FormStatus.pending:
      case FormStatus.loading:
        return const Text('…', style: muted);
      case FormStatus.failed:
        return const Text('—', style: muted);
      case FormStatus.done:
        break;
    }
    final form = loader.form(puuid, queue: queue);
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

/// 牌位小圖示：這場有牌位就用這場的，沒有時用背景查到的這季牌位。
/// 使用者決定（2026-10-21）：隱藏牌位的玩家也直接顯示。
class _RankIcon extends StatelessWidget {
  final PlayerLine player;
  final String seasonId;
  final MatchReferenceProvider ref;

  const _RankIcon(
      {super.key,
      required this.player,
      required this.seasonId,
      required this.ref});

  @override
  Widget build(BuildContext context) {
    final tier = player.tier > 0
        ? player.tier
        : (context
                .watch<RecentFormLoader>()
                .rank(player.puuid, seasonId)
                .seasonTier ??
            0);
    final item = ref.tier(tier);
    return Tooltip(
      key: ValueKey('rank-${player.puuid}'),
      message: item.name,
      child:
          SizedBox(width: 24, height: 24, child: SkinIcon(url: item.iconUrl)),
    );
  }
}
