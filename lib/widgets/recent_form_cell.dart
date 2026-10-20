import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/recent_form_loader.dart';
import '../screens/match_history_page.dart' show resultColor;
import '../theme/app_theme.dart';

/// 最近 5 場（[queue] 同模式）：勝敗顏色的小方塊（寫 ACS）與平均 ACS。
class RecentFormCell extends StatelessWidget {
  final String puuid;
  final String queue;

  /// 載入時要求的場數（例如即時對局的 10 場）；畫面只顯示最新 5 場。
  final int? games;

  const RecentFormCell(
      {super.key, required this.puuid, required this.queue, this.games});

  @override
  Widget build(BuildContext context) {
    final loader = context.watch<RecentFormLoader>();
    const muted = TextStyle(color: AppColors.muted);
    switch (loader.status(puuid, queue: queue, games: games)) {
      case FormStatus.pending:
      case FormStatus.loading:
        return const Text('…', style: muted);
      case FormStatus.failed:
        return const Text('—', style: muted);
      case FormStatus.done:
        break;
    }
    final all = loader.form(puuid, queue: queue, games: games);
    final form = all == null ? null : RecentForm(all.games.take(5).toList());
    if (form == null || form.games.isEmpty) {
      return const Text('—', style: muted);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < form.games.length; i++)
          Container(
            key: ValueKey('form-$puuid-$i'),
            width: 30,
            margin: const EdgeInsets.only(right: 3),
            padding: const EdgeInsets.symmetric(vertical: 2),
            decoration: BoxDecoration(
              color: resultColor(form.games[i].won).withOpacity(0.25),
              border: Border(
                  bottom: BorderSide(
                      color: resultColor(form.games[i].won), width: 2)),
            ),
            child: Text('${form.games[i].acs}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11)),
          ),
        const SizedBox(width: 6),
        Text('平均 ${form.avgAcs!.round()}', style: muted),
      ],
    );
  }
}
