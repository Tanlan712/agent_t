import 'package:flutter/material.dart';

import '../models/bundle_info.dart';
import 'skin_tile.dart';

class BundleTile extends StatelessWidget {
  final BundleInfo? bundle;
  final int? price;
  final VoidCallback? onTap;

  const BundleTile({super.key, required this.bundle, this.price, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: SizedBox(width: 96, child: SkinIcon(url: bundle?.iconUrl)),
        title: Text(bundle?.name ?? '未知組合包'),
        trailing: price == null
            ? null
            : Text('$price',
                style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
