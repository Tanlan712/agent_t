import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'riot_fixtures.dart';

/// 依社群文件撰寫的裝備假資料（ID 都是虛構）。
Map<String, dynamic> loadoutJson() => {
      'Subject': 'puuid-1',
      'Version': 7,
      'Guns': [
        {
          'ID': 'weapon-v',
          'SkinID': 'skin-std',
          'SkinLevelID': 'lv-std',
          'ChromaID': 'ch-std',
          'CharmInstanceID': 'charm-inst',
          'CharmID': 'charm',
          'CharmLevelID': 'charm-lv',
          'Attachments': <dynamic>[],
        },
        {
          'ID': 'weapon-p',
          'SkinID': 'skin-p',
          'SkinLevelID': 'lv-p',
          'ChromaID': 'ch-p',
          'Attachments': <dynamic>[],
        },
      ],
      'Sprays': [
        {'EquipSlotID': 'slot', 'SprayID': 'spray', 'SprayLevelID': null},
      ],
      'Identity': {'PlayerCardID': 'card', 'PlayerTitleID': 'title'},
      'Incognito': false,
    };

/// 遠端操作的假伺服器：記錄寫入請求，其餘交給 [inner]（預設 [riotClient]）。
/// [status] 以路徑片段指定回應碼（例如 `{'/lock/': 409}`）。
MockClient remoteHttp(List<http.Request> requests,
    {Map<String, int> status = const {},
    String? inviteCode = 'ABC123',
    http.Client? inner}) {
  final base = inner ?? riotClient();
  var loadout = loadoutJson();
  return MockClient((req) async {
    final path = req.url.path;
    final remote = path.contains('/personalization/') ||
        (req.method == 'POST' &&
            (path.contains('/pregame/v1/matches/') ||
                path.contains('/disassociate/') ||
                path.contains('/special/') ||
                path.startsWith('/parties/v1/parties/'))) ||
        (req.method == 'DELETE' && path.startsWith('/parties/v1/players/'));
    if (!remote) {
      final copy = http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes;
      return base.send(copy).then(http.Response.fromStream);
    }
    requests.add(req);
    for (final e in status.entries) {
      if (path.contains(e.key)) return http.Response('{}', e.value);
    }
    if (path.contains('/personalization/')) {
      if (req.method == 'PUT') {
        loadout = jsonDecode(req.body) as Map<String, dynamic>;
      }
      return http.Response(jsonEncode(loadout), 200,
          headers: {'content-type': 'application/json'});
    }
    if (path.endsWith('/invitecode')) {
      return http.Response(
          jsonEncode({
            'ID': 'party-1',
            if (inviteCode != null) 'InviteCode': inviteCode
          }),
          200);
    }
    // 社群文件：多數寫入回傳更新後的隊伍或場次；這裡回傳空內容，確認不會報錯。
    return http.Response('', 200);
  });
}
