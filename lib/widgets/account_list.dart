import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/riot_provider.dart';
import '../storage/session_storage.dart';
import '../theme/app_theme.dart';

/// 保存過的 Riot 帳號（多帳號切換，AGENTS.md 第 4 節）：點一下切換，
/// token 還有效就不用重新登入；右邊的按鈕登出並刪除該帳號。
class AccountList extends StatelessWidget {
  /// 手機 App：過期的帳號會在背景續期。
  final bool inApp;

  const AccountList({super.key, this.inApp = false});

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('已保存的帳號', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final a in riot.accounts) _tile(context, riot, a),
      ],
    );
  }

  Widget _tile(BuildContext context, RiotProvider riot, SavedAccount a) {
    final active = a.puuid == riot.activePuuid;
    final valid = riot.hasValidSession(a);
    final String status;
    if (valid) {
      final minutes = (riot.timeLeftOf(a).inSeconds / 60).ceil();
      status = '${active ? '使用中' : '可直接切換'} · 登入剩 $minutes 分鐘';
    } else if (inApp && a.autoRenew) {
      status = active ? '已過期，正在背景續期' : '已過期，切換後會在背景續期';
    } else {
      status = active ? '已過期，請重新登入' : '已過期，切換後需要重新登入';
    }
    return ListTile(
      key: ValueKey('account-${a.puuid}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      selected: active,
      leading: Icon(
        active
            ? (valid ? Icons.verified_user : Icons.timer_off_outlined)
            : Icons.person_outline,
        color: active
            ? (valid ? AppColors.owned : AppColors.warn)
            : AppColors.muted,
      ),
      title: Text('${a.displayName}（${a.shard}）',
          overflow: TextOverflow.ellipsis),
      subtitle: Text(status),
      onTap: active || riot.isBusy ? null : () => riot.switchAccount(a.puuid),
      trailing: IconButton(
        tooltip: '登出並刪除這個帳號',
        icon: const Icon(Icons.logout),
        onPressed: () => riot.removeAccount(a.puuid),
      ),
    );
  }
}
