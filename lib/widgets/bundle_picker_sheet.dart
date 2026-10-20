import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/bundle_info.dart';
import '../providers/catalog_provider.dart';
import 'bundle_tile.dart';

/// 從組合包清單挑一個；取消時回傳 null。
Future<BundleInfo?> showBundlePicker(BuildContext context) {
  return showModalBottomSheet<BundleInfo>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _BundlePickerSheet(),
  );
}

class _BundlePickerSheet extends StatefulWidget {
  const _BundlePickerSheet();

  @override
  State<_BundlePickerSheet> createState() => _BundlePickerSheetState();
}

class _BundlePickerSheetState extends State<_BundlePickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final bundles =
        context.watch<CatalogProvider>().catalog?.bundles ?? const [];
    final q = _query.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final results = bundles
        .where((b) =>
            q.isEmpty ||
            b.name.toLowerCase().replaceAll(RegExp(r'\s+'), '').contains(q))
        .toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: '搜尋組合包名稱',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, i) => BundleTile(
                bundle: results[i],
                onTap: () => Navigator.pop(context, results[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
