import 'package:flutter/material.dart';

import '../../theme/app_style.dart';

/// Bento 欄數：可用寬度 ≥ 1024 為 12 欄、≥ 600 為 6 欄，否則 1 欄。
int bentoColumns(double width) => width >= 1024
    ? 12
    : width >= 600
        ? 6
        : 1;

/// 以 12 欄為準的 [span12] 換算成 [columns] 欄時佔幾欄（至少 1、最多 columns）。
/// 6 欄時若有 [medium] 就直接用它。
int bentoSpan(int span12, int columns, {int? medium}) {
  final s = switch (columns) {
    12 => span12,
    6 => medium ?? (span12 / 2).ceil(),
    _ => columns,
  };
  return s.clamp(1, columns);
}

class BentoTile {
  final int span;

  /// 6 欄時佔幾欄；null 時用 span 的一半（無條件進位）。
  final int? medium;
  final Widget child;

  const BentoTile({required this.span, this.medium, required this.child});
}

/// 12 欄 Bento 格：由左到右排，放不下就換列；列內頂端對齊。
class BentoGrid extends StatelessWidget {
  final List<BentoTile> children;

  /// null 時用目前風格的 [AppStyle.bentoGap]。
  final double? gap;

  const BentoGrid({super.key, required this.children, this.gap});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final style = context.appStyle;
        final gap = this.gap ?? style.bentoGap;
        final cols = bentoColumns(c.maxWidth);
        // E 夢幻漸層：最多雙欄（span 對齊到 6 或 12）。
        int span(BentoTile t) {
          if (!style.snapToHalves) {
            return bentoSpan(t.span, cols, medium: t.medium);
          }
          return bentoSpan(t.span <= 6 ? 6 : 12, cols,
              medium: t.span <= 6 ? 3 : 6);
        }

        final colW = (c.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in children)
              SizedBox(
                // 取整，避免浮點誤差讓同一列放不下而換列。
                width: (span(t) * colW + (span(t) - 1) * gap).floorToDouble(),
                child: t.child,
              ),
          ],
        );
      });
}
