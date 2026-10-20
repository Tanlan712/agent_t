import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';

class GamemodesPage extends StatefulWidget {
  const GamemodesPage({super.key});

  @override
  State<GamemodesPage> createState() => _GamemodesPageState();
}

class _GamemodesPageState extends State<GamemodesPage> {
  final ValorantApiService _apiService = ValorantApiService();
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
      setState(() {
        _gamemodes = gamemodes;
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
      currentRoute: '/gamemodes',
      title: '遊戲模式',
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
                          _loadGamemodes();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: displayIcon != null
            ? Image.network(
                displayIcon,
                width: 60,
                height: 60,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.sports_esports, size: 40);
                },
              )
            : const Icon(Icons.sports_esports, size: 40),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null) ...[
              const SizedBox(height: 4),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (duration != null) ...[
              const SizedBox(height: 4),
              Text(
                '時長: $duration',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        isThreeLine: description != null,
      ),
    );
  }
}
