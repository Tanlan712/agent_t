import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorant_shop_tracker/app_routes.dart';
import 'package:valorant_shop_tracker/models/current_shop.dart';
import 'package:valorant_shop_tracker/models/wishlist_item.dart';
import 'package:valorant_shop_tracker/providers/catalog_provider.dart';
import 'package:valorant_shop_tracker/providers/riot_provider.dart';
import 'package:valorant_shop_tracker/providers/settings_provider.dart';
import 'package:valorant_shop_tracker/providers/shop_provider.dart';
import 'package:valorant_shop_tracker/providers/wishlist_provider.dart';
import 'package:valorant_shop_tracker/services/riot_client.dart';
import 'package:valorant_shop_tracker/storage/settings_storage.dart';
import 'package:valorant_shop_tracker/storage/shop_storage.dart';
import 'package:valorant_shop_tracker/storage/wishlist_storage.dart';

import 'catalog_helpers.dart';
import 'riot_fixtures.dart';

/// 測試用的整組 providers，已預先寫入商店／願望清單資料。
class Harness {
  final CatalogProvider catalog;
  final ShopProvider shop;
  final WishlistProvider wishlist;
  final SettingsProvider settings;
  final RiotProvider riot;
  final SharedPreferences prefs;

  Harness(this.catalog, this.shop, this.wishlist, this.settings, this.riot,
      this.prefs);

  static Future<Harness> create(
    WidgetTester tester, {
    CurrentShop shop = const CurrentShop(),
    List<String> wishlist = const [],
    CatalogProvider? catalog,
  }) async {
    final c = catalog ?? await loadedCatalog(tester);
    final prefs = await SharedPreferences.getInstance();
    await ShopStorage(prefs).save(shop);
    await WishlistStorage(prefs).save([
      for (final id in wishlist)
        WishlistItem(skinUuid: id, addedAt: DateTime(2026, 10, 1)),
    ]);
    return Harness(
      c,
      ShopProvider(ShopStorage(prefs)),
      WishlistProvider(WishlistStorage(prefs)),
      SettingsProvider(SettingsStorage(prefs)),
      RiotProvider(RiotClient(client: riotClient())),
      prefs,
    );
  }

  /// [useAppRoutes] 為 true 時改用 App 的路由表（`onGenerateAppRoute`），從 `/` 開始。
  Widget wrap({
    Widget? home,
    Map<String, WidgetBuilder> routes = const {},
    RouteFactory? onGenerateRoute,
    bool useAppRoutes = false,
    List<NavigatorObserver> observers = const [],
  }) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider.value(value: shop),
        ChangeNotifierProvider.value(value: wishlist),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: riot),
      ],
      child: useAppRoutes
          ? MaterialApp(
              onGenerateRoute: onGenerateAppRoute,
              navigatorObservers: observers,
            )
          : MaterialApp(
              home: home,
              routes: routes,
              onGenerateRoute: onGenerateRoute,
              navigatorObservers: observers,
            ),
    );
  }
}
