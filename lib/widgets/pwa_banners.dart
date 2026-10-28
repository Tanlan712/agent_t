import 'package:flutter/material.dart';

import '../providers/pwa_controller.dart';
import '../theme/app_theme.dart';

/// 畫面頂端的「離線中」與「有新版本」提示列（只在網頁版出現）。
class PwaBanners extends StatelessWidget {
  const PwaBanners({super.key, required this.controller, required this.child});

  final PwaController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final bars = [
          if (!controller.online)
            TopNoticeBar(
              key: const ValueKey('pwa-offline-bar'),
              icon: Icons.cloud_off,
              color: AppColors.warn,
              text: '離線中：顯示上次儲存的資料，恢復連線後再同步。',
            ),
          if (controller.showUpdate)
            TopNoticeBar(
              key: const ValueKey('pwa-update-bar'),
              icon: Icons.system_update,
              color: AppColors.info,
              text: '有新版本。',
              actions: [
                TextButton(
                  key: const ValueKey('pwa-update-later'),
                  onPressed: controller.dismissUpdate,
                  child: const Text('稍後'),
                ),
                FilledButton(
                  key: const ValueKey('pwa-update-reload'),
                  onPressed: controller.reload,
                  child: const Text('重新整理'),
                ),
              ],
            ),
        ];
        if (bars.isEmpty) return child;
        return Column(
          children: [
            // 提示列吃掉頂端的安全區域（瀏海），下面的頁面就不用再留。
            SafeArea(
              bottom: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: bars),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 頂端提示列（網頁版的離線／新版本、Android App 的更新共用）。
class TopNoticeBar extends StatelessWidget {
  const TopNoticeBar({
    super.key,
    required this.icon,
    required this.color,
    required this.text,
    this.actions = const [],
  });

  final IconData icon;
  final Color color;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.alphaBlend(color.withOpacity(0.18), AppColors.surface),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: AppColors.text)),
          ),
          for (final a in actions) ...[const SizedBox(width: 8), a],
        ]),
      ),
    );
  }
}
