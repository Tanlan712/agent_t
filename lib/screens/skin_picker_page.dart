import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/skin_search.dart';
import '../providers/catalog_provider.dart';
import '../providers/offer_price_provider.dart';
import '../providers/riot_provider.dart';
import '../widgets/catalog_gate.dart';
import '../shell/layout.dart';
import '../shell/responsive_grid.dart';
import '../widgets/skin_card.dart';

/// 搜尋並選擇一個造型，以 Navigator.pop 回傳 SkinInfo。
class SkinPickerPage extends StatefulWidget {
  const SkinPickerPage({super.key});

  @override
  State<SkinPickerPage> createState() => _SkinPickerPageState();
}

class _SkinPickerPageState extends State<SkinPickerPage> {
  String _query = '';
  String? _weapon;

  /// 由 State 持有：寬度跨過 600 時搜尋框在樹中的位置會變，輸入文字仍要保留。
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final riot = context.watch<RiotProvider>();
    final prices = context.watch<OfferPriceProvider?>();
    return Scaffold(
      appBar: AppBar(title: const Text('選擇造型')),
      body: CatalogGate(
        child: Builder(builder: (context) {
          final results = searchSkins(
              catalog.catalog?.skins ?? const [], _query,
              weaponName: _weapon);
          final search = TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: '搜尋造型名稱',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          );
          final filter = DropdownButton<String?>(
            isExpanded: true,
            value: _weapon,
            items: [
              const DropdownMenuItem(value: null, child: Text('全部武器')),
              for (final w in catalog.weaponNames)
                DropdownMenuItem(value: w, child: Text(w)),
            ],
            onChanged: (v) => setState(() => _weapon = v),
          );
          return LayoutBuilder(builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding(width)),
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      if (width >= 600)
                        Row(children: [
                          Expanded(flex: 2, child: search),
                          const SizedBox(width: 16),
                          Expanded(child: filter),
                        ])
                      else ...[
                        search,
                        filter,
                      ],
                      Expanded(
                        child: results.isEmpty
                            ? const Center(child: Text('找不到符合的造型'))
                            : ResponsiveGridView.builder(
                                minTileWidth: 200,
                                childAspectRatio: 0.78,
                                itemCount: results.length,
                                itemBuilder: (context, i) => SkinCard(
                                  skin: results[i],
                                  price: prices?.priceOf(results[i]),
                                  owned: riot.isOwned(results[i].uuid),
                                  onTap: () =>
                                      Navigator.pop(context, results[i]),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          });
        }),
      ),
    );
  }
}
