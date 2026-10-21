import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';

/// 狀態標籤：邊框與文字同色、15% 底色、不換行。
class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final String? tooltip;

  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    // 文字往主要文字色混 30%：疊在 15% 底色上，所有主題的對比都 ≥ 4.5。
    final fg = Color.lerp(color, context.palette.text, 0.3)!;
    Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(label,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                    color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (tooltip != null) chip = Tooltip(message: tooltip!, child: chip);
    return chip;
  }
}
