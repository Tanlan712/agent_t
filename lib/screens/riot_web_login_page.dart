import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../services/riot_auth.dart';

/// 只有 Android／iOS App 有內嵌登入（AGENTS.md 第 3 節「手機 App」）；網頁版維持貼網址。
bool get inAppLoginSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// 開啟內嵌 Riot 登入頁；登入完成時回傳跳轉網址，使用者關掉頁面時回傳 null。
Future<String?> openRiotWebLogin(BuildContext context) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const RiotWebLoginPage()),
    );

/// 內嵌 Riot 官方登入頁。使用者自己在 Riot 頁面輸入帳密；
/// App 不注入 JavaScript、不讀取表單或 cookie，只在跳轉到 playvalorant.com 時攔下網址。
class RiotWebLoginPage extends StatefulWidget {
  const RiotWebLoginPage({super.key});

  @override
  State<RiotWebLoginPage> createState() => _RiotWebLoginPageState();
}

class _RiotWebLoginPageState extends State<RiotWebLoginPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // Riot 的登入頁需要 JavaScript；App 本身不執行任何腳本。
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) => _capture(request.url)
            ? NavigationDecision.prevent
            : NavigationDecision.navigate,
        onUrlChange: (change) {
          final url = change.url;
          if (url != null) _capture(url);
        },
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      ))
      ..loadRequest(Uri.parse(riotLoginUrl));
  }

  /// 是 Riot 的跳轉網址時關掉頁面並回傳網址；網址含 token，不寫入 log。
  bool _capture(String url) {
    if (!isRiotRedirect(url)) return false;
    if (!_done && mounted) {
      _done = true;
      Navigator.of(context).pop(url);
    }
    return true;
  }

  Future<void> _switchAccount() async {
    await WebViewCookieManager().clearCookies();
    await _controller.loadRequest(Uri.parse(riotLoginUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riot 登入'),
        actions: [
          IconButton(
            tooltip: '重新載入',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            tooltip: '切換帳號（清除 Riot 登入記錄）',
            icon: const Icon(Icons.switch_account),
            onPressed: _switchAccount,
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(value: _progress / 100),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
