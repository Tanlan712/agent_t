import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/riot_session.dart';

/// 保存 Riot 登入資訊（含 token），讓重新開啟頁面後保持登入。
/// 使用者決定見 AGENTS.md 第 4 節：登出、授權失敗或讀回時已過期都會刪除。
class SessionStorage {
  static const key = 'riotSession';

  /// App 內登入後設為 true：之後由內嵌頁在背景自動續期（AGENTS.md 第 3 節）；不含 token。
  static const autoRenewKey = 'riotAutoRenew';

  final SharedPreferences _prefs;

  SessionStorage(this._prefs);

  /// 最近一次 [load] 讀到的是已過期的登入資訊（已刪除）；用來提示重新登入。
  bool expiredOnLoad = false;

  bool get autoRenew => _prefs.getBool(autoRenewKey) ?? false;

  Future<void> setAutoRenew(bool on) =>
      on ? _prefs.setBool(autoRenewKey, true) : _prefs.remove(autoRenewKey);

  /// 讀回未過期的登入資訊；沒有、損毀或已過期時刪除並回傳 null。
  RiotSession? load(DateTime now) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    RiotSession? session;
    try {
      session = _fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      // 錯誤內容可能包含 token，只記錄類型。
      debugPrint('$key 資料損壞，已刪除：${e.runtimeType}');
    }
    if (session == null || !now.isBefore(session.expiresAt)) {
      expiredOnLoad = session != null;
      clear();
      return null;
    }
    return session;
  }

  Future<void> save(RiotSession s) => _prefs.setString(
      key,
      jsonEncode({
        'accessToken': s.accessToken,
        'idToken': s.idToken,
        'entitlementsToken': s.entitlementsToken,
        'puuid': s.puuid,
        'gameName': s.gameName,
        'tagLine': s.tagLine,
        'shard': s.shard,
        'clientVersion': s.clientVersion,
        'expiresAt': s.expiresAt.toUtc().toIso8601String(),
      }));

  Future<void> clear() => _prefs.remove(key);

  static RiotSession _fromJson(Map<String, dynamic> j) => RiotSession(
        accessToken: j['accessToken'] as String,
        idToken: j['idToken'] as String,
        entitlementsToken: j['entitlementsToken'] as String,
        puuid: j['puuid'] as String,
        gameName: j['gameName'] as String,
        tagLine: j['tagLine'] as String,
        shard: j['shard'] as String,
        clientVersion: j['clientVersion'] as String,
        expiresAt: DateTime.parse(j['expiresAt'] as String).toLocal(),
      );
}
