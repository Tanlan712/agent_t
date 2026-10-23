import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/app_routes.dart';
import 'package:agent_t/models/current_shop.dart';
import 'package:agent_t/models/match_models.dart';
import 'package:agent_t/models/wishlist_item.dart';
import 'package:agent_t/providers/catalog_provider.dart';
import 'package:agent_t/providers/encounter_provider.dart';
import 'package:agent_t/storage/encounter_storage.dart';
import 'package:agent_t/providers/match_detail_cache.dart';
import 'package:agent_t/providers/match_history_provider.dart';
import 'package:agent_t/providers/match_reference_provider.dart';
import 'package:agent_t/providers/recent_form_loader.dart';
import 'package:agent_t/providers/collection_provider.dart';
import 'package:agent_t/providers/loadout_provider.dart';
import 'package:agent_t/services/remote_client.dart';
import 'package:agent_t/providers/progress_provider.dart';
import 'package:agent_t/providers/offer_price_provider.dart';
import 'package:agent_t/providers/riot_provider.dart';
import 'package:agent_t/providers/riot_resource.dart';
import 'package:agent_t/storage/offer_price_storage.dart';
import 'package:agent_t/services/progress_reference_api.dart';
import 'package:agent_t/providers/seen_players_provider.dart';
import 'package:agent_t/providers/settings_provider.dart';
import 'package:agent_t/providers/shop_provider.dart';
import 'package:agent_t/providers/purchase_history_provider.dart';
import 'package:agent_t/providers/wishlist_provider.dart';
import 'package:agent_t/services/live_client.dart';
import 'package:agent_t/services/match_client.dart';
import 'package:agent_t/services/match_reference_api.dart';
import 'package:agent_t/services/riot_client.dart';
import 'package:agent_t/storage/match_reference_cache.dart';
import 'package:agent_t/theme/app_theme.dart';
import 'package:agent_t/theme/theme_ids.dart';
import 'package:agent_t/theme/themed_app.dart';
import 'package:agent_t/storage/seen_players_storage.dart';
import 'package:agent_t/storage/session_storage.dart';
import 'package:agent_t/storage/settings_storage.dart';
import 'package:agent_t/storage/shop_storage.dart';
import 'package:agent_t/storage/purchase_history_storage.dart';
import 'package:agent_t/storage/wishlist_storage.dart';

import 'catalog_helpers.dart';
import 'match_fixtures.dart';
import 'riot_fixtures.dart';

/// 對戰頁面測試用的參考資料（預先寫入快取，不連網）。
final testMatchReference = MatchReference(
  // season-1 是測試期間的本幕（match-details 與他人 MMR 的假資料都用它）。
  seasons: {
    'season-1': SeasonRef(
        name: 'V26 第六幕',
        start: DateTime.utc(2023),
        end: DateTime.utc(2100),
        isAct: true),
  },
  agents: {
    'agent-$myPuuid': RefItem(name: '蓋克'),
    'agent-mate': RefItem(name: '菲德'),
  },
  maps: {'/Game/Maps/Ascent/Ascent': RefItem(name: '亞海懸城')},
  tiers: {
    0: RefItem(name: '牌階未定'),
    18: RefItem(name: '鑽石 2'),
    12: RefItem(name: '白金 1'),
    21: RefItem(name: '超凡 1'),
  },
);

/// 測試用的整組 providers，已預先寫入商店／願望清單資料。
class Harness {
  final CatalogProvider catalog;
  final ShopProvider shop;
  final WishlistProvider wishlist;
  final SettingsProvider settings;
  final RiotProvider riot;
  final MatchHistoryProvider matchHistory;
  final MatchReferenceProvider matchReference;
  final SharedPreferences prefs;
  final MatchClient matchClient;
  final MatchDetailCache matchCache;
  final SeenPlayersProvider seenPlayers;
  final LiveClient liveClient;
  late final CollectionProvider collection;
  late final ProgressProvider progress;
  late final EquippedLoadoutProvider equipped;
  late final PenaltyProvider penalties;
  late final OfferPriceProvider prices;
  late final PurchaseHistoryProvider purchaseHistory;
  late final RemoteClient remoteClient;
  late final LoadoutProvider loadout;
  late final EncounterProvider encounters =
      EncounterProvider(EncounterStorage(prefs));
  late final RecentFormLoader recentForm = RecentFormLoader(
      matchClient, riot, matchCache,
      onDetails: encounters.recordAll);

  Harness(
      this.catalog,
      this.shop,
      this.wishlist,
      this.settings,
      this.riot,
      this.matchHistory,
      this.matchReference,
      this.prefs,
      this.matchClient,
      this.matchCache,
      this.seenPlayers,
      this.liveClient);

  static Future<Harness> create(
    WidgetTester tester, {
    CurrentShop shop = const CurrentShop(),
    List<String> wishlist = const [],
    CatalogProvider? catalog,
    http.Client? riotHttp,
    int matchPageSize = 10,
    DateTime Function()? now,
    ProgressReferenceApi? progressApi,
    bool storeSession = false,
    Future<void> Function()? onLogout,
  }) async {
    final c = catalog ?? await loadedCatalog(tester);
    final prefs = await SharedPreferences.getInstance();
    await ShopStorage(prefs).save(shop);
    await WishlistStorage(prefs).save([
      for (final id in wishlist)
        WishlistItem(skinUuid: id, addedAt: DateTime(2026, 10, 1)),
    ]);
    final rc = RiotClient(client: riotHttp ?? riotClient());
    final riot = RiotProvider(rc,
        now: now ?? DateTime.now,
        storage: storeSession ? SessionStorage(prefs) : null,
        onLogout: onLogout);
    final refCache = MatchReferenceCache(prefs);
    await refCache.save(testMatchReference);
    final reference = MatchReferenceProvider(
        MatchReferenceApi(client: riotHttp ?? riotClient()), refCache);
    await reference.init();
    final matchClient = MatchClient(rc);
    final matchCache = MatchDetailCache();
    final seenPlayers = SeenPlayersProvider(SeenPlayersStorage(prefs));
    final h = Harness(
      c,
      ShopProvider(ShopStorage(prefs)),
      WishlistProvider(WishlistStorage(prefs)),
      SettingsProvider(SettingsStorage(prefs)),
      riot,
      MatchHistoryProvider(matchClient, riot,
          cache: matchCache,
          pageSize: matchPageSize,
          onDetails: seenPlayers.recordAll),
      reference,
      prefs,
      matchClient,
      matchCache,
      seenPlayers,
      LiveClient(rc),
    );
    h.remoteClient =
        RemoteClient(rc, allowed: () => h.settings.settings.remoteControl);
    h.loadout = LoadoutProvider(h.remoteClient, riot);
    // 測試不真的等待退避。
    h.collection = CollectionProvider(riot, rc, delay: (_) async {});
    h.progress = ProgressProvider(riot, rc,
        progressApi ?? ProgressReferenceApi(client: riotHttp ?? riotClient()),
        delay: (_) async {});
    h.equipped = EquippedLoadoutProvider(riot, rc, delay: (_) async {});
    h.penalties = PenaltyProvider(riot, rc, delay: (_) async {});
    h.prices =
        OfferPriceProvider(OfferPriceStorage(prefs), now: now ?? DateTime.now);
    riot.onStorefront = h.prices.record;
    h.purchaseHistory = PurchaseHistoryProvider(PurchaseHistoryStorage(prefs),
        now: now ?? DateTime.now);
    return h;
  }

  /// [useAppRoutes] 為 true 時改用 App 的路由表（`onGenerateAppRoute`），從 `/` 開始。
  /// [choice] 指定固定主題；[useSettingsTheme] 為 true 時改為跟著 settings 切換（同 MyApp）。
  Widget wrap({
    Widget? home,
    Map<String, WidgetBuilder> routes = const {},
    RouteFactory? onGenerateRoute,
    bool useAppRoutes = false,
    List<NavigatorObserver> observers = const [],
    ThemeChoice choice = const ThemeChoice(),
    bool useSettingsTheme = false,
  }) {
    Widget app(ThemeData theme, TransitionBuilder? builder) => useAppRoutes
        ? MaterialApp(
            theme: theme,
            themeAnimationDuration: Duration.zero,
            builder: builder,
            onGenerateRoute: onGenerateAppRoute,
            navigatorObservers: observers,
          )
        : MaterialApp(
            theme: theme,
            themeAnimationDuration: Duration.zero,
            builder: builder,
            home: home,
            routes: routes,
            onGenerateRoute: onGenerateRoute,
            navigatorObservers: observers,
          );
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider.value(value: shop),
        ChangeNotifierProvider.value(value: wishlist),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: riot),
        ChangeNotifierProvider.value(value: collection),
        ChangeNotifierProvider.value(value: progress),
        ChangeNotifierProvider.value(value: equipped),
        ChangeNotifierProvider.value(value: penalties),
        ChangeNotifierProvider.value(value: prices),
        ChangeNotifierProvider.value(value: purchaseHistory),
        Provider.value(value: matchClient),
        Provider.value(value: liveClient),
        Provider.value(value: remoteClient),
        ChangeNotifierProvider.value(value: loadout),
        Provider.value(value: matchCache),
        ChangeNotifierProvider.value(value: recentForm),
        ChangeNotifierProvider.value(value: seenPlayers),
        ChangeNotifierProvider.value(value: encounters),
        ChangeNotifierProvider.value(value: matchHistory),
        ChangeNotifierProvider.value(value: matchReference),
      ],
      child: useSettingsTheme
          ? ThemedApp(useGoogleFonts: false, builder: app)
          : app(buildAppTheme(choice: choice, useGoogleFonts: false), null),
    );
  }
}
