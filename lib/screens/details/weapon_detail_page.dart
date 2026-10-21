import 'package:flutter/material.dart';

import '../../logic/database_logic.dart';
import '../../models/game_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/hud/hud.dart';
import '../../widgets/skin_tile.dart' show SkinIcon;
import 'detail_scaffold.dart';

/// 武器詳細頁：valorant-api.com 提供的全部數據。
class WeaponDetailPage extends StatelessWidget {
  final WeaponInfo weapon;
  final String categoryLabel;

  const WeaponDetailPage(
      {super.key, required this.weapon, required this.categoryLabel});

  @override
  Widget build(BuildContext context) {
    final s = weapon.stats;
    return DetailScaffold(title: weapon.name, children: [
      PanelCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              height: 140, child: Center(child: SkinIcon(url: weapon.icon))),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: Text(weapon.name,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            Text(weapon.cost > 0 ? '\$${weapon.cost}' : '免費',
                style: AppText.tabular(TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold))),
          ]),
          Text(categoryLabel, style: TextStyle(color: AppColors.muted)),
        ]),
      ),
      if (s == null)
        const PanelCard(
          padding: EdgeInsets.all(24),
          child: EmptyState(
              icon: Icons.info_outline,
              title: '無射擊數據',
              message: '近戰武器沒有射速、彈匣與傷害資料'),
        )
      else ...[
        _StatsCard(title: '基本數據', tiles: [
          StatTile(label: '射速（發／秒）', value: formatNumber(s.fireRate)),
          StatTile(label: '彈匣容量', value: formatNumber(s.magazineSize)),
          StatTile(label: '換彈時間（秒）', value: formatNumber(s.reloadTimeSeconds)),
          StatTile(label: '裝備時間（秒）', value: formatNumber(s.equipTimeSeconds)),
          StatTile(label: '移動速度倍率', value: formatNumber(s.runSpeedMultiplier)),
          StatTile(
              label: '首發精準度（度）', value: formatNumber(s.firstBulletAccuracy)),
          StatTile(label: '射擊模式', value: fireModeLabel(s.fireMode)),
          StatTile(label: '穿牆', value: wallPenetrationLabel(s.wallPenetration)),
          StatTile(label: '特性', value: featureLabel(s.feature)),
          StatTile(label: '右鍵', value: altFireLabel(s.altFireType)),
          if ((s.shotgunPelletCount ?? 1) > 1)
            StatTile(label: '彈丸數', value: formatNumber(s.shotgunPelletCount)),
        ]),
        if (s.ads case final ads?)
          _StatsCard(title: '開鏡數據', tiles: [
            StatTile(label: '縮放倍率', value: formatNumber(ads.zoomMultiplier)),
            StatTile(label: '開鏡射速（發／秒）', value: formatNumber(ads.fireRate)),
            StatTile(
                label: '開鏡移動速度倍率', value: formatNumber(ads.runSpeedMultiplier)),
            StatTile(label: '連發數', value: formatNumber(ads.burstCount)),
            StatTile(
                label: '開鏡首發精準度（度）',
                value: formatNumber(ads.firstBulletAccuracy)),
          ]),
        PanelCard(
          key: const ValueKey('damage-table'),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SectionHeader(title: '傷害（依距離）'),
            if (s.damageRanges.isEmpty)
              Text('沒有傷害資料', style: TextStyle(color: AppColors.muted))
            else
              _DamageTable(ranges: s.damageRanges),
          ]),
        ),
      ],
    ]);
  }
}

class _StatsCard extends StatelessWidget {
  final String title;
  final List<Widget> tiles;

  const _StatsCard({required this.title, required this.tiles});

  @override
  Widget build(BuildContext context) => PanelCard(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SectionHeader(title: title),
          Wrap(spacing: 16, runSpacing: 16, children: tiles),
        ]),
      );
}

class _DamageTable extends StatelessWidget {
  final List<DamageRange> ranges;

  const _DamageTable({required this.ranges});

  @override
  Widget build(BuildContext context) {
    final head = TextStyle(color: AppColors.muted, fontSize: 12);
    final cell = AppText.tabular(const TextStyle(fontSize: 14));
    Widget pad(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: w);
    return Table(
      columnWidths: const {0: FlexColumnWidth(1.4)},
      children: [
        TableRow(children: [
          for (final t in ['距離（公尺）', '頭部', '身體', '腿部'])
            pad(Text(t, style: head)),
        ]),
        for (final r in ranges)
          TableRow(
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.outline))),
            children: [
              pad(Text(
                  '${formatNumber(r.rangeStartMeters)}–${formatNumber(r.rangeEndMeters)}',
                  style: cell)),
              pad(Text(formatNumber(r.headDamage), style: cell)),
              pad(Text(formatNumber(r.bodyDamage), style: cell)),
              pad(Text(formatNumber(r.legDamage), style: cell)),
            ],
          ),
      ],
    );
  }
}
