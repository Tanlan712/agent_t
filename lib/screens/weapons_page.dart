import 'package:flutter/material.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('武器'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: displayIcon != null
            ? Image.network(
                displayIcon,
                width: 60,
                height: 60,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.track_changes, size: 40);
                },
              )
            : const Icon(Icons.track_changes, size: 40),
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(category),
        trailing: cost > 0
            ? Chip(
                label: Text(
                  '$cost',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: Colors.orange[100],
              )
            : const Chip(
                label: Text('免費'),
                backgroundColor: Colors.green,
              ),
      ),
    );
  }
}
