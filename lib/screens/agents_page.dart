import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

import '../shell/app_shell.dart';
import '../shell/responsive_grid.dart';
import 'package:valorant_shop_tracker/services/valorant_api_service.dart';

class AgentsPage extends StatefulWidget {
  const AgentsPage({super.key});

  @override
  State<AgentsPage> createState() => _AgentsPageState();
}

class _AgentsPageState extends State<AgentsPage> {
  final ValorantApiService _apiService = ValorantApiService();
  List<Map<String, dynamic>> _agents = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    try {
      final agents = await _apiService.getAgents();
      setState(() {
        _agents = agents;
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
      currentRoute: '/agents',
      title: '角色',
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
                          _loadAgents();
                        },
                        child: const Text('重試'),
                      ),
                    ],
                  ),
                )
              : ResponsiveGridView.builder(
                  minTileWidth: 140,
                  childAspectRatio: 0.75,
                  itemCount: _agents.length,
                  itemBuilder: (context, index) {
                    final agent = _agents[index];
                    return _buildAgentCard(agent);
                  },
                ),
    );
  }

  Widget _buildAgentCard(Map<String, dynamic> agent) {
    final displayName = agent['displayName'] as String;
    final role = agent['role'] as Map<String, dynamic>?;
    final displayIcon = agent['displayIcon'] as String?;
    final background = agent['background'] as String?;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (background != null)
                  Image.network(
                    background,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: AppColors.surfaceHigh,
                        child: const Icon(Icons.person, size: 64),
                      );
                    },
                  )
                else
                  Container(
                    color: AppColors.surfaceHigh,
                    child: const Icon(Icons.person, size: 64),
                  ),
                if (displayIcon != null)
                  Center(
                    child: Image.network(
                      displayIcon,
                      width: 80,
                      height: 80,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (role != null)
                  Text(
                    role['displayName'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
