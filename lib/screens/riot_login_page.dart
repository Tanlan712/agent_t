import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/riot_provider.dart';
import '../providers/settings_provider.dart';
import '../services/riot_auth.dart';
import '../services/shared_login.dart';
import '../widgets/account_list.dart';
import '../widgets/hud/hud.dart';
import 'riot_web_login_page.dart';

/// Riot 登入：使用者在 Riot 官方頁面登入後，把跳轉網址貼回來，
/// 或在 Android 上把跳轉頁「分享」給本 App（[takeShared]）。
/// Android／iOS App 另外提供內嵌登入，登入完成後自動帶回跳轉網址。
class RiotLoginPage extends StatefulWidget {
  static const sharedBadMessage =
      '分享的網址找不到登入資訊，請在登入後跳到的 playvalorant.com 頁面按「分享」';

  const RiotLoginPage({
    super.key,
    this.inAppLoginAvailable,
    this.openInAppLogin = openRiotWebLogin,
    this.takeShared = takeSharedLogin,
  });

  /// null 時依平台判斷（[inAppLoginSupported]）。
  final bool? inAppLoginAvailable;

  /// 開啟內嵌登入頁，回傳跳轉網址；使用者取消時回傳 null。
  final Future<String?> Function(BuildContext context) openInAppLogin;

  /// 取出 Android 分享進來的文字（取出後即刪除）；預設讀 service worker 暫存的內容。
  final Future<String?> Function() takeShared;

  @override
  State<RiotLoginPage> createState() => _RiotLoginPageState();
}

class _RiotLoginPageState extends State<RiotLoginPage> {
  final _controller = TextEditingController();
  String? _error;

  /// 已登入時按了「新增其他帳號」：顯示登入方式。
  bool _adding = false;
  late String _shard = context.read<SettingsProvider>().settings.loginShard;

  static const _shards = {
    'ap': '亞太（ap）',
    'kr': '韓國（kr）',
    'na': '北美／拉美／巴西（na）',
    'eu': '歐洲（eu）',
  };

  @override
  void initState() {
    super.initState();
    _receiveShared();
  }

  Future<void> _receiveShared() async {
    final shared = await widget.takeShared();
    if (shared == null || !mounted) return;
    final url = findRiotRedirect(shared);
    if (url == null) {
      setState(() => _error = RiotLoginPage.sharedBadMessage);
      return;
    }
    _controller.text = url;
    await _submit();
  }

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

  Future<void> _submit() => _loginWith(_controller.text);

  Future<void> _openInAppLogin() async {
    final riot = context.read<RiotProvider>();
    // 新增帳號：先清掉內嵌頁記住的帳號，Riot 才會顯示登入頁。
    if (_adding) await riot.prepareNewLogin();
    if (!mounted) return;
    final url = await widget.openInAppLogin(context);
    if (url == null || !mounted) return;
    // App 內登入的 Riot 登入記錄留在內嵌頁，之後可以在背景續期（AGENTS.md 第 3 節）。
    await _loginWith(url, autoRenew: true);
  }

  Future<void> _loginWith(String url, {bool autoRenew = false}) async {
    final error = await context
        .read<RiotProvider>()
        .login(url, fallbackShard: _shard, autoRenew: autoRenew);
    if (!mounted) return;
    setState(() {
      _error = error;
      if (error == null) _adding = false;
    });
    if (error == null) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final session = riot.session;
    final inApp = widget.inAppLoginAvailable ?? inAppLoginSupported;

    return Scaffold(
      appBar: AppBar(title: const Text('Riot 帳號')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 風險提示：警示色條＋圖示（MASTER.md：不用 emoji 當圖示）。
              PanelCard(
                accent: AppColors.warn,
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber, color: AppColors.warn),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        '使用 Riot 未公開 API，可能違反服務條款，帳號有受處分的風險。'
                        '登入資訊保存在這個瀏覽器，用完請登出。',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (riot.accounts.length > 1 ||
                  (riot.accounts.isNotEmpty && !riot.isLoggedIn)) ...[
                AccountList(inApp: inApp),
                const SizedBox(height: 16),
              ],
              if (riot.isLoggedIn && session != null) ...[
                ListTile(
                  leading: Icon(Icons.verified_user, color: AppColors.owned),
                  title: Text('已登入：${session.displayName}（${session.shard}）'),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                        onPressed: riot.logout, child: const Text('登出')),
                    if (!_adding)
                      OutlinedButton.icon(
                        key: const ValueKey('add-account'),
                        onPressed: () => setState(() => _adding = true),
                        icon: const Icon(Icons.person_add_alt),
                        label: const Text('新增其他帳號'),
                      ),
                  ],
                ),
              ],
              if (!riot.isLoggedIn || _adding) ...[
                if (_adding) ...[
                  const SizedBox(height: 16),
                  Text(
                    inApp
                        ? '請在 Riot 頁面登入另一個帳號。'
                        : '請先在 Riot 登入頁登出，或用無痕視窗開啟登入網址。',
                  ),
                  const SizedBox(height: 16),
                ],
                if (inApp) ...[
                  FilledButton.icon(
                    onPressed: riot.isBusy ? null : _openInAppLogin,
                    icon: const Icon(Icons.login),
                    label: const Text('在 App 內登入 Riot'),
                  ),
                  const SizedBox(height: 16),
                ],
                const Text('1. 開啟 Riot 登入頁並登入（勾選「保持登入」）'),
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
                const Text('2. 複製跳轉後 playvalorant.com 的完整網址，貼到下方'
                    '（Android App 可直接「分享」給本 App）'),
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
                  onChanged: (v) {
                    setState(() => _shard = v ?? 'ap');
                    context.read<SettingsProvider>().setLoginShard(_shard);
                  },
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
