import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/collection_provider.dart';
import 'providers/loadout_provider.dart';
import 'providers/login_prefetcher.dart';
import 'providers/offer_price_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/pwa_controller.dart';
import 'providers/catalog_provider.dart';
import 'providers/match_detail_cache.dart';
import 'providers/match_history_provider.dart';
import 'providers/match_reference_provider.dart';
import 'providers/recent_form_loader.dart';
import 'providers/riot_provider.dart';
import 'providers/riot_resource.dart';
import 'providers/seen_players_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shop_auto_refresh.dart';
import 'providers/shop_provider.dart';
import 'providers/wishlist_provider.dart';
import 'app_routes.dart';
import 'logic/eva_progress.dart';
import 'screens/riot_web_login_page.dart';
import 'services/progress_reference_api.dart';
import 'services/catalog_api.dart';
import 'services/live_client.dart';
import 'services/match_client.dart';
import 'services/match_reference_api.dart';
import 'services/pwa.dart';
import 'services/remote_client.dart';
import 'services/riot_client.dart';
import 'storage/catalog_cache.dart';
import 'storage/match_reference_cache.dart';
import 'storage/offer_price_storage.dart';
import 'storage/seen_players_storage.dart';
import 'storage/session_storage.dart';
import 'storage/settings_storage.dart';
import 'storage/shop_storage.dart';
import 'storage/wishlist_storage.dart';
import 'theme/themed_app.dart';
import 'widgets/pwa_banners.dart';
import 'widgets/riot_auto_renew.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsProvider(SettingsStorage(prefs));
  // EVA 故事層的劇集：每個有打開 App 的日子前進一話（只存在這個瀏覽器）。
  settings.updateEva((s) => recordOpen(s, DateTime.now()));
  final catalog = CatalogProvider(CatalogApi(), CatalogCache(prefs));
  // 不等待：先顯示畫面，目錄在背景載入。
  catalog.init();

  // 商店同步與對戰紀錄共用同一個 Riot 登入；登入資訊保存到 token 過期為止（AGENTS.md 第 4 節）。
  final riotClient = RiotClient();
  // 手機 App 按「登出」時一併清除內嵌頁的 Riot 登入記錄，背景續期也跟著停止。
  final riot = RiotProvider(riotClient,
      storage: SessionStorage(prefs),
      onLogout: inAppLoginSupported ? clearRiotWebLogin : null);
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
  // 目前裝備與排隊懲罰（只讀 GET，AGENTS.md 第 3 節）。
  final equipped = EquippedLoadoutProvider(riot, riotClient);
  final penalties = PenaltyProvider(riot, riotClient);
  // 造型的實際定價：同步商店時順便記下看到的價格（不另外送請求）。
  final prices = OfferPriceProvider(OfferPriceStorage(prefs));
  riot.onStorefront = prices.record;
  final shop = ShopProvider(ShopStorage(prefs));
  // 遠端操作（寫入）：每次送出前檢查使用者是否在設定頁同意（規格 2026-10-22-remote-control-design.md）。
  final remoteClient =
      RemoteClient(riotClient, allowed: () => settings.settings.remoteControl);
  // 登入後（含重新開頁恢復登入）先在背景讀一次：商店與錢包、收藏、通行證
  // （依序、同時最多 2 個 Riot 請求）。
  LoginPrefetcher(riot, collection, progress, shop: shop, catalog: catalog);
  // 網頁開著時，每日商店到期或夜市結束後自動同步（使用者決定 2026-10-22）。
  ShopAutoRefresher(riot, shop, catalog);
  // 網頁版的離線提示、安裝、新版本提示與商店刷新通知；手機 App 不做任何事。
  final pwa = PwaController(createPwaPlatform())..start();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider.value(value: shop),
        ChangeNotifierProvider(
            create: (_) => WishlistProvider(WishlistStorage(prefs))),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: riot),
        ChangeNotifierProvider.value(value: collection),
        ChangeNotifierProvider.value(value: progress),
        ChangeNotifierProvider.value(value: equipped),
        ChangeNotifierProvider.value(value: penalties),
        ChangeNotifierProvider.value(value: prices),
        Provider.value(value: matchClient),
        Provider.value(value: liveClient),
        Provider.value(value: remoteClient),
        ChangeNotifierProvider(
            create: (_) => LoadoutProvider(remoteClient, riot)),
        Provider.value(value: matchCache),
        ChangeNotifierProvider(
            create: (_) => RecentFormLoader(matchClient, riot, matchCache)),
        ChangeNotifierProvider(
            create: (_) => MatchHistoryProvider(matchClient, riot,
                cache: matchCache, onDetails: seenPlayers.recordAll)),
        ChangeNotifierProvider.value(value: seenPlayers),
        ChangeNotifierProvider.value(value: matchReference),
        ChangeNotifierProvider.value(value: pwa),
      ],
      child: MyApp(pwa: pwa),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.pwa});

  final PwaController pwa;

  @override
  Widget build(BuildContext context) {
    return ThemedApp(
      builder: (theme, builder) => MaterialApp(
        title: 'Agent T',
        debugShowCheckedModeBanner: false,
        theme: theme,
        // 主題立即切換：AppColors（全域）與 Theme.of 不會有一段時間不一致。
        themeAnimationDuration: Duration.zero,
        // 手機 App 在背景續期 Riot 登入（AGENTS.md 第 3 節）；網頁版不做任何事。
        // 頂端的離線／新版本提示列包在最外層，所有頁面都看得到。
        builder: (context, child) => PwaBanners(
            controller: pwa,
            child: RiotAutoRenew(child: builder(context, child))),
        onGenerateRoute: onGenerateAppRoute,
      ),
    );
  }
}
