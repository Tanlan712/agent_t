import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/app_update_controller.dart';
import '../services/app_update.dart';
import '../theme/app_theme.dart';
import 'pwa_banners.dart';

/// 簽章不同時改用瀏覽器下載（先移除舊版再安裝）。
final apkDownloadUrl = Uri.parse(
    'https://github.com/$appUpdateRepo/releases/latest/download/Agent-T.apk');

/// 簽章不同時的說明（提示列的「說明」與設定頁共用）。
const signatureMismatchHelp = [
  '新版 APK 的簽章和手機上這一版不同，Android 不允許直接覆蓋安裝。'
      '原因是 GitHub 還沒有設定固定的簽章金鑰，每次建置都用臨時金鑰。',
  '一次性設定：在自己的電腦用 keytool 產生金鑰，把 ANDROID_KEYSTORE_BASE64 等四個值存進 repo 的 '
      'GitHub Secrets（步驟見 docs/android.md「固定簽章」）。',
  '設定後的第一個新版仍要「移除舊版 → 用瀏覽器下載安裝」一次（登入與本機資料會清掉），'
      '之後的更新就能直接在 App 內完成。',
];

Future<void> showSignatureMismatchHelp(BuildContext context) => showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('無法直接更新'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in signatureMismatchHelp)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('・$t'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('關閉')),
          FilledButton(
            key: const ValueKey('app-update-browser'),
            onPressed: () {
              Navigator.pop(context);
              launchUrl(apkDownloadUrl, mode: LaunchMode.externalApplication);
            },
            child: const Text('用瀏覽器下載'),
          ),
        ],
      ),
    );

/// 畫面頂端的「有新版」提示列（只在 Android App 出現）。
class AppUpdateBanner extends StatelessWidget {
  const AppUpdateBanner(
      {super.key, required this.controller, required this.child});

  final AppUpdateController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (!controller.showBanner) return child;
        return Column(
          children: [
            SafeArea(bottom: false, child: _bar(context)),
            Expanded(
              child: MediaQuery.removePadding(
                  context: context, removeTop: true, child: child),
            ),
          ],
        );
      },
    );
  }

  Widget _bar(BuildContext context) {
    final c = controller;
    final later = TextButton(
      key: const ValueKey('app-update-later'),
      onPressed: c.dismiss,
      child: const Text('稍後'),
    );
    switch (c.state) {
      case AppUpdateState.downloading:
        return Column(mainAxisSize: MainAxisSize.min, children: [
          TopNoticeBar(
            key: const ValueKey('app-update-bar'),
            icon: Icons.downloading,
            color: AppColors.info,
            text: '正在下載新版${_percent(c.progress)}',
          ),
          LinearProgressIndicator(value: c.progress, minHeight: 2),
        ]);
      case AppUpdateState.needsPermission:
        return TopNoticeBar(
          key: const ValueKey('app-update-bar'),
          icon: Icons.security,
          color: AppColors.warn,
          text: '請允許 Agent T「安裝不明應用程式」，回到 App 後會接著安裝。',
          actions: [
            FilledButton(
              key: const ValueKey('app-update-install'),
              onPressed: c.retryInstall,
              child: const Text('安裝'),
            ),
          ],
        );
      case AppUpdateState.signatureMismatch:
        return TopNoticeBar(
          key: const ValueKey('app-update-bar'),
          icon: Icons.error_outline,
          color: AppColors.warn,
          text: '新版簽章不同，無法直接覆蓋安裝。',
          actions: [
            later,
            FilledButton(
              key: const ValueKey('app-update-help'),
              onPressed: () => showSignatureMismatchHelp(context),
              child: const Text('說明'),
            ),
          ],
        );
      default:
        return TopNoticeBar(
          key: const ValueKey('app-update-bar'),
          icon: Icons.system_update,
          color: AppColors.info,
          text: '有新版 #${c.release?.build}',
          actions: [
            later,
            FilledButton(
              key: const ValueKey('app-update-now'),
              onPressed: c.update,
              child: const Text('更新'),
            ),
          ],
        );
    }
  }
}

String _percent(double? p) => p == null ? '…' : '… ${(p * 100).round()}%';

/// 設定頁「App 更新」卡片（只在 Android App 顯示）。
class AppUpdateCard extends StatelessWidget {
  const AppUpdateCard({super.key, required this.controller});

  final AppUpdateController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final current = c.currentBuild;
        return Card(
          key: const ValueKey('app-update-card'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.system_update, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('App 更新', style: Theme.of(context).textTheme.titleLarge),
                ]),
                const SizedBox(height: 8),
                Text('目前版本 #${current ?? '—'}・從 GitHub Release 下載新版，'
                    '由 Android 系統安裝畫面完成更新（登入與本機資料會保留）。'),
                const SizedBox(height: 8),
                Text(_status(c),
                    key: const ValueKey('app-update-status'),
                    style: TextStyle(color: AppColors.muted)),
                if (c.state == AppUpdateState.downloading) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: c.progress),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    key: const ValueKey('app-update-check'),
                    onPressed: c.busy ? null : c.check,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('檢查更新'),
                  ),
                  if (c.state == AppUpdateState.available)
                    FilledButton.icon(
                      key: const ValueKey('app-update-card-now'),
                      onPressed: c.update,
                      icon: const Icon(Icons.download, size: 18),
                      label: Text('更新到 #${c.release?.build}'),
                    ),
                  if (c.state == AppUpdateState.needsPermission ||
                      c.state == AppUpdateState.installing)
                    FilledButton(
                      onPressed: c.retryInstall,
                      child: const Text('開啟安裝畫面'),
                    ),
                  if (c.state == AppUpdateState.signatureMismatch)
                    FilledButton(
                      onPressed: () => showSignatureMismatchHelp(context),
                      child: const Text('說明'),
                    ),
                ]),
                SwitchListTile(
                  key: const ValueKey('app-update-auto'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('開啟 App 時自動檢查'),
                  value: c.autoCheck,
                  onChanged: c.setAutoCheck,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _status(AppUpdateController c) => switch (c.state) {
        AppUpdateState.idle => '還沒檢查',
        AppUpdateState.checking => '檢查中…',
        AppUpdateState.upToDate => '已經是最新版',
        AppUpdateState.available => '有新版 #${c.release?.build}',
        AppUpdateState.downloading => '下載中${_percent(c.progress)}',
        AppUpdateState.needsPermission => '下載完成：請允許 Agent T「安裝不明應用程式」',
        AppUpdateState.installing => '已開啟系統安裝畫面',
        AppUpdateState.signatureMismatch => '新版簽章不同，無法直接覆蓋安裝',
        AppUpdateState.error => c.error ?? '發生錯誤',
      };
}
