import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';

class WeaponsPage extends StatefulWidget {
  const WeaponsPage({super.key});

  @override
  State<WeaponsPage> createState() => _WeaponsPageState();
}

class _WeaponsPageState extends State<WeaponsPage> {
  final ValorantApiService _apiService = ValorantApiService();
  List<Map<String, dynamic>> _weapons = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWeapons();
  }

  Future<void> _loadWeapons() async {
    try {
      final weapons = await _apiService.getWeapons();
      setState(() {
        _weapons = weapons;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      currentRoute: '/weapons',
      title: '武器',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('載入失敗: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadWeapons();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : ResponsiveGridView.builder(
                  minTileWidth: 200,
                  childAspectRatio: 1.4,
                  itemCount: _weapons.length,
                  itemBuilder: (context, index) {
                    final weapon = _weapons[index];
                    return _buildWeaponCard(weapon);
                  },
                ),
    );
  }

  Widget _buildWeaponCard(Map<String, dynamic> weapon) {
    final displayName = weapon['displayName'] as String;
    final displayIcon = weapon['displayIcon'] as String?;
    final shopData = weapon['shopData'] as Map<String, dynamic>?;
    final cost = shopData?['cost'] as int? ?? 0;
    final category = shopData?['category'] as String? ?? '未知';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: displayIcon != null
                    ? Image.network(
                        displayIcon,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.track_changes, size: 40),
                      )
                    : const Icon(Icons.track_changes, size: 40),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  cost > 0 ? '\$$cost' : '免費',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            Text(
              category,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
