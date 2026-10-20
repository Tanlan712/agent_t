import 'package:flutter/foundation.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../models/seen_player.dart';
import '../storage/seen_players_storage.dart';

/// 遇過的玩家（不含自己），依最後遇到的時間由新到舊，最多 [max] 位。
class SeenPlayersProvider with ChangeNotifier {
  final SeenPlayersStorage _storage;
  final int max;
  List<SeenPlayer> _players;

  SeenPlayersProvider(this._storage, {this.max = 500})
      : _players = _storage.load();

  List<SeenPlayer> get players => List.unmodifiable(_players);

  /// Riot ID 包含 [query]（不分大小寫）的玩家；空字串回傳全部。
  List<SeenPlayer> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return players;
    return _players.where((p) => p.riotId.toLowerCase().contains(q)).toList();
  }

  /// 記錄 [details] 裡除了自己以外的所有玩家，時間用該場的開始時間。
  /// 較新的場次才會更新名稱、時間與場次；名稱查不到（未知玩家）時保留舊名稱。
  Future<void> recordAll(Iterable<MatchDetail> details) async {
    final byId = {for (final p in _players) p.puuid: p};
    var changed = false;
    for (final d in details) {
      final at = d.summary.startTime;
      for (final line in d.teams.values.expand((t) => t)) {
        if (line.isMe) continue;
        final old = byId[line.puuid];
        final known = line.riotId != unknownPlayerName;
        if (old != null && old.lastSeen.isAfter(at)) {
          // 較舊的場次：只在舊紀錄沒有名稱時補上名稱。
          if (known && old.riotId == unknownPlayerName) {
            byId[line.puuid] = SeenPlayer(
                puuid: old.puuid,
                riotId: line.riotId,
                lastSeen: old.lastSeen,
                matchId: old.matchId);
            changed = true;
          }
          continue;
        }
        byId[line.puuid] = SeenPlayer(
          puuid: line.puuid,
          riotId: known ? line.riotId : (old?.riotId ?? line.riotId),
          lastSeen: at,
          matchId: d.summary.matchId,
        );
        changed = true;
      }
    }
    if (!changed) return;
    _players = byId.values.toList()
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
