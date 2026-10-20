import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/match_models.dart';
import 'catalog_api.dart';

/// 從 valorant-api.com 下載特務、地圖、牌位的顯示資料。
class MatchReferenceApi {
  static const _host = 'valorant-api.com';
  final http.Client _client;

  MatchReferenceApi({http.Client? client}) : _client = client ?? http.Client();

  Future<MatchReference> fetch() async {
    final agents = await _data('/v1/agents', {'isPlayableCharacter': 'true'});
    final maps = await _data('/v1/maps');
    final tierSets = await _data('/v1/competitivetiers');

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
    );
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
