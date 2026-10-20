import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/catalog_provider.dart';

/// 造型目錄就緒前顯示載入／錯誤畫面；改用舊快取時提示一次。
class CatalogGate extends StatefulWidget {
  final Widget child;

  const CatalogGate({super.key, required this.child});

  @override
  State<CatalogGate> createState() => _CatalogGateState();
}

class _CatalogGateState extends State<CatalogGate> {
  bool _staleShown = false;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();

    if (catalog.usingStaleCache && !_staleShown) {
      _staleShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('無法更新，使用先前資料')),
        );
      });
    } else if (!catalog.usingStaleCache) {
      _staleShown = false;
    }

    if (catalog.catalog != null) return widget.child;

    final error = catalog.error;
    if (error != null && !catalog.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: catalog.refresh, child: const Text('重試')),
          ],
        ),
      );
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 12),
          Text('下載造型資料中…'),
        ],
      ),
    );
  }
}
