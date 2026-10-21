import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';

class GamemodesPage extends StatefulWidget {
  /// 測試時注入。
  final ValorantApiService? api;

  const GamemodesPage({super.key, this.api});

  @override
  State<GamemodesPage> createState() => _GamemodesPageState();
}

class _GamemodesPageState extends State<GamemodesPage> {
  late final ValorantApiService _apiService =
      widget.api ?? ValorantApiService();
  List<Map<String, dynamic>> _gamemodes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGamemodes();
  }

  Future<void> _loadGamemodes() async {
    try {
      final gamemodes = await _apiService.getGamemodes();
      // 讀取完成前離開頁面時不要再更新畫面。
      if (!mounted) return;
      setState(() {
        _gamemodes = gamemodes;
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
      currentRoute: '/gamemodes',
      title: '遊戲模式',
      subtitle: _isLoading || _error != null ? null : '${_gamemodes.length} 種',
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
                          _loadGamemodes();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : ResponsiveGridView.builder(
                  minTileWidth: 260,
                  childAspectRatio: 1.8,
                  itemCount: _gamemodes.length,
                  itemBuilder: (context, index) {
                    final gamemode = _gamemodes[index];
                    return _buildGamemodeCard(gamemode);
                  },
                ),
    );
  }

  Widget _buildGamemodeCard(Map<String, dynamic> gamemode) {
    final displayName = gamemode['displayName'] as String;
    final displayIcon = gamemode['displayIcon'] as String?;
    final description = gamemode['description'] as String?;
    final duration = gamemode['duration'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 48,
              height: 48,
              child: displayIcon != null
                  // 官方圖示是白色：用文字顏色重新上色，淺色主題也看得到。
                  ? Image.network(
                      displayIcon,
                      key: ValueKey('mode-icon-${gamemode['uuid']}'),
                      color: AppColors.text,
                      colorBlendMode: BlendMode.srcIn,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.sports_esports, size: 40),
                    )
                  : const Icon(Icons.sports_esports, size: 40),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        description,
                        overflow: TextOverflow.fade,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                  if (duration != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '時長: $duration',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
