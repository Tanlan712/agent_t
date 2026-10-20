import 'package:shared_preferences/shared_preferences.dart';

import '../models/seen_player.dart';
import 'prefs_json.dart';

class SeenPlayersStorage {
  static const _key = 'seen_players';

  final SharedPreferences _prefs;

  SeenPlayersStorage(this._prefs);

  List<SeenPlayer> load() => readPrefsJson(
        _prefs,
        _key,
        (json) => (json as List<dynamic>)
            .map((e) => SeenPlayer.fromJson(e as Map<String, dynamic>))
            .toList(),
        <SeenPlayer>[],
      );

  Future<void> save(List<SeenPlayer> players) =>
      writePrefsJson(_prefs, _key, players.map((e) => e.toJson()).toList());
}
