/// valorant-api.com 的公開遊戲資料（武器、地圖、造型、特務）；欄位見 docs/api-fields.md。
library;

double? _num(Object? v) => v is num ? v.toDouble() : null;
int? _int(Object? v) => v is num ? v.toInt() : null;
String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
Map<String, dynamic>? _map(Object? v) => v is Map<String, dynamic> ? v : null;
List<Map<String, dynamic>> _list(Object? v) => [
      if (v is List)
        for (final e in v)
          if (e is Map<String, dynamic>) e
    ];

class DamageRange {
  final double rangeStartMeters;
  final double rangeEndMeters;
  final double headDamage;
  final double bodyDamage;
  final double legDamage;

  const DamageRange({
    required this.rangeStartMeters,
    required this.rangeEndMeters,
    required this.headDamage,
    required this.bodyDamage,
    required this.legDamage,
  });

  factory DamageRange.fromJson(Map<String, dynamic> j) => DamageRange(
        rangeStartMeters: _num(j['rangeStartMeters']) ?? 0,
        rangeEndMeters: _num(j['rangeEndMeters']) ?? 0,
        headDamage: _num(j['headDamage']) ?? 0,
        bodyDamage: _num(j['bodyDamage']) ?? 0,
        legDamage: _num(j['legDamage']) ?? 0,
      );
}

/// 開鏡數據。
class AdsStats {
  final double? zoomMultiplier;
  final double? fireRate;
  final double? runSpeedMultiplier;
  final int? burstCount;
  final double? firstBulletAccuracy;

  const AdsStats({
    this.zoomMultiplier,
    this.fireRate,
    this.runSpeedMultiplier,
    this.burstCount,
    this.firstBulletAccuracy,
  });

  factory AdsStats.fromJson(Map<String, dynamic> j) => AdsStats(
        zoomMultiplier: _num(j['zoomMultiplier']),
        fireRate: _num(j['fireRate']),
        runSpeedMultiplier: _num(j['runSpeedMultiplier']),
        burstCount: _int(j['burstCount']),
        firstBulletAccuracy: _num(j['firstBulletAccuracy']),
      );
}

class WeaponStatsInfo {
  final double? fireRate;
  final int? magazineSize;
  final double? runSpeedMultiplier;
  final double? equipTimeSeconds;
  final double? reloadTimeSeconds;
  final double? firstBulletAccuracy;
  final int? shotgunPelletCount;
  final String? wallPenetration;
  final String? feature;
  final String? fireMode;
  final String? altFireType;
  final AdsStats? ads;
  final List<DamageRange> damageRanges;

  const WeaponStatsInfo({
    this.fireRate,
    this.magazineSize,
    this.runSpeedMultiplier,
    this.equipTimeSeconds,
    this.reloadTimeSeconds,
    this.firstBulletAccuracy,
    this.shotgunPelletCount,
    this.wallPenetration,
    this.feature,
    this.fireMode,
    this.altFireType,
    this.ads,
    this.damageRanges = const [],
  });

  factory WeaponStatsInfo.fromJson(Map<String, dynamic> j) => WeaponStatsInfo(
        fireRate: _num(j['fireRate']),
        magazineSize: _int(j['magazineSize']),
        runSpeedMultiplier: _num(j['runSpeedMultiplier']),
        equipTimeSeconds: _num(j['equipTimeSeconds']),
        reloadTimeSeconds: _num(j['reloadTimeSeconds']),
        firstBulletAccuracy: _num(j['firstBulletAccuracy']),
        shotgunPelletCount: _int(j['shotgunPelletCount']),
        wallPenetration: _str(j['wallPenetration']),
        feature: _str(j['feature']),
        fireMode: _str(j['fireMode']),
        altFireType: _str(j['altFireType']),
        ads: switch (_map(j['adsStats'])) {
          final m? => AdsStats.fromJson(m),
          null => null,
        },
        damageRanges: [
          for (final r in _list(j['damageRanges'])) DamageRange.fromJson(r)
        ],
      );
}

class WeaponInfo {
  final String uuid;
  final String name;
  final String? icon;

  /// `EEquippableCategory::Rifle` 等。
  final String category;

  /// 商店的類別名稱（zh-TW）；近戰沒有。
  final String? categoryText;
  final int cost;

  /// 近戰為 null。
  final WeaponStatsInfo? stats;

  const WeaponInfo({
    required this.uuid,
    required this.name,
    this.icon,
    required this.category,
    this.categoryText,
    this.cost = 0,
    this.stats,
  });

  factory WeaponInfo.fromJson(Map<String, dynamic> j) {
    final shop = _map(j['shopData']);
    final stats = _map(j['weaponStats']);
    return WeaponInfo(
      uuid: _str(j['uuid']) ?? '',
      name: _str(j['displayName']) ?? '',
      icon: _str(j['displayIcon']),
      category: _str(j['category']) ?? '',
      categoryText: _str(shop?['categoryText']),
      cost: _int(shop?['cost']) ?? 0,
      stats: stats == null ? null : WeaponStatsInfo.fromJson(stats),
    );
  }
}

/// 小地圖上的地點；[u]、[v] 是小地圖圖片上的相對位置（0～1）。
class MapCallout {
  final String label;
  final double u;
  final double v;

  const MapCallout({required this.label, required this.u, required this.v});
}

class MapInfo {
  final String uuid;
  final String name;
  final String? splash;

  /// 完整小地圖（`displayIcon`）；部分模式地圖沒有。
  final String? minimap;
  final String? coordinates;
  final String? tacticalDescription;
  final List<MapCallout> callouts;

  const MapInfo({
    required this.uuid,
    required this.name,
    this.splash,
    this.minimap,
    this.coordinates,
    this.tacticalDescription,
    this.callouts = const [],
  });

  factory MapInfo.fromJson(Map<String, dynamic> j) {
    final xm = _num(j['xMultiplier']);
    final ym = _num(j['yMultiplier']);
    final xa = _num(j['xScalarToAdd']);
    final ya = _num(j['yScalarToAdd']);
    final canPlace = xm != null && ym != null && xa != null && ya != null;
    return MapInfo(
      uuid: _str(j['uuid']) ?? '',
      name: _str(j['displayName']) ?? '',
      splash: _str(j['splash']),
      minimap: _str(j['displayIcon']),
      coordinates: _str(j['coordinates']),
      tacticalDescription: _str(j['tacticalDescription']),
      callouts: [
        if (canPlace)
          for (final c in _list(j['callouts']))
            if (_map(c['location']) case final loc?)
              if ((_num(loc['x']), _num(loc['y'])) case (final x?, final y?))
                MapCallout(
                  label: _calloutLabel(
                      _str(c['superRegionName']), _str(c['regionName'])),
                  // valorant-api 文件的換算：x、y 軸互換後縮放平移。
                  u: y * xm + xa,
                  v: x * ym + ya,
                ),
      ],
    );
  }
}

String _calloutLabel(String? superRegion, String? region) {
  if (region == null) return superRegion ?? '';
  if (superRegion == null || superRegion == region) return region;
  return '$superRegion $region';
}

class SkinLevelInfo {
  final String name;
  final String? icon;
  final String? videoUrl;

  const SkinLevelInfo({required this.name, this.icon, this.videoUrl});
}

class ChromaInfo {
  final String name;

  /// `fullRender`，沒有時用 `displayIcon`。
  final String? image;
  final String? swatch;
  final String? videoUrl;

  const ChromaInfo(
      {required this.name, this.image, this.swatch, this.videoUrl});
}

class SkinInfo {
  final String uuid;
  final String name;
  final String? icon;
  final String? themeUuid;
  final List<SkinLevelInfo> levels;
  final List<ChromaInfo> chromas;

  const SkinInfo({
    required this.uuid,
    required this.name,
    this.icon,
    this.themeUuid,
    this.levels = const [],
    this.chromas = const [],
  });

  factory SkinInfo.fromJson(Map<String, dynamic> j) {
    final levels = _list(j['levels']);
    final chromas = _list(j['chromas']);
    return SkinInfo(
      uuid: _str(j['uuid']) ?? '',
      name: _str(j['displayName']) ?? '',
      // 造型本身常沒有圖，改用第一個炫彩或等級的圖。
      icon: _str(j['displayIcon']) ??
          (chromas.isEmpty
              ? null
              : _str(chromas.first['fullRender']) ??
                  _str(chromas.first['displayIcon'])) ??
          (levels.isEmpty ? null : _str(levels.first['displayIcon'])),
      themeUuid: _str(j['themeUuid']),
      levels: [
        for (final l in levels)
          SkinLevelInfo(
            name: _str(l['displayName']) ?? '',
            icon: _str(l['displayIcon']),
            videoUrl: _str(l['streamedVideo']),
          ),
      ],
      chromas: [
        for (final c in chromas)
          ChromaInfo(
            name: _str(c['displayName']) ?? '',
            image: _str(c['fullRender']) ?? _str(c['displayIcon']),
            swatch: _str(c['swatch']),
            videoUrl: _str(c['streamedVideo']),
          ),
      ],
    );
  }
}

/// `/v1/themes` 的一筆主題。
class ThemeRef {
  final String uuid;
  final String name;

  const ThemeRef({required this.uuid, required this.name});

  factory ThemeRef.fromJson(Map<String, dynamic> j) =>
      ThemeRef(uuid: _str(j['uuid']) ?? '', name: _str(j['displayName']) ?? '');
}

class AgentAbility {
  /// `Grenade`、`Ability1`、`Ability2`、`Ultimate`、`Passive`。
  final String slot;
  final String name;
  final String description;
  final String? icon;

  const AgentAbility({
    required this.slot,
    required this.name,
    required this.description,
    this.icon,
  });
}

class AgentInfo {
  final String uuid;
  final String name;
  final String? role;
  final String description;
  final String? icon;
  final String? portrait;
  final String? background;
  final List<AgentAbility> abilities;

  const AgentInfo({
    required this.uuid,
    required this.name,
    this.role,
    this.description = '',
    this.icon,
    this.portrait,
    this.background,
    this.abilities = const [],
  });

  factory AgentInfo.fromJson(Map<String, dynamic> j) => AgentInfo(
        uuid: _str(j['uuid']) ?? '',
        name: _str(j['displayName']) ?? '',
        role: _str(_map(j['role'])?['displayName']),
        description: _str(j['description']) ?? '',
        icon: _str(j['displayIcon']),
        portrait: _str(j['fullPortrait']),
        background: _str(j['background']),
        abilities: [
          for (final a in _list(j['abilities']))
            AgentAbility(
              slot: _str(a['slot']) ?? '',
              name: _str(a['displayName']) ?? '',
              description: _str(a['description']) ?? '',
              icon: _str(a['displayIcon']),
            ),
        ],
      );
}
