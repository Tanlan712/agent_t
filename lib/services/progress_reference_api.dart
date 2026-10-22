import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/match_models.dart' show RefItem;
import '../models/progress_reference.dart';
import 'catalog_api.dart';

/// 從 valorant-api.com 下載收藏、通行證、任務的顯示資料（公開資料，依序請求）。
class ProgressReferenceApi {
  static const _host = 'valorant-api.com';
  final http.Client _client;

  ProgressReferenceApi({http.Client? client})
      : _client = client ?? http.Client();

  Future<ProgressReference> fetch() async {
    final weapons = await _data('/v1/weapons');
    final agents = await _data('/v1/agents', {'isPlayableCharacter': 'true'});
    final buddies = await _data('/v1/buddies');
    final sprays = await _data('/v1/sprays');
    final cards = await _data('/v1/playercards');
    final titles = await _data('/v1/playertitles');
    final contracts = await _data('/v1/contracts');
    final seasons = await _data('/v1/seasons');
    final missions = await _data('/v1/missions');
    final currencies = await _data('/v1/currencies');

    final weaponList = <RefWeapon>[];
    final skinLevels = <String, RefSkinLevel>{};
    final chromas = <String, RefChroma>{};
    for (final w in weapons) {
      final weaponName = w['displayName'] as String? ?? '';
      final weaponUuid = _id(w['uuid']);
      weaponList.add(RefWeapon(
          uuid: weaponUuid,
          name: weaponName,
          iconUrl: w['displayIcon'] as String?,
          category: w['category'] as String? ?? '',
          categoryText: switch (w['shopData']) {
            {'categoryText': final String t} when t.isNotEmpty => t,
            _ => null,
          }));
      for (final skin in (w['skins'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>()) {
        final skinUuid = _id(skin['uuid']);
        final skinName = skin['displayName'] as String? ?? '';
        final levels = (skin['levels'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        for (var i = 0; i < levels.length; i++) {
          skinLevels[_id(levels[i]['uuid'])] = RefSkinLevel(
            skinUuid: skinUuid,
            skinName: skinName,
            weaponName: weaponName,
            weaponUuid: weaponUuid,
            levelIndex: i,
            iconUrl: levels[i]['displayIcon'] as String? ??
                skin['displayIcon'] as String?,
            videoUrl: levels[i]['streamedVideo'] as String?,
          );
        }
        final skinChromas = (skin['chromas'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        for (var i = 0; i < skinChromas.length; i++) {
          final c = skinChromas[i];
          chromas[_id(c['uuid'])] = RefChroma(
              skinUuid: skinUuid,
              swatchUrl: c['swatch'] as String?,
              iconUrl:
                  c['fullRender'] as String? ?? c['displayIcon'] as String?,
              index: i);
        }
      }
    }

    return ProgressReference(
      weapons: weaponList,
      skinLevels: skinLevels,
      chromas: chromas,
      agents: {
        for (final a in agents)
          _id(a['uuid']): RefAgent(
            uuid: _id(a['uuid']),
            name: a['displayName'] as String? ?? '',
            iconUrl: a['displayIcon'] as String?,
            role: (a['role'] as Map<String, dynamic>?)?['displayName']
                    as String? ??
                '',
            isBase: a['isBaseContent'] == true,
          ),
      },
      buddyLevels: {
        for (final b in buddies)
          for (final l in (b['levels'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>())
            _id(l['uuid']): RefItem(
                name: b['displayName'] as String? ?? '',
                iconUrl: b['displayIcon'] as String?),
      },
      sprays: {
        for (final s in sprays)
          _id(s['uuid']): RefItem(
              name: s['displayName'] as String? ?? '',
              iconUrl: s['displayIcon'] as String?),
      },
      cards: {
        for (final c in cards)
          _id(c['uuid']): RefItem(
              name: c['displayName'] as String? ?? '',
              iconUrl: c['smallArt'] as String?),
      },
      titles: {
        for (final t in titles)
          _id(t['uuid']): RefItem(
              name: t['titleText'] as String? ??
                  t['displayName'] as String? ??
                  ''),
      },
      currencies: {
        for (final c in currencies)
          _id(c['uuid']): RefItem(
              name: c['displayName'] as String? ?? '',
              iconUrl: c['displayIcon'] as String?),
      },
      contracts: {for (final c in contracts) _id(c['uuid']): _contract(c)},
      seasons: {
        for (final s in seasons)
          if (DateTime.tryParse(s['startTime'] as String? ?? '')
              case final start?)
            if (DateTime.tryParse(s['endTime'] as String? ?? '')
                case final end?)
              _id(s['uuid']): RefSeason(
                  name: s['displayName'] as String? ?? '',
                  start: start,
                  end: end),
      },
      missions: {
        for (final m in missions)
          _id(m['uuid']): RefMission(
            title: m['title'] as String? ?? m['displayName'] as String? ?? '',
            kind: _kind(m['type'] as String?),
            xpGrant: (m['xpGrant'] as num?)?.toInt() ?? 0,
            target: ((m['progressToComplete'] as num?)?.toInt() ?? 0)
                .clamp(1, 1 << 30),
          ),
      },
    );
  }

  static String _id(Object? v) => (v as String? ?? '').toLowerCase();

  static MissionKind _kind(String? type) => switch (type) {
        final t? when t.contains('Daily') => MissionKind.daily,
        final t? when t.contains('Weekly') => MissionKind.weekly,
        _ => MissionKind.other,
      };

  static RefReward _reward(Map<String, dynamic> r) => RefReward(
        type: r['type'] as String? ?? '',
        uuid: _id(r['uuid']),
        amount: (r['amount'] as num?)?.toInt() ?? 1,
      );

  /// 依序攤平所有章節的階級；章節的免費獎勵掛在該章最後一階。
  static RefContract _contract(Map<String, dynamic> c) {
    final content = c['content'] as Map<String, dynamic>? ?? const {};
    final tiers = <RefTier>[];
    final chapters = <RefChapter>[];
    for (final ch in (content['chapters'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>()) {
      final levels = (ch['levels'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      final free = [
        for (final r in (ch['freeRewards'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>())
          _reward(r),
      ];
      final chapterTiers = <RefTier>[];
      for (var i = 0; i < levels.length; i++) {
        chapterTiers.add(RefTier(
          reward:
              _reward(levels[i]['reward'] as Map<String, dynamic>? ?? const {}),
          xp: (levels[i]['xp'] as num?)?.toInt() ?? 0,
          freeRewards: i == levels.length - 1 ? free : const [],
        ));
      }
      tiers.addAll(chapterTiers);
      chapters.add(RefChapter(
          tiers: chapterTiers,
          freeRewards: free,
          isEpilogue: ch['isEpilogue'] == true));
    }
    return RefContract(
      name: c['displayName'] as String? ?? '',
      relationType: content['relationType'] as String? ?? '',
      relationUuid: _id(content['relationUuid']),
      tiers: tiers,
      chapters: chapters,
    );
  }

  Future<List<Map<String, dynamic>>> _data(String path,
      [Map<String, String> query = const {}]) async {
    final http.Response res;
    try {
      res = await _client
          .get(Uri.https(_host, path, {...query, 'language': 'zh-TW'}));
    } catch (_) {
      throw CatalogFetchException('$path 連線失敗');
    }
    if (res.statusCode != 200) {
      throw CatalogFetchException('$path 回應 ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return (body['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
  }
}
