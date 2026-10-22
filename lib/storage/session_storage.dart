import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/riot_session.dart';

/// 保存過的 Riot 帳號（多帳號切換，使用者決定 2026-10-22，AGENTS.md 第 4 節）。
/// [session] 是未過期的登入資訊（含 token），過期或被 Riot 拒絕時刪除、只留下帳號名稱；
/// [cookies] 是手機 App 內嵌頁的 Riot 登入 cookie（AGENTS.md 第 3 節），網頁版一律為 null。
class SavedAccount {
  final String puuid;
  final String gameName;
  final String tagLine;
  final String shard;
  final RiotSession? session;
  final bool autoRenew;
  final String? cookies;

  const SavedAccount({
    required this.puuid,
    required this.gameName,
    required this.tagLine,
    required this.shard,
    this.session,
    this.autoRenew = false,
    this.cookies,
  });

  String get displayName => gameName.isEmpty ? '已登入玩家' : '$gameName#$tagLine';

  /// 還有沒過期的 token（不用重新登入就能切換）。
  bool hasValidSession(DateTime now) =>
      session != null && now.isBefore(session!.expiresAt);

  SavedAccount copyWith({
    RiotSession? Function()? session,
    bool? autoRenew,
    String? Function()? cookies,
  }) =>
      SavedAccount(
        puuid: puuid,
        gameName: gameName,
        tagLine: tagLine,
        shard: shard,
        session: session != null ? session() : this.session,
        autoRenew: autoRenew ?? this.autoRenew,
        cookies: cookies != null ? cookies() : this.cookies,
      );

  @override
  String toString() => 'SavedAccount($displayName)';
}

/// 保存 Riot 帳號清單與目前使用的帳號，讓重新開啟頁面後保持登入、切換帳號不用再登入。
/// 使用者決定見 AGENTS.md 第 4 節：登出會刪除整個帳號；授權失敗或讀回時已過期只刪除 token。
class SessionStorage {
  static const key = 'riotAccounts';
  static const activeKey = 'riotActiveAccount';

  /// 舊版只保存一個帳號：讀到時轉成帳號清單後刪除。
  static const legacyKey = 'riotSession';
  static const legacyAutoRenewKey = 'riotAutoRenew';

  final SharedPreferences _prefs;
  List<SavedAccount> _accounts = [];
  String? _active;

  SessionStorage(this._prefs) {
    _read();
  }

  /// 最近一次 [load] 讀到的是已過期的登入資訊（已刪除）；用來提示重新登入。
  bool expiredOnLoad = false;

  List<SavedAccount> get accounts => List.unmodifiable(_accounts);
  String? get activePuuid => _active;
  SavedAccount? get active => account(_active);

  SavedAccount? account(String? puuid) {
    for (final a in _accounts) {
      if (a.puuid == puuid) return a;
    }
    return null;
  }

  /// 目前帳號是在 App 內登入的：可由內嵌頁在背景自動續期（AGENTS.md 第 3 節）。
  bool get autoRenew => active?.autoRenew ?? false;

  Future<void> setAutoRenew(bool on) =>
      _update(_active, (a) => a.copyWith(autoRenew: on));

  /// 讀回目前帳號未過期的登入資訊；其他帳號過期的 token 也一併刪除（帳號保留）。
  RiotSession? load(DateTime now) {
    var changed = false;
    for (var i = 0; i < _accounts.length; i++) {
      final a = _accounts[i];
      if (a.session == null || a.hasValidSession(now)) continue;
      if (a.puuid == _active) expiredOnLoad = true;
      _accounts[i] = a.copyWith(session: () => null);
      changed = true;
    }
    if (changed) _write();
    return active?.session;
  }

  /// 保存登入資訊並設為目前帳號；同一個帳號（puuid）只留一筆。
  Future<void> save(RiotSession s) {
    final old = account(s.puuid);
    final next = SavedAccount(
      puuid: s.puuid,
      gameName: s.gameName,
      tagLine: s.tagLine,
      shard: s.shard,
      session: s,
      autoRenew: old?.autoRenew ?? false,
      cookies: old?.cookies,
    );
    _accounts = [
      for (final a in _accounts) a.puuid == s.puuid ? next : a,
      if (old == null) next,
    ];
    _active = s.puuid;
    return _write();
  }

  /// 刪除目前帳號的 token（過期或被 Riot 拒絕）；帳號與自動續期設定保留。
  Future<void> clear() =>
      _update(_active, (a) => a.copyWith(session: () => null));

  Future<void> setActive(String? puuid) {
    _active = account(puuid)?.puuid;
    return _write();
  }

  Future<void> setCookies(String puuid, String? cookies) =>
      _update(puuid, (a) => a.copyWith(cookies: () => cookies));

  /// 登出：刪除整個帳號（token、cookie 與設定）。
  Future<void> remove(String puuid) {
    _accounts = [
      for (final a in _accounts)
        if (a.puuid != puuid) a
    ];
    if (_active == puuid) _active = null;
    return _write();
  }

  Future<void> _update(String? puuid, SavedAccount Function(SavedAccount) f) {
    if (account(puuid) == null) return Future.value();
    _accounts = [
      for (final a in _accounts) a.puuid == puuid ? f(a) : a,
    ];
    return _write();
  }

  void _read() {
    final raw = _prefs.getString(key);
    if (raw != null) {
      try {
        _accounts = [
          for (final j in jsonDecode(raw) as List)
            _accountFromJson(j as Map<String, dynamic>),
        ];
      } catch (e) {
        // 錯誤內容可能包含 token，只記錄類型。
        debugPrint('$key 資料損壞，已刪除：${e.runtimeType}');
        _accounts = [];
        _prefs.remove(key);
      }
    }
    _active = account(_prefs.getString(activeKey))?.puuid;
    _migrateLegacy();
  }

  void _migrateLegacy() {
    final raw = _prefs.getString(legacyKey);
    final renew = _prefs.getBool(legacyAutoRenewKey) ?? false;
    if (raw == null && !_prefs.containsKey(legacyAutoRenewKey)) return;
    if (raw != null) {
      try {
        final s = _sessionFromJson(jsonDecode(raw) as Map<String, dynamic>);
        _accounts = [
          for (final a in _accounts)
            if (a.puuid != s.puuid) a,
          SavedAccount(
            puuid: s.puuid,
            gameName: s.gameName,
            tagLine: s.tagLine,
            shard: s.shard,
            session: s,
            autoRenew: renew,
          ),
        ];
        _active = s.puuid;
      } catch (e) {
        debugPrint('$legacyKey 資料損壞，已刪除：${e.runtimeType}');
      }
    }
    _prefs.remove(legacyKey);
    _prefs.remove(legacyAutoRenewKey);
    _write();
  }

  Future<void> _write() async {
    if (_accounts.isEmpty) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(
          key, jsonEncode([for (final a in _accounts) _accountToJson(a)]));
    }
    final active = _active;
    if (active == null) {
      await _prefs.remove(activeKey);
    } else {
      await _prefs.setString(activeKey, active);
    }
  }

  static Map<String, dynamic> _accountToJson(SavedAccount a) => {
        'puuid': a.puuid,
        'gameName': a.gameName,
        'tagLine': a.tagLine,
        'shard': a.shard,
        if (a.session != null) 'session': _sessionToJson(a.session!),
        if (a.autoRenew) 'autoRenew': true,
        if (a.cookies != null) 'cookies': a.cookies,
      };

  static SavedAccount _accountFromJson(Map<String, dynamic> j) {
    final s = j['session'] as Map<String, dynamic>?;
    return SavedAccount(
      puuid: j['puuid'] as String,
      gameName: j['gameName'] as String,
      tagLine: j['tagLine'] as String,
      shard: j['shard'] as String,
      session: s == null ? null : _sessionFromJson(s),
      autoRenew: j['autoRenew'] as bool? ?? false,
      cookies: j['cookies'] as String?,
    );
  }

  static Map<String, dynamic> _sessionToJson(RiotSession s) => {
        'accessToken': s.accessToken,
        'idToken': s.idToken,
        'entitlementsToken': s.entitlementsToken,
        'puuid': s.puuid,
        'gameName': s.gameName,
        'tagLine': s.tagLine,
        'shard': s.shard,
        'clientVersion': s.clientVersion,
        'expiresAt': s.expiresAt.toUtc().toIso8601String(),
      };

  static RiotSession _sessionFromJson(Map<String, dynamic> j) => RiotSession(
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
