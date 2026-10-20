import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/live_mapper.dart';
import '../logic/suspicion.dart';
import '../logic/match_mapper.dart' show queueName;
import '../models/live_models.dart';
import '../models/skin_info.dart';
import '../providers/catalog_provider.dart';
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
  /// 小號／代打推測的門檻（使用者決定，AGENTS.md）。
  final SuspicionRules rules;

  const LivePage({super.key, this.rules = const SuspicionRules()});

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
        games: liveFormGames);
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
      return _MatchView(
          match: _live.match!, live: _live, ref: ref, rules: widget.rules);
    }
    if (_live.phase == LivePhase.pregame && _live.pregame != null) {
      return _PregameView(
          pregame: _live.pregame!, live: _live, ref: ref, rules: widget.rules);
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
  final SuspicionRules rules;

  const _MatchView(
      {required this.match,
      required this.live,
      required this.ref,
      required this.rules});

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
                      player: p,
                      live: live,
                      ref: ref,
                      queue: match.queueId,
                      seasonId: match.seasonId,
                      rules: rules),
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
  final String seasonId;
  final SuspicionRules rules;

  const _PlayerRow(
      {required this.player,
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
    final tier = ref.tier(player.tier > 0
        ? player.tier
        : (context
                .watch<RecentFormLoader>()
                .rank(player.puuid, seasonId)
                .seasonTier ??
            0));
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
            Row(
              children: [
                Tooltip(
                  key: ValueKey('live-rank-${player.puuid}'),
                  message: tier.name,
                  child: SizedBox(
                      width: 24,
                      height: 24,
                      child: SkinIcon(url: tier.iconUrl)),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  key: ValueKey('live-agent-${player.puuid}'),
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
                      // 使用者要求：對局 10 人都判斷（包括自己），教練除外。
                      if (!player.isCoach)
                        _SuspicionTag(
                            puuid: player.puuid,
                            level: player.level,
                            seasonWins: player.seasonWins,
                            queue: queue,
                            rules: rules),
                      // 實測隱藏等級時 Riot 直接給 0，不顯示以免誤導。
                      if (player.level > 0) ...[
                        const SizedBox(width: 6),
                        Text('Lv ${player.level}',
                            key: ValueKey('live-level-${player.puuid}'),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                      if (player.isCoach) ...[
                        const SizedBox(width: 6),
                        const Text('教練',
                            style: TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ],
                  ),
                ),
                if (!player.isCoach)
                  RecentFormCell(
                      key: ValueKey('form-${player.puuid}'),
                      puuid: player.puuid,
                      queue: queue,
                      games: liveFormGames),
              ],
            ),
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

  const _PregameView(
      {required this.pregame,
      required this.live,
      required this.ref,
      required this.rules});

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
                const Text('選角中', style: TextStyle(color: AppColors.owned)),
                Text('剩餘 $seconds 秒',
                    key: const ValueKey('pregame-remaining'),
                    style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
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
              style: const TextStyle(color: AppColors.muted)),
        ),
        const SizedBox(height: 24),
        const Center(
          child: Text('名稱資料來自 Riot，請勿公開或分享他人資訊。',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      ],
    );
  }
}

class _PregameRow extends StatelessWidget {
  final PregamePlayer player;
  final LivePartyProvider live;
  final MatchReferenceProvider ref;
  final String queue;
  final String seasonId;
  final SuspicionRules rules;

  const _PregameRow(
      {required this.player,
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
    final tier = ref.tier(player.tier > 0
        ? player.tier
        : (context
                .watch<RecentFormLoader>()
                .rank(player.puuid, seasonId)
                .seasonTier ??
            0));
    final name = live.name(player.puuid) ??
        (live.nameMissing(player.puuid) ? '未知玩家' : '…');
    final locked = player.selection == AgentSelection.locked;
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
                    _SuspicionTag(
                        puuid: player.puuid,
                        level: player.level,
                        seasonWins: player.seasonWins,
                        queue: queue,
                        rules: rules),
                  if (player.level > 0) ...[
                    const SizedBox(width: 6),
                    Text('Lv ${player.level}',
                        key: ValueKey('live-level-${player.puuid}'),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12)),
                  ],
                ],
              ),
            ),
            RecentFormCell(
                key: ValueKey('form-${player.puuid}'),
                puuid: player.puuid,
                queue: queue,
                games: liveFormGames),
          ],
        ),
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

/// 疑似小號／表現突變的標籤；只是推測，滑鼠移上去列出原因（使用者決定，AGENTS.md）。
class _SuspicionTag extends StatelessWidget {
  final String puuid;
  final int level;
  final int? seasonWins;
  final String queue;
  final SuspicionRules rules;

  const _SuspicionTag(
      {required this.puuid,
      required this.level,
      required this.seasonWins,
      required this.queue,
      required this.rules});

  @override
  Widget build(BuildContext context) {
    final form = context
        .watch<RecentFormLoader>()
        .form(puuid, queue: queue, games: liveFormGames);
    if (form == null) return const SizedBox.shrink();
    final s = assessAccount(
        level: level, seasonWins: seasonWins, recent: form.games, rules: rules);
    if (!s.any) return const SizedBox.shrink();
    final label = [if (s.smurf) '疑似小號', if (s.shift) '表現突變'].join('・');
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        key: ValueKey('sus-$puuid'),
        message: '${s.reasons.join('\n')}\n（依公開數據推測，可能誤判）',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.wishlistGold),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('⚠ $label',
              style:
                  const TextStyle(color: AppColors.wishlistGold, fontSize: 11)),
        ),
      ),
    );
  }
}
