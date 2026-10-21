import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// 造型稀有度，對應 valorant-api.com contenttiers 的 devName。
enum Tier {
  select('Select', '精選'),
  deluxe('Deluxe', '奢華'),
  premium('Premium', '尊爵'),
  exclusive('Exclusive', '限定'),
  ultra('Ultra', '究極');

  const Tier(this.devName, this.label);

  final String devName;
  final String label;

  /// 依目前明暗取色（色表在 app_palette.dart）。
  Color get color => AppPalette.current.tier[index];

  static Tier? fromDevName(String? devName) {
    for (final tier in Tier.values) {
      if (tier.devName == devName) return tier;
    }
    return null;
  }
}
