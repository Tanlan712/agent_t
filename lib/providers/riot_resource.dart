import 'package:flutter/foundation.dart';

import '../models/penalty_status.dart';
import '../models/player_loadout.dart';
import '../models/riot_session.dart';
import '../services/riot_client.dart';
import 'riot_provider.dart';
import 'riot_retry.dart';

/// 單一個只讀 GET 的 Riot 資料（例如目前裝備、排隊懲罰）：登入期間快取，
/// 登出或換帳號時清空；失敗時用 [refresh] 重試。
class RiotResource<T> with ChangeNotifier {
  final RiotProvider _riot;
  final Future<T> Function(RiotSession) _fetch;
  final Future<void> Function(Duration) _delay;

  /// 格式不符時顯示的訊息（例如「取得目前裝備：回應格式不符」）。
  final String label;

  T? _value;
  String? _error;
  String? _loadedFor;
  bool _isLoading = false;
  bool _disposed = false;

  /// 換帳號、登出或重新整理時遞增；舊的載入看到不同的 generation 就丟棄結果。
  int _generation = 0;

  RiotResource(this._riot, this._fetch,
      {required this.label, Future<void> Function(Duration)? delay})
      : _delay = delay ?? Future<void>.delayed {
    _riot.addListener(_onRiot);
  }

  T? get value => _value;
  String? get error => _error;
  bool get isLoading => _isLoading;

  String? get _puuid => _riot.isLoggedIn ? _riot.session?.puuid : null;

  void _onRiot() {
    if ((_loadedFor != null || _isLoading) && _puuid != _loadedFor) _reset();
  }

  void _reset() {
    _generation++;
    _value = null;
    _error = null;
    _loadedFor = null;
    _isLoading = false;
    _notify();
  }

  /// 已為目前帳號載入過就不重抓，避免畫面重建時反覆請求。
  Future<void> load() async {
    final puuid = _puuid;
    final s = _riot.session;
    if (puuid == null || s == null || _isLoading || _loadedFor == puuid) {
      return;
    }
    final gen = ++_generation;
    _isLoading = true;
    _error = null;
    _loadedFor = puuid;
    _notify();
    try {
      final v = await withRiotRetry(() => _fetch(s), delay: _delay);
      if (gen == _generation) _value = v;
    } on RiotApiException catch (e) {
      if (gen != _generation) return;
      if (e.isAuthError) {
        // AGENTS.md 第 4 節：授權失敗時立即登出並刪除保存的登入資訊。
        _riot.expire();
        return;
      }
      _error = e.message;
    } catch (_) {
      if (gen == _generation) _error = '$label：回應格式不符';
    } finally {
      if (gen == _generation) {
        _isLoading = false;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    _reset();
    await load();
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

/// 目前裝備（收藏頁「目前裝備」分頁）。
class EquippedLoadoutProvider extends RiotResource<PlayerLoadout> {
  EquippedLoadoutProvider(RiotProvider riot, RiotClient client, {super.delay})
      : super(riot, client.fetchLoadout, label: '取得目前裝備');
}

/// 排隊懲罰（通行證頁）。
class PenaltyProvider extends RiotResource<PenaltyStatus> {
  PenaltyProvider(RiotProvider riot, RiotClient client, {super.delay})
      : super(riot, client.fetchPenalties, label: '取得排隊懲罰');
}
