import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/collection_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/catalog_provider.dart';
import 'providers/match_detail_cache.dart';
import 'providers/match_history_provider.dart';
import 'providers/match_reference_provider.dart';
import 'providers/recent_form_loader.dart';
import 'providers/riot_provider.dart';
import 'providers/seen_players_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/wishlist_provider.dart';
import 'app_routes.dart';
import 'services/progress_reference_api.dart';
import 'services/catalog_api.dart';
import 'services/live_client.dart';
import 'services/match_client.dart';
import 'services/match_reference_api.dart';
import 'services/riot_client.dart';
import 'storage/catalog_cache.dart';
import 'storage/match_reference_cache.dart';
import 'storage/seen_players_storage.dart';
import 'storage/session_storage.dart';
import 'storage/settings_storage.dart';
import 'storage/shop_storage.dart';
import 'storage/wishlist_storage.dart';
import 'theme/themed_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 載入環境變數 (如果 .env 不存在也不會報錯)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('未找到 .env 檔案，使用預設設定');
  }

  final prefs = await SharedPreferences.getInstance();
  final catalog = CatalogProvider(CatalogApi(), CatalogCache(prefs));
  // 不等待：先顯示畫面，目錄在背景載入。
  catalog.init();

  // 商店同步與對戰紀錄共用同一個 Riot 登入；登入資訊保存到 token 過期為止（AGENTS.md 第 4 節）。
  final riotClient = RiotClient();
  final riot = RiotProvider(riotClient, storage: SessionStorage(prefs));
  // 自己的紀錄、最近 5 場與玩家頁共用同一份場次快取。
  final matchClient = MatchClient(riotClient);
  // 即時對局（glz）只有 GET，規則見 AGENTS.md。
  final liveClient = LiveClient(riotClient);
  final matchCache = MatchDetailCache();
  // 遇過的玩家只存在這個瀏覽器（localStorage），方便之後查詢他的紀錄。
  final seenPlayers = SeenPlayersProvider(SeenPlayersStorage(prefs));
  final matchReference =
      MatchReferenceProvider(MatchReferenceApi(), MatchReferenceCache(prefs));
  matchReference.init();
  // 自己的收藏、等級、通行證與任務（只讀 GET，AGENTS.md 第 3 節）。
  final collection = CollectionProvider(riot, riotClient);
  final progress = ProgressProvider(riot, riotClient, ProgressReferenceApi());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider(create: (_) => ShopProvider(ShopStorage(prefs))),
        ChangeNotifierProvider(
            create: (_) => WishlistProvider(WishlistStorage(prefs))),
        ChangeNotifierProvider(
            create: (_) => SettingsProvider(SettingsStorage(prefs))),
        ChangeNotifierProvider.value(value: riot),
        ChangeNotifierProvider.value(value: collection),
        ChangeNotifierProvider.value(value: progress),
        Provider.value(value: matchClient),
        Provider.value(value: liveClient),
        Provider.value(value: matchCache),
        ChangeNotifierProvider(
            create: (_) => RecentFormLoader(matchClient, riot, matchCache)),
        ChangeNotifierProvider(
            create: (_) => MatchHistoryProvider(matchClient, riot,
                cache: matchCache, onDetails: seenPlayers.recordAll)),
        ChangeNotifierProvider.value(value: seenPlayers),
        ChangeNotifierProvider.value(value: matchReference),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ThemedApp(
      builder: (theme, builder) => MaterialApp(
        title: 'VALORANT 商店追蹤',
        debugShowCheckedModeBanner: false,
        theme: theme,
        // 主題立即切換：AppColors（全域）與 Theme.of 不會有一段時間不一致。
        themeAnimationDuration: Duration.zero,
        builder: builder,
        onGenerateRoute: onGenerateAppRoute,
      ),
    );
  }
}
