import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/shop_time.dart';
import '../logic/wishlist_match.dart';
import '../providers/catalog_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/wishlist_provider.dart';
import '../widgets/bundle_tile.dart';
import '../widgets/catalog_gate.dart';
import '../widgets/skin_tile.dart';
import 'shop_edit_page.dart';

String formatRemaining(Duration d) => '剩餘 ${d.inHours} 小時 ${d.inMinutes % 60} 分';

class MyShopPage extends StatelessWidget {
  final DateTime Function() now;

  const MyShopPage({super.key, this.now = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final shop = context.watch<ShopProvider>().shop;
    final wishlist = context.watch<WishlistProvider>();
    final highlight = context.watch<SettingsProvider>().settings.highlightWishlist;
    final t = now();

    final matched = highlight ? wishlistUuidsInShop(shop, wishlist.uuids, t) : <String>{};
    final dailyActive = isDailyActive(shop, t);
    final nightActive = isNightMarketActive(shop, t);

    void edit(ShopSection section) =>
        Navigator.pushNamed(context, '/my-shop/edit', arguments: section);

    return Scaffold(
      appBar: AppBar(title: const Text('我的商店')),
      body: CatalogGate(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (matched.isNotEmpty)
              Card(
                color: wishlistGold.withOpacity(0.2),
                child: ListTile(
                  leading: const Icon(Icons.star, color: wishlistGold),
                  title: Text('今天有 ${matched.length} 個願望清單造型上架'),
                ),
              ),
            _Section(
              title: '每日商店',
              status: shop.daily.isEmpty
                  ? null
                  : dailyActive
                      ? formatRemaining(shop.dailyExpiresAt!.difference(t))
                      : '已過期，請更新',
              onEdit: () => edit(ShopSection.daily),
              children: [
                for (final e in shop.daily)
                  SkinTile(
                    skin: catalog.skinById(e.skinUuid),
                    price: e.price,
                    highlighted: dailyActive && matched.contains(e.skinUuid),
                  ),
              ],
            ),
            _Section(
              title: '夜市',
              status: shop.nightMarket.isEmpty
                  ? null
                  : nightActive
                      ? formatRemaining(shop.nightMarketEndsAt!.difference(t))
                      : '已過期，請更新',
              onEdit: () => edit(ShopSection.nightMarket),
              children: [
                for (final e in shop.nightMarket)
                  SkinTile(
                    skin: catalog.skinById(e.skinUuid),
                    price: e.discountedPrice,
                    originalPrice: e.originalPrice,
                    highlighted: nightActive && matched.contains(e.skinUuid),
                  ),
              ],
            ),
            _Section(
              title: '精選組合包',
              status: null,
              onEdit: () => edit(ShopSection.featuredBundle),
              children: [
                if (shop.featuredBundle case final b?)
                  BundleTile(bundle: catalog.bundleById(b.bundleUuid), price: b.price),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? status;
  final VoidCallback onEdit;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.status,
    required this.onEdit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final empty = children.isEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  empty ? '尚未輸入' : (status ?? ''),
                  style: TextStyle(
                    color: status == '已過期，請更新'
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).hintColor,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onEdit,
                icon: Icon(empty ? Icons.add : Icons.edit),
                label: Text(empty ? '新增' : '編輯'),
              ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}
