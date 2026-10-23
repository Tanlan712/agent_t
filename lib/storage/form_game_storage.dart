import 'package:shared_preferences/shared_preferences.dart';

import '../providers/recent_form_loader.dart' show FormGame;
import 'prefs_json.dart';

/// 自己已結束場次的戰績摘要（不是整場 JSON），重開網頁時不必再抓 match-details。
/// 玩家 puuid → 場次 id → 摘要；每位最多 [maxPerPlayer] 場，超過時丟掉最舊的。
class FormGameStorage {
  static const _key = 'form_games_v1';
  static const maxPerPlayer = 60;

  final SharedPreferences _prefs;

  FormGameStorage(this._prefs);

  Map<String, FormGame> load(String puuid) => readPrefsJson(
        _prefs,
        _key,
        (json) => {
          for (final e
              in ((json as Map<String, dynamic>)[puuid] as List<dynamic>? ??
                      const [])
                  .cast<Map<String, dynamic>>())
            if (formGameFromJson(e) case final g?) g.matchId: g,
        },
        <String, FormGame>{},
      );

  /// 合併 [games] 到這位玩家的快取，依開始時間由新到舊保留。
  Future<void> save(String puuid, Iterable<FormGame> games) {
    final all = readPrefsJson<Map<String, dynamic>>(
        _prefs, _key, (json) => json as Map<String, dynamic>, {});
    final mine = load(puuid);
    for (final g in games) {
      mine[g.matchId] = g;
    }
    final epoch = DateTime.fromMillisecondsSinceEpoch(0);
    final sorted = mine.values.toList()
      ..sort((a, b) => (b.startTime ?? epoch).compareTo(a.startTime ?? epoch));
    all[puuid] = [for (final g in sorted.take(maxPerPlayer)) formGameToJson(g)];
    return writePrefsJson(_prefs, _key, all);
  }

  Future<void> clear() => _prefs.remove(_key);
}

Map<String, dynamic> formGameToJson(FormGame g) => {
      'm': g.matchId,
      if (g.won != null) 'w': g.won,
      'a': g.acs,
      'ag': g.agentId,
      'k': g.kills,
      'd': g.deaths,
      'as': g.assists,
      if (g.rating != null) 'r': g.rating,
      if (g.headshotPercent != null) 'h': g.headshotPercent,
      'q': g.queueId,
      if (g.startTime != null) 't': g.startTime!.toUtc().toIso8601String(),
      if (g.weaponKills.isNotEmpty) 'wk': g.weaponKills,
    };

FormGame? formGameFromJson(Map<String, dynamic> j) {
  final id = j['m'];
  if (id is! String || id.isEmpty) return null;
  return FormGame(
    matchId: id,
    won: j['w'] as bool?,
    acs: (j['a'] as num?)?.toInt() ?? 0,
    agentId: j['ag'] as String? ?? '',
    kills: (j['k'] as num?)?.toInt() ?? 0,
    deaths: (j['d'] as num?)?.toInt() ?? 0,
    assists: (j['as'] as num?)?.toInt() ?? 0,
    rating: (j['r'] as num?)?.toDouble(),
    headshotPercent: (j['h'] as num?)?.toDouble(),
    queueId: j['q'] as String? ?? '',
    startTime: DateTime.tryParse(j['t'] as String? ?? ''),
    weaponKills: {
      for (final e in (j['wk'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: (e.value as num).toInt(),
    },
  );
}
