import 'package:flutter/material.dart';

import 'theme_ids.dart';

/// 導覽型態（規格 2026-10-21-ui-themes-design.md §4.1）。
enum NavLayout {
  topMinimalMenu,
  topTabs,
  topDropdowns,
  sideRail,
  topHamburger,
  evaColumn,

  /// G：MD3 導覽抽屜（膠囊形選中指示）。
  materialDrawer,
}

enum HeaderVariant {
  poster,
  numbered,
  centered,
  terminal,
  dreamy,
  evaAlert,
  evaMonitor,
  evaFusion,
  material,
}

/// [material]：MD3 填色卡片（無邊框、12px 圓角、hover 疊一層狀態色）。
enum CardVariant {
  flat,
  glowTop,
  cornerMarks,
  soft,
  evaTab,
  evaBracket,
  material
}

enum KpiVariant { tiles, terminalLines, evaNumerals, evaBracket }

/// 目前風格的形狀、字級、間距與排列變體；共用元件從這裡讀。
class AppStyle extends ThemeExtension<AppStyle> {
  final ThemeStyleId id;
  final NavLayout nav;
  final HeaderVariant header;
  final CardVariant card;
  final KpiVariant kpi;
  final double cardRadius;
  final double bentoGap;
  final double gridSpacing;

  /// ResponsiveGrid 卡片最小寬度的倍率。
  final double tileWidthFactor;

  /// null 時用 layout.dart 的 contentMaxWidth。
  final double? contentMaxWidth;

  /// BentoGrid 跨欄對齊到 6 或 12（最多雙欄）。
  final bool snapToHalves;
  final double headerTitleSize;
  final FontWeight headerWeight;

  const AppStyle({
    required this.id,
    required this.nav,
    required this.header,
    required this.card,
    required this.kpi,
    required this.cardRadius,
    required this.bentoGap,
    required this.gridSpacing,
    required this.tileWidthFactor,
    this.contentMaxWidth,
    this.snapToHalves = false,
    required this.headerTitleSize,
    required this.headerWeight,
  });

  static AppStyle of(ThemeStyleId id) => _styles[id]!;

  @override
  AppStyle copyWith() => this;

  @override
  AppStyle lerp(AppStyle? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension AppStyleContext on BuildContext {
  AppStyle get appStyle =>
      Theme.of(this).extension<AppStyle>() ??
      AppStyle.of(ThemeStyleId.editorial);
}

const _styles = <ThemeStyleId, AppStyle>{
  ThemeStyleId.editorial: AppStyle(
    id: ThemeStyleId.editorial,
    nav: NavLayout.topMinimalMenu,
    header: HeaderVariant.poster,
    card: CardVariant.flat,
    kpi: KpiVariant.tiles,
    cardRadius: 0,
    bentoGap: 24,
    gridSpacing: 16,
    tileWidthFactor: 1,
    headerTitleSize: 40,
    headerWeight: FontWeight.w800,
  ),
  ThemeStyleId.neon: AppStyle(
    id: ThemeStyleId.neon,
    nav: NavLayout.topTabs,
    header: HeaderVariant.numbered,
    card: CardVariant.glowTop,
    kpi: KpiVariant.tiles,
    cardRadius: 10,
    bentoGap: 16,
    gridSpacing: 16,
    tileWidthFactor: 1,
    headerTitleSize: 28,
    headerWeight: FontWeight.w600,
  ),
  ThemeStyleId.airy: AppStyle(
    id: ThemeStyleId.airy,
    nav: NavLayout.topDropdowns,
    header: HeaderVariant.centered,
    card: CardVariant.flat,
    kpi: KpiVariant.tiles,
    cardRadius: 0,
    bentoGap: 24,
    gridSpacing: 16,
    tileWidthFactor: 1,
    contentMaxWidth: 1080,
    headerTitleSize: 26,
    headerWeight: FontWeight.w500,
  ),
  ThemeStyleId.terminal: AppStyle(
    id: ThemeStyleId.terminal,
    nav: NavLayout.sideRail,
    header: HeaderVariant.terminal,
    card: CardVariant.cornerMarks,
    kpi: KpiVariant.terminalLines,
    cardRadius: 0,
    bentoGap: 8,
    gridSpacing: 8,
    tileWidthFactor: 0.85,
    headerTitleSize: 24,
    headerWeight: FontWeight.w500,
  ),
  ThemeStyleId.dreamy: AppStyle(
    id: ThemeStyleId.dreamy,
    nav: NavLayout.topHamburger,
    header: HeaderVariant.dreamy,
    card: CardVariant.soft,
    kpi: KpiVariant.tiles,
    cardRadius: 4,
    bentoGap: 20,
    gridSpacing: 16,
    tileWidthFactor: 1.15,
    snapToHalves: true,
    headerTitleSize: 28,
    headerWeight: FontWeight.w600,
  ),
  ThemeStyleId.evaAlert: AppStyle(
    id: ThemeStyleId.evaAlert,
    nav: NavLayout.evaColumn,
    header: HeaderVariant.evaAlert,
    card: CardVariant.evaTab,
    kpi: KpiVariant.evaNumerals,
    cardRadius: 0,
    bentoGap: 8,
    gridSpacing: 8,
    tileWidthFactor: 0.85,
    headerTitleSize: 38,
    headerWeight: FontWeight.w900,
  ),
  ThemeStyleId.evaMonitor: AppStyle(
    id: ThemeStyleId.evaMonitor,
    nav: NavLayout.evaColumn,
    header: HeaderVariant.evaMonitor,
    card: CardVariant.evaBracket,
    kpi: KpiVariant.evaBracket,
    cardRadius: 0,
    bentoGap: 8,
    gridSpacing: 8,
    tileWidthFactor: 1,
    headerTitleSize: 24,
    headerWeight: FontWeight.w700,
  ),
  ThemeStyleId.evaFusion: AppStyle(
    id: ThemeStyleId.evaFusion,
    nav: NavLayout.evaColumn,
    header: HeaderVariant.evaFusion,
    card: CardVariant.evaBracket,
    kpi: KpiVariant.evaNumerals,
    cardRadius: 0,
    bentoGap: 8,
    gridSpacing: 8,
    tileWidthFactor: 1,
    headerTitleSize: 38,
    headerWeight: FontWeight.w900,
  ),
  ThemeStyleId.material: AppStyle(
    id: ThemeStyleId.material,
    nav: NavLayout.materialDrawer,
    header: HeaderVariant.material,
    card: CardVariant.material,
    kpi: KpiVariant.tiles,
    cardRadius: 12,
    bentoGap: 16,
    gridSpacing: 16,
    tileWidthFactor: 1,
    headerTitleSize: 32,
    headerWeight: FontWeight.w400,
  ),
};
