import 'package:flutter/material.dart';

import '../models/bundle_info.dart';
import '../theme/app_theme.dart';
import 'skin_tile.dart';

class BundleTile extends StatelessWidget {
  final BundleInfo? bundle;
  final int? price;
  final VoidCallback? onTap;

  /// 橫幅模式：16:6 大圖，名稱與價格疊在圖片下緣。
  final bool banner;

  const BundleTile({
    super.key,
    required this.bundle,
    this.price,
    this.onTap,
    this.banner = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = bundle?.name ?? '未知組合包';
    if (!banner) {
      return Card(
        child: ListTile(
          onTap: onTap,
          leading: SizedBox(width: 96, child: SkinIcon(url: bundle?.iconUrl)),
          title: Text(name),
          trailing: price == null
              ? null
              : Text('$price',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
    }
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 6,
          child: Stack(
            fit: StackFit.expand,
            children: [
              SkinIcon(url: bundle?.iconUrl, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, AppColors.background],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    if (price != null)
                      Text('$price VP',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
