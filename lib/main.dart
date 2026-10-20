import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/catalog_provider.dart';
import 'providers/riot_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/shop_provider.dart';
import 'providers/wishlist_provider.dart';
import 'app_routes.dart';
import 'services/catalog_api.dart';
import 'services/riot_client.dart';
import 'storage/catalog_cache.dart';
import 'storage/settings_storage.dart';
import 'storage/shop_storage.dart';
import 'storage/wishlist_storage.dart';
import 'theme/app_theme.dart';

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
      title: 'VALORANT 商店追蹤',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      onGenerateRoute: onGenerateAppRoute,
    );
  }
}
