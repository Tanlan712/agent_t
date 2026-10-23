/// 自訂對戰的選項：glz `parties/v1/parties/customgameconfigs`（GET）回傳的可用地圖、模式與伺服器，
/// 以及設定（`CustomGameData.Settings`）裡顯示用的名稱。欄位依 techchrism 的 valorant-api-types。
class CustomGameConfig {
  /// mapUrl，例如 `/Game/Maps/Ascent/Ascent`。
  final List<String> maps;

  /// 模式路徑，例如 `/Game/GameModes/Bomb/BombGameMode.BombGameMode_C`。
  final List<String> modes;

  /// 伺服器（GamePod ID）。
  final List<String> pods;

  const CustomGameConfig(
      {this.maps = const [], this.modes = const [], this.pods = const []});

  factory CustomGameConfig.fromJson(Map<String, dynamic> json) {
    List<String> strings(Object? v) => [
          for (final e in v as List<dynamic>? ?? const [])
            if (e is String && e.isNotEmpty) e,
        ];
    final pods = json['GamePodPingServiceInfo'];
    return CustomGameConfig(
      maps: strings(json['EnabledMaps']),
      modes: strings(json['EnabledModes']),
      pods:
          pods is Map ? ([for (final k in pods.keys) '$k']..sort()) : const [],
    );
  }
}

const _modeNames = {
  'bomb': '標準',
  'quickbomb': '超速衝點',
  'deathmatch': '死鬥',
  'hurm': '團隊死鬥',
  'gungame': '軍備升級',
  'oneforall': '複製',
  'snowballfight': '雪球大戰',
  'swiftplay': '輕鬆打',
  'newmap': '輕鬆打',
};

/// 模式路徑的中文名稱；認不得時用路徑裡的資料夾名稱。
String customModeName(String mode) {
  final parts = mode.split('/').where((p) => p.isNotEmpty).toList();
  final i = parts.indexWhere((p) => p.toLowerCase() == 'gamemodes');
  final folders = i < 0 ? parts : parts.sublist(i + 1);
  for (final f in folders) {
    final key = f.toLowerCase().replaceAll('_', '');
    for (final e in _modeNames.entries) {
      if (key.startsWith(e.key)) return e.value;
    }
  }
  final last = (folders.isEmpty ? mode : folders.first).split('.').first;
  return last.isEmpty ? mode : last;
}

const _podCities = {
  'hongkong': '香港',
  'tokyo': '東京',
  'singapore': '新加坡',
  'sydney': '雪梨',
  'mumbai': '孟買',
  'seoul': '首爾',
  'bahrain': '巴林',
  'frankfurt': '法蘭克福',
  'london': '倫敦',
  'paris': '巴黎',
  'madrid': '馬德里',
  'stockholm': '斯德哥爾摩',
  'warsaw': '華沙',
  'istanbul': '伊斯坦堡',
  'tel-aviv': '特拉維夫',
  'dallas': '達拉斯',
  'chicago': '芝加哥',
  'atlanta': '亞特蘭大',
  'ashburn': '阿什本',
  'oregon': '奧勒岡',
  'norcal': '北加州',
  'santiago': '聖地牙哥',
  'saopaulo': '聖保羅',
  'mexicocity': '墨西哥市',
  'miami': '邁阿密',
};

/// GamePod ID 的顯示名稱，例如 `aresriot.aws-rclusterprod-ape1-1.ap-gp-hongkong-1` → `香港 1`。
String customPodName(String pod) {
  final i = pod.lastIndexOf('-gp-');
  if (i < 0) return pod;
  var rest = pod.substring(i + 4);
  var number = '';
  final m = RegExp(r'^(.*)-(\d+)$').firstMatch(rest);
  if (m != null) {
    rest = m.group(1)!;
    number = m.group(2)!;
  }
  final city = _podCities[rest] ?? rest;
  return number.isEmpty ? city : '$city $number';
}

/// 自訂對戰的規則開關（`Settings.GameRules`，值是字串 "true"／"false"）。
const customGameRules = {
  'PlayOutAllRounds': '打完全部回合',
  'IsOvertimeWinByTwo': '延長賽要贏兩回合',
  'TournamentMode': '錦標賽模式',
  'AllowGameModifiers': '允許作弊選項',
  'SkipMatchHistory': '不留對戰紀錄',
};

bool customRuleOn(Map<String, dynamic>? settings, String rule) =>
    '${(settings?['GameRules'] as Map?)?[rule]}' == 'true';

/// 改一項設定，其餘欄位原樣帶回（Riot 要整份 Settings）。
Map<String, dynamic> withCustomSetting(
        Map<String, dynamic> settings, String key, Object value) =>
    {...settings, key: value};

/// 切換一項規則；GameRules 是 null 時建立新的。
Map<String, dynamic> withCustomRule(
        Map<String, dynamic> settings, String rule, bool on) =>
    {
      ...settings,
      'GameRules': {
        ...?(settings['GameRules'] as Map?)?.cast<String, dynamic>(),
        rule: on ? 'true' : 'false',
      },
    };
