import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'nav_items.dart';

/// 分組側欄：展開時 248 寬（圖示＋名稱＋分組標題），收合時 72 寬（只有圖示＋提示）。
/// 項目過多或視窗太矮時可捲動；[footer]（Riot 狀態）固定在底部。
/// 展開時可以「編輯選單」：在同一組內拖曳或上移／下移，順序存在設定裡。
class SideNav extends StatefulWidget {
  final String currentRoute;
  final bool extended;
  final ValueChanged<NavItem> onSelect;
  final String brand;
  final Widget? footer;

  const SideNav({
    super.key,
    required this.currentRoute,
    required this.extended,
    required this.onSelect,
    this.brand = '',
    this.footer,
  });

  @override
  State<SideNav> createState() => _SideNavState();
}

class _SideNavState extends State<SideNav> {
  bool _editing = false;

  void _move(List<NavItem> ordered, NavItem item, int delta) {
    final group = [
      for (final n in ordered)
        if (n.group == item.group) n
    ];
    final i = group.indexOf(item);
    final j = i + delta;
    if (j < 0 || j >= group.length) return;
    group.insert(j, group.removeAt(i));
    _saveGroup(ordered, item.group, group);
  }

  /// 把某一組的新順序和其他組目前的順序合成完整清單後保存。
  void _saveGroup(List<NavItem> ordered, NavGroup g, List<NavItem> group) {
    final next = <String>[
      for (final grp in NavGroup.values)
        ...(grp == g ? group : ordered.where((n) => n.group == grp))
            .map((n) => n.route),
    ];
    context.read<SettingsProvider>().setNavOrder(next);
  }

  Widget _groupLabel(NavGroup g) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 6),
        child: Text(navGroupLabels[g]!,
            style: const TextStyle(
                fontSize: 11, color: AppColors.muted, letterSpacing: 0.6)),
      );

  @override
  Widget build(BuildContext context) {
    final extended = widget.extended;
    final editing = _editing && extended;
    final ordered =
        orderedNavItems(context.watch<SettingsProvider>().settings.navOrder);
    final children = <Widget>[];
    for (final g in NavGroup.values) {
      final group = [
        for (final n in ordered)
          if (n.group == g) n
      ];
      if (group.isEmpty) continue;
      if (children.isNotEmpty && !extended) {
        children.add(const Divider(height: 17, indent: 16, endIndent: 16));
      }
      if (extended) children.add(_groupLabel(g));
      if (editing) {
        children.add(ReorderableListView(
          key: ValueKey('nav-reorder-${g.name}'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          onReorder: (from, to) {
            final list = [...group];
            final item = list.removeAt(from);
            list.insert(to > from ? to - 1 : to, item);
            _saveGroup(ordered, g, list);
          },
          children: [
            for (var i = 0; i < group.length; i++)
              _EditTile(
                key: ValueKey('nav-${group[i].route}'),
                index: i,
                item: group[i],
                onUp: i == 0 ? null : () => _move(ordered, group[i], -1),
                onDown: i == group.length - 1
                    ? null
                    : () => _move(ordered, group[i], 1),
              ),
          ],
        ));
      } else {
        for (final item in group) {
          children.add(_NavTile(
            key: ValueKey('nav-${item.route}'),
            item: item,
            selected: item.route == canonicalRoute(widget.currentRoute),
            extended: extended,
            onTap: () => widget.onSelect(item),
          ));
        }
      }
    }
    return Container(
      width: extended ? 248 : 72,
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(extended ? 20 : 0, 20, 12, 4),
            child: extended
                ? Text(widget.brand,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold))
                : const Icon(Icons.local_fire_department,
                    color: AppColors.primary),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: children,
            ),
          ),
          // 編輯選單只在展開時提供（收合時放不下上移／下移按鈕）。
          if (extended)
            Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: editing
                    ? Row(children: [
                        TextButton(
                          key: const ValueKey('nav-edit-reset'),
                          onPressed: () => context
                              .read<SettingsProvider>()
                              .setNavOrder(const []),
                          child: const Text('恢復預設'),
                        ),
                        const Spacer(),
                        FilledButton(
                          key: const ValueKey('nav-edit-done'),
                          onPressed: () => setState(() => _editing = false),
                          child: const Text('完成'),
                        ),
                      ])
                    : Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          key: const ValueKey('nav-edit'),
                          onPressed: () => setState(() => _editing = true),
                          icon: const Icon(Icons.tune, size: 18),
                          label: const Text('編輯選單'),
                        ),
                      ),
              ),
            ),
          // 透明 Material：footer（ListTile）的焦點與水波畫在側欄底色之上。
          if (widget.footer != null)
            Material(type: MaterialType.transparency, child: widget.footer!),
        ],
      ),
    );
  }
}

/// 編輯模式的項目：拖曳把手＋上移／下移（不靠拖曳也能用鍵盤調整）。
class _EditTile extends StatelessWidget {
  final int index;
  final NavItem item;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  const _EditTile({
    super.key,
    required this.index,
    required this.item,
    required this.onUp,
    required this.onDown,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Material(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 40,
            child: Row(children: [
              ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.drag_indicator,
                      size: 18, color: AppColors.muted),
                ),
              ),
              Icon(item.icon, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(item.label,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14))),
              IconButton(
                key: ValueKey('nav-up-${item.route}'),
                tooltip: '上移',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: onUp,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                key: ValueKey('nav-down-${item.route}'),
                tooltip: '下移',
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: onDown,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
            ]),
          ),
        ),
      );
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
}
