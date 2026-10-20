import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';

class PlayerCardsPage extends StatefulWidget {
  const PlayerCardsPage({super.key});

  @override
  State<PlayerCardsPage> createState() => _PlayerCardsPageState();
}

class _PlayerCardsPageState extends State<PlayerCardsPage> {
  final ValorantApiService _apiService = ValorantApiService();
  List<Map<String, dynamic>> _playerCards = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPlayerCards();
  }

  Future<void> _loadPlayerCards() async {
    try {
      final cards = await _apiService.getPlayerCards();
      setState(() {
        _playerCards = cards;
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
      currentRoute: '/playercards',
      title: '玩家卡片',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text('載入失敗: $_error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _error = null;
                          });
                          _loadPlayerCards();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : ResponsiveGridView.builder(
                  minTileWidth: 200,
                  childAspectRatio: 0.6,
                  itemCount: _playerCards.length,
                  itemBuilder: (context, index) {
                    final card = _playerCards[index];
                    return _buildPlayerCardWidget(card);
                  },
                ),
    );
  }

  Widget _buildPlayerCardWidget(Map<String, dynamic> card) {
    final displayName = card['displayName'] as String;
    final largeArt = card['largeArt'] as String?;
    final smallArt = card['smallArt'] as String?;
    final wideArt = card['wideArt'] as String?;

    final imageUrl = wideArt ?? largeArt ?? smallArt;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl != null)
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.surfaceHigh,
                  child: const Icon(Icons.badge, size: 64),
                );
              },
            )
          else
            Container(
              color: AppColors.surfaceHigh,
              child: const Icon(Icons.badge, size: 64),
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
              child: Text(
                displayName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
