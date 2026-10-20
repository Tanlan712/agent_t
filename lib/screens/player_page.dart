import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_models.dart';
import '../providers/match_detail_cache.dart';
import '../providers/match_reference_provider.dart';
import '../providers/player_history_provider.dart';
import '../providers/riot_provider.dart';
import '../providers/seen_players_provider.dart';
import '../services/match_client.dart';
import '../theme/app_theme.dart';
import '../shell/responsive_grid.dart';
import 'match_history_page.dart' show MatchCard;

/// 其他玩家的對戰紀錄；資料只放在記憶體，離開頁面即釋放。
class PlayerPage extends StatefulWidget {
  final PlayerRef player;

  const PlayerPage({super.key, required this.player});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerHistoryProvider _history;

  @override
  void initState() {
    super.initState();
    _history = PlayerHistoryProvider(context.read<MatchClient>(),
        context.read<RiotProvider>(), context.read<MatchDetailCache>(),
        puuid: widget.player.puuid,
        onDetails: context.read<SeenPlayersProvider>().recordAll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _history.loadFirstPage();
    });
  }

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.player.riotId)),
      body: ListenableBuilder(
        listenable: _history,
        builder: (context, _) => _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final h = _history;
    final ref = context.watch<MatchReferenceProvider>();
    if (h.entries.isEmpty && h.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final recent = [
      for (final e in h.entries.take(5))
        if (e.detail case final d?) d.summary.acs,
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (recent.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                  '最近 ${recent.length} 場平均 ACS '
                  '${(recent.reduce((a, b) => a + b) / recent.length).round()}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ),
        if (h.error case final e?)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(e, style: const TextStyle(color: AppColors.error)),
                if (h.entries.isEmpty && !h.isLoading)
                  OutlinedButton(
                    onPressed: h.loadFirstPage,
                    child: const Text('重試'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minTileWidth: 420,
          childAspectRatio: 3.4,
          children: [
            for (final e in h.entries)
              MatchCard(entry: e, ref: ref, otherPlayer: true),
          ],
        ),
        if (h.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Center(
              child: OutlinedButton(
                onPressed: h.isLoading ? null : h.loadMore,
                child: h.isLoading
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
}
