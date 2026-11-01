import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../logic/match_mapper.dart' show queueName;
import '../logic/today_summary.dart';
import '../models/match_models.dart';
import '../providers/match_reference_provider.dart';
import '../services/file_share.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';

String _signed(int n) => n > 0 ? '+$n' : '$n';

String _dateLabel(DateTime d) {
  final l = d.toLocal();
  return '${l.year}/${l.month}/${l.day}';
}

/// 對戰紀錄頁頂端的「今日小結」：今天的場次、勝率、RR 淨變化，可以產生分享圖片。
class TodaySummaryCard extends StatelessWidget {
  final TodaySummary summary;
  final MatchReferenceProvider ref;
  final String playerName;
  final RankInfo? rank;
  final DateTime now;

  /// 測試時注入。
  final FileShare? files;

  const TodaySummaryCard({
    super.key,
    required this.summary,
    required this.ref,
    required this.playerName,
    this.rank,
    required this.now,
    this.files,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final rr = s.rrNet;
    final agent = s.topAgentId;
    final stats = <(String, String, Color?)>[
      ('場數', '${s.count}', null),
      ('勝-負', '${s.wins}-${s.losses}${s.draws > 0 ? '-${s.draws}' : ''}', null),
      ('勝率', s.winRate == null ? '—' : '${s.winRate}%', null),
      (
        'RR',
        rr == null ? '—' : _signed(rr),
        rr == null || rr == 0 ? null : (rr > 0 ? AppColors.win : AppColors.loss)
      ),
      ('K/D', s.kd.toStringAsFixed(2), null),
      ('平均 ACS', s.avgAcs == 0 ? '—' : '${s.avgAcs}', null),
    ];
    return PanelCard(
      key: const ValueKey('today-summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: '今日小結',
            trailing: TextButton.icon(
              key: const ValueKey('today-share'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => TodayShareDialog(
                  summary: s,
                  ref: ref,
                  playerName: playerName,
                  rank: rank,
                  now: now,
                  files: files ?? FileShare.platform(),
                ),
              ),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('分享圖片'),
            ),
          ),
          Wrap(spacing: 20, runSpacing: 10, children: [
            for (final (label, value, color) in stats)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label,
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  Text(value,
                      style: AppText.tabular(TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: color))),
                ],
              ),
          ]),
          if (agent != null || s.partial) ...[
            const SizedBox(height: 8),
            Text(
              [
                if (agent != null) '最常用：${ref.agent(agent).name}',
                if (s.partial) '只計算已載入的場次，按「載入更多」可補齊',
              ].join(' · '),
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// 分享圖片的預覽與分享／儲存按鈕。
class TodayShareDialog extends StatefulWidget {
  final TodaySummary summary;
  final MatchReferenceProvider ref;
  final String playerName;
  final RankInfo? rank;
  final DateTime now;
  final FileShare files;

  const TodayShareDialog({
    super.key,
    required this.summary,
    required this.ref,
    required this.playerName,
    this.rank,
    required this.now,
    required this.files,
  });

  @override
  State<TodayShareDialog> createState() => _TodayShareDialogState();
}

class _TodayShareDialogState extends State<TodayShareDialog> {
  final _boundary = GlobalKey();
  bool _busy = false;

  String get _fileName {
    final l = widget.now.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return 'agent-t-today-${l.year}${two(l.month)}${two(l.day)}.png';
  }

  Future<void> _run(bool share) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await _capture();
      if (bytes == null) {
        messenger.showSnackBar(const SnackBar(content: Text('產生圖片失敗')));
        return;
      }
      final ok = share
          ? await widget.files
              .share(_fileName, 'image/png', bytes, text: 'Agent T 今日小結')
          : await widget.files.save(_fileName, 'image/png', bytes);
      if (!share && ok) {
        messenger.showSnackBar(const SnackBar(content: Text('已儲存圖片')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Uint8List?> _capture() async {
    final box = _boundary.currentContext?.findRenderObject();
    if (box is! RenderRepaintBoundary) return null;
    final image = await box.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    final files = widget.files;
    return AlertDialog(
      title: const Text('分享今日小結'),
      content: SingleChildScrollView(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: RepaintBoundary(
            key: _boundary,
            child: TodayShareImage(
              summary: widget.summary,
              ref: widget.ref,
              playerName: widget.playerName,
              rank: widget.rank,
              now: widget.now,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('關閉')),
        if (files.canSave)
          OutlinedButton(
            key: const ValueKey('today-save-image'),
            onPressed: _busy ? null : () => _run(false),
            child: const Text('儲存圖片'),
          ),
        if (files.canShare)
          FilledButton(
            key: const ValueKey('today-share-image'),
            onPressed: _busy ? null : () => _run(true),
            child: const Text('分享'),
          ),
      ],
    );
  }
}

/// 分享圖片本身：固定 360 寬，只含自己的數據（不含他人資訊）。
class TodayShareImage extends StatelessWidget {
  final TodaySummary summary;
  final MatchReferenceProvider ref;
  final String playerName;
  final RankInfo? rank;
  final DateTime now;

  static const maxRows = 8;

  const TodayShareImage({
    super.key,
    required this.summary,
    required this.ref,
    required this.playerName,
    this.rank,
    required this.now,
  });

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final rr = s.rrNet;
    final r = rank;
    final tier = r == null || r.tier == 0 ? null : ref.tier(r.tier).name;
    final big = AppText.tabular(TextStyle(
        fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.text));
    Widget stat(String label, String value, {Color? color}) => Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
              Text(value, style: big.copyWith(color: color)),
            ],
          ),
        );
    // 圖片要不透明（玻璃類主題的卡片是半透明）。
    final bg = Color.alphaBlend(
        AppColors.surface, AppColors.background.withAlpha(255));
    return Material(
      color: bg,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.primary, width: 6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text('今日小結',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const Spacer(),
              Text(_dateLabel(now),
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
            ]),
            const SizedBox(height: 4),
            Text(
              [playerName, if (tier != null) '$tier · ${r!.rr} RR'].join('  '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            Row(children: [
              stat('戰績', '${s.wins}勝 ${s.losses}敗'),
              stat('勝率', s.winRate == null ? '—' : '${s.winRate}%'),
              stat('RR', rr == null ? '—' : _signed(rr),
                  color: rr == null || rr == 0
                      ? null
                      : (rr > 0 ? AppColors.win : AppColors.loss)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              stat('場數', '${s.count}'),
              stat('K/D', s.kd.toStringAsFixed(2)),
              stat('ACS', s.avgAcs == 0 ? '—' : '${s.avgAcs}'),
            ]),
            const SizedBox(height: 16),
            Divider(height: 1, color: AppColors.muted.withOpacity(0.3)),
            const SizedBox(height: 8),
            for (final g in s.games.take(maxRows))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Container(
                    width: 4,
                    height: 18,
                    color: switch (g.won) {
                      true => AppColors.win,
                      false => AppColors.loss,
                      null => AppColors.muted,
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${ref.map(g.mapId).name} · ${ref.agent(g.myAgentId).name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.text),
                    ),
                  ),
                  Text(
                    '${g.myScore}:${g.enemyScore}  ${g.kills}/${g.deaths}/${g.assists}'
                    '${g.rrChange == null ? '' : '  ${_signed(g.rrChange!)}'}',
                    style: AppText.tabular(
                        TextStyle(fontSize: 12, color: AppColors.muted)),
                  ),
                ]),
              ),
            if (s.games.length > maxRows)
              Text('還有 ${s.games.length - maxRows} 場',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            Text(
              'Agent T · ${{
                for (final g in s.games) queueName(g.queueId)
              }.join('／')}',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
