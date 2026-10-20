import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'hud_card.dart';

/// KPI 摘要卡：標籤、大數字、變化（勝負色加箭頭）。
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;

  /// true 上升（win）、false 下降（loss）、null 中性（muted）。
  final bool? up;
  final Widget? leading;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.up,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (up) {
      true => AppColors.win,
      false => AppColors.loss,
      null => AppColors.muted,
    };
    return HudCard(
      notched: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 8)],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: AppText.label),
                const SizedBox(height: 2),
                Text(value,
                    style: AppText.kpi(context),
                    overflow: TextOverflow.ellipsis),
                if (delta != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (up != null)
                        Icon(up! ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14, color: color),
                      Flexible(
                        child: Text(delta!,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.tabular(
                                TextStyle(color: color, fontSize: 12))),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 頁首 KPI 列：每個 tile 至少 [minTileWidth]，放得下就同一列平分。
class KpiStrip extends StatelessWidget {
  final List<KpiTile> tiles;

  static const minTileWidth = 160.0;

  const KpiStrip({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(builder: (context, c) {
      final fit = ((c.maxWidth + gap) / (minTileWidth + gap)).floor();
      final perRow = fit.clamp(1, tiles.isEmpty ? 1 : tiles.length);
      final width = (c.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final t in tiles) SizedBox(width: width, child: t),
        ],
      );
    });
  }
}
