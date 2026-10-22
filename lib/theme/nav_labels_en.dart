import '../shell/nav_items.dart';

/// 頂層頁面的英文名（頁首小標、浮水印、EVA 導覽）；不改 nav_items.dart。
const Map<String, String> navLabelsEn = {
  '/': 'STORE',
  '/wishlist': 'WISHLIST',
  '/matches': 'RECORD',
  '/live': 'LIVE',
  '/players': 'CONTACTS',
  '/collection': 'ARCHIVE',
  '/wallet': 'WALLET',
  '/progress': 'PROGRESS',
  '/agents': 'AGENTS',
  '/weapons': 'WEAPONS',
  '/maps': 'MAPS',
  '/bundles': 'BUNDLES',
  '/gamemodes': 'MODES',
  '/playercards': 'CARDS',
  '/settings': 'CONFIG',
};

/// 路由在導覽中的序號（從 1 開始，依使用者自訂的 [order]）；不在導覽中時為 null。
int? navNumberOf(String? route, [List<String> order = const []]) {
  if (route == null) return null;
  final i = orderedNavItems(order)
      .indexWhere((n) => n.route == canonicalRoute(route));
  return i < 0 ? null : i + 1;
}

/// 兩位數序號，例如 3 → `03`。
String twoDigits(int n) => n.toString().padLeft(2, '0');
