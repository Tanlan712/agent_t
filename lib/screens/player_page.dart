import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/match_models.dart';
import '../providers/encounter_provider.dart';
import '../providers/match_detail_cache.dart';
import '../providers/player_history_provider.dart';
import '../providers/riot_provider.dart';
import '../providers/seen_players_provider.dart';
import '../services/match_client.dart';
import 'match_history_page.dart' show MatchHistoryBody;

/// 其他玩家的對戰紀錄：牌位與 RR、KPI、各模式戰績、走勢、篩選與統計，
/// 版面與自己的對戰紀錄相同。資料只放在記憶體，離開頁面即釋放。
class PlayerPage extends StatefulWidget {
  final PlayerRef player;
  final DateTime Function() now;

  const PlayerPage({super.key, required this.player, this.now = DateTime.now});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final PlayerHistoryProvider _history;

  @override
  void initState() {
    super.initState();
    _history = PlayerHistoryProvider(context.read<MatchClient>(),
        context.read<RiotProvider>(), context.read<MatchDetailCache>(),
        puuid: widget.player.puuid, onDetails: (details) {
      context.read<SeenPlayersProvider>().recordAll(details);
      // 對方的場次裡有自己時，也算遇過（AGENTS.md 第 2 節）。
      context.read<EncounterProvider>().recordAll(details);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _history.loadFirstPage();
    });
  }

  @override
  void dispose() {
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.player.riotId)),
      body: ListenableBuilder(
        listenable: _history,
        builder: (context, _) => MatchHistoryBody(
            history: _history, otherPlayer: true, now: widget.now),
      ),
    );
  }
}
