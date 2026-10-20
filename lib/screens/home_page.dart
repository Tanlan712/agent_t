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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _buildFeatureCard(context,
                    title: '我的商店', icon: Icons.storefront, route: '/my-shop'),
                const SizedBox(width: 16),
                _buildFeatureCard(context,
                    title: '願望清單', icon: Icons.star, route: '/wishlist'),
              ],
            ),
          ),
          Expanded(child: _buildBrowseGrid(context)),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String route,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        color: scheme.primaryContainer,
        elevation: 4,
        child: InkWell(
          onTap: () => Navigator.pushNamed(context, route),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(icon, size: 40, color: scheme.onPrimaryContainer),
                const SizedBox(height: 8),
                Text(title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: scheme.onPrimaryContainer)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBrowseGrid(BuildContext context) {
    return GridView.count(
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
