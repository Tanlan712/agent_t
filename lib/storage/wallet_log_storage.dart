import 'package:shared_preferences/shared_preferences.dart';

import '../models/wallet_log.dart';
import 'prefs_json.dart';

/// 每個帳號（puuid）的錢包紀錄，只存在這個瀏覽器（localStorage）。
class WalletLogStorage {
  static const _key = 'wallet_log_v1';

  final SharedPreferences _prefs;

  WalletLogStorage(this._prefs);

  Map<String, AccountWalletLog> load() => readPrefsJson(
        _prefs,
        _key,
        (json) => {
          for (final e in (json as Map<String, dynamic>).entries)
            e.key: AccountWalletLog.fromJson(e.value as Map<String, dynamic>),
        },
        <String, AccountWalletLog>{},
      );

  Future<void> save(Map<String, AccountWalletLog> logs) => writePrefsJson(
      _prefs, _key, {for (final e in logs.entries) e.key: e.value.toJson()});
}
