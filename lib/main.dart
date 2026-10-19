import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_page.dart';
import 'screens/agents_page.dart';
import 'screens/weapons_page.dart';
import 'screens/maps_page.dart';
import 'screens/bundles_page.dart';
import 'screens/gamemodes_page.dart';
import 'screens/playercards_page.dart';
import 'screens/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 載入環境變數 (如果 .env 不存在也不會報錯)
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    print('未找到 .env 檔案，使用預設設定');
  }

  runApp(const MyApp());
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
      },
    );
  }
}
