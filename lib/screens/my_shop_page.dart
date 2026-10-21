import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/shop_time.dart';
import '../logic/wishlist_match.dart';
import '../models/riot_session.dart';
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
import '../widgets/hud/hud.dart';
import '../widgets/skin_card.dart';
import '../widgets/skin_tile.dart' show wishlistGold;
import 'shop_edit_page.dart';

/// 商店造型卡片的寬高比。
const _cardAspect = 0.78;

String formatRemaining(Duration d) =>
    '剩餘 ${d.inHours} 小時 ${d.inMinutes % 60} 分';

String _compact(Duration d) => '${d.inHours} 小時 ${d.inMinutes % 60} 分';

int _discount(int original, int now) =>
    original <= 0 ? 0 : ((1 - now / original) * 100).round();

/// 頁首 KPI：每日商店倒數；登入且同步後加上錢包與已擁有造型數。
class _ShopKpi extends StatelessWidget {
  final String daily;
  final RiotWallet? wallet;
  final int? owned;

  const _ShopKpi(
      {required this.daily, required this.wallet, required this.owned});

  @override
  Widget build(BuildContext context) {
    final w = wallet;
    final tiles = [
      KpiTile(label: '商店刷新', value: daily),
      if (w != null) ...[
        KpiTile(label: 'VP', value: '${w.vp}'),
        KpiTile(label: '輻能點數', value: '${w.radianite}'),
        KpiTile(label: '王國幣', value: '${w.kingdom}'),
      ],
      if (owned != null) KpiTile(label: '已擁有造型', value: '$owned'),
    ];
    // 右欄直向堆疊；6 欄以下由 BentoGrid 換到下一列，仍是直向。
    return Column(
      key: const ValueKey('shop-kpi'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < tiles.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          tiles[i],
        ],
      ],
    );
  }
}

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

    final dailySection = _Section(
      key: const ValueKey('shop-daily'),
      title: '每日商店',
      emptyIcon: Icons.storefront,
      status: shop.daily.isEmpty
          ? null
          : dailyActive
              ? formatRemaining(shop.dailyExpiresAt!.difference(t))
              : '已過期，請更新',
      onEdit: () => edit(ShopSection.daily),
      children: [
        if (shop.daily.isNotEmpty)
          // 每日 4 款：可用寬度 ≥ 360 時固定 2×2，否則單欄。
          LayoutBuilder(
            builder: (context, c) => GridView.count(
              crossAxisCount: c.maxWidth >= 360 ? 2 : 1,
              childAspectRatio: _cardAspect,
              mainAxisSpacing: gridSpacing,
              crossAxisSpacing: gridSpacing,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final e in shop.daily)
                  SkinCard(
                    skin: catalog.skinById(e.skinUuid),
                    price: e.price,
                    highlighted: dailyActive && matched.contains(e.skinUuid),
                    owned: riot.isOwned(e.skinUuid),
                  ),
              ],
            ),
          ),
      ],
    );

    final nightSection = _Section(
      title: '夜市',
      emptyIcon: Icons.nightlight_outlined,
      emptyLabel: '尚未開放',
      emptyTitle: '尚未開放',
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
                  trailing: StatusChip(
                      label:
                          '-${_discount(e.originalPrice, e.discountedPrice)}%',
                      color: AppColors.warn),
                  highlighted: nightActive && matched.contains(e.skinUuid),
                  owned: riot.isOwned(e.skinUuid),
                ),
            ],
          ),
      ],
    );

    final bundleSection = _Section(
      title: '精選組合包',
      emptyIcon: Icons.card_giftcard,
      status: null,
      onEdit: () => edit(ShopSection.featuredBundle),
      children: [
        if (shop.featuredBundle case final b?)
          BundleTile(
              bundle: catalog.bundleById(b.bundleUuid),
              price: b.price,
              banner: true),
      ],
    );

    return AppShell(
      currentRoute: '/',
      title: '我的商店',
      subtitle: shop.daily.isNotEmpty && dailyActive
          ? '刷新倒數 ${_compact(shop.dailyExpiresAt!.difference(t))}'
          : null,
      child: CatalogGate(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            BentoGrid(children: [
              BentoTile(
                  span: 12,
                  child: riot.isLoggedIn
                      ? const _RiotBar()
                      : _LoginHero(onManual: () => edit(ShopSection.daily))),
              BentoTile(span: 8, child: dailySection),
              BentoTile(
                span: 4,
                child: _ShopKpi(
                  daily: shop.daily.isEmpty
                      ? '—'
                      : dailyActive
                          ? _compact(shop.dailyExpiresAt!.difference(t))
                          : '已過期',
                  wallet: riot.wallet,
                  owned:
                      riot.wallet == null ? null : riot.ownedSkinUuids.length,
                ),
              ),
              BentoTile(span: 8, child: nightSection),
              BentoTile(
                span: 4,
                child: _WishlistHits(
                  enabled: highlight,
                  names: [
                    for (final id in matched)
                      catalog.skinById(id)?.name ?? '未知造型',
                  ],
                ),
              ),
              BentoTile(span: 12, child: bundleSection),
            ]),
          ],
        ),
      ),
    );
  }
}

/// 未登入時的登入大卡。
class _LoginHero extends StatelessWidget {
  final VoidCallback onManual;

  const _LoginHero({required this.onManual});

  @override
  Widget build(BuildContext context) => PanelCard(
        key: const ValueKey('shop-login-hero'),
        accent: AppColors.primary,
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login, color: AppColors.primary, size: 28),
                SizedBox(width: 16),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('登入 Riot 以自動同步',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('自動讀取每日商店、夜市與錢包；也可以手動輸入商店內容',
                          style:
                              TextStyle(fontSize: 14, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            Wrap(spacing: 8, runSpacing: 8, children: [
              FilledButton(
                onPressed: () => Navigator.pushNamed(context, '/riot-login'),
                child: const Text('登入 Riot'),
              ),
              OutlinedButton(onPressed: onManual, child: const Text('手動輸入')),
            ]),
          ],
        ),
      );
}

/// 右下：今天上架的願望清單造型。
class _WishlistHits extends StatelessWidget {
  final List<String> names;
  final bool enabled;

  const _WishlistHits({required this.names, required this.enabled});

  @override
  Widget build(BuildContext context) => PanelCard(
        key: const ValueKey('shop-wishlist-hits'),
        accent: names.isEmpty ? null : wishlistGold,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: '願望清單上架'),
            if (!enabled)
              const Text('已關閉願望清單標示', style: TextStyle(color: AppColors.muted))
            else if (names.isEmpty)
              const Text('今天沒有願望清單造型', style: TextStyle(color: AppColors.muted))
            else ...[
              Text('今天有 ${names.length} 個願望清單造型上架',
                  style: const TextStyle(
                      color: wishlistGold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              for (final n in names)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    const Icon(Icons.star, size: 16, color: wishlistGold),
                    const SizedBox(width: 6),
                    Expanded(child: Text(n, overflow: TextOverflow.ellipsis)),
                  ]),
                ),
            ],
          ],
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final String? status;
  final IconData emptyIcon;

  /// 沒有資料時標題旁的文字與空狀態標題（夜市為「尚未開放」）。
  final String emptyLabel;
  final String emptyTitle;
  final VoidCallback onEdit;
  final List<Widget> children;

  const _Section({
    super.key,
    required this.title,
    required this.status,
    required this.emptyIcon,
    this.emptyLabel = '尚未輸入',
    this.emptyTitle = '還沒有資料',
    required this.onEdit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final empty = children.isEmpty;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  empty ? emptyLabel : (status ?? ''),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color:
                        status == '已過期，請更新' ? AppColors.error : AppColors.muted,
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
          const SizedBox(height: 12),
          if (empty)
            EmptyState(
                icon: emptyIcon,
                title: emptyTitle,
                message: '登入 Riot 自動同步，或按「新增」手動輸入')
          else
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
    // 未登入時由 _LoginHero 顯示。
    if (session == null) return const SizedBox.shrink();
    return PanelCard(
      child: Padding(
        padding: EdgeInsets.zero,
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
                // Flexible：文字在 Wrap 給的最大寬度內換行，不會溢出。
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('已登入：${session.displayName}（${session.shard}）',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
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
