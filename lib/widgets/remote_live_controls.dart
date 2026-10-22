import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
class RemotePregameControls extends StatelessWidget {
  final LivePregame pregame;
  final RemoteActions actions;

  /// 預選特務；null 代表還沒設定。
  final String? preferredAgent;
  final RefItem Function(String agentId) agent;

  /// 送出成功後重新讀取即時對局。
  final VoidCallback onDone;

  const RemotePregameControls({
    super.key,
    required this.pregame,
    required this.actions,
    required this.preferredAgent,
    required this.agent,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: actions,
        builder: (context, _) {
          final me = pregame.allies.where((a) => a.isMe).firstOrNull;
          final locked = me?.selection == AgentSelection.locked;
          final id = preferredAgent;
          final disabled = actions.busy || locked || id == null;
          Future<void> run(Future<bool> Function() send) async {
            if (await send()) onDone();
          }

          return _RemoteCard(
            key: const ValueKey('remote-pregame'),
            title: '遠端選角',
            actions: actions,
            children: [
              if (id == null)
                Text('尚未預選特務：到「我的收藏 → 特務」按圖釘設定。',
                    style: TextStyle(color: AppColors.muted))
              else
                Row(children: [
                  SizedBox(
                      width: 40,
                      height: 40,
                      child: SkinIcon(url: agent(id).iconUrl)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('預選：${agent(id).name}',
                        key: const ValueKey('remote-preferred-agent'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ]),
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
  'TeamOne': '攻擊方',
  'TeamTwo': '防守方',
  'TeamSpectate': '觀戰',
};

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
          final code = actions.inviteCode(party.id);
          final queues = {
            ...party.eligibleQueues,
            if (party.queueId.isNotEmpty) party.queueId,
          }.toList();
          final others = party.members.where((m) => !m.isMe).toList();
          final mapId = party.customSettings?['Map'] as String?;
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
                        if (party.customSettings != null &&
                            widget.maps.isNotEmpty)
                          DropdownButton<String>(
                            key: const ValueKey('remote-custom-map'),
                            value:
                                widget.maps.containsKey(mapId) ? mapId : null,
                            hint: const Text('地圖'),
                            items: [
                              for (final e in widget.maps.entries)
                                DropdownMenuItem(
                                    value: e.key, child: Text(e.value.name)),
                            ],
                            onChanged: busy
                                ? null
                                : (m) {
                                    if (m != null && m != mapId) {
                                      _run(() => actions.setCustomMap(
                                          party.id, party.customSettings!, m));
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
