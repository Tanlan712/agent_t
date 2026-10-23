import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../logic/purchase_history.dart';

/// 開啟 Riot 官方購買紀錄頁；使用者按「匯入」時回傳解析出的紀錄，關掉頁面時回傳 null。
/// 只有手機 App 可用（[inAppLoginSupported]）。
Future<List<PurchaseRecord>?> openPurchaseImport(
        BuildContext context, Uri url) =>
    Navigator.of(context).push<List<PurchaseRecord>>(
      MaterialPageRoute(builder: (_) => PurchaseImportPage(url: url)),
    );

/// 內嵌 Riot 客服網站的購買紀錄頁（使用者決定 2026-10-23，AGENTS.md 第 3 節）。
/// 使用者自己登入；只有按下「匯入這頁的紀錄」時，才在 support.riotgames.com 執行
/// [purchaseScrapeScript] 讀紀錄表格的文字。不讀 cookie、不自動點擊、不送出資料。
class PurchaseImportPage extends StatefulWidget {
  const PurchaseImportPage({super.key, required this.url});

  final Uri url;

  @override
  State<PurchaseImportPage> createState() => _PurchaseImportPageState();
}

class _PurchaseImportPageState extends State<PurchaseImportPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      // 客服網站與 Riot 登入頁需要 JavaScript；App 只在按下匯入時執行唯讀腳本。
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onNavigationRequest: (request) => allowPurchaseNavigation(request.url,
                isMainFrame: request.isMainFrame)
            ? NavigationDecision.navigate
            : NavigationDecision.prevent,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      ))
      ..loadRequest(widget.url);
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final current = Uri.tryParse(await _controller.currentUrl() ?? '');
    if (current?.host != purchaseHistoryHost) {
      messenger.showSnackBar(
          const SnackBar(content: Text('請先登入，並回到 Riot 客服網站的購買紀錄頁再匯入')));
      return;
    }
    setState(() => _reading = true);
    try {
      final result =
          await _controller.runJavaScriptReturningResult(purchaseScrapeScript);
      final records = parsePurchaseRows(decodeScrapeResult(result));
      if (records.isEmpty) {
        messenger.showSnackBar(
            const SnackBar(content: Text('找不到購買紀錄，請確認已登入並打開紀錄清單')));
        return;
      }
      navigator.pop(records);
    } catch (e) {
      // 頁面內容可能含個人資料，只記錄類型。
      debugPrint('讀取購買紀錄失敗：${e.runtimeType}');
      messenger
          .showSnackBar(const SnackBar(content: Text('讀取失敗，請重新整理頁面後再試一次')));
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('官方購買紀錄'),
        actions: [
          IconButton(
            tooltip: '重新載入',
            icon: const Icon(Icons.refresh),
            onPressed: () => _controller.reload(),
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
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.icon(
            key: const ValueKey('purchase-import-run'),
            onPressed: _reading ? null : _import,
            icon: const Icon(Icons.download),
            label: Text(_reading ? '讀取中…' : '匯入這頁的紀錄'),
          ),
        ),
      ),
    );
  }
}
