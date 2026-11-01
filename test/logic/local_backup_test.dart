import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agent_t/logic/local_backup.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({
        'settings': jsonEncode({
          'themeStyle': 'neon',
          'remoteControl': true,
          'remoteControlSince': '2026-10-22',
          'preferredAgent': 'abc',
        }),
        'shop_history_v1_me': '{"days":[],"nights":[]}',
        'encounters_v1': '{}',
        'pass_xp_v1_me_c1': '{"2026-11-01":100}',
        'app_update_auto_check_v1': false,
        // 不得進備份的資料。
        'riotAccounts': '[{"token":"fake-token"}]',
        'riotActiveAccount': 'me',
        'current_shop': '{}',
        'catalog_v2': '{}',
      }));

  test('匯出只含白名單資料，不含登入資訊與快取', () async {
    final prefs = await SharedPreferences.getInstance();
    final b = buildBackup(prefs, DateTime.utc(2026, 11, 1));
    final keys = (b['data'] as Map).keys.toSet();
    expect(keys, {
      'settings',
      'shop_history_v1_me',
      'encounters_v1',
      'pass_xp_v1_me_c1',
      'app_update_auto_check_v1',
    });
    final text = encodeBackup(b);
    expect(text.contains('fake-token'), isFalse);
    expect(text.contains('riotAccounts'), isFalse);
  });

  test('還原：覆蓋備份裡的資料、略過被加進去的登入資訊、遠端操作要重新同意', () async {
    final prefs = await SharedPreferences.getInstance();
    final b = buildBackup(prefs, DateTime.utc(2026, 11, 1));
    (b['data'] as Map)['riotAccounts'] = {'t': 's', 'v': 'evil'};
    (b['data'] as Map)['encounters_v1'] = {'t': 's', 'v': '{"x":{}}'};
    final contents = parseBackup(encodeBackup(b));
    expect(contents.values.containsKey('riotAccounts'), isFalse);
    expect(contents.summary.keys, contains('商店歷史'));

    await prefs.setString('encounters_v1', '{}');
    final n = await restoreBackup(prefs, contents);
    expect(n, 5);
    expect(prefs.getString('encounters_v1'), '{"x":{}}');
    expect(prefs.getString('riotAccounts'), '[{"token":"fake-token"}]');
    expect(prefs.getBool('app_update_auto_check_v1'), isFalse);
    final settings =
        jsonDecode(prefs.getString('settings')!) as Map<String, dynamic>;
    expect(settings['themeStyle'], 'neon');
    expect(settings['remoteControl'], isFalse);
    expect(settings['preferredAgent'], isNull);
  });

  test('不是備份檔或版本太新時丟出 FormatException', () {
    expect(() => parseBackup('hello'), throwsFormatException);
    expect(() => parseBackup('{"format":"other"}'), throwsFormatException);
    expect(
        () => parseBackup(jsonEncode({
              'format': backupFormat,
              'version': backupVersion + 1,
              'data': {}
            })),
        throwsFormatException);
  });

  test('檔名', () {
    expect(backupFileName(DateTime(2026, 11, 1, 9)),
        'agent-t-backup-20261101.json');
  });
}
