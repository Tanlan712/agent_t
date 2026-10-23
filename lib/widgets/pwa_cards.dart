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
      PwaInstallState.installed => ('已經安裝成 App，可以從主畫面或應用程式清單開啟。', null),
      PwaInstallState.available => (
          '安裝後會有自己的視窗與圖示，沒有網路時也能打開，看上次同步的商店。',
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
          '在 Safari 按下方的「分享」按鈕，選「加入主畫面」。'
              '加入後從主畫面開啟，才能收到商店刷新通知（iOS 16.4 以上）。',
          null,
        ),
      _ => (
          '這個瀏覽器目前沒有提供安裝提示。可以從網址列或選單的「安裝」／「加到主畫面」安裝；'
              '已經安裝過的話，直接從主畫面開啟。',
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
        Text('尚未設定推播金鑰。照 docs/push.md 在 GitHub 設定 VAPID 金鑰後，這裡就能開啟通知。',
            key: ValueKey('push-not-configured')),
      ];
    } else if (permission == 'unsupported') {
      body = const [
        Text('這個瀏覽器不支援通知。iPhone／iPad 要先「加入主畫面」，再從主畫面開啟 App（iOS 16.4 以上）。',
            key: ValueKey('push-unsupported')),
      ];
    } else if (permission == 'denied') {
      body = const [
        Text('通知已被封鎖。請在瀏覽器的網站設定中允許通知，再回到這裡。', key: ValueKey('push-denied')),
      ];
    } else if (subscription == null) {
      body = [
        const Text('每天台灣時間早上 8 點左右（每日商店刷新）收到一則通知。'
            'GitHub 排程可能延遲幾分鐘到一小時。'),
        const SizedBox(height: 12),
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
        const Text('這台裝置已訂閱。最後一步：按「複製訂閱資料」，貼到 GitHub 的 secret '
            'PUSH_SUBSCRIPTIONS（多台裝置就放在同一個 JSON 陣列），詳見 docs/push.md。'),
        const SizedBox(height: 8),
        Text('訂閱資料只用來把通知送到這台裝置，請勿公開貼出。',
            style: TextStyle(color: AppColors.muted)),
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
