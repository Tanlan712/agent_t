import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/catalog_provider.dart';
import 'providers/riot_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/wishlist_provider.dart';
import 'screens/agents_page.dart';
import 'screens/bundles_page.dart';
import 'screens/gamemodes_page.dart';
import 'screens/home_page.dart';
import 'screens/maps_page.dart';
import 'screens/my_shop_page.dart';
import 'screens/playercards_page.dart';
import 'screens/riot_login_page.dart';
import 'screens/settings_page.dart';
import 'screens/shop_edit_page.dart';
import 'screens/skin_picker_page.dart';
import 'screens/weapons_page.dart';
import 'screens/wishlist_page.dart';
import 'services/catalog_api.dart';
import 'services/riot_client.dart';
import 'storage/catalog_cache.dart';
import 'storage/settings_storage.dart';
import 'storage/shop_storage.dart';
import 'storage/wishlist_storage.dart';

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

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: catalog),
        ChangeNotifierProvider(create: (_) => ShopProvider(ShopStorage(prefs))),
        ChangeNotifierProvider(
            create: (_) => WishlistProvider(WishlistStorage(prefs))),
        ChangeNotifierProvider(
            create: (_) => SettingsProvider(SettingsStorage(prefs))),
        ChangeNotifierProvider(create: (_) => RiotProvider(RiotClient())),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VALORANT 資料庫',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomePage(),
      routes: {
        '/agents': (context) => const AgentsPage(),
        '/weapons': (context) => const WeaponsPage(),
        '/maps': (context) => const MapsPage(),
        '/bundles': (context) => const BundlesPage(),
        '/gamemodes': (context) => const GamemodesPage(),
        '/playercards': (context) => const PlayerCardsPage(),
        '/settings': (context) => const SettingsPage(),
        '/my-shop': (context) => const MyShopPage(),
        '/wishlist': (context) => const WishlistPage(),
        '/skin-picker': (context) => const SkinPickerPage(),
        '/riot-login': (context) => const RiotLoginPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/my-shop/edit') {
          final section =
              settings.arguments as ShopSection? ?? ShopSection.daily;
          return MaterialPageRoute(
            builder: (_) => ShopEditPage(section: section),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
