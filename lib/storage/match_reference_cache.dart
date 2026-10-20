import 'package:shared_preferences/shared_preferences.dart';

import '../models/match_models.dart';
import 'prefs_json.dart';

class MatchReferenceCache {
  static const _key = 'match_reference_v1';

  final SharedPreferences _prefs;

  MatchReferenceCache(this._prefs);

  MatchReference? load() => readPrefsJson<MatchReference?>(
        _prefs,
        _key,
        (json) => MatchReference.fromJson(json as Map<String, dynamic>),
        null,
      );

  Future<void> save(MatchReference reference) =>
      writePrefsJson(_prefs, _key, reference.toJson());
}
