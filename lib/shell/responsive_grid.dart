import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/app_style.dart';

const double gridSpacing = 16;

/// 可用寬度能放下幾欄（每欄至少 [minTileWidth]），最少 1 欄。
int columnsFor(double width, double minTileWidth,
        {double spacing = gridSpacing}) =>
    max(1, ((width + spacing) / (minTileWidth + spacing)).floor());

/// 大量資料用的網格：本身可捲動、延遲建構（只建可見的卡片）。
class ResponsiveGridView extends StatelessWidget {
  final double minTileWidth;
  final double childAspectRatio;

  /// 固定每格高度（設定時忽略 [childAspectRatio]）。
  final double? mainAxisExtent;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry padding;

  const ResponsiveGridView.builder({
    super.key,
    required this.minTileWidth,
    required this.childAspectRatio,
    this.mainAxisExtent,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
  });

  @override
  Widget build(BuildContext context) {
    final style = context.appStyle;
    final spacing = style.gridSpacing;
    return LayoutBuilder(
      builder: (context, constraints) => GridView.builder(
        padding: padding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columnsFor(
              constraints.maxWidth, minTileWidth * style.tileWidthFactor,
              spacing: spacing),
          childAspectRatio: childAspectRatio,
          mainAxisExtent: mainAxisExtent,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
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
    final style = context.appStyle;
    final spacing = style.gridSpacing;
    return LayoutBuilder(
      builder: (context, constraints) => GridView.count(
        crossAxisCount: columnsFor(
            constraints.maxWidth, minTileWidth * style.tileWidthFactor,
            spacing: spacing),
        childAspectRatio: childAspectRatio,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: children,
      ),
    );
  }
}
