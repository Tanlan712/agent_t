import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/riot_provider.dart';
import '../services/riot_auth.dart';

/// Riot 登入：使用者在 Riot 官方頁面登入後，把跳轉網址貼回來。
class RiotLoginPage extends StatefulWidget {
  const RiotLoginPage({super.key});

  @override
  State<RiotLoginPage> createState() => _RiotLoginPageState();
}

class _RiotLoginPageState extends State<RiotLoginPage> {
  final _controller = TextEditingController();
  String? _error;
  String _shard = 'ap';

  static const _shards = {
    'ap': '亞太（ap）',
    'kr': '韓國（kr）',
    'na': '北美／拉美／巴西（na）',
    'eu': '歐洲（eu）',
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openLogin() async {
    final ok =
        await launchUrl(Uri.parse(riotLoginUrl), webOnlyWindowName: '_blank');
    if (!ok && mounted) {
      setState(() => _error = '無法開啟新分頁，請改用「複製登入網址」');
    }
  }

  Future<void> _copyUrl() async {
    await Clipboard.setData(const ClipboardData(text: riotLoginUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('已複製登入網址')));
  }

  Future<void> _submit() async {
    final error = await context
        .read<RiotProvider>()
        .login(_controller.text, fallbackShard: _shard);
    if (!mounted) return;
    setState(() => _error = error);
    if (error == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final session = riot.session;

    return Scaffold(
      appBar: AppBar(title: const Text('Riot 帳號')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '⚠️ 使用 Riot 未公開 API，可能違反服務條款，帳號有受處分的風險，'
                    'API 也可能隨時失效。建議使用非主要帳號。\n'
                    '本 App 不會接觸你的密碼；登入資訊只保留在這個分頁的記憶體中，'
                    '重新整理或約 1 小時後需要重新登入。',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (riot.isLoggedIn && session != null) ...[
                ListTile(
                  leading: const Icon(Icons.verified_user, color: Colors.green),
                  title: Text('已登入：${session.displayName}（${session.shard}）'),
                ),
                OutlinedButton(onPressed: riot.logout, child: const Text('登出')),
              ] else ...[
                const Text('1. 開啟 Riot 官方登入頁並登入。'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: _openLogin,
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('開啟 Riot 登入頁'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _copyUrl,
                      icon: const Icon(Icons.copy),
                      label: const Text('複製登入網址'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('2. 登入後網頁會跳到 playvalorant.com，'
                    '把網址列的完整網址貼到下方。'),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('redirect-field'),
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'https://playvalorant.com/opt_in#access_token=…',
                    errorText: _error,
                    errorMaxLines: 3,
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _shard,
                  decoration: const InputDecoration(
                    labelText: '伺服器區域（自動偵測失敗時使用）',
                  ),
                  items: [
                    for (final e in _shards.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() => _shard = v ?? 'ap'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: riot.isBusy ? null : _submit,
                  child: riot.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('完成登入'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
