import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../logic/shop_history.dart';
import '../logic/skin_search.dart';
import '../providers/catalog_provider.dart';
import '../providers/riot_provider.dart';
import '../providers/shop_history_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud.dart';

String _date(DateTime d) {
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}/${two(l.month)}/${two(l.day)}';
}

enum _View { days, ranking }

/// 商店歷史：每次同步記下的每日商店，可以查某個造型上次出現與出現次數。
class ShopHistoryPage extends StatefulWidget {
  final DateTime Function() now;

  const ShopHistoryPage({super.key, this.now = DateTime.now});

  @override
  State<ShopHistoryPage> createState() => _ShopHistoryPageState();
}

class _ShopHistoryPageState extends State<ShopHistoryPage> {
  final _query = TextEditingController();
  _View _view = _View.days;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final puuid = context.watch<RiotProvider>().activePuuid;
    final provider = context.watch<ShopHistoryProvider>();
    final catalog = context.watch<CatalogProvider>();
    final history =
        puuid == null ? const ShopHistory() : provider.historyOf(puuid);
    final appearances = skinAppearances(history);
    final byId = {for (final a in appearances) a.skinUuid: a};
    final now = widget.now();
    String nameOf(String id) => catalog.skinById(id)?.name ?? '未知造型';

    final q = _query.text.trim();
    final children = <Widget>[
      Row(children: [
        Expanded(
            child: KpiTile(label: '記錄天數', value: '${history.days.length}')),
        const SizedBox(width: 12),
        Expanded(
            child: KpiTile(label: '出現過的造型', value: '${appearances.length}')),
        const SizedBox(width: 12),
        Expanded(
            child: KpiTile(label: '夜市期數', value: '${history.nights.length}')),
      ]),
      TextField(
        key: const ValueKey('shop-history-search'),
        controller: _query,
        onChanged: (_) => setState(() {}),
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: '搜尋造型名稱，查上次出現與次數',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    ];

    if (history.isEmpty) {
      children.add(const PanelCard(
          child: EmptyState(
              icon: Icons.history,
              title: '還沒有紀錄',
              message: '從現在開始，每次同步商店都會記下當天的 4 款與夜市（只存在這台裝置）')));
    } else if (q.isNotEmpty) {
      final skins = catalog.catalog?.skins ?? const [];
      final found = searchSkins(skins, q).take(60).toList()
        ..sort((a, b) {
          final x = byId[a.uuid]?.lastSeen, y = byId[b.uuid]?.lastSeen;
          if (x == null && y == null) return 0;
          if (x == null) return 1;
          if (y == null) return -1;
          return y.compareTo(x);
        });
      children.add(PanelCard(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: found.isEmpty
            ? const EmptyState(icon: Icons.search_off, title: '找不到這個造型')
            : Column(children: [
                for (final s in found)
                  _SkinRow(
                      name: s.name,
                      iconUrl: s.iconUrl,
                      appearance: byId[s.uuid],
                      now: now),
              ]),
      ));
    } else {
      children.add(Align(
        alignment: Alignment.centerLeft,
        child: SegmentedButton<_View>(
          segments: const [
            ButtonSegment(value: _View.days, label: Text('每天的商店')),
            ButtonSegment(value: _View.ranking, label: Text('出現次數')),
          ],
          selected: {_view},
          onSelectionChanged: (v) => setState(() => _view = v.first),
        ),
      ));
      if (_view == _View.days) {
        for (final d in history.days.reversed.take(120)) {
          children.add(PanelCard(
            key: ValueKey('shop-history-day-${d.expiresAt}'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                    title: _date(d.startsAt),
                    trailing: Text(daysAgoLabel(d.startsAt, now),
                        style: TextStyle(color: AppColors.muted))),
                for (var i = 0; i < d.skins.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(children: [
                      Expanded(
                          child: Text(nameOf(d.skins[i]),
                              overflow: TextOverflow.ellipsis)),
                      if (i < d.prices.length)
                        Text('${d.prices[i]} VP',
                            style: AppText.tabular(
                                TextStyle(color: AppColors.muted))),
                    ]),
                  ),
              ],
            ),
          ));
        }
      } else {
        final ranked = [...appearances]
          ..sort((a, b) => b.dailyCount.compareTo(a.dailyCount));
        children.add(PanelCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            for (final a in ranked.take(200))
              _SkinRow(
                  name: nameOf(a.skinUuid),
                  iconUrl: catalog.skinById(a.skinUuid)?.iconUrl,
                  appearance: a,
                  now: now),
          ]),
        ));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('商店歷史')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(
            key: const ValueKey('shop-history-list'),
            padding: const EdgeInsets.all(16),
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SkinRow extends StatelessWidget {
  final String name;
  final String? iconUrl;
  final SkinAppearance? appearance;
  final DateTime now;

  const _SkinRow(
      {required this.name,
      required this.iconUrl,
      required this.appearance,
      required this.now});

  @override
  Widget build(BuildContext context) {
    final a = appearance;
    final last = a?.lastSeen;
    final parts = <String>[
      if (a == null || (a.dailyCount == 0 && a.nightCount == 0))
        '紀錄中沒出現過'
      else ...[
        if (last != null)
          '上次 ${_date(last)}（${daysAgoLabel(last, now)}）'
        else
          '沒在每日商店出現過',
        '每日商店 ${a.dailyCount} 次',
        if (a.nightCount > 0) '夜市 ${a.nightCount} 次',
      ],
    ];
    return ListTile(
      dense: true,
      leading: SizedBox(
        width: 56,
        child: iconUrl == null
            ? Icon(Icons.image_not_supported_outlined, color: AppColors.muted)
            : Image.network(iconUrl!,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.muted)),
      ),
      title: Text(name, overflow: TextOverflow.ellipsis),
      subtitle: Text(parts.join(' · '),
          style: TextStyle(color: AppColors.muted, fontSize: 12)),
      trailing: a?.lastPrice == null
          ? null
          : Text('${a!.lastPrice} VP',
              style: AppText.tabular(const TextStyle(fontSize: 13))),
    );
  }
}
