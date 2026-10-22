import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../logic/match_mapper.dart' show queueName;
import '../models/live_models.dart';
import '../models/match_models.dart';
import '../providers/remote_actions.dart';
import '../theme/app_theme.dart';
import 'skin_tile.dart' show SkinIcon;

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
            ],
          );
        },
      );
}

/// 隊伍的遠端操作：所有人可以切換準備；隊長另外可以取得代碼、排隊、變更模式、開放或鎖定隊伍。
class RemotePartyControls extends StatelessWidget {
  final LiveParty party;
  final RemoteActions actions;
  final VoidCallback onDone;

  const RemotePartyControls(
      {super.key,
      required this.party,
      required this.actions,
      required this.onDone});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: actions,
        builder: (context, _) {
          final busy = actions.busy;
          final me = party.me;
          final queuing = party.state == 'MATCHMAKING';
          final code = actions.inviteCode(party.id);
          Future<void> run(Future<bool> Function() send) async {
            if (await send()) onDone();
          }

          final queues = {
            ...party.eligibleQueues,
            if (party.queueId.isNotEmpty) party.queueId,
          }.toList();
          return _RemoteCard(
            key: const ValueKey('remote-party'),
            title: '遠端隊伍',
            actions: actions,
            children: [
              Wrap(spacing: 8, runSpacing: 8, children: [
                if (me != null)
                  OutlinedButton.icon(
                    key: const ValueKey('remote-ready'),
                    onPressed: busy
                        ? null
                        : () =>
                            run(() => actions.setReady(party.id, !me.isReady)),
                    icon: Icon(me.isReady
                        ? Icons.pause_circle_outline
                        : Icons.check_circle_outline),
                    label: Text(me.isReady ? '改成未準備' : '設為準備'),
                  ),
                if (party.iAmOwner) ...[
                  FilledButton.icon(
                    key: const ValueKey('remote-queue'),
                    onPressed: busy
                        ? null
                        : () => run(() => queuing
                            ? actions.leaveQueue(party.id)
                            : actions.joinQueue(party.id)),
                    icon: Icon(queuing ? Icons.stop : Icons.play_arrow),
                    label: Text(queuing ? '取消排隊' : '開始排隊'),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('remote-access'),
                    onPressed: busy
                        ? null
                        : () => run(() =>
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
              if (party.iAmOwner && queues.isNotEmpty) ...[
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
                              run(() => actions.changeQueue(party.id, q));
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
              if (!party.iAmOwner) ...[
                const SizedBox(height: 8),
                Text('只有隊長可以取得代碼、排隊、變更模式與開放或鎖定隊伍。',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ],
          );
        },
      );
}
