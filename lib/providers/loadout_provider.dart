import 'package:flutter/foundation.dart';

import '../logic/loadout_logic.dart';
import '../services/remote_client.dart';
import '../services/riot_client.dart';
import 'riot_provider.dart';

/// 自己的裝備（遠端換造型用）：只在使用者同意遠端操作後讀取與寫入，資料只放在記憶體。
class LoadoutProvider with ChangeNotifier {
  final RemoteClient _client;
  final RiotProvider _riot;

  Map<String, dynamic>? _loadout;
  String? _loadedFor;
  bool _loading = false;
  bool _busy = false;
  String? _error;
  bool _disposed = false;

  LoadoutProvider(this._client, this._riot) {
    _riot.addListener(_onRiot);
  }

  bool get loading => _loading;

  /// 正在送出裝備變更。
  bool get busy => _busy;
  String? get error => _error;

  /// 某把槍目前裝備的造型；還沒讀到時為 null。
  String? equipped(String weaponUuid) => equippedSkin(_loadout, weaponUuid);

  String? get _puuid => _riot.isLoggedIn ? _riot.session?.puuid : null;

  void _onRiot() {
    if (_loadedFor != null && _puuid != _loadedFor) {
      _loadout = null;
      _loadedFor = null;
      _error = null;
      _notify();
    }
  }

  /// 同一帳號只讀一次；[force] 時重新讀取。
  Future<void> load({bool force = false}) async {
    final s = _riot.session;
    final puuid = _puuid;
    if (s == null || puuid == null || _loading) return;
    if (!force && _loadedFor == puuid) return;
    _loading = true;
    _error = null;
    _notify();
    try {
      _loadout = await _client.fetchLoadout(s);
      _loadedFor = puuid;
    } on RemoteDisabledException catch (e) {
      _error = e.toString();
    } on RiotApiException catch (e) {
      if (e.isAuthError) _riot.expire();
      _error = e.message;
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// 裝備造型：先讀最新的裝備（避免蓋掉在遊戲裡的變更），只改這把槍後寫回。失敗不重試。
  Future<bool> equip(SkinEquip skin, String chromaUuid) async {
    final s = _riot.session;
    final puuid = _puuid;
    if (s == null || puuid == null || _busy) return false;
    _busy = true;
    _error = null;
    _notify();
    try {
      final current = await _client.fetchLoadout(s);
      final next = applySkin(current,
          weaponUuid: skin.weaponUuid,
          skinUuid: skin.skinUuid,
          levelUuid: skin.levelUuid,
          chromaUuid: chromaUuid);
      _loadout = await _client.putLoadout(s, next) ?? next;
      _loadedFor = puuid;
      return true;
    } on RemoteDisabledException catch (e) {
      _error = e.toString();
    } on RiotApiException catch (e) {
      if (e.isAuthError) _riot.expire();
      _error = e.message;
    } finally {
      _busy = false;
      _notify();
    }
    return false;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _riot.removeListener(_onRiot);
    super.dispose();
  }
}
