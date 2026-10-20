import 'package:flutter/material.dart';

import '../models/skin_info.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';
import 'skin_tile.dart' show SkinIcon;
import 'tier_badge.dart';

/// 直式造型卡片（網格用）：大圖在上，名稱、武器、稀有度、價格在下。
/// [skin] 為 null 時顯示「未知造型」。
class SkinCard extends StatelessWidget {
  final SkinInfo? skin;
  final int? price;
  final int? originalPrice;
  final bool highlighted;
  final bool owned;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SkinCard({
    super.key,
    required this.skin,
    this.price,
    this.originalPrice,
    this.highlighted = false,
    this.owned = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final skin = this.skin;
    final textTheme = Theme.of(context).textTheme;
    // 戰術 HUD：右上角切角，底部稀有度色條。
    return ClipPath(
      clipper: const NotchClipper(),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          side: highlighted
              ? const BorderSide(color: AppColors.wishlistGold, width: 3)
              : const BorderSide(color: AppColors.outline),
        ),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: skin?.tier.color ?? AppColors.outline, width: 3)),
            gradient: skin == null
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      skin.tier.color.withOpacity(0.10),
                      AppColors.surface,
                    ],
                  ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Center(child: SkinIcon(url: skin?.iconUrl)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        skin?.name ?? '未知造型',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (skin != null)
                            Text(skin.weaponName,
                                style: textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted)),
                          if (skin != null) TierBadge(tier: skin.tier),
                          if (owned)
                            const Text('已擁有',
                                style: TextStyle(
                                    color: AppColors.owned,
                                    fontWeight: FontWeight.bold)),
                          if (highlighted)
                            const Text('★ 願望清單',
                                style: TextStyle(
                                    color: AppColors.wishlistGold,
                                    fontWeight: FontWeight.bold)),
                        ],
                      ),
                      if (price != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (originalPrice != null) ...[
                              Text('$originalPrice',
                                  style: textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                      decoration: TextDecoration.lineThrough)),
                              const SizedBox(width: 6),
                            ],
                            Text('$price',
                                style: textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 4),
                            Text('VP',
                                style: textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  Positioned(top: 4, right: 12, child: trailing!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
