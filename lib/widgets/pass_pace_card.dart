import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/progress_logic.dart';
import '../storage/pass_xp_storage.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';

/// 通行證節奏：距賽季結束幾天、每天／每週要拿多少 XP 才能升滿，以及每日經驗紀錄。
/// 每日紀錄靠每天打開這頁時存下的累積經驗（只存在本機）。
class PassPaceCard extends StatefulWidget {
  final BattlePass pass;
  final String puuid;
  final DateTime now;

  const PassPaceCard(
      {super.key, required this.pass, required this.puuid, required this.now});

  @override
  State<PassPaceCard> createState() => _PassPaceCardState();
}

class _PassPaceCardState extends State<PassPaceCard> {
  Map<String, int> _log = const {};
  String? _recorded;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _record();
  }

  @override
  void didUpdateWidget(PassPaceCard old) {
    super.didUpdateWidget(old);
    _record();
  }

  void _record() {
    final storage = context.read<PassXpStorage?>();
    final id = widget.pass.contractId;
    if (storage == null || id == null) return;
    final earned = passEarnedXp(widget.pass);
    final day = xpDayKey(widget.now);
    final mark = '${widget.puuid}|$id|$day|$earned';
    if (mark == _recorded) return;
    _recorded = mark;
    _log = storage.load(widget.puuid, id);
    storage.record(widget.puuid, id, day, earned).then((log) {
      if (mounted) setState(() => _log = log);
    });
  }

  @override
  Widget build(BuildContext context) {
    final pace = passPace(widget.pass, widget.now);
    if (pace == null) return const SizedBox.shrink();
    final gains = dailyXpGains(_log);
    final muted = TextStyle(color: AppColors.muted, fontSize: 13);
    String n(int v) => v
        .toString()
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

    return PanelCard(
      key: const ValueKey('pass-pace'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionHeader(title: '通行證節奏'),
          Wrap(spacing: 24, runSpacing: 12, children: [
            _Stat(
                key: const ValueKey('pace-days'),
                label: '賽季剩餘',
                value: pace.daysLeft <= 0 ? '已結束' : '${pace.daysLeft} 天'),
            _Stat(
                key: const ValueKey('pace-remaining'),
                label: '升滿還差',
                value: pace.isDone ? '已升滿' : '${n(pace.remainingXp)} XP'),
            if (!pace.isDone && pace.perDay != null) ...[
              _Stat(
                  key: const ValueKey('pace-per-day'),
                  label: '每天要拿',
                  value: '${n(pace.perDay!)} XP'),
              _Stat(
                  key: const ValueKey('pace-per-week'),
                  label: '每週要拿',
                  value: '${n(pace.perWeek!)} XP'),
            ],
          ]),
          const SizedBox(height: 8),
          Text('已累積 ${n(pace.earnedXp)} / ${n(pace.targetXp)} XP（不含尾聲）',
              style: AppText.tabular(muted)),
          const SizedBox(height: 16),
          const Text('每日經驗紀錄', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (gains.isEmpty)
            Text('每天打開這頁會記下進度，明天起就能看到每天拿了多少經驗', style: muted)
          else
            for (final (day, gained) in gains)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  SizedBox(
                      width: 96,
                      child: Text(day.substring(5).replaceAll('-', '/'),
                          style: AppText.tabular(muted))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pace.perDay == null || pace.perDay == 0
                            ? (gained > 0 ? 1 : 0)
                            : (gained / pace.perDay!).clamp(0, 1),
                        minHeight: 6,
                        color: pace.perDay != null && gained >= pace.perDay!
                            ? AppColors.win
                            : AppColors.info,
                        backgroundColor: AppColors.surfaceHigh,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: Text('+${n(gained)} XP',
                        textAlign: TextAlign.end,
                        style: AppText.tabular(muted)),
                  ),
                ]),
              ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 2),
          Text(value,
              style: AppText.tabular(
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
        ],
      );
}
