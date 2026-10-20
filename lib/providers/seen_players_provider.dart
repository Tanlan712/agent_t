import 'package:flutter/foundation.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../models/seen_player.dart';
import '../storage/seen_players_storage.dart';

/// 遇過的玩家（不含自己），依最後遇到的時間由新到舊，最多 [max] 位。
class SeenPlayersProvider with ChangeNotifier {
  final SeenPlayersStorage _storage;
  final int max;
  final DateTime Function() _now;
  List<SeenPlayer> _players;

  SeenPlayersProvider(this._storage,
      {this.max = 500, DateTime Function() now = DateTime.now})
      : _now = now,
        _players = _storage.load();

  List<SeenPlayer> get players => List.unmodifiable(_players);

  /// Riot ID 包含 [query]（不分大小寫）的玩家；空字串回傳全部。
  List<SeenPlayer> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return players;
    return _players.where((p) => p.riotId.toLowerCase().contains(q)).toList();
  }

  /// 記錄 [details] 裡除了自己以外的所有玩家；再次遇到時更新名稱與時間。
  /// 名稱查不到（未知玩家）時保留之前記下的名稱。
  Future<void> recordAll(Iterable<MatchDetail> details) async {
    final now = _now();
    final byId = {for (final p in _players) p.puuid: p};
    final touched = <SeenPlayer>[];
    for (final d in details) {
      for (final line in d.teams.values.expand((t) => t)) {
        if (line.isMe) continue;
        // 同一批裡先遇到的紀錄優先於已存的舊紀錄。
        final i = touched.indexWhere((p) => p.puuid == line.puuid);
        final earlier = i < 0 ? null : touched.removeAt(i);
        final stored = byId.remove(line.puuid);
        final old = earlier ?? stored;
        final known = line.riotId != unknownPlayerName;
        touched.add(SeenPlayer(
          puuid: line.puuid,
          riotId: known ? line.riotId : (old?.riotId ?? line.riotId),
          lastSeen: now,
          matchId: d.summary.matchId,
        ));
      }
    }
    if (touched.isEmpty) return;
    // 這次遇到的排最前面（後遇到的更前面），其餘維持原本的新舊順序。
    _players = [...touched.reversed, ...byId.values]
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    if (_players.length > max) _players = _players.sublist(0, max);
    await _save();
  }

  Future<void> remove(String puuid) async {
    _players = _players.where((p) => p.puuid != puuid).toList();
    await _save();
  }

  Future<void> clear() async {
    _players = [];
    await _save();
  }

  Future<void> _save() async {
    await _storage.save(_players);
    notifyListeners();
  }
}
