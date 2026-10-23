import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/combat_stats.dart' show competitiveGames, peakRank;
import '../logic/live_mapper.dart';
import '../logic/progress_logic.dart' show ownedAgents;
import '../logic/suspicion.dart';
import '../logic/match_mapper.dart' show queueName;
import '../models/live_models.dart';
import '../models/progress_reference.dart';
import '../models/skin_info.dart';
import '../providers/catalog_provider.dart';
import '../providers/collection_provider.dart';
import '../providers/progress_provider.dart';
import '../models/match_models.dart';
import '../providers/live_party_provider.dart';
import '../providers/match_reference_provider.dart';
import '../providers/recent_form_loader.dart';
import '../providers/remote_actions.dart';
import '../providers/riot_provider.dart';
import '../providers/settings_provider.dart';
import '../services/live_client.dart';
import '../services/match_client.dart';
import '../services/remote_client.dart';
import '../services/riot_client.dart' show ItemTypes;
import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import '../widgets/combat_stats.dart';
import '../widgets/encounter_tag.dart';
import '../widgets/player_specialty.dart';
import '../widgets/recent_form_cell.dart';
import '../widgets/remote_live_controls.dart';
import '../widgets/skin_tile.dart' show SkinIcon;

/// 即時對局（目前只有隊伍階段）。只有 GET，頁面開著時每 10 秒更新。
class LivePage extends StatefulWidget {
  /// 小號／代打推測的門檻（使用者決定，AGENTS.md）。
  final SuspicionRules rules;

  const LivePage({super.key, this.rules = const SuspicionRules()});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  late final LivePartyProvider _live;
  late final RecentFormLoader _forms;

  /// 遠端操作（使用者在設定頁同意後才顯示，規格 2026-10-22-remote-control-design.md）。
  late final RemoteActions _remote;
  String? _formsFor;

  @override
  void initState() {
    super.initState();
    _live = LivePartyProvider(context.read<LiveClient>(),
        context.read<MatchClient>(), context.read<RiotProvider>());
    _remote = RemoteActions(
        context.read<RemoteClient>(), context.read<RiotProvider>());
    _forms = context.read<RecentFormLoader>();
    _live.addListener(_requestForms);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.read<RiotProvider>().isLoggedIn) _live.start();
    });
  }

  /// 使用者決定（AGENTS.md 第 2 節）：對局中查每位玩家的最近 5 場（同模式，教練除外）；
  /// 選角時查隊友（Riot 不提供對手）。
  void _requestForms() {
    final m = _live.match;
    final pre = _live.pregame;
    if (_live.phase == LivePhase.inGame && m != null) {
      _request(
          'core:${m.matchId}',
          [
            for (final id in m.teamIds)
              for (final p in m.team(id))
                if (!p.isCoach) p.puuid,
          ],
          m.queueId,
          m.seasonId,
          {
            for (final p in m.players)
              if (p.tier == 0 && !p.isCoach) p.puuid,
          });
    } else if (_live.phase == LivePhase.party && _live.party != null) {
      // 使用者決定（2026-10-22）：大廳顯示隊友的最近一場與牌位（AGENTS.md 第 2 節）。
      final members = [for (final m in _live.party!.members) m.puuid];
      final key = 'party:${members.join(',')}';
      if (key != _formsFor) {
        _formsFor = key;
        requestCombatStats(context, members,
            games: memberStatsGames, owner: this);
      }
    } else if (_live.phase == LivePhase.pregame && pre != null) {
      _request(
          'pre:${pre.matchId}',
          [for (final a in pre.allies) a.puuid],
          pre.queueId,
          pre.seasonId,
          {
            for (final a in pre.allies)
              if (a.tier == 0) a.puuid,
          });
    }
  }

  void _request(String key, List<String> puuids, String queue, String seasonId,
      Set<String> rankFor) {
    if (key == _formsFor) return;
    _formsFor = key;
    _forms.request(puuids,
        owner: this,
        queue: queue,
        seasonId: seasonId,
        rankFor: rankFor,
        // 小號判斷要用歷史最高牌位與競技總場數（AGENTS.md 第 2 節）。
        profileFor: puuids.toSet(),
        games: liveFormGames);
    // 「遇過」的標示：另外排入自己最近的場次（不限模式），讀到的場次會記下同場玩家。
    // 已讀過的場次走快取，不會重複請求。
    final me = context.read<RiotProvider>().session?.puuid;
    if (me != null) {
      _forms.request([me], owner: this, games: encounterScanGames);
    }
  }

  @override
  void dispose() {
    _live.removeListener(_requestForms);
    _forms.cancelPending(owner: this);
    _remote.dispose();
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

  /// 遠端選角可選的特務：收藏讀到時只列已擁有的（含初始特務），否則列全部特務。
  List<String> _agentChoices(BuildContext context, MatchReferenceProvider ref) {
    Set<String>? owned;
    ProgressReference? progress;
    try {
      owned = context.watch<CollectionProvider>().owned[ItemTypes.agent];
      progress = context.watch<ProgressProvider>().ref;
    } on ProviderNotFoundException {
      // 沒有收藏資料（例如單獨測試即時對局頁）時列全部特務。
    }
    if (owned != null && progress != null) {
      return [for (final a in ownedAgents(owned, progress)) a.uuid];
    }
    return ref.agents.keys.toList();
  }

  Widget _body(BuildContext context) {
    final ref = context.watch<MatchReferenceProvider>();
    final settings = context.watch<SettingsProvider>().settings;
    if (_live.phase == LivePhase.inGame && _live.match != null) {
      return _MatchView(
          match: _live.match!,
          live: _live,
          ref: ref,
          rules: widget.rules,
          remote: settings.remoteControl
              ? RemoteMatchControls(
                  match: _live.match!, actions: _remote, onDone: _live.refresh)
              : null);
    }
    if (_live.phase == LivePhase.pregame && _live.pregame != null) {
      return _PregameView(
          pregame: _live.pregame!,
          live: _live,
          ref: ref,
          rules: widget.rules,
          remote: settings.remoteControl
              ? RemotePregameControls(
                  pregame: _live.pregame!,
                  actions: _remote,
                  preferredAgent: settings.preferredAgent,
                  agent: ref.agent,
                  choices: _agentChoices(context, ref),
                  onDone: _live.refresh)
              : null);
    }
    final party = _live.party;
    if (party == null) {
      switch (_live.status) {
        case LiveStatus.offline:
          return const EmptyState(
              key: ValueKey('live-offline'),
              icon: Icons.power_settings_new,
              title: '遊戲沒有開啟',
              message: '開啟 VALORANT 後這頁會自動更新');
        case LiveStatus.noParty:
          return const EmptyState(
              key: ValueKey('live-no-party'),
              icon: Icons.sports_esports,
              title: '目前不在大廳');
        case LiveStatus.error:
        case LiveStatus.loggedOut:
          return Center(
              child: Text(_live.error ?? '讀取失敗',
                  style: TextStyle(color: AppColors.error)));
        default:
          return const Center(child: CircularProgressIndicator());
      }
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        _PartyHeader(party: party),
        if (settings.remoteControl) ...[
          const SizedBox(height: 16),
          RemotePartyControls(
              party: party,
              actions: _remote,
              onDone: _live.refresh,
              name: (id) => _live.name(id) ?? '玩家',
              maps: ref.maps),
        ],
        if (_live.error case final e?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(e, style: TextStyle(color: AppColors.error)),
          ),
        const SizedBox(height: 16),
        ResponsiveGrid(
          minTileWidth: 260,
          childAspectRatio: 2.6,
          // 卡片下半是戰鬥數據，固定高度讓窄欄換行時也放得下。
          mainAxisExtent: 236,
          children: [
            for (final m in party.members)
              _MemberCard(member: m, live: _live, ref: ref),
          ],
        ),
        const SizedBox(height: 24),
        Center(
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
                style: TextStyle(color: AppColors.muted)),
            if (waited != null && !waited.isNegative)
              Text(
                  '已排隊 ${waited.inMinutes}:${(waited.inSeconds % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(color: AppColors.muted)),
            if (party.pings.isNotEmpty) _Pings(pings: party.pings),
          ],
        ),
      ),
    );
  }
}

/// 到各伺服器的延遲（party 的 Pings），由低到高。
class _Pings extends StatelessWidget {
  final List<ServerPing> pings;

  const _Pings({required this.pings});

  @override
  Widget build(BuildContext context) {
    Color color(int ms) => ms <= 50
        ? AppColors.win
        : ms <= 100
            ? AppColors.warn
            : AppColors.loss;
    return Wrap(
      key: const ValueKey('party-pings'),
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('延遲', style: TextStyle(color: AppColors.muted)),
        for (final p in pings)
          Container(
            key: ValueKey('ping-${p.podId}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: color(p.ping).withOpacity(0.6)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('${serverName(p.podId)} ${p.ping} ms',
                style: AppText.tabular(
                    TextStyle(fontSize: 12, color: color(p.ping)))),
          ),
      ],
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
        triggerMode: TooltipTriggerMode.tap,
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(
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
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
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
                                style: TextStyle(
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
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: CombatStatsView(
                    puuid: member.puuid, games: memberStatsGames, dense: true),
              ),
            ),
          ]),
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
  final SuspicionRules rules;

  /// 遠端對局卡片；未同意遠端操作時為 null。
  final Widget? remote;

  const _MatchView(
      {required this.match,
      required this.live,
      required this.ref,
      required this.rules,
      this.remote});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        KpiStrip(tiles: [
          KpiTile(
              key: const ValueKey('live-kpi-map'),
              label: '地圖',
              value: ref.map(match.mapId).name),
          KpiTile(
              key: const ValueKey('live-kpi-mode'),
              label: '模式',
              value: match.queueId.isEmpty ? '—' : queueName(match.queueId)),
          KpiTile(
              key: const ValueKey('live-kpi-state'),
              label: '狀態',
              value: match.state == 'IN_PROGRESS' ? '進行中' : match.state),
        ]),
        if (remote case final r?) ...[
          const SizedBox(height: 16),
          r,
        ],
        const SizedBox(height: 16),
        // 12 欄時我方與敵方左右並排（各 6 欄），6 欄以下上下排列。
        LayoutBuilder(builder: (context, c) {
          final span = bentoColumns(c.maxWidth) == 12 ? 6 : 12;
          return BentoGrid(children: [
            for (final teamId in match.teamIds)
              BentoTile(
                span: match.teamIds.length == 2 ? span : 12,
                child: Column(
                  key: ValueKey('live-team-$teamId'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 8),
                      child: Text(teamId == match.myTeamId ? '我方' : '敵方',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: teamId == match.myTeamId
                                  ? AppColors.win
                                  : AppColors.loss)),
                    ),
                    PanelCard(
                      padding: EdgeInsets.zero,
                      accent: teamId == match.myTeamId
                          ? AppColors.win
                          : AppColors.loss,
                      child: Column(
                        children: [
                          for (final p in match.team(teamId))
                            _PlayerRow(
                                player: p,
                                matchId: match.matchId,
                                live: live,
                                ref: ref,
                                queue: match.queueId,
                                seasonId: match.seasonId,
                                rules: rules),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ]);
        }),
        const SizedBox(height: 24),
        Center(
          child: Text('名稱資料來自 Riot，請勿公開或分享他人資訊。',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final LivePlayer player;
  final String matchId;
  final LivePartyProvider live;
  final MatchReferenceProvider ref;
  final String queue;
  final String seasonId;
  final SuspicionRules rules;

  const _PlayerRow(
      {required this.player,
      required this.matchId,
      required this.live,
      required this.ref,
      required this.queue,
      required this.seasonId,
      required this.rules});

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
    final tierId = player.tier > 0
        ? player.tier
        : (context
                .watch<RecentFormLoader>()
                .rank(player.puuid, seasonId)
                .seasonTier ??
            0);
    final tier = ref.tier(tierId);
    final name = live.name(player.puuid) ??
        (live.nameMissing(player.puuid) ? '未知玩家' : '…');
    return InkWell(
      key: ValueKey('live-player-${player.puuid}'),
      onTap: () => _open(context),
      child: Container(
        color: player.isMe ? AppColors.surfaceHigh : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 窄螢幕（例如手機）把最近幾場移到下一行，避免玩家列 overflow。
            LayoutBuilder(builder: (context, c) {
              final narrow = c.maxWidth < 440;
              final form = player.isCoach
                  ? null
                  : RecentFormCell(
                      key: ValueKey('form-${player.puuid}'),
                      puuid: player.puuid,
                      queue: queue,
                      games: liveFormGames);
              final row = Row(
                children: [
                  Tooltip(
                    key: ValueKey('live-rank-${player.puuid}'),
                    triggerMode: TooltipTriggerMode.tap,
                    message: tier.name,
                    child: SizedBox(
                        width: 24,
                        height: 24,
                        child: SkinIcon(url: tier.iconUrl)),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    key: ValueKey('live-agent-${player.puuid}'),
                    triggerMode: TooltipTriggerMode.tap,
                    message: agent.name,
                    child: SizedBox(
                        width: 32,
                        height: 32,
                        child: SkinIcon(url: agent.iconUrl)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(name,
                              key: ValueKey('live-name-${player.puuid}'),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: player.isMe
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ),
                        // 之前同場打過的玩家（使用者決定 2026-10-23）。
                        if (!player.isMe)
                          EncounterTag(puuid: player.puuid, matchId: matchId),
                        // 使用者要求：對局 10 人都判斷（包括自己），教練除外。
                        if (!player.isCoach)
                          _SuspicionTag(
                              puuid: player.puuid,
                              level: player.level,
                              seasonWins: player.seasonWins,
                              tier: tierId,
                              queue: queue,
                              rules: rules),
                        // 實測隱藏等級時 Riot 直接給 0，不顯示以免誤導。
                        if (player.level > 0) ...[
                          const SizedBox(width: 6),
                          Text('Lv ${player.level}',
                              key: ValueKey('live-level-${player.puuid}'),
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                        ],
                        if (player.isCoach) ...[
                          const SizedBox(width: 6),
                          Text('教練',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                  if (!narrow && form != null) form,
                ],
              );
              if (!narrow || form == null) return row;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row,
                  // 仍放不下時等比例縮小，不截斷數字。
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: form),
                  ),
                ],
              );
            }),
            // 使用者決定（2026-10-23）：顯示擅長的特務與常用槍。
            if (!player.isCoach)
              PlayerSpecialty(
                  puuid: player.puuid, queue: queue, games: liveFormGames),
            if (!player.isCoach) _SkinStrip(puuid: player.puuid, live: live),
          ],
        ),
      ),
    );
  }
}

const _selectionLabels = {
  AgentSelection.none: '未選',
  AgentSelection.selected: '已選',
  AgentSelection.locked: '已鎖定',
};

/// 選角中（pregame）的畫面：我方 5 人；Riot 不提供對手，只顯示人數與已鎖定人數。
class _PregameView extends StatefulWidget {
  final LivePregame pregame;
  final LivePartyProvider live;
  final MatchReferenceProvider ref;
  final SuspicionRules rules;

  /// 遠端選角卡片；未同意遠端操作時為 null。
  final Widget? remote;

  const _PregameView(
      {required this.pregame,
      required this.live,
      required this.ref,
      required this.rules,
      this.remote});

  @override
  State<_PregameView> createState() => _PregameViewState();
}

class _PregameViewState extends State<_PregameView> {
  /// 只在畫面上倒數，不會多發請求。
  late final Timer _tick =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pre = widget.pregame;
    final fetched = widget.live.pregameFetchedAt ?? DateTime.now();
    final left = pre.remaining - DateTime.now().difference(fetched);
    final seconds = left.isNegative ? 0 : left.inSeconds;
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
                Text(widget.ref.map(pre.mapId).name,
                    style: Theme.of(context).textTheme.titleLarge),
                if (pre.queueId.isNotEmpty) Text(queueName(pre.queueId)),
                Text('選角中', style: TextStyle(color: AppColors.owned)),
                Text('剩餘 $seconds 秒',
                    key: const ValueKey('pregame-remaining'),
                    style: TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ),
        if (widget.remote case final r?) ...[
          const SizedBox(height: 16),
          r,
        ],
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text('我方',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.owned)),
        ),
        Card(
          child: Column(
            children: [
              for (final a in pre.allies)
                _PregameRow(
                    player: a,
                    matchId: pre.matchId,
                    live: widget.live,
                    ref: widget.ref,
                    queue: pre.queueId,
                    seasonId: pre.seasonId,
                    rules: widget.rules),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('敵方 ${pre.enemySize} 人，已鎖定 ${pre.enemyLocked} 人',
              style: TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text('名稱資料來自 Riot，請勿公開或分享他人資訊。',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

class _PregameRow extends StatelessWidget {
  final PregamePlayer player;
  final String matchId;
  final LivePartyProvider live;
  final MatchReferenceProvider ref;
  final String queue;
  final String seasonId;
  final SuspicionRules rules;

  const _PregameRow(
      {required this.player,
      required this.matchId,
      required this.live,
      required this.ref,
      required this.queue,
      required this.seasonId,
      required this.rules});

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
    final tierId = player.tier > 0
        ? player.tier
        : (context
                .watch<RecentFormLoader>()
                .rank(player.puuid, seasonId)
                .seasonTier ??
            0);
    final tier = ref.tier(tierId);
    final name = live.name(player.puuid) ??
        (live.nameMissing(player.puuid) ? '未知玩家' : '…');
    final locked = player.selection == AgentSelection.locked;
    return InkWell(
      key: ValueKey('live-player-${player.puuid}'),
      onTap: () => _open(context),
      child: Container(
        color: player.isMe ? AppColors.surfaceHigh : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // 窄螢幕把最近幾場移到下一行，避免選角列 overflow（同對局列）。
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 440;
            final form = RecentFormCell(
                key: ValueKey('form-${player.puuid}'),
                puuid: player.puuid,
                queue: queue,
                games: liveFormGames);
            final row = Row(
              children: [
                Tooltip(
                  key: ValueKey('live-rank-${player.puuid}'),
                  triggerMode: TooltipTriggerMode.tap,
                  message: tier.name,
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: SkinIcon(url: tier.iconUrl)),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  key: ValueKey('live-agent-${player.puuid}'),
                  triggerMode: TooltipTriggerMode.tap,
                  message: player.agentId.isEmpty ? '尚未選擇' : agent.name,
                  child: SizedBox(
                      width: 32,
                      height: 32,
                      child: player.agentId.isEmpty
                          ? null
                          : SkinIcon(url: agent.iconUrl)),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 48,
                  child: Text(_selectionLabels[player.selection]!,
                      key: ValueKey('pregame-state-${player.puuid}'),
                      style: TextStyle(
                          fontSize: 12,
                          color: locked ? AppColors.owned : AppColors.muted)),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(name,
                            key: ValueKey('live-name-${player.puuid}'),
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontWeight: player.isMe
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ),
                      if (!player.isMe)
                        EncounterTag(puuid: player.puuid, matchId: matchId),
                      if (!player.isMe)
                        _SuspicionTag(
                            puuid: player.puuid,
                            level: player.level,
                            seasonWins: player.seasonWins,
                            tier: tierId,
                            queue: queue,
                            rules: rules),
                      if (player.level > 0) ...[
                        const SizedBox(width: 6),
                        Text('Lv ${player.level}',
                            key: ValueKey('live-level-${player.puuid}'),
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                if (!narrow) form,
              ],
            );
            if (!narrow) return row;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row,
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: form),
                ),
              ],
            );
          }),
          // 使用者決定（2026-10-23）：選角時顯示隊友擅長的特務與常用槍。
          PlayerSpecialty(
              puuid: player.puuid, queue: queue, games: liveFormGames),
        ]),
      ),
    );
  }
}

/// 玩家攜帶的造型（使用者決定，AGENTS.md）。預設只顯示主要武器，可以展開全部；
/// 造型目錄沒有的（預設造型）不顯示；全部都是預設造型時整列不顯示。
class _SkinStrip extends StatefulWidget {
  final String puuid;
  final LivePartyProvider live;

  const _SkinStrip({required this.puuid, required this.live});

  @override
  State<_SkinStrip> createState() => _SkinStripState();
}

class _SkinStripState extends State<_SkinStrip> {
  bool _all = false;

  Widget _icon(String weaponId, SkinInfo skin) => Tooltip(
        key: ValueKey('skin-${widget.puuid}-$weaponId'),
        triggerMode: TooltipTriggerMode.tap,
        message: skin.name,
        child: Container(
          width: 56,
          height: 28,
          margin: const EdgeInsets.only(right: 6),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: skin.tier.color, width: 2)),
          ),
          child: SkinIcon(url: skin.iconUrl),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final skins = widget.live.skins(widget.puuid);
    if (skins == null) return const SizedBox.shrink();
    final catalog = context.watch<CatalogProvider>();
    SkinInfo? info(String weaponId) {
      final id = skins[weaponId];
      return id == null ? null : catalog.skinById(id);
    }

    final main = [
      for (final w in mainWeaponIds)
        if (info(w) case final skin?) (w, skin),
    ];
    final others = [
      for (final w in skins.keys)
        if (!mainWeaponIds.contains(w))
          if (info(w) case final skin?) (w, skin),
    ];
    if (main.isEmpty && others.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: ValueKey('skins-${widget.puuid}'),
      padding: const EdgeInsets.only(top: 6, left: 64),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          for (final (w, skin) in main) _icon(w, skin),
          if (_all)
            for (final (w, skin) in others) _icon(w, skin),
          if (others.isNotEmpty)
            TextButton(
              key: ValueKey('skins-more-${widget.puuid}'),
              onPressed: () => setState(() => _all = !_all),
              child: Text(_all ? '收合' : '全部（+${others.length}）'),
            ),
        ],
      ),
    );
  }
}

/// 即時對局要求的場數：最新 5 場顯示，更早 5 場用來比較表現突變。
const liveFormGames = 10;

/// 進入選角或對局時掃描自己最近幾場（不限模式），用來標示遇過的玩家。
/// 實測 match-history 一次超過 10 場可能回 400。
const encounterScanGames = 10;

/// 疑似小號／代打的標籤；只是推測，滑鼠移上去列出原因與分數（使用者決定，AGENTS.md）。
class _SuspicionTag extends StatelessWidget {
  final String puuid;
  final int level;
  final int? seasonWins;

  /// 畫面上顯示的本季牌位；0 表示未知。
  final int tier;
  final String queue;
  final SuspicionRules rules;

  const _SuspicionTag(
      {required this.puuid,
      required this.level,
      required this.seasonWins,
      required this.tier,
      required this.queue,
      required this.rules});

  @override
  Widget build(BuildContext context) {
    final loader = context.watch<RecentFormLoader>();
    final form = loader.form(puuid, queue: queue, games: liveFormGames);
    if (form == null) return const SizedBox.shrink();
    final mmr = loader.mmr(puuid);
    final seasons =
        context.watch<MatchReferenceProvider>().reference?.seasons ?? const {};
    final s = assessAccount(
        level: level,
        seasonWins: seasonWins,
        recent: form.games,
        rules: rules,
        currentTier: tier,
        peakTier: mmr == null ? null : peakRank(mmr, seasons)?.tier,
        careerGames: mmr == null ? null : competitiveGames(mmr));
    if (!s.any) return const SizedBox.shrink();
    final label = s.label;
    final detail = '${s.detail}（依公開數據推測，可能誤判）';
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      // 滑鼠移上去看提示；手機點一下開對話框看完整原因。
      child: Tooltip(
        key: ValueKey('sus-$puuid'),
        message: detail,
        child: InkWell(
          key: ValueKey('sus-tap-$puuid'),
          onTap: () => showDialog<void>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text(label),
              content: Text(detail),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c), child: const Text('關閉')),
              ],
            ),
          ),
          child: StatusChip(
              label: label,
              color: s.high ? AppColors.loss : AppColors.warn,
              icon: Icons.warning_amber),
        ),
      ),
    );
  }
}
