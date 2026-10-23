import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/current_shop.dart';
import '../models/match_models.dart' show RefItem;
import '../models/progress_reference.dart';
import '../providers/progress_provider.dart';
import '../services/riot_client.dart' show ItemTypes;
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';
import 'skin_tile.dart' show SkinIcon;

/// 配件的類別名稱。
String accessoryKind(String itemTypeId) => switch (itemTypeId) {
      ItemTypes.buddyLevel => '吊飾',
      ItemTypes.spray => '噴漆',
      ItemTypes.playerCard => '玩家卡片',
      ItemTypes.title => '稱號',
      _ => '配件',
    };

/// 從 valorant-api 的參考資料找配件的名稱與圖示；找不到時為 null。
RefItem? accessoryRef(AccessoryEntry e, ProgressReference? ref) {
  if (ref == null) return null;
  final map = switch (e.itemTypeId) {
    ItemTypes.buddyLevel => ref.buddyLevels,
    ItemTypes.spray => ref.sprays,
    ItemTypes.playerCard => ref.cards,
    ItemTypes.title => ref.titles,
    _ => const <String, RefItem>{},
  };
  return map[e.itemId];
}

String _remaining(Duration d) {
  if (d.isNegative) return '已過期，請更新';
  if (d.inDays > 0) return '剩餘 ${d.inDays} 天 ${d.inHours % 24} 小時';
  return '剩餘 ${d.inHours} 小時 ${d.inMinutes % 60} 分';
}

/// 我的商店的「配件商店」：吊飾、噴漆、卡片、稱號，用王國幣購買（只顯示，不購買）。
class AccessoryStoreSection extends StatefulWidget {
  final CurrentShop shop;
  final DateTime now;

  const AccessoryStoreSection(
      {super.key, required this.shop, required this.now});

  @override
  State<AccessoryStoreSection> createState() => _AccessoryStoreSectionState();
}

class _AccessoryStoreSectionState extends State<AccessoryStoreSection> {
  @override
  void initState() {
    super.initState();
    // 名稱與圖示來自公開資料（valorant-api），不送 Riot 請求。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ProgressProvider?>()?.ensureReference();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ref = context.watch<ProgressProvider?>()?.ref;
    final shop = widget.shop;
    final end = shop.accessoryEndsAt;
    return PanelCard(
      key: const ValueKey('shop-accessories'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text('配件商店',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                end == null ? '' : _remaining(end.difference(widget.now)),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          ]),
          const SizedBox(height: 4),
          Text('用王國幣（獎章）購買', style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: 12),
          ResponsiveGrid(
            minTileWidth: 200,
            mainAxisExtent: 76,
            childAspectRatio: 3,
            children: [
              for (final e in shop.accessories) _tile(e, accessoryRef(e, ref)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(AccessoryEntry e, RefItem? item) => Container(
        key: ValueKey('accessory-${e.itemId}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(children: [
          SizedBox(
            width: 52,
            height: 52,
            child: e.itemTypeId == ItemTypes.title
                ? Icon(Icons.text_fields, color: AppColors.muted)
                : SkinIcon(url: item?.iconUrl),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item?.name ?? '讀取名稱中…',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${accessoryKind(e.itemTypeId)} · ${e.price} 王國幣',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
        ]),
      );
}
