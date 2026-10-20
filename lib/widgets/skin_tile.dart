import 'package:flutter/material.dart';

import '../models/skin_info.dart';
import '../theme/app_theme.dart';
import 'tier_badge.dart';

const wishlistGold = AppColors.wishlistGold;

/// 造型卡片；[skin] 為 null 時顯示「未知造型」佔位。
class SkinTile extends StatelessWidget {
  final SkinInfo? skin;
  final int? price;
  final int? originalPrice;
  final bool highlighted;
  final bool owned;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SkinTile({
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
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: highlighted
            ? const BorderSide(color: wishlistGold, width: 3)
            : BorderSide.none,
      ),
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(width: 72, child: SkinIcon(url: skin?.iconUrl)),
        title: Text(skin?.name ?? '未知造型'),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (skin != null) Text(skin.weaponName),
            if (skin != null) TierBadge(tier: skin.tier),
            if (owned)
              const Text('已擁有',
                  style: TextStyle(
                      color: AppColors.owned, fontWeight: FontWeight.bold)),
            if (highlighted)
              const Text('★ 願望清單',
                  style: TextStyle(
                      color: wishlistGold, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: trailing ??
            (price == null ? null : _PriceLabel(price!, originalPrice)),
      ),
    );
  }
}

class _PriceLabel extends StatelessWidget {
  final int price;
  final int? originalPrice;

  const _PriceLabel(this.price, this.originalPrice);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (originalPrice != null)
          Text('$originalPrice',
              style: const TextStyle(
                  decoration: TextDecoration.lineThrough, fontSize: 12)),
        Text('$price', style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

/// 網路圖片，失敗或沒有網址時顯示佔位圖示。
class SkinIcon extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  const SkinIcon({super.key, required this.url, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    const placeholder = Icon(Icons.image_not_supported);
    final url = this.url;
    if (url == null) return placeholder;
    return Image.network(url,
        fit: fit, errorBuilder: (_, __, ___) => placeholder);
  }
}
