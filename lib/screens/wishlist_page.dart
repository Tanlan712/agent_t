import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/wishlist_match.dart';
import '../models/skin_info.dart';
import '../providers/catalog_provider.dart';
import '../providers/riot_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/wishlist_provider.dart';
import '../shell/app_shell.dart';
import '../widgets/catalog_gate.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import '../widgets/skin_card.dart';

class WishlistPage extends StatelessWidget {
  final DateTime Function() now;

  const WishlistPage({super.key, this.now = DateTime.now});

  Future<void> _add(BuildContext context) async {
    final wishlist = context.read<WishlistProvider>();
    final skin =
        await Navigator.pushNamed(context, '/skin-picker') as SkinInfo?;
    if (skin != null) await wishlist.add(skin.uuid);
  }

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final riot = context.watch<RiotProvider>();
    final wishlist = context.watch<WishlistProvider>();
    final shop = context.watch<ShopProvider>().shop;
    final onSale = wishlistUuidsInShop(shop, wishlist.uuids, now());
    // 上架中的排在最前面，其餘維持加入順序。
    final items = [
      ...wishlist.items.where((e) => onSale.contains(e.skinUuid)),
      ...wishlist.items.where((e) => !onSale.contains(e.skinUuid)),
    ];

    return AppShell(
      currentRoute: '/wishlist',
      title: '願望清單',
      subtitle: items.isEmpty ? null : '${items.length} 款',
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: '加入造型',
          onPressed: () => _add(context),
        ),
      ],
      child: CatalogGate(
        child: wishlist.items.isEmpty
            ? EmptyState(
                icon: Icons.star_border,
                title: '願望清單是空的，按 ＋ 加入造型',
                actionLabel: '加入造型',
                onAction: () => _add(context),
              )
            : ResponsiveGridView.builder(
                minTileWidth: 200,
                childAspectRatio: 0.72,
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  final isOnSale = onSale.contains(item.skinUuid);
                  return Dismissible(
                    key: ValueKey(item.skinUuid),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 24),
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: const Icon(Icons.delete),
                    ),
                    onDismissed: (_) => wishlist.remove(item.skinUuid),
                    child: SkinCard(
                      skin: catalog.skinById(item.skinUuid),
                      highlighted: isOnSale,
                      owned: riot.isOwned(item.skinUuid),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isOnSale)
                            const StatusChip(
                                label: '現在上架中', color: AppColors.warn),
                          IconButton(
                            tooltip: '移出願望清單',
                            icon: const Icon(Icons.close),
                            onPressed: () => wishlist.remove(item.skinUuid),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
