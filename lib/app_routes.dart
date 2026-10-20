import 'package:flutter/material.dart';

import 'models/match_models.dart';
import 'screens/agents_page.dart';
import 'screens/bundles_page.dart';
import 'screens/gamemodes_page.dart';
import 'screens/maps_page.dart';
import 'screens/match_detail_page.dart';
import 'screens/match_history_page.dart';
import 'screens/my_shop_page.dart';
import 'screens/player_page.dart';
import 'screens/playercards_page.dart';
import 'screens/riot_login_page.dart';
import 'screens/settings_page.dart';
import 'screens/shop_edit_page.dart';
import 'screens/skin_picker_page.dart';
import 'screens/weapons_page.dart';
import 'screens/wishlist_page.dart';

/// 頂層頁面：包在 AppShell 裡，切換時沒有轉場動畫。
final Map<String, WidgetBuilder> _topLevel = {
  '/': (_) => const MyShopPage(),
  '/my-shop': (_) => const MyShopPage(),
  '/wishlist': (_) => const WishlistPage(),
  '/matches': (_) => const MatchHistoryPage(),
  '/agents': (_) => const AgentsPage(),
  '/weapons': (_) => const WeaponsPage(),
  '/maps': (_) => const MapsPage(),
  '/bundles': (_) => const BundlesPage(),
  '/gamemodes': (_) => const GamemodesPage(),
  '/playercards': (_) => const PlayerCardsPage(),
  '/settings': (_) => const SettingsPage(),
};

Route<dynamic>? onGenerateAppRoute(RouteSettings settings) {
  final topLevel = _topLevel[settings.name];
  if (topLevel != null) {
    return PageRouteBuilder<void>(
      settings: settings,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (context, _, __) => topLevel(context),
    );
  }
  switch (settings.name) {
    case '/my-shop/edit':
      final section = settings.arguments as ShopSection? ?? ShopSection.daily;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => ShopEditPage(section: section),
      );
    case '/skin-picker':
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => const SkinPickerPage(),
      );
    case '/matches/detail':
      // 參數是自己紀錄的 matchId，或玩家頁帶入的 MatchDetail。
      final args = settings.arguments;
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => args is MatchDetail
            ? MatchDetailPage(matchId: args.summary.matchId, detail: args)
            : MatchDetailPage(matchId: args as String? ?? ''),
      );
    case '/players/detail':
      return MaterialPageRoute<void>(
        settings: settings,
        // 網頁重新整理後參數會遺失，此時顯示提示而不是錯誤畫面。
        builder: (_) => switch (settings.arguments) {
          final PlayerRef p => PlayerPage(player: p),
          _ => Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('找不到這位玩家')),
            ),
        },
      );
    case '/riot-login':
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => const RiotLoginPage(),
      );
  }
  return null;
}
