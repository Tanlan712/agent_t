import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/skin_search.dart';
import '../providers/catalog_provider.dart';
import '../providers/riot_provider.dart';
import '../widgets/catalog_gate.dart';
import '../widgets/skin_tile.dart';

/// 搜尋並選擇一個造型，以 Navigator.pop 回傳 SkinInfo。
class SkinPickerPage extends StatefulWidget {
  const SkinPickerPage({super.key});

  @override
  State<SkinPickerPage> createState() => _SkinPickerPageState();
}

class _SkinPickerPageState extends State<SkinPickerPage> {
  String _query = '';
  String? _weapon;

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final riot = context.watch<RiotProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('選擇造型')),
      body: CatalogGate(
        child: Builder(builder: (context) {
          final results = searchSkins(
              catalog.catalog?.skins ?? const [], _query,
              weaponName: _weapon);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: '搜尋造型名稱',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _weapon,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('全部武器')),
                    for (final w in catalog.weaponNames)
                      DropdownMenuItem(value: w, child: Text(w)),
                  ],
                  onChanged: (v) => setState(() => _weapon = v),
                ),
              ),
              Expanded(
                child: results.isEmpty
                    ? const Center(child: Text('找不到符合的造型'))
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) => SkinTile(
                          skin: results[i],
                          owned: riot.isOwned(results[i].uuid),
                          onTap: () => Navigator.pop(context, results[i]),
                        ),
                      ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
