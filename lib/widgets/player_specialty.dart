import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/match_reference_provider.dart';
import '../providers/recent_form_loader.dart';
import '../theme/app_theme.dart';
import 'skin_tile.dart' show SkinIcon;

/// 即時對局的玩家擅長什麼（使用者決定 2026-10-23，AGENTS.md 第 2 節）：
/// 從同一份最近幾場（[queue] 同模式）算出最常玩、表現最好的特務，以及擊殺最多的槍。
/// 不另外送請求；最近幾場還沒載入完時不顯示。
class PlayerSpecialty extends StatelessWidget {
  final String puuid;
  final String queue;
  final int? games;

  const PlayerSpecialty(
      {super.key, required this.puuid, required this.queue, this.games});

  @override
  Widget build(BuildContext context) {
    final loader = context.watch<RecentFormLoader>();
    if (loader.status(puuid, queue: queue, games: games) != FormStatus.done) {
      return const SizedBox.shrink();
    }
    final form = loader.form(puuid, queue: queue, games: games);
    if (form == null || form.games.isEmpty) return const SizedBox.shrink();
    final ref = context.watch<MatchReferenceProvider>();
    final agents = form.agentForms.take(2).toList();
    final weapons = [
      for (final (id, kills) in form.weaponKills)
        if (ref.weapon(id) case final w?) (w, kills),
    ].take(2).toList();
    final muted = TextStyle(color: AppColors.muted, fontSize: 12);
    return Padding(
      key: ValueKey('specialty-$puuid'),
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('近 ${form.games.length} 場擅長', style: muted),
          for (final a in agents)
            Tooltip(
              message:
                  '${ref.agent(a.agentId).name}：${a.games} 場、勝 ${a.wins}、平均 ACS ${a.avgAcs.round()}',
              triggerMode: TooltipTriggerMode.tap,
              // Text.rich：窄螢幕時可以換行，不會 overflow。
              child: Text.rich(
                key: ValueKey('specialty-agent-$puuid-${a.agentId}'),
                TextSpan(children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: SkinIcon(url: ref.agent(a.agentId).iconUrl)),
                  ),
                  TextSpan(
                      text:
                          ' ${ref.agent(a.agentId).name} ${a.games} 場・${(a.wins / a.games * 100).round()}%・ACS ${a.avgAcs.round()}'),
                ]),
                style: AppText.tabular(
                    TextStyle(color: AppColors.text, fontSize: 12)),
              ),
            ),
          if (weapons.isNotEmpty)
            Text(
                '常用槍 ${weapons.map((w) => '${w.$1.name} ${w.$2} 殺').join('、')}',
                key: ValueKey('specialty-weapons-$puuid'),
                style: AppText.tabular(muted)),
        ],
      ),
    );
  }
}
