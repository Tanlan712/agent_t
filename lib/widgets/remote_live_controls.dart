import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/custom_game.dart';
import '../logic/match_mapper.dart' show queueName;
import '../models/live_models.dart';
import '../models/match_models.dart';
import '../providers/remote_actions.dart';
import '../theme/app_theme.dart';
import 'skin_tile.dart' show SkinIcon;

/// 會被 Riot 懲罰或無法復原的動作：先跳確認框，按「確定」才送出。
Future<bool> confirmRemote(
    BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消')),
        FilledButton(
            key: const ValueKey('remote-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定')),
      ],
    ),
  );
  return ok == true;
}

/// 遠端操作卡片的外框：標題、送出中的提示與上一個錯誤。
class _RemoteCard extends StatelessWidget {
  final String title;
  final RemoteActions actions;
  final List<Widget> children;

  const _RemoteCard(
      {super.key,
      required this.title,
      required this.actions,
      required this.children});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.settings_remote, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (actions.busy)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
              ]),
              const SizedBox(height: 12),
              ...children,
              if (actions.error case final e?) ...[
                const SizedBox(height: 8),
                Text(e,
                    key: const ValueKey('remote-error'),
                    style: TextStyle(color: AppColors.error)),
              ],
            ],
          ),
        ),
      );
}

/// 選角時的遠端選角：只在使用者按下按鈕時送出，不會自動選擇或鎖定（AGENTS.md 第 1 節）。
/// 預設是預選特務，也可以在下拉選單改選其他特務。
class RemotePregameControls extends StatefulWidget {
  final LivePregame pregame;
  final RemoteActions actions;

  /// 預選特務；null 代表還沒設定。
  final String? preferredAgent;
  final RefItem Function(String agentId) agent;

  /// 下拉選單可選的特務（uuid 小寫）；空的時候只能用預選特務。
  final List<String> choices;

  /// 送出成功後重新讀取即時對局。
  final VoidCallback onDone;

  const RemotePregameControls({
    super.key,
    required this.pregame,
    required this.actions,
    required this.preferredAgent,
    required this.agent,
    required this.onDone,
    this.choices = const [],
  });

  @override
  State<RemotePregameControls> createState() => _RemotePregameControlsState();
}

class _RemotePregameControlsState extends State<RemotePregameControls> {
  /// 使用者在下拉選單改選的特務；null 時用預選特務。
  String? _picked;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.actions,
        builder: (context, _) {
          final pregame = widget.pregame;
          final actions = widget.actions;
          final me = pregame.allies.where((a) => a.isMe).firstOrNull;
          final locked = me?.selection == AgentSelection.locked;
          final id = (_picked ?? widget.preferredAgent)?.toLowerCase();
          // 隊友已鎖定的特務不能再選。
          final taken = {
            for (final a in pregame.allies)
              if (!a.isMe && a.selection == AgentSelection.locked)
                a.agentId.toLowerCase(),
          };
          final blocked = id != null && taken.contains(id);
          final disabled = actions.busy || locked || id == null || blocked;
          final choices = {
            ...widget.choices.map((c) => c.toLowerCase()),
            if (id != null) id,
          }.toList()
            ..sort(
                (a, b) => widget.agent(a).name.compareTo(widget.agent(b).name));
          Future<void> run(Future<bool> Function() send) async {
            if (await send()) widget.onDone();
          }

          final current = me == null || me.agentId.isEmpty
              ? null
              : '目前：${widget.agent(me.agentId.toLowerCase()).name}'
                  '（${locked ? '已鎖定' : '已選擇'}）';
          return _RemoteCard(
            key: const ValueKey('remote-pregame'),
            title: '遠端選角',
            actions: actions,
            children: [
              if (widget.preferredAgent == null) ...[
                Text('尚未預選特務：到「我的收藏 → 特務」按圖釘設定，或在下面直接選。',
                    style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 8),
              ],
              if (choices.isNotEmpty)
                Row(children: [
                  if (id != null)
                    SizedBox(
                        width: 40,
                        height: 40,
                        child: SkinIcon(url: widget.agent(id).iconUrl)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: (choices.length > 1 || id == null) && !locked
                        ? DropdownButton<String>(
                            key: const ValueKey('remote-agent-picker'),
                            isExpanded: true,
                            value: id,
                            hint: const Text('選特務'),
                            items: [
                              for (final c in choices)
                                DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                        c ==
                                                widget.preferredAgent
                                                    ?.toLowerCase()
                                            ? '${widget.agent(c).name}（預選）'
                                            : widget.agent(c).name,
                                        overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: actions.busy
                                ? null
                                : (c) => setState(() => _picked = c),
                          )
                        : Text(
                            id == null ? '選特務' : '預選：${widget.agent(id).name}',
                            key: const ValueKey('remote-preferred-agent'),
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
              if (current != null) ...[
                const SizedBox(height: 4),
                Text(current,
                    key: const ValueKey('remote-current-agent'),
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
              if (blocked) ...[
                const SizedBox(height: 4),
                Text('隊友已鎖定這位特務，請改選其他特務。',
                    key: const ValueKey('remote-agent-taken'),
                    style: TextStyle(color: AppColors.error, fontSize: 12)),
              ],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  key: const ValueKey('remote-select-agent'),
                  onPressed: disabled
                      ? null
                      : () =>
                          run(() => actions.selectAgent(pregame.matchId, id)),
                  icon: const Icon(Icons.touch_app),
                  label: const Text('選擇'),
                ),
                FilledButton.icon(
                  key: const ValueKey('remote-lock-agent'),
                  onPressed: disabled
                      ? null
                      : () => run(() => actions.lockAgent(pregame.matchId, id)),
                  icon: const Icon(Icons.lock),
                  label: Text(locked ? '已鎖定' : '鎖定'),
                ),
              ]),
              const SizedBox(height: 8),
              Text('不會自動送出：要你親手按「鎖定」才會鎖定。',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const SizedBox(height: 8),
              TextButton.icon(
                key: const ValueKey('remote-quit-pregame'),
                onPressed: actions.busy
                    ? null
                    : () async {
                        if (await confirmRemote(
                            context, '離開選角？', '等同逃跑：Riot 會給排隊限制，競技模式還會扣 RR。')) {
                          await run(() => actions.quitPregame(pregame.matchId));
                        }
                      },
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                icon: const Icon(Icons.exit_to_app),
                label: const Text('離開選角（逃跑）'),
              ),
            ],
          );
        },
      );
}

/// 對局中的遠端操作：只有「離開對局」，按下後要再確認。
class RemoteMatchControls extends StatelessWidget {
  final LiveMatch match;
  final RemoteActions actions;
  final VoidCallback onDone;

  const RemoteMatchControls(
      {super.key,
      required this.match,
      required this.actions,
      required this.onDone});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: actions,
        builder: (context, _) => _RemoteCard(
          key: const ValueKey('remote-match'),
          title: '遠端對局',
          actions: actions,
          children: [
            TextButton.icon(
              key: const ValueKey('remote-leave-match'),
              onPressed: actions.busy
                  ? null
                  : () async {
                      if (await confirmRemote(context, '離開對局？',
                          '中途離開會被 Riot 懲罰（排隊限制、競技扣 RR），隊友也會少一人。')) {
                        if (await actions.leaveCoreGame(match.matchId)) {
                          onDone();
                        }
                      }
                    },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('離開對局'),
            ),
          ],
        ),
      );
}

/// 自訂對戰的隊伍名稱。
const customTeamLabels = {
  'TeamOne': 'A 隊',
  'TeamTwo': 'B 隊',
  'TeamSpectate': '觀戰',
};

/// 自訂對戰設定：地圖、模式、伺服器用 Riot 的 customgameconfigs 清單，
/// 讀不到時地圖退回 valorant-api.com 的全部地圖，模式與伺服器只列目前的設定。
class _CustomSettings extends StatelessWidget {
  final Map<String, dynamic> settings;
  final CustomGameConfig? config;
  final Map<String, RefItem> maps;
  final bool busy;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _CustomSettings({
    required this.settings,
    required this.config,
    required this.maps,
    required this.busy,
    required this.onChanged,
  });

  Widget _dropdown(String label, String key, List<String> options,
      String Function(String) name) {
    final current = settings[key] as String?;
    final values = {
      ...options,
      if (current != null && current.isNotEmpty) current,
    }.toList();
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label),
      const SizedBox(width: 8),
      ConstrainedBox(
        // 窄螢幕不溢出：名稱太長時截斷。
        constraints: const BoxConstraints(maxWidth: 200),
        child: DropdownButton<String>(
          key: ValueKey('remote-custom-${key.toLowerCase()}'),
          value: current != null && values.contains(current) ? current : null,
          hint: Text(label),
          isExpanded: true,
          items: [
            for (final v in values)
              DropdownMenuItem(
                  value: v,
                  child: Text(name(v), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: busy
              ? null
              : (v) {
                  if (v != null && v != current) {
                    onChanged(withCustomSetting(settings, key, v));
                  }
                },
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final mapOptions =
        config?.maps.isNotEmpty == true ? config!.maps : maps.keys.toList();
    String mapName(String url) =>
        maps[url]?.name ?? url.split('/').where((p) => p.isNotEmpty).last;
    return Column(
      key: const ValueKey('remote-custom-settings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _dropdown('地圖', 'Map', mapOptions, mapName),
            _dropdown('模式', 'Mode', config?.modes ?? const [], customModeName),
            _dropdown(
                '伺服器', 'GamePod', config?.pods ?? const [], customPodName),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in customGameRules.entries)
            FilterChip(
              key: ValueKey('remote-rule-${e.key}'),
              label: Text(e.value),
              selected: customRuleOn(settings, e.key),
              onSelected: busy
                  ? null
                  : (on) => onChanged(withCustomRule(settings, e.key, on)),
            ),
        ]),
      ],
    );
  }
}

/// 隊伍的遠端操作：所有人可以切換準備與邀請；隊長另外可以取得代碼、排隊、變更模式、
/// 開放或鎖定隊伍、踢人與自訂對戰。
class RemotePartyControls extends StatefulWidget {
  final LiveParty party;
  final RemoteActions actions;
  final VoidCallback onDone;

  /// 成員顯示名稱。
  final String Function(String puuid) name;

  /// 自訂對戰可選的地圖（mapUrl → 名稱）。
  final Map<String, RefItem> maps;

  const RemotePartyControls(
      {super.key,
      required this.party,
      required this.actions,
      required this.onDone,
      required this.name,
      this.maps = const {}});

  @override
  State<RemotePartyControls> createState() => _RemotePartyControlsState();
}

class _RemotePartyControlsState extends State<RemotePartyControls> {
  final _invite = TextEditingController();

  @override
  void dispose() {
    _invite.dispose();
    super.dispose();
  }

  Future<void> _run(Future<bool> Function() send) async {
    if (await send()) widget.onDone();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: widget.actions,
        builder: (context, _) {
          final party = widget.party;
          final actions = widget.actions;
          final busy = actions.busy;
          final me = party.me;
          final owner = party.iAmOwner;
          final custom = party.isCustomGame;
          final queuing = party.state == 'MATCHMAKING';
          final code = actions.inviteCode(party.id) ?? party.inviteCode;
          final queues = {
            ...party.eligibleQueues,
            if (party.queueId.isNotEmpty) party.queueId,
          }.toList();
          final others = party.members.where((m) => !m.isMe).toList();
          if (owner && custom) {
            WidgetsBinding.instance
                .addPostFrameCallback((_) => actions.loadCustomConfig());
          }
          return _RemoteCard(
            key: const ValueKey('remote-party'),
            title: '遠端隊伍',
            actions: actions,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (me != null && !custom)
                  OutlinedButton.icon(
                    key: const ValueKey('remote-ready'),
                    onPressed: busy
                        ? null
                        : () =>
                            _run(() => actions.setReady(party.id, !me.isReady)),
                    icon: Icon(me.isReady
                        ? Icons.pause_circle_outline
                        : Icons.check_circle_outline),
                    label: Text(me.isReady ? '改成未準備' : '設為準備'),
                  ),
                if (owner && !custom)
                  FilledButton.icon(
                    key: const ValueKey('remote-queue'),
                    onPressed: busy
                        ? null
                        : () => _run(() => queuing
                            ? actions.leaveQueue(party.id)
                            : actions.joinQueue(party.id)),
                    icon: Icon(queuing ? Icons.stop : Icons.play_arrow),
                    label: Text(queuing ? '取消排隊' : '開始排隊'),
                  ),
                if (owner) ...[
                  OutlinedButton.icon(
                    key: const ValueKey('remote-access'),
                    onPressed: busy
                        ? null
                        : () => _run(() =>
                            actions.setAccessibility(party.id, !party.isOpen)),
                    icon: Icon(party.isOpen ? Icons.lock : Icons.lock_open),
                    label: Text(party.isOpen ? '鎖定隊伍' : '開放隊伍'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('remote-invite-code'),
                    onPressed:
                        busy ? null : () => actions.fetchInviteCode(party.id),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('取得隊伍代碼'),
                  ),
                ],
              ]),
              if (owner && !custom && queues.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Text('模式'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    key: const ValueKey('remote-queue-mode'),
                    value: party.queueId.isEmpty ? null : party.queueId,
                    items: [
                      for (final q in queues)
                        DropdownMenuItem(value: q, child: Text(queueName(q))),
                    ],
                    // 排隊中不能換模式。
                    onChanged: busy || queuing
                        ? null
                        : (q) {
                            if (q != null && q != party.queueId) {
                              _run(() => actions.changeQueue(party.id, q));
                            }
                          },
                  ),
                ]),
              ],
              if (code != null) ...[
                const SizedBox(height: 12),
                Row(children: [
                  const Text('隊伍代碼'),
                  const SizedBox(width: 12),
                  SelectableText(code,
                      key: const ValueKey('remote-code'),
                      style: AppText.tabular(const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(
                    tooltip: '複製',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已複製隊伍代碼')));
                    },
                  ),
                ]),
              ],
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('remote-invite-field'),
                    controller: _invite,
                    decoration: const InputDecoration(
                        isDense: true, hintText: '邀請玩家：名稱#標籤'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  key: const ValueKey('remote-invite'),
                  onPressed: busy
                      ? null
                      : () async {
                          if (await actions.invite(party.id, _invite.text)) {
                            _invite.clear();
                            widget.onDone();
                          }
                        },
                  child: const Text('邀請'),
                ),
              ]),
              if (owner && others.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final m in others)
                  Row(
                    key: ValueKey('remote-member-${m.puuid}'),
                    children: [
                      Expanded(
                          child: Text(widget.name(m.puuid),
                              overflow: TextOverflow.ellipsis)),
                      if (custom)
                        DropdownButton<String>(
                          key: ValueKey('remote-team-${m.puuid}'),
                          value: party.customTeams[m.puuid],
                          hint: const Text('隊伍'),
                          items: [
                            for (final e in customTeamLabels.entries)
                              DropdownMenuItem(
                                  value: e.key, child: Text(e.value)),
                          ],
                          onChanged: busy
                              ? null
                              : (t) {
                                  if (t != null &&
                                      t != party.customTeams[m.puuid]) {
                                    _run(() => actions.setCustomTeam(
                                        party.id, t, m.puuid));
                                  }
                                },
                        ),
                      TextButton(
                        key: ValueKey('remote-kick-${m.puuid}'),
                        onPressed: busy
                            ? null
                            : () async {
                                if (await confirmRemote(context, '踢出成員？',
                                    '把 ${widget.name(m.puuid)} 移出隊伍。')) {
                                  await _run(() => actions.kick(m.puuid));
                                }
                              },
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.error),
                        child: const Text('踢出'),
                      ),
                    ],
                  ),
              ],
              if (owner) ...[
                const SizedBox(height: 12),
                if (!custom)
                  OutlinedButton.icon(
                    key: const ValueKey('remote-make-custom'),
                    onPressed: busy || queuing
                        ? null
                        : () => _run(() => actions.makeCustomGame(party.id)),
                    icon: const Icon(Icons.tune),
                    label: const Text('建立自訂對戰'),
                  )
                else ...[
                  Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (me != null)
                          DropdownButton<String>(
                            key: const ValueKey('remote-my-team'),
                            value: party.customTeams[me.puuid],
                            hint: const Text('我的隊伍'),
                            items: [
                              for (final e in customTeamLabels.entries)
                                DropdownMenuItem(
                                    value: e.key, child: Text(e.value)),
                            ],
                            onChanged: busy
                                ? null
                                : (t) {
                                    if (t != null &&
                                        t != party.customTeams[me.puuid]) {
                                      _run(() => actions.setCustomTeam(
                                          party.id, t, me.puuid));
                                    }
                                  },
                          ),
                        FilledButton.icon(
                          key: const ValueKey('remote-start-custom'),
                          onPressed: busy
                              ? null
                              : () =>
                                  _run(() => actions.startCustomGame(party.id)),
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('開始自訂對戰'),
                        ),
                        OutlinedButton(
                          key: const ValueKey('remote-make-default'),
                          onPressed: busy
                              ? null
                              : () => _run(() => actions.makeDefault(
                                  party.id,
                                  party.eligibleQueues.contains('unrated') ||
                                          party.eligibleQueues.isEmpty
                                      ? 'unrated'
                                      : party.eligibleQueues.first)),
                          child: const Text('回到一般模式'),
                        ),
                      ]),
                  if (party.customSettings case final settings?) ...[
                    const SizedBox(height: 12),
                    _CustomSettings(
                      settings: settings,
                      config: actions.customConfig,
                      maps: widget.maps,
                      busy: busy,
                      onChanged: (next) =>
                          _run(() => actions.setCustomSettings(party.id, next)),
                    ),
                  ],
                ],
              ],
              if (!owner) ...[
                const SizedBox(height: 8),
                Text('只有隊長可以取得代碼、排隊、變更模式、開放或鎖定隊伍、踢人與自訂對戰。',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ],
          );
        },
      );
}
