import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/riot_provider.dart';
import '../theme/app_theme.dart';
import 'layout.dart';
import 'nav_items.dart';

const appName = 'VALORANT 商店追蹤';

/// 頂層頁面共用的殼層：依寬度切換抽屜／窄導覽列／展開導覽列，
/// 並把內容置中、限制最大寬度。
class AppShell extends StatelessWidget {
  final String currentRoute;
  final String title;
  final List<Widget> actions;
  final Widget child;

  const AppShell({
    super.key,
    required this.currentRoute,
    required this.title,
    this.actions = const [],
    required this.child,
  });

  int? get _selectedIndex {
    final i =
        navItems.indexWhere((n) => n.route == canonicalRoute(currentRoute));
    return i < 0 ? null : i;
  }

  void _go(BuildContext context, NavItem item, {bool closeDrawer = false}) {
    if (closeDrawer) Navigator.pop(context);
    if (item.route == canonicalRoute(currentRoute)) return;
    Navigator.pushReplacementNamed(context, item.route);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final mode = navModeFor(width);
      final body = _Content(padding: horizontalPadding(width), child: child);

      if (mode == NavMode.drawer) {
        return Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          drawer: _NavDrawer(
            selectedIndex: _selectedIndex,
            onTap: (item, ctx) => _go(ctx, item, closeDrawer: true),
          ),
          body: body,
        );
      }

      final extended = mode == NavMode.extended;
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: extended ? 240 : 88,
              color: AppColors.surface,
              child: Column(
                children: [
                  Expanded(
                    child: NavigationRail(
                      extended: extended,
                      minExtendedWidth: 240,
                      labelType: extended
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      selectedIndex: _selectedIndex,
                      leading: extended
                          ? const Padding(
                              padding: EdgeInsets.fromLTRB(8, 16, 8, 8),
                              child: Text(appName,
                                  style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold)),
                            )
                          : const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Icon(Icons.local_fire_department,
                                  color: AppColors.primary),
                            ),
                      destinations: [
                        for (final item in navItems)
                          NavigationRailDestination(
                            icon: Icon(item.icon),
                            label: Text(item.label),
                          ),
                      ],
                      onDestinationSelected: (i) => _go(context, navItems[i]),
                    ),
                  ),
                  _RiotStatus(compact: !extended),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Content(
                    padding: horizontalPadding(width),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24, bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                          ),
                          ...actions,
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

/// 置中並限制最大寬度的內容區。
class _Content extends StatelessWidget {
  final double padding;
  final Widget child;

  const _Content({required this.padding, required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: contentMaxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: padding),
          child: child,
        ),
      ),
    );
  }
}

class _NavDrawer extends StatelessWidget {
  final int? selectedIndex;
  final void Function(NavItem item, BuildContext context) onTap;

  const _NavDrawer({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    NavGroup? group;
    for (var i = 0; i < navItems.length; i++) {
      final item = navItems[i];
      if (item.group != group) {
        group = item.group;
        tiles.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(navGroupLabels[group]!,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ));
      }
      tiles.add(ListTile(
        leading: Icon(item.icon),
        title: Text(item.label),
        selected: i == selectedIndex,
        selectedColor: AppColors.primary,
        selectedTileColor: AppColors.surfaceHigh,
        onTap: () => onTap(item, context),
      ));
    }
    return Drawer(
      child: SafeArea(
        child: ListView(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(appName,
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
            ),
            ...tiles,
            const Divider(),
            const _RiotStatus(compact: false),
          ],
        ),
      ),
    );
  }
}

/// 導覽底部的 Riot 登入狀態；點擊進入登入頁。
class _RiotStatus extends StatelessWidget {
  final bool compact;

  const _RiotStatus({required this.compact});

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final session = riot.session;
    final label =
        riot.isLoggedIn && session != null ? session.displayName : '登入 Riot';
    final icon = Icon(
      riot.isLoggedIn ? Icons.verified_user : Icons.login,
      color: riot.isLoggedIn ? AppColors.owned : AppColors.muted,
    );
    void open() => Navigator.pushNamed(context, '/riot-login');

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IconButton(
          key: const ValueKey('nav-riot'),
          tooltip: label,
          icon: icon,
          onPressed: open,
        ),
      );
    }
    return ListTile(
      key: const ValueKey('nav-riot'),
      leading: icon,
      title: Text(label, overflow: TextOverflow.ellipsis),
      onTap: open,
    );
  }
}
