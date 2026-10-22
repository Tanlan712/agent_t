import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../logic/progress_logic.dart';
import '../../models/progress_reference.dart';
import '../../providers/progress_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud/hud.dart';
import '../../widgets/pass_card.dart';
import '../../widgets/skin_tile.dart' show SkinIcon;
import 'detail_scaffold.dart';

/// 我的收藏 › 特務：點特務看合約等級、章節與每階獎勵（使用者決定 2026-10-22）。
/// 只用已讀到的合約進度（contracts GET）與參考資料，不送新的請求。
class AgentLevelPage extends StatelessWidget {
  final RefAgent agent;

  const AgentLevelPage({super.key, required this.agent});

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final ref = progress.ref;
    final snapshot = progress.contracts;
    final a = agent;

    Widget status(IconData icon, String title) => PanelCard(
          padding: const EdgeInsets.all(24),
          child: EmptyState(icon: icon, title: title),
        );

    final Widget body;
    if (ref == null || snapshot == null) {
      body = progress.isLoading
          ? status(Icons.hourglass_empty, '讀取等級中…')
          : status(Icons.error_outline, '無法取得等級');
    } else {
      final pass = agentContract(snapshot, ref, a.uuid);
      body = pass == null
          ? status(Icons.military_tech, '找不到這個特務的合約資料')
          : PassCard(key: const ValueKey('agent-pass'), pass: pass, ref: ref);
    }

    return DetailScaffold(title: a.name, children: [
      PanelCard(
        child: Row(children: [
          SizedBox(width: 64, height: 64, child: SkinIcon(url: a.iconUrl)),
          const SizedBox(width: 16),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(a.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
              Text(a.role, style: TextStyle(color: AppColors.muted)),
            ]),
          ),
        ]),
      ),
      body,
    ]);
  }
}
