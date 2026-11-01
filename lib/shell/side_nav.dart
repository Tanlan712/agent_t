import 'package:flutter/material.dart';

import '../theme/app_palette.dart';
import '../theme/app_style.dart';
import '../theme/app_theme.dart';
import '../widgets/hud/hud_card.dart' show glassDecoration;
import 'nav_items.dart';

/// 分組側欄：展開時 248 寬（圖示＋名稱＋分組標題），收合時 72 寬（只有圖示＋提示）。
/// 項目過多或視窗太矮時可捲動；[footer]（Riot 狀態）固定在底部。
/// [items] 預設是 [navItems]；外殼會傳入依使用者自訂順序排好的清單（設定頁「選單順序」）。
class SideNav extends StatelessWidget {
  final String currentRoute;
  final bool extended;
  final ValueChanged<NavItem> onSelect;
  final String brand;
  final Widget? footer;
  final List<NavItem> items;

  const SideNav({
    super.key,
    required this.currentRoute,
    required this.extended,
    required this.onSelect,
    this.brand = '',
    this.footer,
    this.items = navItems,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    NavGroup? group;
    for (final item in items) {
      if (item.group != group) {
        if (group != null && !extended) {
          children.add(const Divider(height: 17, indent: 16, endIndent: 16));
        }
        group = item.group;
        if (extended) {
          children.add(Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
            child: Text(navGroupLabels[group]!,
                style: TextStyle(
                    fontSize: 11, color: AppColors.muted, letterSpacing: 0.6)),
          ));
        }
      }
      children.add(_NavTile(
        key: ValueKey('nav-${item.route}'),
        item: item,
        selected: item.route == canonicalRoute(currentRoute),
        extended: extended,
        onTap: () => onSelect(item),
      ));
    }
    final glass = context.appStyle.nav == NavLayout.glassSidebar;
    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(extended ? 20 : 0, 20, 12, 4),
          child: extended
              ? Text(brand,
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold))
              : Icon(Icons.local_fire_department, color: AppColors.primary),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 4),
            children: children,
          ),
        ),
        // 透明 Material：footer（ListTile）的焦點與水波畫在側欄底色之上。
        if (footer != null)
          Material(type: MaterialType.transparency, child: footer!),
      ],
    );
    if (glass) {
      // H：浮起來的玻璃面板，四周留 12px 讓背景光暈透出來。
      return SizedBox(
        width: extended ? 248 : 80,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          child: DecoratedBox(
            key: const ValueKey('glass-side-nav'),
            decoration: glassDecoration(
                context.palette, const BorderRadius.all(Radius.circular(26))),
            child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(26)),
                child: column),
          ),
        ),
      );
    }
    return Container(
      width: extended ? 248 : 72,
      color: AppColors.surface,
      child: column,
    );
  }
}

class _NavTile extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool extended;
  final VoidCallback onTap;

  const _NavTile({
    super.key,
    required this.item,
    required this.selected,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (context.appStyle.nav == NavLayout.materialDrawer) {
      return _materialTile(context);
    }
    if (context.appStyle.nav == NavLayout.glassSidebar) {
      return _glassTile(context);
    }
    final color = selected ? AppColors.text : AppColors.muted;
    final still = MediaQuery.disableAnimationsOf(context);
    Widget tile = Material(
      color: selected ? AppColors.surfaceHigh : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.surfaceHigh.withOpacity(0.5),
        hoverDuration: still ? Duration.zero : null,
        splashFactory: still ? NoSplash.splashFactory : null,
        child: SizedBox(
          height: 40,
          child: Row(
            mainAxisAlignment:
                extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (selected)
                Container(
                    key: const ValueKey('nav-indicator'),
                    width: 3,
                    height: 20,
                    color: AppColors.primary)
              else
                const SizedBox(width: 3),
              SizedBox(width: extended ? 12 : 8),
              Icon(item.icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.muted),
              if (extended) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          color: color,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w400)),
                ),
              ] else
                const SizedBox(width: 11),
            ],
          ),
        ),
      ),
    );
    if (!extended) tile = Tooltip(message: item.label, child: tile);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Semantics(button: true, selected: selected, child: tile),
    );
  }

  /// G Material 3：導覽抽屜的膠囊項目（56 高、選中填 secondaryContainer）。
  Widget _materialTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final still = MediaQuery.disableAnimationsOf(context);
    final fg = selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;
    Widget tile = Material(
      key: selected ? const ValueKey('nav-indicator') : null,
      color: selected ? scheme.secondaryContainer : Colors.transparent,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        hoverDuration: still ? Duration.zero : null,
        splashFactory: still ? NoSplash.splashFactory : null,
        child: SizedBox(
          height: extended ? 56 : 40,
          child: Row(
            mainAxisAlignment:
                extended ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              if (extended) const SizedBox(width: 16),
              Icon(item.icon, size: 24, color: fg),
              if (extended) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          color: fg,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (!extended) tile = Tooltip(message: item.label, child: tile);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Semantics(button: true, selected: selected, child: tile),
    );
  }

  /// H 玻璃黏土：選中項目是主色漸層膠囊＋白字，帶一點同色投影。
  Widget _glassTile(BuildContext context) {
    final p = context.palette;
    final still = MediaQuery.disableAnimationsOf(context);
    final gradient = p.accentGradient ?? [p.buttonFill, p.buttonFill];
    final fg = selected ? p.onButton : p.muted;
    const radius = BorderRadius.all(Radius.circular(16));
    Widget tile = DecoratedBox(
      key: selected ? const ValueKey('nav-indicator') : null,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: selected ? LinearGradient(colors: gradient) : null,
        boxShadow: selected
            ? [
                BoxShadow(
                    color: gradient.first.withOpacity(0.35),
                    blurRadius: 16,
                    spreadRadius: -6,
                    offset: const Offset(0, 8)),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          hoverColor: p.primary.withOpacity(0.08),
          hoverDuration: still ? Duration.zero : null,
          splashFactory: still ? NoSplash.splashFactory : null,
          child: SizedBox(
            height: 44,
            child: Row(
              mainAxisAlignment:
                  extended ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                if (extended) const SizedBox(width: 14),
                Icon(item.icon, size: 20, color: fg),
                if (extended) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(item.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 14,
                            color: selected ? p.onButton : p.text,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    if (!extended) tile = Tooltip(message: item.label, child: tile);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Semantics(button: true, selected: selected, child: tile),
    );
  }
}
