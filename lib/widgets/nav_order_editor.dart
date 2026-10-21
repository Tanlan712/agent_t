import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../shell/nav_items.dart';
import '../theme/app_theme.dart';
import 'hud/hud.dart';

/// 設定頁「選單順序」：在同一組內拖曳或上移／下移，所有風格的導覽都套用同一份順序。
class NavOrderEditor extends StatelessWidget {
  const NavOrderEditor({super.key});

  /// 把某一組的新順序和其他組目前的順序合成完整清單後保存。
  static void _saveGroup(BuildContext context, List<NavItem> ordered,
      NavGroup g, List<NavItem> group) {
    final next = <String>[
      for (final grp in NavGroup.values)
        ...(grp == g ? group : ordered.where((n) => n.group == grp))
            .map((n) => n.route),
    ];
    context.read<SettingsProvider>().setNavOrder(next);
  }

  static void _move(BuildContext context, List<NavItem> ordered,
      List<NavItem> group, int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= group.length) return;
    final list = [...group];
    list.insert(j, list.removeAt(i));
    _saveGroup(context, ordered, group.first.group, list);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final order = settings.settings.navOrder;
    final ordered = orderedNavItems(order);
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.reorder, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('選單順序',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              key: const ValueKey('order-reset'),
              onPressed:
                  order.isEmpty ? null : () => settings.setNavOrder(const []),
              child: const Text('恢復預設'),
            ),
          ]),
          const SizedBox(height: 4),
          Text('拖曳或用上移／下移調整，只能在同一組內移動；所有風格的導覽都會套用。',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
          for (final g in NavGroup.values) ..._group(context, ordered, g),
        ],
      ),
    );
  }

  List<Widget> _group(BuildContext context, List<NavItem> ordered, NavGroup g) {
    final group = [
      for (final n in ordered)
        if (n.group == g) n
    ];
    if (group.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
        child: Text(navGroupLabels[g]!,
            style: TextStyle(
                fontSize: 11, color: AppColors.muted, letterSpacing: 0.6)),
      ),
      ReorderableListView(
        key: ValueKey('order-group-${g.name}'),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        onReorder: (from, to) {
          final list = [...group];
          final item = list.removeAt(from);
          list.insert(to > from ? to - 1 : to, item);
          _saveGroup(context, ordered, g, list);
        },
        children: [
          for (var i = 0; i < group.length; i++)
            _EditTile(
              key: ValueKey('order-${group[i].route}'),
              index: i,
              item: group[i],
              onUp: i == 0 ? null : () => _move(context, ordered, group, i, -1),
              onDown: i == group.length - 1
                  ? null
                  : () => _move(context, ordered, group, i, 1),
            ),
        ],
      ),
    ];
  }
}

/// 一個項目：拖曳把手＋上移／下移（不靠拖曳也能用鍵盤調整）。
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
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Material(
          color: AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 44,
            child: Row(children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
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
                key: ValueKey('order-up-${item.route}'),
                tooltip: '上移',
                iconSize: 18,
                onPressed: onUp,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                key: ValueKey('order-down-${item.route}'),
                tooltip: '下移',
                iconSize: 18,
                onPressed: onDown,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
            ]),
          ),
        ),
      );
}
