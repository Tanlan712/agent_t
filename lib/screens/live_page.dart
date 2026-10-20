import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/live_mapper.dart';
import '../logic/match_mapper.dart' show queueName;
import '../models/live_models.dart';
import '../models/match_models.dart';
import '../providers/live_party_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/recent_form_loader.dart';
import '../providers/riot_provider.dart';
import '../services/live_client.dart';
import '../services/match_client.dart';
import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import '../widgets/recent_form_cell.dart';
import '../widgets/skin_tile.dart' show SkinIcon;

/// 即時對局（目前只有隊伍階段）。只有 GET，頁面開著時每 10 秒更新。
class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  late final LivePartyProvider _live;
  late final RecentFormLoader _forms;
  String? _formsFor;

  @override
  void initState() {
    super.initState();
    _live = LivePartyProvider(context.read<LiveClient>(),
        context.read<MatchClient>(), context.read<RiotProvider>());
    _forms = context.read<RecentFormLoader>();
    _live.addListener(_requestForms);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<RiotProvider>().isLoggedIn) _live.start();
    });
  }

  /// 使用者決定（AGENTS.md 第 2 節）：對局中查每位玩家的最近 5 場（同模式，教練除外）。
  void _requestForms() {
    final m = _live.match;
    if (_live.phase != LivePhase.inGame ||
        m == null ||
        m.matchId == _formsFor) {
      return;
    }
    _formsFor = m.matchId;
    _forms.request([
      for (final id in m.teamIds)
        for (final p in m.team(id))
          if (!p.isCoach) p.puuid,
    ], owner: this, queue: m.queueId);
  }

  @override
  void dispose() {
    _live.removeListener(_requestForms);
    _forms.cancelPending(owner: this);
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
    final ref = context.watch<MatchReferenceProvider>();
    if (_live.phase == LivePhase.inGame && _live.match != null) {
      return _MatchView(match: _live.match!, live: _live, ref: ref);
    }
    if (_live.phase == LivePhase.pregame) {
      return const Center(child: Text('選角中…（對局開始後會自動切換成即時對戰）'));
    }
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
          child: Text('名稱資料來自 Riot，請勿公開或分享他人資訊（包含隱藏名稱的成員）。',
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
    // Riot 會保留上一次排隊的時間，所以只在配對中時顯示。
    final since = party.state == 'MATCHMAKING' ? party.queueEntryTime : null;
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
    final tier = ref.tier(member.tier);
    return Tooltip(
        key: ValueKey('live-rank-${member.puuid}'),
        message: tier.name,
        child: SizedBox(
            width: 28, height: 28, child: SkinIcon(url: tier.iconUrl)));
  }

  @override
  Widget build(BuildContext context) {
    final name = live.name(member.puuid) ?? '…';
    return Card(
      key: ValueKey('live-member-${member.puuid}'),
      clipBehavior: Clip.antiAlias,
      color: member.isMe ? AppColors.surfaceHigh : null,
      child: InkWell(
        onTap: () => _open(context),
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
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
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
                        ...[
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

/// 對局中（core-game）的即時對戰畫面：雙方 10 人，我方在上。
class _MatchView extends StatelessWidget {
  final LiveMatch match;
  final LivePartyProvider live;
  final MatchReferenceProvider ref;

  const _MatchView(
      {required this.match, required this.live, required this.ref});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(ref.map(match.mapId).name,
                    style: Theme.of(context).textTheme.titleLarge),
                if (match.queueId.isNotEmpty) Text(queueName(match.queueId)),
                Text(match.state == 'IN_PROGRESS' ? '進行中' : match.state,
                    style: const TextStyle(color: AppColors.owned)),
              ],
            ),
          ),
        ),
        for (final teamId in match.teamIds) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(teamId == match.myTeamId ? '我方' : '敵方',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: teamId == match.myTeamId
                        ? AppColors.owned
                        : AppColors.error)),
          ),
          Card(
            child: Column(
              children: [
                for (final p in match.team(teamId))
                  _PlayerRow(
                      player: p, live: live, ref: ref, queue: match.queueId),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        const Center(
          child: Text('名稱資料來自 Riot，請勿公開或分享他人資訊。',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final LivePlayer player;
  final LivePartyProvider live;
  final MatchReferenceProvider ref;
  final String queue;

  const _PlayerRow(
      {required this.player,
      required this.live,
      required this.ref,
      required this.queue});

  void _open(BuildContext context) {
    final nav = Navigator.of(context);
    if (player.isMe) {
      nav.pushNamedAndRemoveUntil('/matches', (_) => false);
    } else {
      nav.pushNamed('/players/detail',
          arguments: PlayerRef(
              puuid: player.puuid, riotId: live.name(player.puuid) ?? '玩家'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final agent = ref.agent(player.agentId);
    final tier = ref.tier(player.tier);
    return InkWell(
      key: ValueKey('live-player-${player.puuid}'),
      onTap: () => _open(context),
      child: Container(
        color: player.isMe ? AppColors.surfaceHigh : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Tooltip(
              key: ValueKey('live-rank-${player.puuid}'),
              message: tier.name,
              child: SizedBox(
                  width: 24, height: 24, child: SkinIcon(url: tier.iconUrl)),
            ),
            const SizedBox(width: 8),
            Tooltip(
              key: ValueKey('live-agent-${player.puuid}'),
              message: agent.name,
              child: SizedBox(
                  width: 32, height: 32, child: SkinIcon(url: agent.iconUrl)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(live.name(player.puuid) ?? '…',
                        key: ValueKey('live-name-${player.puuid}'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: player.isMe
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                  const SizedBox(width: 6),
                  Text('Lv ${player.level}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  if (player.isCoach) ...[
                    const SizedBox(width: 6),
                    const Text('教練',
                        style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ],
                ],
              ),
            ),
            if (!player.isCoach)
              RecentFormCell(
                  key: ValueKey('form-${player.puuid}'),
                  puuid: player.puuid,
                  queue: queue),
          ],
        ),
      ),
    );
  }
}
