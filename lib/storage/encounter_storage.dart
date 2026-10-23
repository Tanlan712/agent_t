import 'package:shared_preferences/shared_preferences.dart';

import '../models/encounter.dart';
import 'prefs_json.dart';

/// 自己的 puuid → 對方 puuid → 同場紀錄（由新到舊）。
typedef EncounterBook = Map<String, Map<String, List<Encounter>>>;

class EncounterStorage {
  static const _key = 'encounters_v1';

  final SharedPreferences _prefs;

  EncounterStorage(this._prefs);

  EncounterBook load() => readPrefsJson(
        _prefs,
        _key,
        (json) => {
          for (final self in (json as Map<String, dynamic>).entries)
            self.key: {
              for (final p in (self.value as Map<String, dynamic>).entries)
                p.key: [
                  for (final e in p.value as List<dynamic>)
                    Encounter.fromJson(e as Map<String, dynamic>)
                ],
            },
        },
        <String, Map<String, List<Encounter>>>{},
      );

  Future<void> save(EncounterBook book) => writePrefsJson(_prefs, _key, {
        for (final self in book.entries)
          self.key: {
            for (final p in self.value.entries)
              p.key: [for (final e in p.value) e.toJson()],
          },
      });

  Future<void> clear() => _prefs.remove(_key);
}
