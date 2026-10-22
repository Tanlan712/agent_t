import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/catalog_provider.dart';
import '../providers/settings_provider.dart';
import '../shell/nav_items.dart' show wishlistEnabled;

String _two(int n) => n.toString().padLeft(2, '0');

String formatDateTime(DateTime t) =>
    '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

/// 設定頁的「我的商店」區塊：刷新時間、願望清單標示、重新下載目錄。
class MyShopSettingsCard extends StatelessWidget {
  const MyShopSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final catalog = context.watch<CatalogProvider>();
    final fetchedAt = catalog.catalog?.fetchedAt;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('我的商店', style: Theme.of(context).textTheme.titleLarge),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle),
              title: const Text('Riot 帳號'),
              subtitle: const Text('登入後可自動同步商店、錢包與已擁有造型'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pushNamed(context, '/riot-login'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(
                  '商店刷新時間 ${_two(settings.resetHour)}:${_two(settings.resetMinute)}'),
              subtitle: const Text('用來計算每日商店的到期時間'),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay(
                      hour: settings.resetHour, minute: settings.resetMinute),
                );
                if (picked != null) {
                  await settingsProvider.setResetTime(
                      picked.hour, picked.minute);
                }
              },
            ),
            if (wishlistEnabled)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('標示願望清單'),
                value: settings.highlightWishlist,
                onChanged: settingsProvider.setHighlightWishlist,
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.download),
              title: const Text('重新下載造型目錄'),
              subtitle: Text(fetchedAt == null
                  ? '尚未下載'
                  : '上次下載：${formatDateTime(fetchedAt)}'),
              trailing: catalog.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: catalog.isLoading ? null : catalog.refresh,
            ),
          ],
        ),
      ),
    );
  }
}
