import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/progress_logic.dart';
import '../models/progress_reference.dart';
import '../providers/progress_provider.dart';
import '../providers/riot_provider.dart';
import '../shell/app_shell.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import '../widgets/skin_tile.dart' show SkinIcon;

String _countdown(Duration d) =>
    d.isNegative ? '—' : '${d.inDays} 天 ${d.inHours % 24} 小時';

/// 通行證與任務：只讀登入者自己的等級、合約與任務（AGENTS.md 第 3 節）。
class ProgressPage extends StatefulWidget {
  final DateTime Function() now;

  const ProgressPage({super.key, this.now = DateTime.now});

  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.watch<RiotProvider>().isLoggedIn) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ProgressProvider>().load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final p = context.watch<ProgressProvider>();

    if (!riot.isLoggedIn) {
      return AppShell(
        currentRoute: '/progress',
        title: '通行證與任務',
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            PanelCard(
              padding: const EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.military_tech,
                title: '登入 Riot 以查看通行證與任務',
                message: '登入後會顯示你的帳號等級、通行證進度與每日／每週任務',
                actionLabel: '登入 Riot',
                onAction: () => Navigator.pushNamed(context, '/riot-login'),
              ),
            ),
          ],
        ),
      );
    }

    final ref = p.ref;
    final contracts = p.contracts;
    final now = widget.now();
    final pass = ref == null || contracts == null
        ? null
        : currentBattlePass(contracts, ref, now);
    final missions =
        ref == null || contracts == null ? null : joinMissions(contracts, ref);
    final refill = contracts?.weeklyRefill;
    final loading = p.isLoading && p.xp == null && contracts == null;

    return AppShell(
      currentRoute: '/progress',
      title: '通行證與任務',
      actions: [
        IconButton(
          tooltip: '重新整理',
          onPressed: p.isLoading ? null : p.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (p.error case final e?)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: PanelCard(
                accent: AppColors.loss,
                child: Row(children: [
                  Expanded(
                      child: Text(e,
                          style: const TextStyle(color: AppColors.error))),
                  OutlinedButton(onPressed: p.refresh, child: const Text('重試')),
                ]),
              ),
            ),
          if (loading)
            for (var i = 0; i < 3; i++)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: SkeletonBox(height: 96),
              )
          else ...[
            KpiStrip(tiles: [
              KpiTile(
                  key: const ValueKey('kpi-level'),
                  label: '帳號等級',
                  value: p.xp == null ? '—' : '${p.xp!.level}'),
              KpiTile(
                  key: const ValueKey('kpi-xp'),
                  label: '本級經驗',
                  value: p.xp == null ? '—' : '${p.xp!.xp}'),
              KpiTile(
                  key: const ValueKey('kpi-pass'),
                  label: '通行證階級',
                  value: pass == null
                      ? '—'
                      : '${pass.reached} / ${pass.tiers.length}'),
              KpiTile(
                  key: const ValueKey('kpi-weekly'),
                  label: '每週任務刷新',
                  value: refill == null
                      ? '—'
                      : _countdown(refill.difference(now))),
            ]),
            const SizedBox(height: 16),
            if (ref != null && contracts != null)
              pass == null
                  ? const PanelCard(
                      padding: EdgeInsets.all(24),
                      child: EmptyState(
                          icon: Icons.military_tech, title: '目前沒有進行中的通行證'),
                    )
                  : _PassCard(pass: pass, ref: ref),
            const SizedBox(height: 16),
            if (missions != null)
              LayoutBuilder(builder: (context, c) {
                final span = bentoColumns(c.maxWidth) == 12 ? 6 : 12;
                return BentoGrid(children: [
                  BentoTile(
                      span: span,
                      child: _MissionCard(
                          key: const ValueKey('missions-daily'),
                          title: '每日任務',
                          missions: missions[MissionKind.daily]!)),
                  BentoTile(
                      span: span,
                      child: _MissionCard(
                          key: const ValueKey('missions-weekly'),
                          title: '每週任務',
                          missions: missions[MissionKind.weekly]!)),
                ]);
              }),
          ],
        ],
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  final BattlePass pass;
  final ProgressReference ref;

  const _PassCard({required this.pass, required this.ref});

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
                    const TextStyle(color: AppColors.muted, fontSize: 13))),
          ),
          if (next == null)
            const Text('已完成全部階級',
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
                    const TextStyle(color: AppColors.muted, fontSize: 12))),
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
                        '第 ${ch.startTier}–${ch.startTier + ch.tiers.length - 1} 階'
                        '${ch.freeRewards.isEmpty ? '' : '・免費 ${ch.freeRewards.length}'}',
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
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
              const Icon(Icons.check_circle, size: 16, color: AppColors.win),
          ]),
          Expanded(
            child: icon == null
                ? const Icon(Icons.card_giftcard, color: AppColors.muted)
                : SkinIcon(url: icon),
          ),
          Text(rewardTypeLabel(reward.type),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 11)),
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

class _MissionCard extends StatelessWidget {
  final String title;
  final List<MissionView> missions;

  const _MissionCard({super.key, required this.title, required this.missions});

  @override
  Widget build(BuildContext context) => PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(title: title),
            if (missions.isEmpty)
              const Text('目前沒有任務', style: TextStyle(color: AppColors.muted))
            else
              for (final m in missions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Expanded(
                            child:
                                Text(m.title, overflow: TextOverflow.ellipsis)),
                        if (m.complete)
                          const StatusChip(
                              label: '完成',
                              color: AppColors.win,
                              icon: Icons.check),
                      ]),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value:
                              (m.complete ? m.target : m.progress) / m.target,
                          minHeight: 6,
                          color: m.complete ? AppColors.win : AppColors.info,
                          backgroundColor: AppColors.surfaceHigh,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(
                            '${m.complete ? m.target : m.progress} / ${m.target}',
                            style: AppText.tabular(const TextStyle(
                                color: AppColors.muted, fontSize: 12))),
                        const Spacer(),
                        Text('+${m.xpGrant} XP',
                            style: AppText.tabular(const TextStyle(
                                color: AppColors.muted, fontSize: 12))),
                      ]),
                    ],
                  ),
                ),
          ],
        ),
      );
}
