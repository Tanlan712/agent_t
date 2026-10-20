import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../providers/match_history_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/riot_provider.dart';
import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import '../widgets/skin_tile.dart' show SkinIcon;

String _two(int n) => n.toString().padLeft(2, '0');

String formatMatchTime(DateTime t) =>
    '${t.month}/${t.day} ${_two(t.hour)}:${_two(t.minute)}';

String formatRr(int rr) => rr > 0 ? '+$rr' : '$rr';

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
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('登入 Riot 以查看對戰紀錄'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pushNamed(context, '/riot-login'),
              child: const Text('登入 Riot'),
            ),
          ],
        ),
      );
    } else if (history.entries.isEmpty && history.isLoading) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          _RankHeader(rank: history.rank, recentRr: history.recentRr, ref: ref),
          if (history.error case final e?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(e, style: const TextStyle(color: AppColors.error)),
            ),
          const SizedBox(height: 16),
          ResponsiveGrid(
            minTileWidth: 420,
            childAspectRatio: 3.4,
            children: [
              for (final e in history.entries) _MatchCard(entry: e, ref: ref),
            ],
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

class _RankHeader extends StatelessWidget {
  final RankInfo? rank;
  final List<int> recentRr;
  final MatchReferenceProvider ref;

  const _RankHeader(
      {required this.rank, required this.recentRr, required this.ref});

  @override
  Widget build(BuildContext context) {
    final rank = this.rank;
    final tier = rank == null ? null : ref.tier(rank.tier);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
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

class _MatchCard extends StatelessWidget {
  final MatchEntry entry;
  final MatchReferenceProvider ref;

  const _MatchCard({required this.entry, required this.ref});

  @override
  Widget build(BuildContext context) {
    final d = entry.detail;
    if (d == null) {
      return Card(
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
    return Card(
      key: ValueKey('match-card-${s.matchId}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, '/matches/detail',
            arguments: entry.ref.matchId),
        child: Row(
          children: [
            Container(width: 6, color: resultColor(s.won)),
            SizedBox(width: 72, child: SkinIcon(url: map.iconUrl)),
            const SizedBox(width: 12),
            SizedBox(
                width: 40, height: 40, child: SkinIcon(url: agent.iconUrl)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(map.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(queueName(s.queueId),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  Text(formatMatchTime(entry.ref.startTime),
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
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
      ),
    );
  }
}
