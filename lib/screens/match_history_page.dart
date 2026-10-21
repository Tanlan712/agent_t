import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../providers/match_history_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/riot_provider.dart';
import '../shell/app_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
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
                  Text(e, style: const TextStyle(color: AppColors.error)),
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
          // 列表：每場一列，細邊框＋左側勝負色條。
          for (final e in history.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(height: 76, child: MatchCard(entry: e, ref: ref)),
            ),
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
          const Center(
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
          child: _RankHeader(
              key: const ValueKey('history-rank'),
              rank: history.rank,
              recentRr: rr,
              ref: ref)),
      BentoTile(
        span: 3,
        child: KpiTile(
          key: const ValueKey('kpi-rr'),
          label: '近 ${rr.length} 場 RR',
          value: rr.isEmpty ? '—' : formatRr(rrSum),
          up: rrUp(rr),
        ),
      ),
      BentoTile(
        span: 2,
        child: KpiTile(
          label: '勝率（${decided.length} 場）',
          value: decided.isEmpty
              ? '—'
              : '${(wins / decided.length * 100).round()}%',
        ),
      ),
      BentoTile(
        span: 3,
        child: KpiTile(
          label: '平均 ACS',
          value: details.isEmpty
              ? '—'
              : '${(details.fold<int>(0, (a, s) => a + s.acs) / details.length).round()}',
        ),
      ),
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
              const Text('最近：', style: TextStyle(color: AppColors.muted)),
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
              style: const TextStyle(color: AppColors.muted)),
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
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
                Text(formatMatchTime(entry.ref.startTime),
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 12)),
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
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
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
