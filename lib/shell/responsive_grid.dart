import 'dart:math';

import 'package:flutter/material.dart';

const double gridSpacing = 16;

/// 可用寬度能放下幾欄（每欄至少 [minTileWidth]），最少 1 欄。
int columnsFor(double width, double minTileWidth) =>
    max(1, ((width + gridSpacing) / (minTileWidth + gridSpacing)).floor());

/// 依可用寬度自動決定欄數的網格；不自己捲動，可放在外層捲動容器裡。
class ResponsiveGrid extends StatelessWidget {
  final double minTileWidth;
  final double childAspectRatio;
  final List<Widget> children;

  const ResponsiveGrid({
    super.key,
    required this.minTileWidth,
    required this.childAspectRatio,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        crossAxisCount: columnsFor(constraints.maxWidth, minTileWidth),
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: gridSpacing,
        crossAxisSpacing: gridSpacing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}
