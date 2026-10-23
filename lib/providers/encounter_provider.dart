import 'package:flutter/foundation.dart';

import '../logic/encounters.dart';
import '../models/encounter.dart';
import '../models/match_models.dart';
import '../storage/encounter_storage.dart';

/// 和自己同場打過的玩家（使用者決定 2026-10-23，AGENTS.md 第 2 節）：
/// 即時對局用來標示「遇過」。只存在這個瀏覽器／這支手機，各帳號分開；
/// 只記場次、地圖、隊友或對手與勝負，不記名稱。
class EncounterProvider with ChangeNotifier {
  final EncounterStorage _storage;

  /// 每個帳號最多記幾位玩家（最近遇到的優先保留）。
  final int maxPlayers;

  /// 每位玩家最多記幾場。
  final int maxPerPlayer;

  EncounterBook _book;

  EncounterProvider(this._storage,
      {this.maxPlayers = 1000, this.maxPerPlayer = 5})
      : _book = _storage.load();

  /// [self] 和 [puuid] 同場的紀錄，由新到舊；[exclude] 通常是正在進行的這場。
  List<Encounter> withPlayer(String self, String puuid, {String? exclude}) => [
        for (final e in _book[self]?[puuid] ?? const <Encounter>[])
          if (e.matchId != exclude) e,
      ];

  /// 從已載入的場次詳情記錄（只有自己在場的才算）；同一場重複記錄會略過。
  Future<void> recordAll(Iterable<MatchDetail> details) async {
    final touched = <String>{};
    for (final d in details) {
      final found = encountersIn(d);
      if (found.isEmpty) continue;
      final self =
          d.teams.values.expand((t) => t).firstWhere((l) => l.isMe).puuid;
      final players = _book[self] ??= {};
      for (final MapEntry(key: puuid, value: e) in found.entries) {
        final list = players[puuid] ??= [];
        if (list.any((x) => x.matchId == e.matchId)) continue;
        list
          ..add(e)
          ..sort((a, b) => b.startTime.compareTo(a.startTime));
        if (list.length > maxPerPlayer) {
          list.removeRange(maxPerPlayer, list.length);
        }
        // 比保留的場次都舊而被刪掉時不算變更。
        if (list.contains(e)) touched.add(self);
      }
    }
    if (touched.isEmpty) return;
    for (final self in touched) {
      final players = _book[self]!;
      if (players.length <= maxPlayers) continue;
      final keep = players.entries.toList()
        ..sort((a, b) =>
            b.value.first.startTime.compareTo(a.value.first.startTime));
      _book[self] = Map.fromEntries(keep.take(maxPlayers));
    }
    await _storage.save(_book);
    notifyListeners();
  }

  Future<void> clear() async {
    _book = {};
    await _storage.clear();
    notifyListeners();
  }
}
