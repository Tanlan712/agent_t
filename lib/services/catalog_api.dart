import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/bundle_info.dart';
import '../models/skin_catalog.dart';
import '../models/skin_info.dart';
import '../models/tier.dart';

class CatalogFetchException implements Exception {
  final String message;
  CatalogFetchException(this.message);

  @override
  String toString() => 'CatalogFetchException: $message';
}

/// 從 valorant-api.com 下載造型與組合包，精簡成 [SkinCatalog]。
class CatalogApi {
  static const _host = 'valorant-api.com';
  static const _language = 'zh-TW';

  final http.Client _client;
  final DateTime Function() _now;

  CatalogApi({http.Client? client, DateTime Function() now = DateTime.now})
      : _client = client ?? http.Client(),
        _now = now;

  Future<SkinCatalog> fetchCatalog() async {
    final tiers = await _getData('/v1/contenttiers');
    final weapons = await _getData('/v1/weapons');
    final bundles = await _getData('/v1/bundles');

    final tierByUuid = <String, Tier>{
      for (final t in tiers.cast<Map<String, dynamic>>())
        if (Tier.fromDevName(t['devName'] as String?) case final tier?)
          t['uuid'] as String: tier,
    };

    final skins = <SkinInfo>[];
    for (final weapon in weapons.cast<Map<String, dynamic>>()) {
      final weaponName = weapon['displayName'] as String;
      for (final skin in (weapon['skins'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()) {
        final tier = tierByUuid[skin['contentTierUuid']];
        if (tier == null) continue;
        skins.add(SkinInfo(
          uuid: skin['uuid'] as String,
          name: skin['displayName'] as String,
          weaponName: weaponName,
          tier: tier,
          iconUrl: skin['displayIcon'] as String? ?? _firstLevelIcon(skin),
        ));
      }
    }

    return SkinCatalog(
      skins: skins,
      bundles: bundles
          .cast<Map<String, dynamic>>()
          .map((b) => BundleInfo(
                uuid: b['uuid'] as String,
                name: b['displayName'] as String,
                iconUrl: b['displayIcon'] as String?,
              ))
          .toList(),
      fetchedAt: _now(),
    );
  }

  String? _firstLevelIcon(Map<String, dynamic> skin) {
    final levels = skin['levels'] as List<dynamic>? ?? [];
    if (levels.isEmpty) return null;
    return (levels.first as Map<String, dynamic>)['displayIcon'] as String?;
  }

  Future<List<dynamic>> _getData(String path) async {
    final uri = Uri.https(_host, path, {'language': _language});
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw CatalogFetchException('$path 回應 ${response.statusCode}');
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return body['data'] as List<dynamic>;
  }
}
