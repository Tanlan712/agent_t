import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_models.dart';
import '../providers/seen_players_provider.dart';
import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import 'match_history_page.dart' show formatMatchTime;

/// 對戰中遇過的玩家（存在這個瀏覽器），點擊可查詢他的對戰紀錄。
class SeenPlayersPage extends StatefulWidget {
  const SeenPlayersPage({super.key});

  @override
  State<SeenPlayersPage> createState() => _SeenPlayersPageState();
}

class _SeenPlayersPageState extends State<SeenPlayersPage> {
  String _query = '';

  Future<void> _clearAll(BuildContext context) async {
    final seen = context.read<SeenPlayersProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清除所有遇過的玩家？'),
        content: const Text('只會刪除這個瀏覽器裡的紀錄，無法復原。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok == true) await seen.clear();
  }

  @override
  Widget build(BuildContext context) {
    final seen = context.watch<SeenPlayersProvider>();
    final list = seen.search(_query);

    final Widget body;
    if (seen.players.isEmpty) {
      body = const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('還沒有遇過的玩家'),
            SizedBox(height: 8),
            Text('打開對戰紀錄後，同場的玩家會自動記錄在這裡',
                style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜尋 Riot ID',
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: list.isEmpty
                ? const EmptyState(icon: Icons.person_search, title: '找不到符合的玩家')
                : ResponsiveGridView.builder(
                    minTileWidth: 280,
                    childAspectRatio: 3.6,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final p = list[i];
                      return PanelCard(
                        padding: EdgeInsets.zero,
                        child: Center(
                          child: ListTile(
                            leading: const Icon(Icons.person_outline),
                            title: Text(p.riotId),
                            subtitle: Text(
                                '最後遇到：${p.lastSeenKnown ? formatMatchTime(p.lastSeen) : '—'}',
                                style: const TextStyle(color: AppColors.muted)),
                            trailing: IconButton(
                              key: ValueKey('seen-delete-${p.puuid}'),
                              icon: const Icon(Icons.delete_outline),
                              tooltip: '刪除',
                              onPressed: () => seen.remove(p.puuid),
                            ),
                            onTap: () => Navigator.pushNamed(
                                context, '/players/detail',
                                arguments: PlayerRef(
                                    puuid: p.puuid, riotId: p.riotId)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text('共 ${seen.players.length} 位・只存在這個瀏覽器，請勿公開或分享他人資訊',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ),
        ],
      );
    }

    return AppShell(
      currentRoute: '/players',
      title: '遇過的玩家',
      subtitle: seen.players.isEmpty ? null : '${seen.players.length} 位玩家',
      actions: [
        if (seen.players.isNotEmpty)
          TextButton(
              onPressed: () => _clearAll(context), child: const Text('全部清除')),
      ],
      child: body,
    );
  }
}
