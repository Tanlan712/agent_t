import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import 'package:agent_t/services/valorant_api_service.dart';

class PlayerCardsPage extends StatefulWidget {
  /// 測試時注入。
  final ValorantApiService? api;

  const PlayerCardsPage({super.key, this.api});

  @override
  State<PlayerCardsPage> createState() => _PlayerCardsPageState();
}

class _PlayerCardsPageState extends State<PlayerCardsPage> {
  late final ValorantApiService _apiService =
      widget.api ?? ValorantApiService();
  List<Map<String, dynamic>> _playerCards = [];
  String _query = '';
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
      // 讀取完成前離開頁面時不要再更新畫面。
      if (!mounted) return;
      setState(() {
        _playerCards = cards;
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
      currentRoute: '/playercards',
      title: '玩家卡片',
      subtitle:
          _isLoading || _error != null ? null : '${_playerCards.length} 張',
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
                          _loadPlayerCards();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('playercard-search'),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: '搜尋卡片名稱',
                              isDense: true,
                            ),
                            onChanged: (v) => setState(() => _query = v.trim()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('${_filtered.length} / ${_playerCards.length} 張',
                            style: TextStyle(color: AppColors.muted)),
                      ]),
                    ),
                    Expanded(
                      // 直式卡面：手機一列 3 張，寬螢幕更多。
                      child: ResponsiveGridView.builder(
                        minTileWidth: 88,
                        childAspectRatio: 0.45,
                        itemCount: _filtered.length,
                        itemBuilder: (context, index) =>
                            _buildPlayerCardWidget(_filtered[index]),
                      ),
                    ),
                  ],
                ),
    );
  }

  List<Map<String, dynamic>> get _filtered => _query.isEmpty
      ? _playerCards
      : [
          for (final c in _playerCards)
            if ((c['displayName'] as String? ?? '')
                .toLowerCase()
                .contains(_query.toLowerCase()))
              c
        ];

  Widget _buildPlayerCardWidget(Map<String, dynamic> card) {
    final displayName = card['displayName'] as String;
    final largeArt = card['largeArt'] as String?;
    final smallArt = card['smallArt'] as String?;
    final wideArt = card['wideArt'] as String?;

    // 直式網格用直式大圖。
    final imageUrl = largeArt ?? smallArt ?? wideArt;

    return Card(
      key: ValueKey('card-${card['uuid']}'),
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
