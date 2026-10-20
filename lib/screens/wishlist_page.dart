import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/wishlist_match.dart';
import '../models/skin_info.dart';
import '../providers/catalog_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/catalog_gate.dart';
import '../widgets/skin_tile.dart';

class WishlistPage extends StatelessWidget {
  final DateTime Function() now;

  const WishlistPage({super.key, this.now = DateTime.now});

  Future<void> _add(BuildContext context) async {
    final wishlist = context.read<WishlistProvider>();
    final skin = await Navigator.pushNamed(context, '/skin-picker') as SkinInfo?;
    if (skin != null) await wishlist.add(skin.uuid);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final shop = context.watch<ShopProvider>().shop;
    final onSale = wishlistUuidsInShop(shop, wishlist.uuids, now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('願望清單'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: '加入造型',
            onPressed: () => _add(context),
          ),
        ],
      ),
      body: CatalogGate(
        child: wishlist.items.isEmpty
            ? const Center(child: Text('願望清單是空的，按 ＋ 加入造型'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final item in wishlist.items)
                    Dismissible(
                      key: ValueKey(item.skinUuid),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: const Icon(Icons.delete),
                      ),
                      onDismissed: (_) => wishlist.remove(item.skinUuid),
                      child: SkinTile(
                        skin: catalog.skinById(item.skinUuid),
                        highlighted: onSale.contains(item.skinUuid),
                        trailing: onSale.contains(item.skinUuid)
                            ? const Chip(label: Text('現在上架中'))
                            : null,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
