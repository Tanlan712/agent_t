import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/match_models.dart';
import 'catalog_api.dart';
import 'valorant_api_client.dart';

/// 從 valorant-api.com 下載特務、地圖、牌位與賽季的顯示資料。
class MatchReferenceApi {
  static const _host = 'valorant-api.com';
  final http.Client _client;

  MatchReferenceApi({http.Client? client})
      : _client = client ?? valorantApiHttp;

  Future<MatchReference> fetch() async {
    final agents = await _data('/v1/agents', {'isPlayableCharacter': 'true'});
    final maps = await _data('/v1/maps');
    final tierSets = await _data('/v1/competitivetiers');
    // 賽季只用來顯示名稱與判斷本幕：下載失敗時留空，不影響其他資料。
    List<dynamic> seasons;
    try {
      seasons = await _data('/v1/seasons');
    } catch (_) {
      seasons = const [];
    }

    // 武器只用來顯示武器統計的名稱：下載失敗時留空。
    List<dynamic> weapons;
    try {
      weapons = await _data('/v1/weapons');
    } catch (_) {
      weapons = const [];
    }

    final lastSeason = tierSets.isEmpty
        ? const <dynamic>[]
        : (tierSets.last as Map<String, dynamic>)['tiers'] as List<dynamic>? ??
            const [];

    return MatchReference(
      agents: {
        for (final a in agents.cast<Map<String, dynamic>>())
          (a['uuid'] as String).toLowerCase(): RefItem(
              name: a['displayName'] as String,
              iconUrl: a['displayIcon'] as String?),
      },
      maps: {
        for (final m in maps.cast<Map<String, dynamic>>())
          if (m['mapUrl'] case final String url)
            url: RefItem(
                name: m['displayName'] as String,
                iconUrl: m['listViewIcon'] as String?),
      },
      tiers: {
        for (final t in lastSeason.cast<Map<String, dynamic>>())
          (t['tier'] as num).toInt(): RefItem(
              name: t['tierName'] as String,
              iconUrl: t['smallIcon'] as String?),
      },
      seasons: _seasons(seasons.whereType<Map<String, dynamic>>().toList()),
      weapons: {
        for (final w in weapons.whereType<Map<String, dynamic>>())
          if (w['uuid'] case final String id)
            id.toLowerCase(): RefItem(
                name: w['displayName'] as String? ?? '',
                iconUrl: w['killStreamIcon'] as String? ??
                    w['displayIcon'] as String?),
      },
      minimaps: {
        for (final m in maps.cast<Map<String, dynamic>>())
          if ((
            m['mapUrl'],
            m['displayIcon'],
            m['xMultiplier'],
            m['yMultiplier'],
            m['xScalarToAdd'],
            m['yScalarToAdd']
          )
              case (
                final String url,
                final String icon,
                final num xm,
                final num ym,
                final num xa,
                final num ya
              ))
            url: MinimapRef(
                imageUrl: icon,
                xMultiplier: xm.toDouble(),
                yMultiplier: ym.toDouble(),
                xScalarToAdd: xa.toDouble(),
                yScalarToAdd: ya.toDouble()),
      },
    );
  }

  /// 幕的名稱帶上層賽季，例如「V26 第六幕」；缺起訖日期的略過。
  static Map<String, SeasonRef> _seasons(List<Map<String, dynamic>> raw) {
    String id(Object? v) => (v as String? ?? '').toLowerCase();
    final names = {
      for (final s in raw) id(s['uuid']): s['displayName'] as String? ?? ''
    };
    return {
      for (final s in raw)
        if ((
          DateTime.tryParse(s['startTime'] as String? ?? ''),
          DateTime.tryParse(s['endTime'] as String? ?? '')
        )
            case (final start?, final end?))
          id(s['uuid']): SeasonRef(
            name: [
              if (names[id(s['parentUuid'])] case final p? when p.isNotEmpty) p,
              s['displayName'] as String? ?? '',
            ].join(' '),
            start: start,
            end: end,
            isAct: s['type'] == 'EAresSeasonType::Act',
          ),
    };
  }

  Future<List<dynamic>> _data(String path,
      [Map<String, String> query = const {}]) async {
    final res = await _client
        .get(Uri.https(_host, path, {...query, 'language': 'zh-TW'}));
    if (res.statusCode != 200) {
      throw CatalogFetchException('$path 回應 ${res.statusCode}');
    }
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return body['data'] as List<dynamic>;
  }
}
