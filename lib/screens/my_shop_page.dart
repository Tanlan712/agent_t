import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/shop_time.dart';
import '../logic/wishlist_match.dart';
import '../providers/catalog_provider.dart';
import '../providers/riot_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/wishlist_provider.dart';
import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import '../widgets/bundle_tile.dart';
import '../widgets/catalog_gate.dart';
import '../widgets/skin_card.dart';
import '../widgets/skin_tile.dart' show wishlistGold;
import 'shop_edit_page.dart';

/// 商店造型卡片的寬高比。
const _cardAspect = 0.78;

String formatRemaining(Duration d) =>
    '剩餘 ${d.inHours} 小時 ${d.inMinutes % 60} 分';

class MyShopPage extends StatelessWidget {
  final DateTime Function() now;

  const MyShopPage({super.key, this.now = DateTime.now});

  @override
  Widget build(BuildContext context) {
    final catalog = context.watch<CatalogProvider>();
    final shop = context.watch<ShopProvider>().shop;
    final wishlist = context.watch<WishlistProvider>();
    final highlight =
        context.watch<SettingsProvider>().settings.highlightWishlist;
    final riot = context.watch<RiotProvider>();
    final t = now();

    final matched =
        highlight ? wishlistUuidsInShop(shop, wishlist.uuids, t) : <String>{};
    final dailyActive = isDailyActive(shop, t);
    final nightActive = isNightMarketActive(shop, t);

    void edit(ShopSection section) =>
        Navigator.pushNamed(context, '/my-shop/edit', arguments: section);

    return AppShell(
      currentRoute: '/',
      title: '我的商店',
      child: CatalogGate(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          children: [
            const _RiotBar(),
            const SizedBox(height: 24),
            if (matched.isNotEmpty) ...[
              Card(
                color: wishlistGold.withOpacity(0.2),
                child: ListTile(
                  leading: const Icon(Icons.star, color: wishlistGold),
                  title: Text('今天有 ${matched.length} 個願望清單造型上架'),
                ),
              ),
              const SizedBox(height: 24),
            ],
            _Section(
              title: '每日商店',
              status: shop.daily.isEmpty
                  ? null
                  : dailyActive
                      ? formatRemaining(shop.dailyExpiresAt!.difference(t))
                      : '已過期，請更新',
              onEdit: () => edit(ShopSection.daily),
              children: [
                if (shop.daily.isNotEmpty)
                  ResponsiveGrid(
                    minTileWidth: 240,
                    childAspectRatio: _cardAspect,
                    children: [
                      for (final e in shop.daily)
                        SkinCard(
                          skin: catalog.skinById(e.skinUuid),
                          price: e.price,
                          highlighted:
                              dailyActive && matched.contains(e.skinUuid),
                          owned: riot.isOwned(e.skinUuid),
                        ),
                    ],
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
                if (shop.nightMarket.isNotEmpty)
                  ResponsiveGrid(
                    minTileWidth: 240,
                    childAspectRatio: _cardAspect,
                    children: [
                      for (final e in shop.nightMarket)
                        SkinCard(
                          skin: catalog.skinById(e.skinUuid),
                          price: e.discountedPrice,
                          originalPrice: e.originalPrice,
                          highlighted:
                              nightActive && matched.contains(e.skinUuid),
                          owned: riot.isOwned(e.skinUuid),
                        ),
                    ],
                  ),
              ],
            ),
            _Section(
              title: '精選組合包',
              status: null,
              onEdit: () => edit(ShopSection.featuredBundle),
              children: [
                if (shop.featuredBundle case final b?)
                  BundleTile(
                      bundle: catalog.bundleById(b.bundleUuid),
                      price: b.price,
                      banner: true),
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
          if (children.isNotEmpty) const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// 頁面頂端的 Riot 帳號列：未登入時引導登入，登入後提供同步與錢包。
class _RiotBar extends StatelessWidget {
  const _RiotBar();

  Future<void> _sync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<RiotProvider>().sync(
          shop: context.read<ShopProvider>(),
          catalog: context.read<CatalogProvider>(),
        );
    messenger.showSnackBar(SnackBar(content: Text(error ?? '已從 Riot 同步商店')));
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final session = riot.session;
    if (!riot.isLoggedIn || session == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.login),
          title: const Text('登入 Riot 以自動同步'),
          subtitle: const Text('或在下方手動輸入商店內容'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.pushNamed(context, '/riot-login'),
        ),
      );
    }
    final wallet = riot.wallet;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        // Wrap：窄螢幕時同步按鈕自動換到下一行。
        child: Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_user, color: AppColors.owned),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('已登入：${session.displayName}（${session.shard}）',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (wallet != null)
                      Text(
                          'VP ${wallet.vp} · 輻能點數 ${wallet.radianite} · 王國幣 ${wallet.kingdom}'),
                    if (wallet != null)
                      Text('已擁有 ${riot.ownedSkinUuids.length} 款造型'),
                  ],
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: riot.isBusy ? null : () => _sync(context),
              icon: riot.isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync),
              label: const Text('從 Riot 同步'),
            ),
          ],
        ),
      ),
    );
  }
}
