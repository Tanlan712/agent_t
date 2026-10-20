import 'dart:math';

import 'package:flutter/material.dart';

const double gridSpacing = 16;

/// 可用寬度能放下幾欄（每欄至少 [minTileWidth]），最少 1 欄。
int columnsFor(double width, double minTileWidth) =>
    max(1, ((width + gridSpacing) / (minTileWidth + gridSpacing)).floor());

/// 大量資料用的網格：本身可捲動、延遲建構（只建可見的卡片）。
class ResponsiveGridView extends StatelessWidget {
  final double minTileWidth;
  final double childAspectRatio;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  const ResponsiveGridView.builder({
    super.key,
    required this.minTileWidth,
    required this.childAspectRatio,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnsFor(constraints.maxWidth, minTileWidth),
          childAspectRatio: childAspectRatio,
          mainAxisSpacing: gridSpacing,
          crossAxisSpacing: gridSpacing,
        ),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }
}

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
