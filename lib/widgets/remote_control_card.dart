import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

/// 遠端操作的風險說明（設定頁卡片與確認對話框共用）。
const remoteControlRisks = [
  '這些功能會「寫入」Riot 未公開的遊戲伺服器端點（換造型、選角、隊伍、排隊），'
      '比只讀取更明顯違反 Riot 服務條款，帳號可能被標記，甚至被停權。',
  '每個動作都要你親手按一次才送出；App 不會自動選角、自動鎖定或自動排隊。',
  '網頁版可能被瀏覽器擋下（CORS），這時會顯示「連線失敗」；手機 App 不受影響。',
  '這些端點沒有用真實帳號測試過，可能失效或行為和遊戲裡不同。',
];

/// 設定頁的「遠端操作」：同意後才顯示所有遠端按鈕（規格 2026-10-22-remote-control-design.md）。
class RemoteControlCard extends StatelessWidget {
  const RemoteControlCard({super.key});

  Future<void> _enable(BuildContext context) async {
    final settings = context.read<SettingsProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('啟用遠端操作？'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final r in remoteControlRisks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('・$r'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消')),
          FilledButton(
              key: const ValueKey('remote-consent-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('我了解風險，啟用')),
        ],
      ),
    );
    if (ok == true) await settings.setRemoteControl(true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final s = provider.settings;
    final since = DateTime.tryParse(s.remoteControlSince ?? '');
    return Card(
      key: const ValueKey('remote-control-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.settings_remote, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text('遠端操作', style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 8),
            const Text('在收藏庫換造型、預選特務並在選角時一鍵選擇或鎖定、'
                '在隊伍中切換準備；隊長可以取得隊伍代碼、開始或取消排隊、變更模式、開放或鎖定隊伍。'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warn.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber, color: AppColors.warn, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final r in remoteControlRisks)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(r),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SwitchListTile(
              key: const ValueKey('remote-consent-switch'),
              contentPadding: EdgeInsets.zero,
              title: Text(s.remoteControl ? '已啟用遠端操作' : '我同意，啟用遠端操作'),
              subtitle: Text(s.remoteControl
                  ? '同意時間：${since == null ? '—' : _date(since)}・關閉即撤回同意'
                  : '預設關閉；關閉時所有遠端按鈕都不會顯示'),
              value: s.remoteControl,
              onChanged: (v) =>
                  v ? _enable(context) : provider.setRemoteControl(false),
            ),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
