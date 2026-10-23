import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logic/purchase_history.dart';
import '../providers/purchase_history_provider.dart';
import '../providers/riot_provider.dart';
import '../shell/app_shell.dart';
import '../storage/purchase_history_storage.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';
import 'match_history_page.dart' show formatMatchTime;
import 'purchase_import_page.dart';
import 'riot_web_login_page.dart' show inAppLoginSupported;

/// Riot 客服網站的官方購買紀錄（要在該網站另外登入）。
final officialPurchaseHistory = Uri.parse(
    'https://support.riotgames.com/zh-tw/valorant/billing/checking-your-purchase-history');

Future<bool> _openInNewTab(Uri uri) =>
    launchUrl(uri, webOnlyWindowName: '_blank');

/// 錢包紀錄：Riot 沒有儲值紀錄的 API，只顯示從官方購買紀錄匯入的資料
/// （使用者決定 2026-10-23，AGENTS.md 第 3 節）。
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
    final history = context.read<PurchaseHistoryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final records = await importOfficial(context, officialPurchaseHistory);
    if (records == null) return;
    await history.import(puuid, records);
    messenger
        .showSnackBar(SnackBar(content: Text('已匯入 ${records.length} 筆官方購買紀錄')));
  }

  Future<void> _clear(BuildContext context, String puuid) async {
    final history = context.read<PurchaseHistoryProvider>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清除這個帳號匯入的紀錄？'),
        content: const Text('只會刪除這支手機裡的資料，之後可以再匯入。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('取消')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok == true) await history.clear(puuid);
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
              ? '儲值紀錄在 Riot 客服網站。按「匯入」後在官方頁登入，再按「匯入這頁的紀錄」就會列在下方。'
              : '儲值紀錄在 Riot 客服網站，登入後即可查看；手機 App 可以匯入到這裡。'),
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

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final history = context.watch<PurchaseHistoryProvider>();
    final puuid = riot.isLoggedIn ? riot.session?.puuid : null;
    final imported = puuid == null ? null : history.purchases(puuid);
    final wallet = riot.wallet;

    return AppShell(
      currentRoute: '/wallet',
      title: '錢包紀錄',
      actions: [
        if (puuid != null && imported != null)
          TextButton(
              onPressed: () => _clear(context, puuid),
              child: const Text('清除紀錄')),
      ],
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: [
          if (puuid == null)
            PanelCard(
              padding: const EdgeInsets.all(32),
              child: EmptyState(
                icon: Icons.account_balance_wallet,
                title: '登入 Riot 以匯入購買紀錄',
                message: '登入後可以在手機 App 匯入 Riot 官方的購買紀錄',
                actionLabel: '登入 Riot',
                onAction: () => Navigator.pushNamed(context, '/riot-login'),
              ),
            )
          else
            KpiStrip(tiles: [
              KpiTile(
                  label: '目前 VP',
                  code: 'VP BALANCE',
                  value: wallet == null ? '—' : '${wallet.vp}'),
              KpiTile(
                  label: '官方紀錄儲值',
                  code: 'TOP-UP',
                  value: imported == null
                      ? '—'
                      : '${purchasedVp(imported.records)}'),
            ]),
          const SizedBox(height: 16),
          _official(context, puuid),
          if (imported != null) ...[
            const SizedBox(height: 16),
            _PurchaseList(imported: imported),
          ],
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
