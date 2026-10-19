import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('VALORANT 資料庫'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'API 設定',
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        children: [
          _buildCategoryCard(
            context,
            title: '角色',
            icon: Icons.person,
            color: Colors.red,
            route: '/agents',
          ),
          _buildCategoryCard(
            context,
            title: '武器',
            icon: Icons.track_changes,
            color: Colors.orange,
            route: '/weapons',
          ),
          _buildCategoryCard(
            context,
            title: '地圖',
            icon: Icons.map,
            color: Colors.blue,
            route: '/maps',
          ),
          _buildCategoryCard(
            context,
            title: '組合包',
            icon: Icons.card_giftcard,
            color: Colors.purple,
            route: '/bundles',
          ),
          _buildCategoryCard(
            context,
            title: '遊戲模式',
            icon: Icons.sports_esports,
            color: Colors.green,
            route: '/gamemodes',
          ),
          _buildCategoryCard(
            context,
            title: '玩家卡片',
            icon: Icons.badge,
            color: Colors.teal,
            route: '/playercards',
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => Navigator.pushNamed(context, route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: color,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
