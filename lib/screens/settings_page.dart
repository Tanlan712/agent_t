import 'package:flutter/material.dart';
import 'package:valorant_shop_tracker/theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:valorant_shop_tracker/services/app_icon_service.dart';
import 'package:valorant_shop_tracker/services/riot_api_key_manager.dart';
import 'package:valorant_shop_tracker/shell/app_shell.dart';
import 'package:valorant_shop_tracker/widgets/app_icon_picker.dart';
import 'package:valorant_shop_tracker/widgets/hud/hud.dart';
import 'package:valorant_shop_tracker/widgets/my_shop_settings_card.dart';
import 'package:valorant_shop_tracker/widgets/nav_order_editor.dart';
import 'package:valorant_shop_tracker/widgets/remote_control_card.dart';
import 'package:valorant_shop_tracker/widgets/theme/theme_picker.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _apiKey;
  String? _statusMessage;
  int? _status;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  void _loadApiKey() {
    setState(() {
      // 網頁版不載入 .env（不打包機密）；只有測試或本機另行載入時才有值。
      _apiKey = dotenv.isInitialized ? dotenv.env['RIOT_API_KEY'] : null;
    });
  }

  Future<void> _checkApiKey() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      setState(() {
        _status = 0;
        _statusMessage = '未設定 API Key';
      });
      return;
    }

    setState(() {
      _isChecking = true;
    });

    final manager = RiotApiKeyManager(_apiKey!);
    final status = await manager.checkKeyValidity();

    setState(() {
      _status = status;
      _statusMessage = RiotApiKeyManager.messageFor(status);
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              _buildApiKeySection(),
              const SizedBox(height: 24),
              _buildRenewalInstructionsSection(),
              const SizedBox(height: 24),
              _buildAlternativeApiSection(),
              const SizedBox(height: 24),
              const MyShopSettingsCard(),
              const SizedBox(height: 24),
              const RemoteControlCard(),
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

  Widget _buildApiKeySection() {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.key, title: 'Riot API Key'),
          const SizedBox(height: 16),
          if (_apiKey != null && _apiKey!.isNotEmpty) ...[
            Text(
              'API Key: ${_apiKey!.substring(0, 20)}...',
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.schedule, size: 16, color: AppColors.muted),
              const SizedBox(width: 6),
              Text('Development Key 有效期限：24 小時',
                  style: TextStyle(color: AppColors.muted)),
            ]),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isChecking ? null : _checkApiKey,
              icon: _isChecking
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(_isChecking ? '檢查中...' : '檢查狀態'),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 16),
              _StatusBox(status: _status, message: _statusMessage!),
            ],
          ] else ...[
            Row(children: [
              Icon(Icons.cancel_outlined, size: 18, color: AppColors.loss),
              const SizedBox(width: 6),
              const Text('未設定 API Key'),
            ]),
            const SizedBox(height: 8),
            const Text('網頁版不內建 API Key：網站的檔案會公開，金鑰放進去任何人都能取得。'
                '本 App 的商店、戰績等功能使用你登入後的授權，不需要 API Key。'),
          ],
        ],
      ),
    );
  }

  Widget _buildRenewalInstructionsSection() {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.autorenew, title: '更新 API Key'),
          const SizedBox(height: 16),
          Text(
            RiotApiKeyManager.getRenewalInstructions(),
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(
                  text: 'https://developer.riotgames.com/',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已複製網址到剪貼簿'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('複製網址'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlternativeApiSection() {
    return PanelCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: Icons.lightbulb_outline, title: '推薦替代方案'),
          const SizedBox(height: 16),
          Text(
            RiotApiKeyManager.getAlternativeApiInfo(),
            style: const TextStyle(height: 1.5),
          ),
          const SizedBox(height: 16),
          // FilledButton：主題已設為 buttonRed 底＋白字（對比 4.96）。
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(
                const ClipboardData(text: 'https://valorant-api.com/'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('已複製網址到剪貼簿'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('複製 valorant-api.com 網址'),
          ),
        ],
      ),
    );
  }
}

/// 區塊標題：Material 圖示＋文字（MASTER.md：不用 emoji 當圖示）。
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ]);
}

/// 檢查結果：顏色搭配圖示，不只靠顏色表達狀態。
class _StatusBox extends StatelessWidget {
  final int? status;
  final String message;

  const _StatusBox({required this.status, required this.message});

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (status) {
      200 || 404 => (AppColors.win, Icons.check_circle_outline),
      401 || -1 || 0 => (AppColors.loss, Icons.cancel_outlined),
      _ => (AppColors.warn, Icons.warning_amber),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
    );
  }
}
