import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/live_mapper.dart';
import '../logic/match_mapper.dart' show queueName;
import '../models/live_models.dart';
import '../models/match_models.dart';
import '../providers/live_party_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/recent_form_loader.dart' show RankStatus;
import '../providers/riot_provider.dart';
import '../services/live_client.dart';
import '../services/match_client.dart';
import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import '../widgets/skin_tile.dart' show SkinIcon;

/// 即時對局（目前只有隊伍階段）。只有 GET，頁面開著時每 10 秒更新。
class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  late final LivePartyProvider _live;

  @override
  void initState() {
    super.initState();
    _live = LivePartyProvider(context.read<LiveClient>(),
        context.read<MatchClient>(), context.read<RiotProvider>());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<RiotProvider>().isLoggedIn) _live.start();
    });
  }

  @override
  void dispose() {
    _live.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    return AppShell(
      currentRoute: '/live',
      title: '即時對局',
      actions: [
        if (riot.isLoggedIn)
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '重新整理',
            onPressed: _live.refresh,
          ),
      ],
      child: !riot.isLoggedIn
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('登入 Riot 以查看即時對局'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/riot-login'),
                    child: const Text('登入 Riot'),
                  ),
                ],
              ),
            )
          : ListenableBuilder(
              listenable: _live,
              builder: (context, _) => _body(context),
            ),
    );
  }

  Widget _body(BuildContext context) {
    final party = _live.party;
    if (party == null) {
      switch (_live.status) {
        case LiveStatus.noParty:
          return const Center(child: Text('遊戲沒有開啟，或目前不在大廳'));
        case LiveStatus.error:
        case LiveStatus.loggedOut:
          return Center(
              child: Text(_live.error ?? '讀取失敗',
                  style: const TextStyle(color: AppColors.error)));
        default:
          return const Center(child: CircularProgressIndicator());
      }
    }
    final ref = context.watch<MatchReferenceProvider>();
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _PartyHeader(party: party),
        if (_live.error case final e?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(e, style: const TextStyle(color: AppColors.error)),
          ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minTileWidth: 260,
          childAspectRatio: 2.6,
          children: [
            for (final m in party.members)
              _MemberCard(member: m, live: _live, ref: ref),
          ],
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text('名稱資料來自 Riot，請勿公開或分享他人資訊；隱藏名稱、等級或牌位的成員不會顯示。',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

class _PartyHeader extends StatelessWidget {
  final LiveParty party;

  const _PartyHeader({required this.party});

  @override
  Widget build(BuildContext context) {
    final since = party.queueEntryTime;
    final waited =
        since == null ? null : DateTime.now().toUtc().difference(since);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('隊伍・${partyStateLabel(party.state)}',
                style: Theme.of(context).textTheme.titleLarge),
            if (party.queueId.isNotEmpty) Text(queueName(party.queueId)),
            Text(party.isOpen ? '公開' : '不公開',
                style: const TextStyle(color: AppColors.muted)),
            if (waited != null && !waited.isNegative)
              Text(
                  '已排隊 ${waited.inMinutes}:${(waited.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final PartyMember member;
  final LivePartyProvider live;
  final MatchReferenceProvider ref;

  const _MemberCard(
      {required this.member, required this.live, required this.ref});

  void _open(BuildContext context) {
    final nav = Navigator.of(context);
    if (member.isMe) {
      nav.pushNamedAndRemoveUntil('/matches', (_) => false);
    } else {
      nav.pushNamed('/players/detail',
          arguments: PlayerRef(
              puuid: member.puuid, riotId: live.name(member.puuid) ?? '玩家'));
    }
  }

  Widget _rank() {
    final key = ValueKey('live-rank-${member.puuid}');
    switch (live.rankStatus(member.puuid)) {
      case RankStatus.visible:
        final tier = ref.tier(member.tier);
        return Tooltip(
            key: key,
            message: tier.name,
            child: SizedBox(
                width: 28, height: 28, child: SkinIcon(url: tier.iconUrl)));
      case RankStatus.hidden:
        return Tooltip(
            key: key,
            message: '玩家已隱藏牌位',
            child: const Icon(Icons.visibility_off,
                size: 20, color: AppColors.muted));
      case RankStatus.unavailable:
        return Tooltip(
            key: key,
            message: '無法確認是否公開，不顯示',
            child: const Icon(Icons.remove, size: 20, color: AppColors.muted));
      case RankStatus.pending:
        return Tooltip(
            key: key,
            message: '確認牌位是否公開中',
            child: const SizedBox(width: 28, height: 28));
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = member.incognito ? '已隱藏名稱' : (live.name(member.puuid) ?? '…');
    return Card(
      key: ValueKey('live-member-${member.puuid}'),
      clipBehavior: Clip.antiAlias,
      color: member.isMe ? AppColors.surfaceHigh : null,
      child: InkWell(
        // 隱藏名稱的成員不能點（AGENTS.md：不得去匿名化）。
        onTap: member.incognito ? null : () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                  width: 56,
                  height: 56,
                  child: SkinIcon(url: playerCardUrl(member.cardId))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              key: ValueKey('live-name-${member.puuid}'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: member.incognito
                                      ? AppColors.muted
                                      : null)),
                        ),
                        if (member.isOwner) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.star,
                              key: ValueKey('live-owner-${member.puuid}'),
                              size: 16,
                              color: AppColors.wishlistGold),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (!member.hideLevel) ...[
                          Text('Lv ${member.level}',
                              key: ValueKey('live-level-${member.puuid}'),
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                          const SizedBox(width: 12),
                        ],
                        Text(member.isReady ? '已準備' : '未準備',
                            style: TextStyle(
                                color: member.isReady
                                    ? AppColors.owned
                                    : AppColors.muted,
                                fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              _rank(),
            ],
          ),
        ),
      ),
    );
  }
}
