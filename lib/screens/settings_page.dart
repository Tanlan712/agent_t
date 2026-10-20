import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:valorant_shop_tracker/services/riot_api_key_manager.dart';
import 'package:valorant_shop_tracker/widgets/my_shop_settings_card.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _apiKey;
  String? _statusMessage;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  void _loadApiKey() {
    setState(() {
      _apiKey = dotenv.env['RIOT_API_KEY'];
    });
  }

  Future<void> _checkApiKey() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      setState(() {
        _statusMessage = '❌ 未設定 API Key';
      });
      return;
    }

    setState(() {
      _isChecking = true;
    });

    final manager = RiotApiKeyManager(_apiKey!);
    final message = await manager.getStatusMessage();

    setState(() {
      _statusMessage = message;
      _isChecking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('API 設定'),
        backgroundColor: Colors.indigo,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildApiKeySection(),
          const SizedBox(height: 24),
          _buildRenewalInstructionsSection(),
          const SizedBox(height: 24),
          _buildAlternativeApiSection(),
          const SizedBox(height: 24),
          const MyShopSettingsCard(),
        ],
      ),
    );
  }

  Widget _buildApiKeySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔑 Riot API Key',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_apiKey != null && _apiKey!.isNotEmpty) ...[
              Text(
                'API Key: ${_apiKey!.substring(0, 20)}...',
                style: const TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 8),
              Text(
                '⏰ Development Key 有效期限：24 小時',
                style: TextStyle(color: Colors.grey[600]),
              ),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusMessage!.startsWith('✅')
                        ? Colors.green[100]
                        : _statusMessage!.startsWith('❌')
                            ? Colors.red[100]
                            : Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(_statusMessage!),
                ),
              ],
            ] else ...[
              const Text('❌ 未設定 API Key'),
              const SizedBox(height: 8),
              const Text('請在 .env 檔案中設定 RIOT_API_KEY'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRenewalInstructionsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🔄 更新 API Key',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
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
      ),
    );
  }

  Widget _buildAlternativeApiSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💡 推薦替代方案',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              RiotApiKeyManager.getAlternativeApiInfo(),
              style: const TextStyle(height: 1.5),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
