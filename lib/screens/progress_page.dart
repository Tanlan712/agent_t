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
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(title: pass.name),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < pass.tiers.length; i++)
                _TierTile(
                  key: ValueKey('tier-${i + 1}'),
                  number: i + 1,
                  tier: pass.tiers[i],
                  ref: ref,
                  reached: i < pass.reached,
                  isNext: i == pass.reached && next != null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierTile extends StatelessWidget {
  final int number;
  final RefTier tier;
  final ProgressReference ref;
  final bool reached;
  final bool isNext;

  const _TierTile({
    super.key,
    required this.number,
    required this.tier,
    required this.ref,
    required this.reached,
    required this.isNext,
  });

  @override
  Widget build(BuildContext context) {
    final icon = rewardIcon(tier.reward, ref);
    return Container(
      key: isNext ? const ValueKey('tier-next') : null,
      width: 120,
      height: 128,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: reached ? AppColors.surfaceHigh : AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isNext ? AppColors.primary : AppColors.outline,
            width: isNext ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('$number',
                style: AppText.tabular(
                    const TextStyle(color: AppColors.muted, fontSize: 12))),
            const Spacer(),
            if (reached)
              const Icon(Icons.check_circle, size: 16, color: AppColors.win),
          ]),
          Expanded(
            child: icon == null
                ? const Icon(Icons.card_giftcard, color: AppColors.muted)
                : SkinIcon(url: icon),
          ),
          Text(rewardLabel(tier.reward, ref),
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
