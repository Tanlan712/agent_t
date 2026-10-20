import 'package:shared_preferences/shared_preferences.dart';

import '../models/seen_player.dart';
import 'prefs_json.dart';

class SeenPlayersStorage {
  static const _key = 'seen_players_v2';

  /// 第一版記的是載入時間，不是場次時間。
  static const _legacyKey = 'seen_players';

  final SharedPreferences _prefs;

  SeenPlayersStorage(this._prefs);

  List<SeenPlayer> load() {
    if (_prefs.containsKey(_key) || !_prefs.containsKey(_legacyKey)) {
      return _read(_key);
    }
    // 轉移舊資料：保留玩家，時間改成未知；寫入新 key 後才移除舊 key。
    final migrated = [
      for (final p in _read(_legacyKey))
        SeenPlayer(
            puuid: p.puuid,
            riotId: p.riotId,
            lastSeen: SeenPlayer.unknownTime,
            matchId: p.matchId),
    ];
    save(migrated).then((_) => _prefs.remove(_legacyKey));
    return migrated;
  }

  List<SeenPlayer> _read(String key) => readPrefsJson(
        _prefs,
        key,
        (json) => (json as List<dynamic>)
            .map((e) => SeenPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        <SeenPlayer>[],
      );

  Future<void> save(List<SeenPlayer> players) =>
      writePrefsJson(_prefs, _key, players.map((e) => e.toJson()).toList());
}
