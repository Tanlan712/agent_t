import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/purchase_history.dart';
import '../logic/wallet_history.dart';
import '../models/wallet_log.dart';
import '../providers/catalog_provider.dart';
import '../providers/riot_provider.dart';
import '../providers/shop_provider.dart';
import '../providers/wallet_log_provider.dart';
import '../shell/app_shell.dart';
import '../storage/wallet_log_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import 'match_history_page.dart' show formatMatchTime;
import 'purchase_import_page.dart';
import 'riot_web_login_page.dart' show inAppLoginSupported;

String _signed(int n) => n > 0 ? '+$n' : '$n';

/// Riot 客服網站的官方購買紀錄（要在該網站另外登入；App 不讀取頁面內容）。
final officialPurchaseHistory = Uri.parse(
    'https://support.riotgames.com/zh-tw/valorant/billing/checking-your-purchase-history');

Future<bool> _openInNewTab(Uri uri) =>
    launchUrl(uri, webOnlyWindowName: '_blank');

/// 錢包紀錄：同步錢包時記下的 VP 儲值與花費（Riot 沒有儲值紀錄的 API，只存在這個瀏覽器）。
class WalletPage extends StatelessWidget {
  /// 開啟官方購買紀錄（測試時注入）。
  final Future<bool> Function(Uri) launch;

  /// 可以在 App 內匯入官方購買紀錄（只有手機 App；null 時依平台判斷）。
  final bool? canImport;

  /// 開啟匯入頁，回傳讀到的紀錄（測試時注入）。
  final Future<List<PurchaseRecord>?> Function(BuildContext, Uri)
      importOfficial;

  const WalletPage({
    super.key,
    this.launch = _openInNewTab,
    this.canImport,
    this.importOfficial = openPurchaseImport,
  });

  Future<void> _import(BuildContext context, String puuid) async {
    final log = context.read<WalletLogProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final records = await importOfficial(context, officialPurchaseHistory);
    if (records == null) return;
    await log.importPurchases(puuid, records);
    messenger
        .showSnackBar(SnackBar(content: Text('已匯入 ${records.length} 筆官方購買紀錄')));
  }

  Widget _official(BuildContext context, String? puuid) {
    final importable = puuid != null && (canImport ?? inAppLoginSupported);
    return PanelCard(
      key: const ValueKey('wallet-official'),
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(importable
              ? '完整的儲值紀錄在 Riot 客服網站。按「匯入」後在官方頁登入，再按「匯入這頁的紀錄」就會列在下方。'
              : '完整的儲值紀錄在 Riot 客服網站，登入後即可查看。'),
          if (importable)
            FilledButton.icon(
              key: const ValueKey('wallet-official-import'),
              onPressed: () => _import(context, puuid),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('匯入官方購買紀錄'),
            ),
          OutlinedButton.icon(
            key: const ValueKey('wallet-official-open'),
            onPressed: () => launch(officialPurchaseHistory),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('查看官方購買紀錄'),
          ),
        ],
      ),
    );
  }

  Future<void> _sync(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<RiotProvider>().sync(
          shop: context.read<ShopProvider>(),
          catalog: context.read<CatalogProvider>(),
        );
    messenger.showSnackBar(SnackBar(content: Text(error ?? '已從 Riot 更新錢包')));
  }

  Future<void> _clear(BuildContext context, String puuid) async {
    final log = context.read<WalletLogProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清除這個帳號的錢包紀錄？'),
        content: const Text('只會刪除這個瀏覽器裡的紀錄，無法復原。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok == true) await log.clear(puuid);
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final log = context.watch<WalletLogProvider>();
    final catalog = context.watch<CatalogProvider>();
    final puuid = riot.isLoggedIn ? riot.session?.puuid : null;

    if (puuid == null) {
      return AppShell(
        currentRoute: '/wallet',
        title: '錢包紀錄',
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            PanelCard(
              padding: const EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.account_balance_wallet,
                title: '登入 Riot 以記錄錢包',
                message: '登入後每次同步都會記下 VP 餘額，找出儲值與花費',
                actionLabel: '登入 Riot',
                onAction: () => Navigator.pushNamed(context, '/riot-login'),
              ),
            ),
            const SizedBox(height: 16),
            _official(context, null),
          ],
        ),
      );
    }

    final changes = log.changes(puuid);
    final totals = vpTotals(changes);
    final since = log.since(puuid);
    final wallet = riot.wallet;

    return AppShell(
      currentRoute: '/wallet',
      title: '錢包紀錄',
      subtitle: since == null ? null : '從 ${formatMatchTime(since)} 開始記錄',
      actions: [
        IconButton(
          key: const ValueKey('wallet-sync'),
          tooltip: '從 Riot 更新',
          icon: const Icon(Icons.sync),
          onPressed: riot.isBusy ? null : () => _sync(context),
        ),
        if (since != null || log.purchases(puuid) != null)
          TextButton(
              onPressed: () => _clear(context, puuid),
              child: const Text('清除紀錄')),
      ],
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          KpiStrip(tiles: [
            KpiTile(
                label: '目前 VP',
                code: 'VP BALANCE',
                value: wallet == null ? '—' : '${wallet.vp}'),
            KpiTile(
                label: '記錄到的儲值',
                code: 'TOP-UP',
                value: '${totals.toppedUp}',
                up: totals.toppedUp > 0 ? true : null),
            KpiTile(
                label: '記錄到的花費',
                code: 'SPENT',
                value: '${totals.spent}',
                up: totals.spent > 0 ? false : null),
          ]),
          const SizedBox(height: 16),
          _official(context, puuid),
          if (log.purchases(puuid) case final imported?) ...[
            const SizedBox(height: 16),
            _PurchaseList(imported: imported),
          ],
          const SizedBox(height: 16),
          const SectionHeader(title: '變化'),
          const SizedBox(height: 8),
          if (changes.isEmpty)
            PanelCard(
              padding: const EdgeInsets.all(24),
              child: EmptyState(
                icon: Icons.hourglass_empty,
                title: since == null ? '還沒有記錄' : '目前還沒有變化',
                message: '每次同步商店時會記下錢包餘額；儲值或購買後再同步，就會出現在這裡',
              ),
            )
          else
            for (final c in changes) ...[
              _ChangeCard(change: c, catalog: catalog),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 8),
          Text(
            'Riot 沒有提供儲值紀錄，這裡是比對每次同步時的餘額推算出來的，只存在這個瀏覽器。'
            '兩次同步之間又儲值又花費時，只會看到淨變化；完整的購買紀錄請到 Riot 官方客服網站查詢。',
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// 從 Riot 官方購買紀錄匯入的清單。
class _PurchaseList extends StatelessWidget {
  final ImportedPurchases imported;

  const _PurchaseList({required this.imported});

  @override
  Widget build(BuildContext context) {
    final records = imported.records;
    final total = purchasedVp(records);
    return Column(
      key: const ValueKey('wallet-purchases'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(title: '官方購買紀錄（${records.length} 筆）'),
        const SizedBox(height: 4),
        Text(
          '${formatMatchTime(imported.importedAt)} 匯入'
          '${total > 0 ? '・合計 $total VP' : ''}',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        PanelCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              for (final r in records)
                ListTile(
                  dense: true,
                  leading: Icon(Icons.receipt_long, color: AppColors.primary),
                  title: Text(r.item),
                  subtitle: r.date == null ? null : Text(_day(r.date!)),
                  trailing: Text(
                    [
                      if (r.vp != null) '+${r.vp} VP',
                      if (r.price != null) r.price!
                    ].join('\n'),
                    textAlign: TextAlign.end,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _day(DateTime t) =>
    '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

class _ChangeCard extends StatelessWidget {
  final WalletChange change;
  final CatalogProvider catalog;

  const _ChangeCard({required this.change, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final c = change;
    final skins = [
      for (final id in c.newItems)
        if (catalog.skinByItemId(id) case final s?) s.name,
    ];
    final String title;
    final Color color;
    final IconData icon;
    if (c.vp > 0) {
      title = '儲值 ${_signed(c.vp)} VP';
      color = AppColors.win;
      icon = Icons.add_card;
    } else if (c.vp < 0) {
      title = '花費 ${-c.vp} VP';
      color = AppColors.loss;
      icon = Icons.shopping_cart;
    } else {
      title = skins.isNotEmpty || c.newItems.isNotEmpty ? '取得造型' : '其他貨幣變化';
      color = AppColors.muted;
      icon = Icons.inventory_2_outlined;
    }
    final details = [
      if (c.radianite != 0) '輻能點數 ${_signed(c.radianite)}',
      if (c.kingdom != 0) '王國幣 ${_signed(c.kingdom)}',
      if (skins.isNotEmpty)
        '新造型：${skins.join('、')}'
      else if (c.newItems.isNotEmpty)
        '新造型 ${c.newItems.length} 個',
    ];
    return PanelCard(
      accent: color,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                for (final d in details)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(d),
                  ),
                const SizedBox(height: 2),
                Text(
                    '${formatMatchTime(c.from)} ～ ${formatMatchTime(c.at)}'
                    '・餘額 ${c.vpBalance} VP',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
