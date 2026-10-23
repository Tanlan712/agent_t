import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../models/game_data.dart';
import '../shell/app_shell.dart';
import 'details/map_detail_page.dart';
import '../shell/responsive_grid.dart';
import 'package:agent_t/services/valorant_api_service.dart';

class MapsPage extends StatefulWidget {
  /// 測試時注入。
  final ValorantApiService? api;

  const MapsPage({super.key, this.api});

  @override
  State<MapsPage> createState() => _MapsPageState();
}

class _MapsPageState extends State<MapsPage> {
  late final ValorantApiService _apiService =
      widget.api ?? ValorantApiService();
  List<Map<String, dynamic>> _maps = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMaps();
  }

  Future<void> _loadMaps() async {
    try {
      final maps = await _apiService.getMaps();
      // 讀取完成前離開頁面時不要再更新畫面。
      if (!mounted) return;
      setState(() {
        _maps = maps;
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
      currentRoute: '/maps',
      title: '地圖',
      subtitle: _isLoading || _error != null ? null : '${_maps.length} 張',
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
                          _loadMaps();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : ResponsiveGridView.builder(
                  minTileWidth: 260,
                  childAspectRatio: 1.6,
                  itemCount: _maps.length,
                  itemBuilder: (context, index) {
                    final map = _maps[index];
                    return _buildMapCard(map);
                  },
                ),
    );
  }

  Widget _buildMapCard(Map<String, dynamic> map) {
    final displayName = map['displayName'] as String;
    final splash = map['splash'] as String?;
    final coordinates = map['coordinates'] as String?;

    return Card(
      key: ValueKey('db-map-${map['uuid']}'),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
                builder: (_) => MapDetailPage(map: MapInfo.fromJson(map)))),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (splash != null)
              Image.network(
                splash,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.surfaceHigh,
                    child: const Icon(Icons.map, size: 64),
                  );
                },
              )
            else
              Container(
                color: AppColors.surfaceHigh,
                child: const Icon(Icons.map, size: 64),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (coordinates != null)
                      Text(
                        coordinates,
                        // 疊在深色漸層上：和地圖名稱一樣用白色，淺色主題也看得清楚。
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.75),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
