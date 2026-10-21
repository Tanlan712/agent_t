import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/riot_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import 'layout.dart';
import 'nav_items.dart';
import 'side_nav.dart';
import '../widgets/hud/page_header.dart';

const appName = 'VALORANT 商店追蹤';

/// 頂層頁面共用的殼層：依寬度切換抽屜／窄導覽列／展開導覽列，
/// 並把內容置中、限制最大寬度。
class AppShell extends StatelessWidget {
  final String currentRoute;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  const AppShell({
    super.key,
    required this.currentRoute,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
  });

  void _go(BuildContext context, NavItem item) {
    if (item.route == canonicalRoute(currentRoute)) return;
    Navigator.pushReplacementNamed(context, item.route);
  }

  /// 底部導覽選中的位置；不在常用 4 頁時是「更多」（4）。
  int get _bottomIndex {
    final i = bottomNavRoutes.indexOf(canonicalRoute(currentRoute));
    return i < 0 ? bottomNavRoutes.length : i;
  }

  void _onBottomTap(BuildContext context, int i) {
    if (i < bottomNavRoutes.length) {
      _go(context, navItems.firstWhere((n) => n.route == bottomNavRoutes[i]));
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      builder: (sheet) => _MoreSheet(
        selectedRoute: canonicalRoute(currentRoute),
        onTap: (item) {
          Navigator.pop(sheet);
          _go(context, item);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      final mode = navModeFor(width);
      final body = _Content(padding: horizontalPadding(width), child: child);

      final bottom = mode == NavMode.bottom;
      final extended = mode == NavMode.extended;
      // 三種模式共用同一個樹結構（Scaffold > Row > Expanded > Column > Expanded），
      // 只增減導覽欄與標題列；Flex 會從尾端對到同一個 Expanded，
      // 跨斷點時內容子樹（捲動位置、頁面狀態）得以保留。
      return Scaffold(
        appBar: bottom
            ? AppBar(
                title: Text(title),
                actions: [...actions, const _RiotStatus(compact: true)])
            : null,
        bottomNavigationBar: bottom
            ? NavigationBar(
                selectedIndex: _bottomIndex,
                onDestinationSelected: (i) => _onBottomTap(context, i),
                destinations: [
                  for (final r in bottomNavRoutes)
                    for (final n in navItems.where((n) => n.route == r))
                      NavigationDestination(icon: Icon(n.icon), label: n.label),
                  const NavigationDestination(
                      icon: Icon(Icons.more_horiz), label: '更多'),
                ],
              )
            : null,
        body: Row(
          children: [
            if (!bottom)
              SideNav(
                currentRoute: currentRoute,
                extended: extended,
                brand: appName,
                onSelect: (item) => _go(context, item),
                footer: _RiotStatus(compact: !extended),
              ),
            if (!bottom) const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!bottom)
                    _Content(
                      padding: horizontalPadding(width),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 24, bottom: 16),
                        child: PageHeader(
                            title: title, subtitle: subtitle, actions: actions),
                      ),
                    ),
                  // 一直放在樹中（不需要時是空的），跨斷點時結構不變。
                  const ExpiryBanner(),
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

/// 手機「更多」：依分組列出其餘頁面。
class _MoreSheet extends StatelessWidget {
  final String selectedRoute;
  final void Function(NavItem item) onTap;

  const _MoreSheet({required this.selectedRoute, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    NavGroup? group;
    final order = context.watch<SettingsProvider>().settings.navOrder;
    for (final item in orderedNavItems(order)) {
      if (bottomNavRoutes.contains(item.route)) continue;
      if (item.group != group) {
        group = item.group;
        tiles.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(navGroupLabels[group]!, style: AppText.label),
        ));
      }
      tiles.add(ListTile(
        leading: Icon(item.icon),
        title: Text(item.label),
        selected: item.route == selectedRoute,
        selectedColor: AppColors.primary,
        selectedTileColor: AppColors.surfaceHigh,
        onTap: () => onTap(item),
      ));
    }
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: tiles),
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

/// Riot 登入快到期（剩 5 分鐘內）時的提醒列；每 30 秒重新檢查一次。
class ExpiryBanner extends StatefulWidget {
  const ExpiryBanner({super.key});

  @override
  State<ExpiryBanner> createState() => _ExpiryBannerState();
}

class _ExpiryBannerState extends State<ExpiryBanner> {
  late final Timer _tick =
      Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    if (!riot.expiresSoon) return const SizedBox.shrink();
    final minutes = (riot.timeLeft.inSeconds / 60).ceil();
    return Container(
      key: const ValueKey('expiry-banner'),
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined,
              size: 18, color: AppColors.wishlistGold),
          const SizedBox(width: 8),
          Expanded(child: Text('Riot 登入將在 $minutes 分鐘後過期')),
          TextButton(
            onPressed: () => Navigator.pushNamed(context, '/riot-login'),
            child: const Text('重新登入'),
          ),
        ],
      ),
    );
  }
}
