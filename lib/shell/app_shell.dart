import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/riot_provider.dart';
import '../theme/app_theme.dart';
import 'layout.dart';
import 'nav_items.dart';
import 'nav/bottom_nav.dart';
import 'nav/eva_nav.dart';
import 'nav/top_nav.dart';
import 'side_nav.dart';
import '../theme/app_fonts.dart';
import '../theme/app_palette.dart';
import '../theme/app_style.dart';
import '../widgets/theme/eva/eva_layer.dart';
import '../widgets/theme/style_background.dart';
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
    // EVA 系列：新頁面播放切頁標題卡（R2）。
    if (context.appStyle.id.isEva) EvaLayer.requestTitleCard(item.route);
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
      final style = context.appStyle;
      final width = constraints.maxWidth;
      final mode = navModeFor(width);
      final maxWidth = style.contentMaxWidth ?? contentMaxWidth;
      final body = _Content(
          key: const ValueKey('shell-content'),
          padding: horizontalPadding(width),
          maxWidth: maxWidth,
          child: child);

      final bottom = mode == NavMode.bottom;
      final extended = mode == NavMode.extended;
      final top = !bottom && _topLayouts.contains(style.nav);
      final side = !bottom && !top;
      void go(NavItem item) => _go(context, item);
      // 所有模式共用同一個樹結構（Scaffold > Row > Expanded > Column > Expanded），
      // 只增減導覽欄與標題列；Flex 會從尾端對到同一個 Expanded，
      // 跨斷點與切換風格時內容子樹（捲動位置、頁面狀態）得以保留。
      final scaffold = Scaffold(
        appBar: bottom
            ? AppBar(
                title: Text(title),
                actions: [...actions, const _RiotStatus(compact: true)])
            : null,
        drawer: top && style.nav == NavLayout.topHamburger
            ? Drawer(
                child: _NavList(
                    selectedRoute: canonicalRoute(currentRoute),
                    items: navItems,
                    onTap: (item) {
                      Navigator.pop(context);
                      go(item);
                    }))
            : null,
        bottomNavigationBar: bottom
            ? ThemedBottomNav(
                bar: NavigationBar(
                  selectedIndex: _bottomIndex,
                  onDestinationSelected: (i) => _onBottomTap(context, i),
                  destinations: [
                    for (final r in bottomNavRoutes)
                      for (final n in navItems.where((n) => n.route == r))
                        NavigationDestination(
                            icon: Icon(n.icon), label: n.label),
                    const NavigationDestination(
                        icon: Icon(Icons.more_horiz), label: '更多'),
                  ],
                ),
              )
            : null,
        body: StyleBackground(
          style: style.id,
          child: Row(
            children: [
              if (side && style.nav == NavLayout.evaColumn)
                EvaNav(
                  currentRoute: currentRoute,
                  extended: extended,
                  style: style.id,
                  onSelect: go,
                  footer: _RiotStatus(compact: !extended),
                )
              else if (side)
                SideNav(
                  currentRoute: currentRoute,
                  // D 終端機一律是窄側欄。
                  extended: extended && style.nav != NavLayout.sideRail,
                  brand: appName,
                  onSelect: go,
                  footer: _RiotStatus(
                      compact: !extended || style.nav == NavLayout.sideRail),
                ),
              if (side && style.nav != NavLayout.evaColumn)
                const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (top)
                      TopNav(
                        currentRoute: currentRoute,
                        compact: !extended,
                        layout: style.nav,
                        brand: appName,
                        onSelect: go,
                        trailing:
                            _RiotStatus(compact: !extended, inline: extended),
                      ),
                    if (!bottom)
                      _Content(
                        padding: horizontalPadding(width),
                        maxWidth: maxWidth,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 16),
                          child: PageHeader(
                              title: title,
                              subtitle: subtitle,
                              actions: actions,
                              route: currentRoute),
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
        ),
      );
      // EvaLayer 一律存在（只在 EVA 風格啟用），切換風格時頁面狀態保留。
      return EvaLayer(
          currentRoute: currentRoute, enabled: style.id.isEva, child: scaffold);
    });
  }
}

const _topLayouts = {
  NavLayout.topMinimalMenu,
  NavLayout.topTabs,
  NavLayout.topDropdowns,
  NavLayout.topHamburger,
};

/// 置中並限制最大寬度的內容區。
class _Content extends StatelessWidget {
  final double padding;
  final double maxWidth;
  final Widget child;

  const _Content(
      {super.key,
      required this.padding,
      required this.maxWidth,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
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
  Widget build(BuildContext context) => SafeArea(
        child: SingleChildScrollView(
          child: _NavList(
            selectedRoute: selectedRoute,
            items: [
              for (final n in navItems)
                if (!bottomNavRoutes.contains(n.route)) n
            ],
            onTap: onTap,
          ),
        ),
      );
}

/// 依分組列出頁面（手機「更多」與 E 的側邊抽屜共用）。
class _NavList extends StatelessWidget {
  final String selectedRoute;
  final List<NavItem> items;
  final void Function(NavItem item) onTap;

  const _NavList(
      {required this.selectedRoute, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    NavGroup? group;
    for (final item in items) {
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
    return Column(mainAxisSize: MainAxisSize.min, children: tiles);
  }
}

/// 導覽底部的 Riot 登入狀態；點擊進入登入頁。
class _RiotStatus extends StatelessWidget {
  final bool compact;

  /// 頂部列寬螢幕：圖示＋名稱的文字按鈕。
  final bool inline;

  const _RiotStatus({required this.compact, this.inline = false});

  @override
  Widget build(BuildContext context) {
    final riot = context.watch<RiotProvider>();
    final session = riot.session;
    final eva = context.appStyle.id.isEva;
    final label = riot.isLoggedIn && session != null
        ? (eva ? '適格者 ${session.displayName} 登錄済' : session.displayName)
        : (eva ? '適格者 未登錄' : '登入 Riot');
    final icon = Icon(
      riot.isLoggedIn ? Icons.verified_user : Icons.login,
      color: riot.isLoggedIn ? AppColors.owned : AppColors.muted,
    );
    void open() => Navigator.pushNamed(context, '/riot-login');

    if (inline) {
      return TextButton.icon(
        key: const ValueKey('nav-riot'),
        onPressed: open,
        icon: icon,
        label: Text(label, overflow: TextOverflow.ellipsis),
      );
    }
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
    if (context.appStyle.id.isEva) return _EvaEmergency(minutes: minutes);
    return Container(
      key: const ValueKey('expiry-banner'),
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 18, color: AppColors.wishlistGold),
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

/// EVA 系列的到期提醒：▲ 列框住的 EMERGENCY。
class _EvaEmergency extends StatelessWidget {
  final int minutes;

  const _EvaEmergency({required this.minutes});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget triangles() => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 12; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(Icons.change_history, size: 10, color: p.onButton),
              ),
          ],
        );
    return Container(
      key: const ValueKey('eva-emergency'),
      color: p.loss,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ClipRect(child: triangles()),
        Row(children: [
          Text('EMERGENCY',
              style: AppFonts.condensed(TextStyle(
                  fontSize: 18, letterSpacing: 2, color: p.onButton))),
          const SizedBox(width: 12),
          Expanded(
              child: Text('Riot 登入將在 $minutes 分鐘後過期',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.onButton))),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: p.onButton),
            onPressed: () => Navigator.pushNamed(context, '/riot-login'),
            child: const Text('重新登入'),
          ),
        ]),
        ClipRect(child: triangles()),
      ]),
    );
  }
}
