import 'package:flutter/material.dart';

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
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(label,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (tooltip != null) chip = Tooltip(message: tooltip!, child: chip);
    return chip;
  }
}
