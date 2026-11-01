import 'package:flutter/material.dart';

import '../../theme/app_palette.dart';
import '../../theme/app_style.dart';
import '../nav_items.dart';
import '../../widgets/theme/theme_reveal.dart';
import 'fullscreen_menu.dart';

/// 頂部導覽列（A 編輯海報、B 數位霓虹、C 優雅留白、E 夢幻漸層）。
/// [compact]（600–1023 寬）時只顯示圖示＋提示。
/// [items] 預設是 [navItems]；自訂順序合併後可傳入排序後的清單。
class TopNav extends StatelessWidget {
  final String currentRoute;
  final bool compact;
  final ValueChanged<NavItem> onSelect;
  final NavLayout layout;
  final String brand;
  final List<NavItem> items;
  final Widget? trailing;

  const TopNav({
    super.key,
    required this.currentRoute,
    required this.compact,
    required this.onSelect,
    required this.layout,
    this.brand = '',
    this.items = navItems,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (layout == NavLayout.topPills) {
      return PillTopNav(
        currentRoute: currentRoute,
        compact: compact,
        onSelect: onSelect,
        brand: brand,
        items: items,
        trailing: trailing,
      );
    }
    final p = context.palette;
    final selected = canonicalRoute(currentRoute);
    final main = items.where((n) => n.group == NavGroup.shop).toList();
    final others = items.where((n) => n.group != NavGroup.shop).toList();

    Widget link(NavItem item, {bool underline = false}) => _TopLink(
          key: ValueKey('nav-${item.route}'),
          item: item,
          selected: item.route == selected,
          compact: compact,
          underline: underline,
          onTap: () => onSelect(item),
        );

    Widget groupMenu(NavGroup group, List<NavItem> list, {String? label}) =>
        PopupMenuButton<NavItem>(
          key: ValueKey('nav-group-${group.name}'),
          tooltip: label ?? navGroupLabels[group]!,
          onSelected: onSelect,
          itemBuilder: (_) => [
            for (final n in list)
              PopupMenuItem(
                value: n,
                child: Row(children: [
                  Icon(n.icon,
                      size: 18,
                      color: n.route == selected ? p.primary : p.muted),
                  const SizedBox(width: 10),
                  Text(n.label),
                ]),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (compact)
                Icon(Icons.more_horiz, color: p.muted)
              else
                Text(label ?? navGroupLabels[group]!,
                    style: TextStyle(
                        color: list.any((n) => n.route == selected)
                            ? p.text
                            : p.muted)),
              Icon(Icons.expand_more, size: 18, color: p.muted),
            ]),
          ),
        );

    final links = <Widget>[];
    switch (layout) {
      case NavLayout.topTabs:
        links.addAll([
          for (final n in main) link(n, underline: true),
          groupMenu(NavGroup.database, others, label: '更多'),
        ]);
      case NavLayout.topDropdowns:
        for (final g in NavGroup.values) {
          links.add(groupMenu(g, items.where((n) => n.group == g).toList()));
        }
      case NavLayout.topHamburger:
        for (var i = 0; i < main.length; i++) {
          if (i > 0 && !compact) {
            links.add(Text('—', style: TextStyle(color: p.outline)));
          }
          links.add(link(main[i]));
        }
      default:
        links.addAll([for (final n in main) link(n)]);
    }

    final linkRow = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(mainAxisSize: MainAxisSize.min, children: links),
    );

    return Material(
      color: p.surface,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration:
            BoxDecoration(border: Border(bottom: BorderSide(color: p.outline))),
        child: Row(
          children: [
            if (layout == NavLayout.topHamburger)
              IconButton(
                key: const ValueKey('nav-hamburger'),
                tooltip: '選單',
                icon: Icon(Icons.menu, color: p.text),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(brand,
                    style: TextStyle(
                        color: p.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing:
                            layout == NavLayout.topDropdowns ? 2 : 0)),
              ),
            Expanded(
              child: layout == NavLayout.topTabs
                  ? Center(child: linkRow)
                  : Align(alignment: Alignment.centerLeft, child: linkRow),
            ),
            if (layout == NavLayout.topDropdowns && !compact)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                decoration: BoxDecoration(
                    border: Border.all(color: p.text),
                    borderRadius: BorderRadius.circular(999)),
                child:
                    Text('TW', style: TextStyle(fontSize: 12, color: p.text)),
              ),
            if (trailing != null) trailing!,
            if (layout == NavLayout.topMinimalMenu)
              IconButton(
                key: const ValueKey('nav-menu-button'),
                tooltip: '所有頁面',
                icon: Text('///',
                    style: TextStyle(
                        color: p.text,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w800)),
                onPressed: () => showFullscreenMenu(context,
                    currentRoute: currentRoute,
                    onSelect: onSelect,
                    items: items),
              ),
          ],
        ),
      ),
    );
  }
}

class _TopLink extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool compact;
  final bool underline;
  final VoidCallback onTap;

  const _TopLink({
    super.key,
    required this.item,
    required this.selected,
    required this.compact,
    required this.underline,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.text : p.muted;
    final still = MediaQuery.disableAnimationsOf(context);
    Widget body = compact
        ? Icon(item.icon, size: 20, color: selected ? p.primary : p.muted)
        : Text(item.label,
            style: TextStyle(
                fontSize: 14,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400));
    body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        body,
        if (selected && underline)
          Container(
              key: const ValueKey('nav-underline'),
              margin: const EdgeInsets.only(top: 4),
              width: compact ? 20 : 24,
              height: 2,
              color: p.primary)
        else if (underline)
          const SizedBox(height: 6),
      ],
    );
    Widget tile = InkWell(
      onTap: onTap,
      hoverDuration: still ? Duration.zero : null,
      splashFactory: still ? NoSplash.splashFactory : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Center(child: body),
        ),
      ),
    );
    if (compact) tile = Tooltip(message: item.label, child: tile);
    return Semantics(button: true, selected: selected, child: tile);
  }
}

/// I 極簡儀表板的頂部導覽：左邊墨色品牌方塊，中間一整條膠囊放主要頁面
/// （選中的是墨色實心膠囊），其餘頁面收進「更多」；右邊是深淺色切換與 Riot 狀態。
/// 沒有底色與分隔線，直接浮在淺灰底上。
class PillTopNav extends StatelessWidget {
  final String currentRoute;
  final bool compact;
  final ValueChanged<NavItem> onSelect;
  final String brand;
  final List<NavItem> items;
  final Widget? trailing;

  const PillTopNav({
    super.key,
    required this.currentRoute,
    required this.compact,
    required this.onSelect,
    required this.brand,
    required this.items,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final selected = canonicalRoute(currentRoute);
    final main = items.where((n) => n.group == NavGroup.shop).toList();
    final others = items.where((n) => n.group != NavGroup.shop).toList();
    final otherSelected = others.any((n) => n.route == selected);
    final still = MediaQuery.disableAnimationsOf(context);

    final more = PopupMenuButton<NavItem>(
      key: const ValueKey('nav-group-more'),
      tooltip: '更多頁面',
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final n in others)
          PopupMenuItem(
            value: n,
            child: Row(children: [
              Icon(n.icon,
                  size: 18, color: n.route == selected ? p.text : p.muted),
              const SizedBox(width: 10),
              Text(n.label,
                  style: TextStyle(
                      fontWeight: n.route == selected
                          ? FontWeight.w700
                          : FontWeight.w400)),
            ]),
          ),
      ],
      child: _Pill(
        selected: otherSelected,
        still: still,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (compact)
            Icon(Icons.more_horiz,
                size: 18, color: otherSelected ? p.onButton : p.muted)
          else
            Text(
                otherSelected
                    ? others.firstWhere((n) => n.route == selected).label
                    : '更多',
                style: TextStyle(
                    fontSize: 13,
                    color: otherSelected ? p.onButton : p.muted,
                    fontWeight:
                        otherSelected ? FontWeight.w600 : FontWeight.w500)),
          Icon(Icons.expand_more,
              size: 16, color: otherSelected ? p.onButton : p.muted),
        ]),
      ),
    );

    final capsule = Container(
      key: const ValueKey('pill-nav'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
        border: Border.all(color: p.outline),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        for (final n in main)
          _PillLink(
            key: ValueKey('nav-${n.route}'),
            item: n,
            selected: n.route == selected,
            compact: compact,
            onTap: () => onSelect(n),
          ),
        if (others.isNotEmpty) more,
      ]),
    );

    final badge = Container(
      key: const ValueKey('dashboard-brand-badge'),
      width: 32,
      height: 32,
      decoration: BoxDecoration(
          color: p.buttonFill,
          borderRadius: const BorderRadius.all(Radius.circular(9))),
      child: Icon(Icons.local_fire_department, size: 18, color: p.onButton),
    );

    return SizedBox(
      height: 68,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: [
          badge,
          if (!compact) ...[
            const SizedBox(width: 10),
            Text(brand,
                style: TextStyle(
                    color: p.text, fontSize: 15, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: capsule,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const ThemeRevealToggle(),
          if (trailing != null) trailing!,
        ]),
      ),
    );
  }
}

/// 膠囊導覽裡的一格：選中時墨色實心，否則透明。
class _Pill extends StatelessWidget {
  final bool selected;
  final bool still;
  final Widget child;

  const _Pill(
      {required this.selected, required this.still, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedContainer(
      key: selected ? const ValueKey('nav-indicator') : null,
      duration: still ? Duration.zero : const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      constraints: const BoxConstraints(minHeight: 36, minWidth: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? p.buttonFill : Colors.transparent,
        borderRadius: const BorderRadius.all(Radius.circular(999)),
      ),
      child: child,
    );
  }
}

class _PillLink extends StatelessWidget {
  final NavItem item;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  const _PillLink({
    super.key,
    required this.item,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final still = MediaQuery.disableAnimationsOf(context);
    final fg = selected ? p.onButton : p.muted;
    Widget tile = InkWell(
      onTap: onTap,
      customBorder: const StadiumBorder(),
      hoverColor: p.text.withOpacity(0.06),
      hoverDuration: still ? Duration.zero : null,
      splashFactory: still ? NoSplash.splashFactory : null,
      child: _Pill(
        selected: selected,
        still: still,
        child: compact
            ? Icon(item.icon, size: 18, color: fg)
            : Text(item.label,
                style: TextStyle(
                    fontSize: 13,
                    color: selected ? p.onButton : p.text,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
      ),
    );
    if (compact) tile = Tooltip(message: item.label, child: tile);
    return Semantics(button: true, selected: selected, child: tile);
  }
}
