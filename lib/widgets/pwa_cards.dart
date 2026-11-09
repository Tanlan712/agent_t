import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/pwa_controller.dart';
import '../theme/app_theme.dart';

/// 設定頁的「安裝 App」卡（只在網頁版顯示）。
class PwaInstallCard extends StatelessWidget {
  const PwaInstallCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pwa = context.watch<PwaController>();
    final state = pwa.installState;
    final (String text, Widget? action) = switch (state) {
      PwaInstallState.installed => ('已安裝', null),
      PwaInstallState.available => (
          '可離線開啟',
          FilledButton.icon(
            key: const ValueKey('pwa-install-button'),
            onPressed: () async {
              final result = await pwa.install();
              if (!context.mounted || result != 'accepted') return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已安裝 Agent T')));
            },
            icon: const Icon(Icons.install_mobile),
            label: const Text('安裝 App'),
          ),
        ),
      PwaInstallState.iosManual => (
          'Safari「分享」→「加入主畫面」',
          null,
        ),
      _ => (
          '從瀏覽器選單「安裝」或「加到主畫面」',
          null,
        ),
    };
    return _PwaCard(
      key: const ValueKey('pwa-install-card'),
      icon: Icons.install_mobile,
      title: '安裝 App',
      children: [
        Text(text, key: ValueKey('pwa-install-${state.name}')),
        if (action != null) ...[const SizedBox(height: 12), action],
      ],
    );
  }
}

/// 設定頁的「商店刷新通知」卡（只在網頁版顯示，設定方式見 docs/push.md）。
class PushNotificationCard extends StatelessWidget {
  const PushNotificationCard({super.key});

  @override
  Widget build(BuildContext context) {
    final pwa = context.watch<PwaController>();
    final permission = pwa.notificationPermission;
    final subscription = pwa.subscription;
    final List<Widget> body;
    if (!pwa.pushConfigured) {
      body = const [
        Text('尚未設定推播金鑰（docs/push.md）', key: ValueKey('push-not-configured')),
      ];
    } else if (permission == 'unsupported') {
      body = const [
        Text('這個瀏覽器不支援通知；iOS 請從主畫面開啟', key: ValueKey('push-unsupported')),
      ];
    } else if (permission == 'denied') {
      body = const [
        Text('通知已被瀏覽器封鎖', key: ValueKey('push-denied')),
      ];
    } else if (subscription == null) {
      body = [
        FilledButton.icon(
          key: const ValueKey('push-subscribe'),
          onPressed: pwa.busy
              ? null
              : () async {
                  final result = await pwa.subscribe();
                  if (!context.mounted || result != null) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('沒有開啟通知（權限未允許或瀏覽器不支援）')));
                },
          icon: const Icon(Icons.notifications_active),
          label: const Text('開啟通知'),
        ),
      ];
    } else {
      body = [
        const Text('複製訂閱資料，貼到 GitHub secret PUSH_SUBSCRIPTIONS'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            key: const ValueKey('push-copy'),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: subscription));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已複製訂閱資料')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('複製訂閱資料'),
          ),
          OutlinedButton.icon(
            key: const ValueKey('push-test'),
            onPressed: pwa.testNotification,
            icon: const Icon(Icons.notifications),
            label: const Text('測試通知'),
          ),
          TextButton(
            key: const ValueKey('push-unsubscribe'),
            onPressed: pwa.busy ? null : pwa.unsubscribe,
            child: const Text('取消訂閱'),
          ),
        ]),
      ];
    }
    return _PwaCard(
      key: const ValueKey('push-card'),
      icon: Icons.notifications,
      title: '商店刷新通知',
      children: body,
    );
  }
}

class _PwaCard extends StatelessWidget {
  const _PwaCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ]),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}
