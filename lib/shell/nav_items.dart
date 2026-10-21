import 'package:flutter/material.dart';

enum NavGroup { shop, database, settings }

class NavItem {
  final String route;
  final String label;
  final IconData icon;
  final NavGroup group;

  const NavItem(this.route, this.label, this.icon, this.group);
}

/// 側邊導覽的項目；導覽列與抽屜共用。
const List<NavItem> navItems = [
  NavItem('/', '我的商店', Icons.storefront, NavGroup.shop),
  NavItem('/wishlist', '願望清單', Icons.star, NavGroup.shop),
  NavItem('/matches', '對戰紀錄', Icons.history, NavGroup.shop),
  NavItem('/live', '即時對局', Icons.sensors, NavGroup.shop),
  NavItem('/players', '遇過的玩家', Icons.people_outline, NavGroup.shop),
  NavItem('/collection', '我的收藏', Icons.collections_bookmark, NavGroup.shop),
  NavItem('/progress', '通行證與任務', Icons.military_tech, NavGroup.shop),
  NavItem('/agents', '角色', Icons.person, NavGroup.database),
  NavItem('/weapons', '武器', Icons.track_changes, NavGroup.database),
  NavItem('/maps', '地圖', Icons.map, NavGroup.database),
  NavItem('/bundles', '組合包', Icons.card_giftcard, NavGroup.database),
  NavItem('/gamemodes', '遊戲模式', Icons.sports_esports, NavGroup.database),
  NavItem('/playercards', '玩家卡片', Icons.badge, NavGroup.database),
  NavItem('/settings', '設定', Icons.settings, NavGroup.settings),
];

const navGroupLabels = {
  NavGroup.shop: '主要',
  NavGroup.database: '資料庫',
  NavGroup.settings: '其他',
};

/// `/my-shop` 與 `/` 是同一頁。
String canonicalRoute(String route) => route == '/my-shop' ? '/' : route;

/// 手機底部導覽的 4 個常用頁面（第 5 項是「更多」）。
const bottomNavRoutes = ['/', '/matches', '/live', '/wishlist'];

/// 依使用者自訂順序排列導覽項目：只在同一組內調整，組的先後不變；
/// 沒列在 [order] 的項目照預設順序接在組尾，未知的路由忽略。
List<NavItem> orderedNavItems(List<String> order) {
  int rank(NavItem n) {
    final i = order.indexOf(n.route);
    return i < 0 ? order.length + navItems.indexOf(n) : i;
  }

  return [
    for (final g in NavGroup.values)
      ...navItems.where((n) => n.group == g).toList()
        ..sort((a, b) => rank(a).compareTo(rank(b))),
  ];
}
