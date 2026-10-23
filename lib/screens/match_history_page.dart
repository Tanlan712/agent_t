import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/match_highlights.dart';
import '../logic/match_mapper.dart';
import '../logic/match_overview.dart';
import '../logic/match_stats.dart';
import '../models/match_models.dart';
import '../providers/match_history_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/riot_provider.dart';
import '../shell/app_shell.dart';
import '../theme/app_style.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import '../widgets/line_chart.dart';
import '../widgets/match_extras.dart';
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
  String? _filterFor;

  /// false：對戰列表與走勢圖；true：特務／地圖統計。
  bool _stats = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final riot = context.watch<RiotProvider>();
    final history = context.read<MatchHistoryProvider>();
    final puuid = riot.isLoggedIn ? riot.session?.puuid : null;
    // 換帳號時清掉篩選（另一個帳號可能沒玩過選的特務或地圖）。
    if (puuid != null && puuid != _filterFor) {
      _filterFor = puuid;
      _filter = const MatchFilter();
    }
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
            _StatsView(
                games: filtered,
                details: [
                  for (final e in history.entries)
                    if (e.detail case final d? when _filter.accepts(d.summary))
                      d,
                ],
                mapId: _filter.mapId,
                ref: ref)
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
            // 列表：依日期分組，每場一張卡片（地圖背景＋左側勝負色條）。
            for (final (i, g) in groupByDay<MatchEntry>(
                    shown, (e) => e.ref.startTime, (e) => e.detail?.summary)
                .indexed) ...[
              _DayHeader(group: g, index: i),
              for (final e in g.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  // 至少 76 高；字放大時可以長高。
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 76),
                      child: MatchCard(entry: e, ref: ref)),
                ),
            ],
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

/// 頁首：牌位、KPI（只用已載入的資料計算）、近期戰績與常用特務。
class _HistoryKpi extends StatelessWidget {
  final MatchHistoryProvider history;
  final MatchReferenceProvider ref;

  const _HistoryKpi({required this.history, required this.ref});

  @override
  Widget build(BuildContext context) {
    final details = [
      for (final e in history.entries)
        if (e.detail case final d?) d,
    ];
    final o = summarizeHistory(details);
    final rr = history.recentRr;
    final rrSum = rr.fold<int>(0, (a, b) => a + b);
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
              label: '勝率（${o.wins + o.losses} 場）',
              value: o.winRate == null ? '—' : '${(o.winRate! * 100).round()}%',
            ),
            KpiTile(
              label: '平均 ACS',
              value: details.isEmpty
                  ? '—'
                  : '${(details.fold<int>(0, (a, d) => a + d.summary.acs) / details.length).round()}',
            ),
            KpiTile(
              key: const ValueKey('kpi-kd'),
              label: '平均 K/D',
              value: o.kd?.toStringAsFixed(2) ?? '—',
            ),
            KpiTile(
              key: const ValueKey('kpi-adr'),
              label: '平均 ADR',
              value: o.adr == null ? '—' : '${o.adr!.round()}',
            ),
            KpiTile(
              key: const ValueKey('kpi-hs'),
              label: '爆頭率',
              value: o.headshot == null ? '—' : '${o.headshot!.round()}%',
            ),
          ])),
      if (details.isNotEmpty)
        BentoTile(span: 12, child: _RecentForm(overview: o, ref: ref)),
    ]);
  }
}

/// 最近 10 場的勝負方塊與最常用的 3 位特務。
class _RecentForm extends StatelessWidget {
  final HistoryOverview overview;
  final MatchReferenceProvider ref;

  const _RecentForm({required this.overview, required this.ref});

  @override
  Widget build(BuildContext context) {
    final label = TextStyle(color: AppColors.muted, fontSize: 12);
    final form = Column(
      key: const ValueKey('history-form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('近期戰績（新 → 舊）', style: label),
        const SizedBox(height: 8),
        Wrap(spacing: 4, runSpacing: 4, children: [
          for (final d in overview.form)
            Tooltip(
              key: ValueKey('form-${d.summary.matchId}'),
              triggerMode: TooltipTriggerMode.tap,
              message: '${ref.map(d.summary.mapId).name}  '
                  '${d.summary.myScore} : ${d.summary.enemyScore}',
              child: Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: resultColor(d.summary.won).withOpacity(0.2),
                  border: Border.all(color: resultColor(d.summary.won)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(resultLabel(d.summary.won),
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color.lerp(
                            resultColor(d.summary.won), AppColors.text, 0.3))),
              ),
            ),
        ]),
      ],
    );
    final agents = Column(
      key: const ValueKey('history-top-agents'),
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('常用特務', style: label),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 8, children: [
          for (final a in overview.topAgents)
            Row(mainAxisSize: MainAxisSize.min, children: [
              SizedBox(
                  width: 28,
                  height: 28,
                  child: SkinIcon(url: ref.agent(a.key).iconUrl)),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(ref.agent(a.key).name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(
                      '${a.games} 場 · 勝率 ${a.winRate == null ? '—' : '${(a.winRate! * 100).round()}%'}',
                      style: AppText.tabular(label)),
                ],
              ),
            ]),
        ]),
      ],
    );
    return PanelCard(
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth < 640
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [form, const SizedBox(height: 16), agents])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: form),
                const SizedBox(width: 24),
                Expanded(child: agents),
              ]),
      ),
    );
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

/// 一天的組標題：日期與當天勝敗、RR。
class _DayHeader extends StatelessWidget {
  final DayGroup<MatchEntry> group;
  final int index;

  const _DayHeader({required this.group, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ValueKey('day-header-$index'),
      padding: EdgeInsets.only(top: index == 0 ? 0 : 12, bottom: 8),
      child: Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.outline))),
        child: Row(children: [
          Text(dayLabel(group.day, DateTime.now()),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
                dayStatsLabel(
                    wins: group.wins, losses: group.losses, rr: group.rr),
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.tabular(
                    TextStyle(color: AppColors.muted, fontSize: 12))),
          ),
        ]),
      ),
    );
  }
}

/// 全場 MVP 或隊伍 MVP 標籤（列表卡片與詳情頁共用）。
class MvpChip extends StatelessWidget {
  final MvpKind kind;

  const MvpChip({super.key, required this.kind});

  @override
  Widget build(BuildContext context) => kind == MvpKind.match
      ? StatusChip(
          label: '全場 MVP', color: AppColors.warn, icon: Icons.emoji_events)
      : StatusChip(label: '隊伍 MVP', color: AppColors.info);
}

/// 卡片寬度至少這個值時一列排完；較窄時分上下兩段。
const _wideCardMinWidth = 860.0;

String resultTitle(bool? won) => won == null ? '平手' : (won ? '勝利' : '落敗');

/// 一場對戰的卡片；點擊進入單場詳情。[otherPlayer] 用於玩家頁（數據是那位玩家的）。
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
        child: entry.failed
            ? Center(
                child: Text('無法載入這場', style: TextStyle(color: AppColors.muted)))
            : const Row(children: [
                SkeletonBox(width: 48, height: 48),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 120),
                      SizedBox(height: 6),
                      SkeletonBox(width: 80, height: 12),
                    ],
                  ),
                ),
              ]),
      );
    }
    final s = d.summary;
    final line = focusLine(d);
    final map = ref.map(s.mapId);
    final agent = ref.agent(s.myAgentId);
    final color = resultColor(s.won);
    final minutes = (s.durationMs / 60000).round();
    final meta = [
      queueName(s.queueId),
      formatMatchTime(entry.ref.startTime),
      if (minutes > 0) '$minutes 分',
    ].join(' · ');

    final agentIcon = ClipRRect(
      key: ValueKey('card-agent-${s.matchId}'),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        color: color.withOpacity(0.15),
        child: SkinIcon(url: agent.iconUrl),
      ),
    );
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(map.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
      ],
    );
    final result = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(resultTitle(s.won),
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 13)),
        Text('${s.myScore} : ${s.enemyScore}',
            style: AppText.tabular(
                const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
      ],
    );
    final kd = line?.kd ?? (s.kills / (s.deaths == 0 ? 1 : s.deaths));
    // 每張卡片的數據格固定同一組、同一順序（沒有資料時顯示「—」），寬版的欄位才會上下對齊。
    final stats = <_Stat>[
      _Stat('K / D / A', '${s.kills} / ${s.deaths} / ${s.assists}', wide: true),
      _Stat('K/D', kd.toStringAsFixed(2),
          color: kd >= 1 ? AppColors.win : AppColors.loss),
      _Stat('ACS', '${s.acs}'),
      _Stat('ADR', line == null ? '—' : '${line.adr}'),
      _Stat(
          '爆頭率',
          line?.headshotPercent == null
              ? '—'
              : '${line!.headshotPercent!.round()}%'),
      _Stat('表現', line?.rating == null ? '—' : '${line!.rating!.round()}'),
      _Stat('首殺', line == null ? '—' : '${line.firstKills}'),
      switch (s.rrChange) {
        final rr? => _Stat('RR', formatRr(rr),
            color: rr >= 0 ? AppColors.win : AppColors.loss),
        null => const _Stat('RR', '—'),
      },
    ];
    final mvp = line == null || line.mvp == MvpKind.none
        ? null
        : MvpChip(key: ValueKey('card-mvp-${s.matchId}'), kind: line.mvp);

    return PanelCard(
      key: ValueKey('match-card-${s.matchId}'),
      accent: color,
      padding: EdgeInsets.zero,
      // 玩家頁的場次不在自己的紀錄裡，直接把詳情傳給詳情頁。
      onTap: () => Navigator.pushNamed(context, '/matches/detail',
          arguments: otherPlayer ? d : entry.ref.matchId),
      child: Stack(children: [
        Positioned.fill(child: _MapBackdrop(url: map.iconUrl, color: color)),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          child: LayoutBuilder(builder: (context, c) {
            if (c.maxWidth >= _wideCardMinWidth) {
              return Row(children: [
                SizedBox(width: 52, height: 52, child: agentIcon),
                const SizedBox(width: 12),
                SizedBox(width: 180, child: title),
                const SizedBox(width: 8),
                SizedBox(width: 72, child: result),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(children: [
                    for (final st in stats)
                      Expanded(flex: st.wide ? 2 : 1, child: st),
                  ]),
                ),
                SizedBox(
                    width: 96,
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: mvp ?? const SizedBox.shrink())),
              ]);
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  SizedBox(width: 44, height: 44, child: agentIcon),
                  const SizedBox(width: 10),
                  Expanded(child: title),
                  const SizedBox(width: 8),
                  result,
                ]),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final st in stats)
                      SizedBox(width: st.wide ? 84 : 52, child: st),
                    if (mvp != null) mvp,
                  ],
                ),
              ],
            );
          }),
        ),
      ]),
    );
  }
}

/// 卡片背景：地圖橫幅圖，疊上卡片底色漸層（左淡右實）與左緣的勝負色。
class _MapBackdrop extends StatelessWidget {
  final String? url;
  final Color color;

  const _MapBackdrop({required this.url, required this.color});

  @override
  Widget build(BuildContext context) {
    final base = context.appStyle.card == CardVariant.flat
        ? AppColors.surfaceHigh
        : AppColors.surface;
    final url = this.url;
    return Stack(
      key: const ValueKey('match-card-bg'),
      fit: StackFit.expand,
      children: [
        if (url != null)
          Image.network(url,
              fit: BoxFit.cover,
              alignment: Alignment.centerLeft,
              errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                base.withOpacity(0.55),
                base.withOpacity(0.88),
                base.withOpacity(0.96),
              ],
              stops: const [0, 0.4, 1],
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.22), color.withOpacity(0)],
              stops: const [0, 0.45],
            ),
          ),
        ),
      ],
    );
  }
}

/// 卡片上的一格數據：數值在上、標籤在下。
class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  /// K/D/A 這類較長的數值佔比較寬。
  final bool wide;

  const _Stat(this.label, this.value, {this.color, this.wide = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value,
              maxLines: 1,
              style: AppText.tabular(TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color))),
        ),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.muted, fontSize: 11)),
      ],
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
    // 目前選的特務／地圖一定要在選項裡（重新載入或失敗時已載入的場次可能暫時沒有它）。
    final agents = {
      for (final s in summaries) s.myAgentId,
      if (filter.agentId case final a?) a,
    }.toList()
      ..sort((a, b) => ref.agent(a).name.compareTo(ref.agent(b).name));
    final maps = {
      for (final s in summaries) s.mapId,
      if (filter.mapId case final m?) m,
    }.toList()
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

  /// 與 [games] 同一批場次的完整資料（武器統計、多殺與殘局、熱區圖用）。
  final List<MatchDetail> details;

  /// 篩選的地圖；沒有時熱區圖用最常玩的地圖。
  final String? mapId;
  final MatchReferenceProvider ref;

  const _StatsView(
      {required this.games,
      this.details = const [],
      this.mapId,
      required this.ref});

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
      ..._extras(context),
    ]);
  }
}

extension on _StatsView {
  /// 跨場的武器統計、多殺與殘局、某張地圖的擊殺熱區（只用已載入的場次）。
  List<Widget> _extras(BuildContext context) {
    if (details.isEmpty) return const [];
    String focus(MatchDetail d) => d.summary.focusPuuid;
    final weapons = <WeaponStat>[];
    {
      final byFocus = <String, List<MatchDetail>>{};
      for (final d in details) {
        (byFocus[focus(d)] ??= []).add(d);
      }
      final merged = <String, WeaponStat>{};
      for (final e in byFocus.entries) {
        for (final w in weaponStats(e.value, e.key)) {
          final m = merged[w.weapon];
          merged[w.weapon] = m == null
              ? w
              : WeaponStat(
                  weapon: w.weapon,
                  kills: m.kills + w.kills,
                  headshots: m.headshots + w.headshots,
                  shots: m.shots + w.shots,
                  rounds: m.rounds + w.rounds,
                  roundsWon: m.roundsWon + w.roundsWon);
        }
      }
      weapons.addAll(
          merged.values.toList()..sort((a, b) => b.kills.compareTo(a.kills)));
    }
    final highlights = details.fold<PlayerHighlights>(
        const PlayerHighlights(), (a, d) => a + matchHighlights(d, focus(d)));

    // 熱區圖：篩選的地圖，沒有篩選時用最常玩的地圖。
    final counts = <String, int>{};
    for (final d in details) {
      counts[d.summary.mapId] = (counts[d.summary.mapId] ?? 0) + 1;
    }
    final map = mapId ??
        (counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .firstOrNull
            ?.key;
    final onMap = details.where((d) => d.summary.mapId == map).toList();
    final heat = [for (final d in onMap) ...heatPoints(d, focus(d))];

    return [
      const SizedBox(height: 16),
      PanelCard(
        key: const ValueKey('stats-highlights'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader(title: '多殺與殘局'),
          if (highlights.isEmpty)
            Text('沒有 3 殺以上或殘局勝利', style: TextStyle(color: AppColors.muted))
          else
            HighlightChips(highlights),
        ]),
      ),
      const SizedBox(height: 16),
      PanelCard(
        key: const ValueKey('stats-weapons'),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader(title: '武器統計'),
          WeaponStatsTable(stats: weapons, ref: ref, limit: 12),
        ]),
      ),
      if (map != null && heat.isNotEmpty) ...[
        const SizedBox(height: 16),
        KillHeatmap(
            points: heat,
            minimap: ref.minimap(map),
            title: '擊殺熱區圖・${ref.map(map).name}（${onMap.length} 場）'),
      ],
    ];
  }
}
