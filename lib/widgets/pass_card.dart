import 'package:flutter/material.dart';

import '../logic/progress_logic.dart';
import '../models/progress_reference.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';
import 'skin_tile.dart' show SkinIcon;

/// 通行證或特務合約：目前階級、下一階進度，以及依章節列出的每階獎勵。
class PassCard extends StatelessWidget {
  final BattlePass pass;
  final ProgressReference ref;

  const PassCard({super.key, required this.pass, required this.ref});

  @override
  Widget build(BuildContext context) {
    final next = pass.nextTierXp;
    final chapters = passChapters(pass);
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: pass.name,
            trailing: Text('第 ${pass.reached} 階 / ${pass.tiers.length}',
                style: AppText.tabular(
                    TextStyle(color: AppColors.muted, fontSize: 13))),
          ),
          if (next == null)
            Text('已完成全部階級',
                style: TextStyle(
                    color: AppColors.win, fontWeight: FontWeight.w600))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                key: const ValueKey('bp-progress'),
                value: next <= 0 ? 0 : (pass.towardsNext / next).clamp(0, 1),
                minHeight: 8,
                color: AppColors.primary,
                backgroundColor: AppColors.surfaceHigh,
              ),
            ),
            const SizedBox(height: 6),
            Text('下一階 ${pass.towardsNext} / $next XP',
                style: AppText.tabular(
                    TextStyle(color: AppColors.muted, fontSize: 12))),
          ],
          const SizedBox(height: 16),
          for (final ch in chapters)
            _ChapterSection(
              key: ValueKey('chapter-${ch.number}'),
              chapter: ch,
              pass: pass,
              ref: ref,
              // 目前所在的章預設展開；全部完成時展開最後一章。
              initiallyExpanded: ch.state == ChapterState.current ||
                  (pass.isComplete && ch.number == chapters.length),
            ),
        ],
      ),
    );
  }
}

/// 通行證的一章：標題、狀態、5 個階級與免費獎勵；可收合。
class _ChapterSection extends StatefulWidget {
  final PassChapter chapter;
  final BattlePass pass;
  final ProgressReference ref;
  final bool initiallyExpanded;

  const _ChapterSection({
    super.key,
    required this.chapter,
    required this.pass,
    required this.ref,
    required this.initiallyExpanded,
  });

  @override
  State<_ChapterSection> createState() => _ChapterSectionState();
}

class _ChapterSectionState extends State<_ChapterSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final ch = widget.chapter;
    final pass = widget.pass;
    final (label, color) = switch (ch.state) {
      ChapterState.done => ('已完成', AppColors.win),
      ChapterState.current => ('進行中', AppColors.primary),
      ChapterState.locked => ('未解鎖', AppColors.muted),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(children: [
                  Text(ch.isEpilogue ? '尾聲' : '第 ${ch.number} 章',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  StatusChip(label: label, color: color),
                  const Spacer(),
                  if (!_expanded)
                    Text(
                        [
                          if (ch.tierRange.isNotEmpty) ch.tierRange,
                          if (ch.freeRewards.isNotEmpty)
                            '免費 ${ch.freeRewards.length}',
                        ].join('・'),
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.muted),
                ]),
              ),
            ),
          ),
          if (_expanded)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < ch.tiers.length; i++)
                  () {
                    final n = ch.startTier + i;
                    return _RewardTile(
                      key: ValueKey('tier-$n'),
                      badge: '$n',
                      reward: ch.tiers[i].reward,
                      ref: widget.ref,
                      reached: n <= pass.reached,
                      isNext: n == pass.reached + 1 && !pass.isComplete,
                    );
                  }(),
                for (var j = 0; j < ch.freeRewards.length; j++)
                  _RewardTile(
                    key: ValueKey('free-${ch.number}-$j'),
                    badge: '免費',
                    reward: ch.freeRewards[j],
                    ref: widget.ref,
                    reached: ch.state == ChapterState.done,
                    isNext: false,
                    free: true,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 一個獎勵格：階數（或「免費」）、類型、圖示、名稱；已達成打勾、下一階紅框、免費金框。
class _RewardTile extends StatelessWidget {
  final String badge;
  final RefReward reward;
  final ProgressReference ref;
  final bool reached;
  final bool isNext;
  final bool free;

  const _RewardTile({
    super.key,
    required this.badge,
    required this.reward,
    required this.ref,
    required this.reached,
    required this.isNext,
    this.free = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = rewardIcon(reward, ref);
    final borderColor = isNext
        ? AppColors.primary
        : free
            ? AppColors.warn
            : AppColors.outline;
    return Container(
      key: isNext ? const ValueKey('tier-next') : null,
      width: 132,
      height: 148,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: reached ? AppColors.surfaceHigh : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: isNext || free ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(badge,
                style: AppText.tabular(TextStyle(
                    color: free ? AppColors.warn : AppColors.muted,
                    fontSize: 12,
                    fontWeight: free ? FontWeight.w600 : FontWeight.w400))),
            const Spacer(),
            if (reached)
              Icon(Icons.check_circle, size: 16, color: AppColors.win),
          ]),
          Expanded(
            child: icon == null
                ? Icon(Icons.card_giftcard, color: AppColors.muted)
                : SkinIcon(url: icon),
          ),
          Text(rewardTypeLabel(reward.type),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
          Text(rewardLabel(reward, ref),
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
