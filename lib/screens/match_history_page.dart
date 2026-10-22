import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/match_mapper.dart';
import '../logic/match_stats.dart';
import '../models/match_models.dart';
import '../providers/match_history_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/riot_provider.dart';
import '../shell/app_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import '../widgets/line_chart.dart';
import '../widgets/skin_tile.dart' show SkinIcon;

String _two(int n) => n.toString().padLeft(2, '0');

String formatMatchTime(DateTime t) =>
    '${t.month}/${t.day} ${_two(t.hour)}:${_two(t.minute)}';

String formatRr(int rr) => rr > 0 ? '+$rr' : '$rr';

/// 近幾場 RR 合計的方向：正數上升、負數下降、0 或沒有資料為 null。
bool? rrUp(List<int> rr) {
  final sum = rr.fold<int>(0, (a, b) => a + b);
  return sum == 0 ? null : sum > 0;
}

String resultLabel(bool? won) => won == null ? '平' : (won ? '勝' : '敗');

Color resultColor(bool? won) =>
    won == null ? AppColors.muted : (won ? AppColors.owned : AppColors.error);

/// 自己的對戰紀錄列表；登入 Riot 後才有資料。
class MatchHistoryPage extends StatefulWidget {
  const MatchHistoryPage({super.key});

  @override
  State<MatchHistoryPage> createState() => _MatchHistoryPageState();
}

class _MatchHistoryPageState extends State<MatchHistoryPage> {
  MatchFilter _filter = const MatchFilter();

  /// false：對戰列表與走勢圖；true：特務／地圖統計。
  bool _stats = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final riot = context.watch<RiotProvider>();
    final history = context.read<MatchHistoryProvider>();
    final puuid = riot.isLoggedIn ? riot.session?.puuid : null;
    // 第一次進入或換帳號時重新載入；舊帳號的資料不能留在畫面上。
    if (puuid != null && history.loadedFor != puuid && !history.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) history.loadFirstPage();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final history = context.watch<MatchHistoryProvider>();
    final ref = context.watch<MatchReferenceProvider>();

    final Widget body;
    if (!riot.isLoggedIn) {
      // 放在 ListView 裡：高度不受限，空狀態卡依內容高度、不撐滿整頁。
      body = ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          PanelCard(
            padding: const EdgeInsets.all(32),
            child: EmptyState(
              icon: Icons.history,
              title: '登入 Riot 以查看對戰紀錄',
              message: '登入後會列出最近的對戰、RR 變化與表現',
              actionLabel: '登入 Riot',
              onAction: () => Navigator.pushNamed(context, '/riot-login'),
            ),
          ),
        ],
      );
    } else if (history.entries.isEmpty && history.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      // 篩選只作用在已有詳細資料的場次；沒有篩選時列出全部（含讀取失敗的）。
      final summaries = [
        for (final e in history.entries)
          if (e.detail case final d?) d.summary,
      ];
      final filtered = summaries.where(_filter.accepts).toList();
      final shown = _filter.isEmpty
          ? history.entries
          : [
              for (final e in history.entries)
                if (e.detail case final d? when _filter.accepts(d.summary)) e,
            ];
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _HistoryKpi(history: history, ref: ref),
          if (history.error case final e?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(e, style: TextStyle(color: AppColors.error)),
                  // 第一頁失敗時頁面不會自動重試，給使用者手動重試的入口。
                  if (history.entries.isEmpty && !history.isLoading)
                    OutlinedButton(
                      onPressed: history.loadFirstPage,
                      child: const Text('重試'),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          _HistoryControls(
            filter: _filter,
            stats: _stats,
            summaries: summaries,
            ref: ref,
            onFilter: (f) => setState(() => _filter = f),
            onStats: (v) => setState(() => _stats = v),
          ),
          const SizedBox(height: 16),
          if (_stats)
            _StatsView(games: filtered, ref: ref)
          else ...[
            _Charts(games: filtered),
            const SizedBox(height: 16),
            if (shown.isEmpty && !history.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: Text('沒有符合的場次',
                        style: TextStyle(color: AppColors.muted))),
              ),
            // 列表：每場一列，細邊框＋左側勝負色條。
            for (final e in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                // 至少 76 高；字放大時可以長高。
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 76),
                    child: MatchCard(entry: e, ref: ref)),
              ),
          ],
          if (history.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: OutlinedButton(
                  onPressed: history.isLoading ? null : history.loadMore,
                  child: history.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('載入更多'),
                ),
              ),
            ),
          const SizedBox(height: 24),
          Center(
            child: Text('名稱資料來自 Riot，請勿公開或分享他人資訊',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
      );
    }

    return AppShell(currentRoute: '/matches', title: '對戰紀錄', child: body);
  }
}

/// 頁首 KPI：只用已載入的資料計算（近 5 場 RR 合計、勝率、平均 ACS）。
class _HistoryKpi extends StatelessWidget {
  final MatchHistoryProvider history;
  final MatchReferenceProvider ref;

  const _HistoryKpi({required this.history, required this.ref});

  @override
  Widget build(BuildContext context) {
    final details = [
      for (final e in history.entries)
        if (e.detail case final d?) d.summary,
    ];
    final rr = history.recentRr;
    final rrSum = rr.fold<int>(0, (a, b) => a + b);
    final decided = details.where((s) => s.won != null).toList();
    final wins = decided.where((s) => s.won == true).length;
    return BentoGrid(key: const ValueKey('history-kpi'), children: [
      BentoTile(
          span: 4,
          medium: 6,
          child: _RankHeader(
              key: const ValueKey('history-rank'),
              rank: history.rank,
              recentRr: rr,
              ref: ref)),
      // KPI 小卡：窄螢幕每列 2 張，不會各佔一整列。
      BentoTile(
          span: 8,
          medium: 6,
          child: KpiStrip(tiles: [
            KpiTile(
              key: const ValueKey('kpi-rr'),
              label: '近 ${rr.length} 場 RR',
              value: rr.isEmpty ? '—' : formatRr(rrSum),
              up: rrUp(rr),
            ),
            KpiTile(
              label: '勝率（${decided.length} 場）',
              value: decided.isEmpty
                  ? '—'
                  : '${(wins / decided.length * 100).round()}%',
            ),
            KpiTile(
              label: '平均 ACS',
              value: details.isEmpty
                  ? '—'
                  : '${(details.fold<int>(0, (a, s) => a + s.acs) / details.length).round()}',
            ),
          ])),
    ]);
  }
}

class _RankHeader extends StatelessWidget {
  final RankInfo? rank;
  final List<int> recentRr;
  final MatchReferenceProvider ref;

  const _RankHeader(
      {super.key,
      required this.rank,
      required this.recentRr,
      required this.ref});

  @override
  Widget build(BuildContext context) {
    final rank = this.rank;
    final tier = rank == null ? null : ref.tier(rank.tier);
    return PanelCard(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
                width: 40, height: 40, child: SkinIcon(url: tier?.iconUrl)),
            Text(tier?.name ?? '未定級',
                style: Theme.of(context).textTheme.titleLarge),
            if (rank != null) Text('${rank.rr} RR'),
            if (recentRr.isNotEmpty) ...[
              Text('最近：', style: TextStyle(color: AppColors.muted)),
              for (final rr in recentRr)
                Text(formatRr(rr),
                    style: TextStyle(
                        color: rr >= 0 ? AppColors.owned : AppColors.error,
                        fontWeight: FontWeight.bold)),
            ],
          ],
        ),
      ),
    );
  }
}

/// 一場對戰的卡片；點擊進入單場詳情。[otherPlayer] 用於玩家頁：多顯示 ACS。
class MatchCard extends StatelessWidget {
  final MatchEntry entry;
  final MatchReferenceProvider ref;
  final bool otherPlayer;

  const MatchCard(
      {super.key,
      required this.entry,
      required this.ref,
      this.otherPlayer = false});

  @override
  Widget build(BuildContext context) {
    final d = entry.detail;
    if (d == null) {
      return PanelCard(
        key: ValueKey('match-card-${entry.ref.matchId}'),
        child: Center(
          child: Text(entry.failed ? '無法載入這場' : '載入中…',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    final s = d.summary;
    final map = ref.map(s.mapId);
    final agent = ref.agent(s.myAgentId);
    return PanelCard(
      key: ValueKey('match-card-${s.matchId}'),
      accent: resultColor(s.won),
      padding: EdgeInsets.zero,
      // 玩家頁的場次不在自己的紀錄裡，直接把詳情傳給詳情頁。
      onTap: () => Navigator.pushNamed(context, '/matches/detail',
          arguments: otherPlayer ? d : entry.ref.matchId),
      child: Row(
        children: [
          SizedBox(width: 72, child: SkinIcon(url: map.iconUrl)),
          const SizedBox(width: 12),
          SizedBox(width: 40, height: 40, child: SkinIcon(url: agent.iconUrl)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(map.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(queueName(s.queueId),
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                Text(formatMatchTime(entry.ref.startTime),
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(resultLabel(s.won),
                        style: TextStyle(
                            color: resultColor(s.won),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Text('${s.myScore} : ${s.enemyScore}'),
                  ],
                ),
                Text('${s.kills} / ${s.deaths} / ${s.assists}'),
                if (otherPlayer)
                  Text('ACS ${s.acs}',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                if (s.rrChange case final rr?)
                  Text(formatRr(rr),
                      style: TextStyle(
                          color: rr >= 0 ? AppColors.owned : AppColors.error,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 對戰／統計切換與篩選列（模式、特務、地圖、勝負）。
class _HistoryControls extends StatelessWidget {
  final MatchFilter filter;
  final bool stats;
  final List<MatchSummary> summaries;
  final MatchReferenceProvider ref;
  final ValueChanged<MatchFilter> onFilter;
  final ValueChanged<bool> onStats;

  const _HistoryControls({
    required this.filter,
    required this.stats,
    required this.summaries,
    required this.ref,
    required this.onFilter,
    required this.onStats,
  });

  @override
  Widget build(BuildContext context) {
    final agents = {for (final s in summaries) s.myAgentId}.toList()
      ..sort((a, b) => ref.agent(a).name.compareTo(ref.agent(b).name));
    final maps = {for (final s in summaries) s.mapId}.toList()
      ..sort((a, b) => ref.map(a).name.compareTo(ref.map(b).name));
    Widget drop<T>(String key, T value, Map<T, String> options,
            ValueChanged<T> onChanged) =>
        DropdownButton<T>(
          key: ValueKey(key),
          value: value,
          isDense: true,
          underline: const SizedBox.shrink(),
          items: [
            for (final e in options.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v is T) onChanged(v);
          },
        );
    return PanelCard(
      key: const ValueKey('history-filters'),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<bool>(
            key: const ValueKey('history-tab'),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: false, label: Text('對戰')),
              ButtonSegment(value: true, label: Text('統計')),
            ],
            selected: {stats},
            onSelectionChanged: (v) => onStats(v.first),
          ),
          drop<ModeFilter>(
              'filter-mode',
              filter.mode,
              const {
                ModeFilter.all: '全部模式',
                ModeFilter.competitive: '競技',
                ModeFilter.unrated: '一般',
                ModeFilter.other: '其他',
              },
              (v) => onFilter(filter.copyWith(mode: v))),
          drop<String>(
              'filter-agent',
              filter.agentId ?? '',
              {
                '': '全部特務',
                for (final a in agents) a: ref.agent(a).name,
              },
              (v) => onFilter(
                  filter.copyWith(agentId: () => v.isEmpty ? null : v))),
          drop<String>(
              'filter-map',
              filter.mapId ?? '',
              {
                '': '全部地圖',
                for (final m in maps) m: ref.map(m).name,
              },
              (v) =>
                  onFilter(filter.copyWith(mapId: () => v.isEmpty ? null : v))),
          drop<ResultFilter>(
              'filter-result',
              filter.result,
              const {
                ResultFilter.all: '全部勝負',
                ResultFilter.win: '勝',
                ResultFilter.loss: '敗',
              },
              (v) => onFilter(filter.copyWith(result: v))),
          if (!filter.isEmpty)
            TextButton(
              onPressed: () => onFilter(const MatchFilter()),
              child: const Text('清除篩選'),
            ),
        ],
      ),
    );
  }
}

/// RR 與 ACS 走勢（套用篩選，由舊到新）。
class _Charts extends StatelessWidget {
  final List<MatchSummary> games;

  const _Charts({required this.games});

  @override
  Widget build(BuildContext context) {
    final rr = rrSeries(games);
    final acs = acsSeries(games);
    final avgAcs =
        acs.isEmpty ? null : acs.reduce((a, b) => a + b) / acs.length;
    const title = TextStyle(fontWeight: FontWeight.w600);
    Widget note(String t) => SizedBox(
          height: 140,
          child: Center(
              child: Text(t,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12))),
        );
    final rrChart = Column(
      key: const ValueKey('chart-rr'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(rr.isEmpty ? 'RR 走勢（競技）' : 'RR 走勢（競技）・累計 ${formatRr(rr.last)}',
            style: title),
        const SizedBox(height: 8),
        if (rr.length < 2)
          note('至少要 2 場有 RR 變化的競技才畫得出走勢')
        else
          SimpleLineChart(
              values: rr,
              color: AppColors.primary,
              showZero: true,
              semanticsLabel: 'RR 累計走勢，最後 ${formatRr(rr.last)}'),
      ],
    );
    final acsChart = Column(
      key: const ValueKey('chart-acs'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(avgAcs == null ? 'ACS 走勢' : 'ACS 走勢・平均 ACS ${avgAcs.round()}',
            style: title),
        const SizedBox(height: 8),
        if (acs.length < 2)
          note('至少要 2 場才畫得出走勢')
        else
          SimpleLineChart(
              values: acs,
              color: AppColors.info,
              showAverage: true,
              semanticsLabel: 'ACS 走勢，平均 ${avgAcs?.round()}'),
      ],
    );
    return PanelCard(
      key: const ValueKey('history-charts'),
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth < 640
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [rrChart, const SizedBox(height: 16), acsChart])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: rrChart),
                const SizedBox(width: 24),
                Expanded(child: acsChart),
              ]),
      ),
    );
  }
}

/// 特務與地圖的勝率統計（套用篩選，只算已載入的場次）。
class _StatsView extends StatelessWidget {
  final List<MatchSummary> games;
  final MatchReferenceProvider ref;

  const _StatsView({required this.games, required this.ref});

  @override
  Widget build(BuildContext context) {
    String pct(double? v) => v == null ? '—' : '${(v * 100).round()}%';
    Widget table(String key, String title, List<GroupStat> rows,
            String Function(String) nameOf,
            {bool kd = true}) =>
        PanelCard(
          key: ValueKey(key),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionHeader(title: title),
            if (rows.isEmpty)
              Text('沒有符合的場次', style: TextStyle(color: AppColors.muted))
            else
              Table(
                columnWidths: const {0: FlexColumnWidth(2)},
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  TableRow(children: [
                    for (final h in ['名稱', '場數', '勝率', if (kd) 'K/D', 'ACS'])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(h,
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ),
                  ]),
                  for (final r in rows)
                    TableRow(
                      decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: AppColors.outline))),
                      children: [
                        for (final t in [
                          nameOf(r.key),
                          '${r.games}',
                          pct(r.winRate),
                          if (kd) r.avgKd.toStringAsFixed(2),
                          '${r.avgAcs.round()}',
                        ])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(t,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.tabular(
                                    const TextStyle(fontSize: 13))),
                          ),
                      ],
                    ),
                ],
              ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('依已載入的最近 ${games.length} 場計算（按「載入更多」可加入更早的場次）',
          style: TextStyle(color: AppColors.muted, fontSize: 12)),
      const SizedBox(height: 12),
      table('stats-agents', '特務', statsBy(games, (g) => g.myAgentId),
          (id) => ref.agent(id).name),
      const SizedBox(height: 16),
      table('stats-maps', '地圖', statsBy(games, (g) => g.mapId),
          (id) => ref.map(id).name,
          kd: false),
    ]);
  }
}
