import 'package:flutter/material.dart';

import '../../logic/database_logic.dart';
import '../../models/game_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud/hud.dart';
import '../../widgets/skin_tile.dart' show SkinIcon;
import 'detail_scaffold.dart';

/// 特務詳細頁：頭像、定位、介紹與技能（依 C、Q、E、X、被動）。
/// 公開資料沒有技能與解鎖價格，不顯示價格（使用者決定 2026-10-21）。
class AgentDetailPage extends StatelessWidget {
  final AgentInfo agent;

  const AgentDetailPage({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    final a = agent;
    return DetailScaffold(title: a.name, children: [
      PanelCard(
        child: LayoutBuilder(builder: (context, c) {
          final portrait = SizedBox(
            width: 200,
            height: 220,
            child: SkinIcon(url: a.portrait ?? a.icon),
          );
          final info =
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(a.name,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            if (a.role case final r?)
              Text(r, style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            Text(a.description, style: const TextStyle(height: 1.5)),
          ]);
          return c.maxWidth < 560
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [Center(child: portrait), info])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  portrait,
                  const SizedBox(width: 16),
                  Expanded(child: info),
                ]);
        }),
      ),
      const SectionHeader(title: '技能'),
      for (final ab in sortedAbilities(a.abilities))
        PanelCard(
          key: ValueKey('ability-${abilityKey(ab.slot)}'),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox.square(
              dimension: 40,
              child: ab.icon == null
                  ? Icon(Icons.bolt, color: AppColors.muted)
                  : SkinIcon(url: ab.icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      StatusChip(
                          label: abilityKey(ab.slot), color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(ab.name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Text(ab.description, style: const TextStyle(height: 1.5)),
                  ]),
            ),
          ]),
        ),
    ]);
  }
}
