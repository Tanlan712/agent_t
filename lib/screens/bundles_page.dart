import 'package:flutter/material.dart';

import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import '../theme/app_theme.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';

class BundlesPage extends StatefulWidget {
  const BundlesPage({super.key});

  @override
  State<BundlesPage> createState() => _BundlesPageState();
}

class _BundlesPageState extends State<BundlesPage> {
  final ValorantApiService _apiService = ValorantApiService();
  List<Map<String, dynamic>> _bundles = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBundles();
  }

  Future<void> _loadBundles() async {
    try {
      final bundles = await _apiService.getBundles();
      setState(() {
        _bundles = bundles;
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
      currentRoute: '/bundles',
      title: '組合包',
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
                          _loadBundles();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : ResponsiveGridView.builder(
                  minTileWidth: 340,
                  childAspectRatio: 1.7,
                  itemCount: _bundles.length,
                  itemBuilder: (context, index) {
                    final bundle = _bundles[index];
                    return _buildBundleCard(bundle);
                  },
                ),
    );
  }

  Widget _buildBundleCard(Map<String, dynamic> bundle) {
    final displayName = bundle['displayName'] as String;
    final displayIcon = bundle['displayIcon'] as String?;

    const placeholder = ColoredBox(
      color: AppColors.surfaceHigh,
      child: Center(child: Icon(Icons.card_giftcard, size: 48)),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (displayIcon != null)
            Image.network(
              displayIcon,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => placeholder,
            )
          else
            placeholder,
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, AppColors.background],
                stops: [0.5, 1],
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 10,
            child: Text(
              displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
