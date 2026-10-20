import 'package:flutter/material.dart';

/// 造型稀有度，對應 valorant-api.com contenttiers 的 devName。
enum Tier {
  select('Select', '精選', Color(0xFF94A3B8)),
  deluxe('Deluxe', '奢華', Color(0xFF06B6D4)),
  premium('Premium', '尊爵', Color(0xFFE879F9)),
  exclusive('Exclusive', '限定', Color(0xFFA78BFA)),
  ultra('Ultra', '究極', Color(0xFFEAB308));

  const Tier(this.devName, this.label, this.color);

  final String devName;
  final String label;
  final Color color;

  static Tier? fromDevName(String? devName) {
    for (final tier in Tier.values) {
      if (tier.devName == devName) return tier;
    }
    return null;
  }
}
