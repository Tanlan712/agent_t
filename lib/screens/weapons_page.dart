import 'package:flutter/material.dart';

import '../logic/database_logic.dart';
import '../models/game_data.dart';
import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';
import '../widgets/hud/hud.dart';
import 'details/weapon_detail_page.dart';

class WeaponsPage extends StatefulWidget {
  /// 測試時注入。
  final ValorantApiService? api;

  const WeaponsPage({super.key, this.api});

  @override
  State<WeaponsPage> createState() => _WeaponsPageState();
}

class _WeaponsPageState extends State<WeaponsPage> {
  late final ValorantApiService _apiService =
      widget.api ?? ValorantApiService();
  List<WeaponInfo> _weapons = [];
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
      // 讀取完成前離開頁面時不要再更新畫面。
      if (!mounted) return;
      setState(() {
        _weapons = [for (final w in weapons) WeaponInfo.fromJson(w)];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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
      subtitle: _isLoading || _error != null ? null : '${_weapons.length} 把',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, size: 64, color: AppColors.error),
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
              : ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    for (final section in weaponSections(_weapons)) ...[
                      SectionHeader(
                        title: section.label,
                        trailing: Text('${section.weapons.length} 把',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                      ResponsiveGrid(
                        minTileWidth: 200,
                        childAspectRatio: 1.4,
                        children: [
                          for (final w in section.weapons)
                            _buildWeaponCard(w, section.label),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
    );
  }

  Widget _buildWeaponCard(WeaponInfo weapon, String categoryLabel) {
    return Card(
      key: ValueKey('db-weapon-${weapon.uuid}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => WeaponDetailPage(
                    weapon: weapon, categoryLabel: categoryLabel))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: weapon.icon != null
                      ? Image.network(
                          weapon.icon!,
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
                      weapon.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    weapon.cost > 0 ? '\$${weapon.cost}' : '免費',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
