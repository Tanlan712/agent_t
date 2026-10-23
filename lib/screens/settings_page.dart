import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agent_t/providers/pwa_controller.dart';
import 'package:agent_t/services/app_icon_service.dart';
import 'package:agent_t/shell/app_shell.dart';
import 'package:agent_t/widgets/app_icon_picker.dart';
import 'package:agent_t/widgets/my_shop_settings_card.dart';
import 'package:agent_t/widgets/nav_order_editor.dart';
import 'package:agent_t/widgets/pwa_cards.dart';
import 'package:agent_t/widgets/remote_control_card.dart';
import 'package:agent_t/widgets/theme/theme_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    // 安裝與通知只有網頁版有（手機 App、測試沒有 PwaController 或不支援）。
    final pwa = context.watch<PwaController?>();
    final showPwa =
        pwa != null && pwa.installState != PwaInstallState.unsupported;
    return AppShell(
      currentRoute: '/settings',
      title: '設定',
      // 單欄最大寬度 760，置中。
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            key: const ValueKey('settings-list'),
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              const ThemePicker(),
              const SizedBox(height: 24),
              const NavOrderEditor(),
              const SizedBox(height: 24),
              const MyShopSettingsCard(),
              const SizedBox(height: 24),
              const RemoteControlCard(),
              if (showPwa) ...[
                const SizedBox(height: 24),
                const PwaInstallCard(),
                const SizedBox(height: 24),
                const PushNotificationCard(),
              ],
              // 網頁版的圖示由 manifest 固定，無法從頁面更換。
              if (AppIconService.supported) ...[
                const SizedBox(height: 24),
                const AppIconPicker(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
