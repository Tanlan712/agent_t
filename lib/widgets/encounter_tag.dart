import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/encounters.dart';
import '../logic/match_mapper.dart' show queueName;
import '../models/encounter.dart';
import '../providers/encounter_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/riot_provider.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';

/// 即時對局裡「之前遇過」的標籤（使用者決定 2026-10-23，AGENTS.md 第 2 節）。
/// 只根據本機記下的、自己也在場的已結束場次；滑鼠移上去或點一下看每場的日期、地圖、隊友／對手與勝負。
class EncounterTag extends StatelessWidget {
  final String puuid;

  /// 正在進行的這場，不算在「遇過」裡。
  final String matchId;

  const EncounterTag({super.key, required this.puuid, required this.matchId});

  static String _line(Encounter e, MatchReferenceProvider ref) {
    final t = e.startTime;
    final result = switch (e.won) { true => '勝', false => '敗', null => '平' };
    return [
      '${t.month}/${t.day}',
      ref.map(e.mapId).name,
      if (e.queueId.isNotEmpty) queueName(e.queueId),
      e.ally ? '隊友' : '對手',
      result,
    ].join('・');
  }

  static String _record(String role, int games, int wins, int losses) =>
      '$role $games 場（$wins 勝 $losses 敗）';

  @override
  Widget build(BuildContext context) {
    final self = context.select<RiotProvider, String?>((r) => r.session?.puuid);
    final provider = context.watch<EncounterProvider>();
    if (self == null) return const SizedBox.shrink();
    final list = provider.withPlayer(self, puuid, exclude: matchId);
    if (list.isEmpty) return const SizedBox.shrink();
    final ref = context.watch<MatchReferenceProvider>();
    final s = EncounterSummary.of(list);
    // 每位玩家只保留最近幾場，滿了就加「+」表示可能更多。
    final count = list.length >= provider.maxPerPlayer
        ? '${list.length}+'
        : '${list.length}';
    final label = '遇過 $count';
    final detail = [
      if (s.allyGames > 0)
        _record('當隊友', s.allyGames, s.allyWins, s.allyLosses),
      if (s.enemyGames > 0)
        _record('當對手', s.enemyGames, s.enemyWins, s.enemyLosses),
      '',
      for (final e in list) _line(e, ref),
      '',
      '（依這台裝置看過的對戰紀錄）',
    ].join('\n');
    // 和名稱、其他標籤共用一列：窄螢幕放不下時等比例縮小，不 overflow。
    return Flexible(
        child: Padding(
      padding: const EdgeInsets.only(left: 6),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        // 滑鼠移上去看提示；手機點一下開對話框。
        child: Tooltip(
          key: ValueKey('met-$puuid'),
          message: detail,
          child: InkWell(
            key: ValueKey('met-tap-$puuid'),
            onTap: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text(label),
                content: Text(detail),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c),
                      child: const Text('關閉')),
                ],
              ),
            ),
            child: StatusChip(
                label: label,
                color: s.enemyGames > 0 && s.allyGames == 0
                    ? AppColors.loss
                    : AppColors.info,
                icon: Icons.history),
          ),
        ),
      ),
    ));
  }
}
