import 'package:flutter/material.dart';

import '../models/tier.dart';

class TierBadge extends StatelessWidget {
  final Tier tier;

  const TierBadge({super.key, required this.tier});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tier.color.withOpacity(0.15),
        border: Border.all(color: tier.color),
        borderRadius: BorderRadius.circular(4),
      ),
      child:
          Text(tier.label, style: TextStyle(color: tier.color, fontSize: 12)),
    );
  }
}
