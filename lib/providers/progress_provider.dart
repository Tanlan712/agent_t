import 'package:flutter/foundation.dart';

import '../models/account_progress.dart';
import '../models/progress_reference.dart';
import '../services/progress_reference_api.dart';
import '../services/riot_client.dart';
import 'riot_provider.dart';
import 'riot_retry.dart';

/// 自己的帳號等級、通行證與任務（只讀 GET）；Riot 資料在登入期間快取，
/// 公開參考資料（valorant-api）下載一次後沿用。
class ProgressProvider with ChangeNotifier {
  final RiotProvider _riot;
  final RiotClient _client;
  final ProgressReferenceApi _api;
  final Future<void> Function(Duration) _delay;

  AccountXp? _xp;
  ContractsSnapshot? _contracts;
  ProgressReference? _ref;
  String? _error;
  String? _loadedFor;
  bool _isLoading = false;
  bool _refLoading = false;
  String? _refError;
  bool _disposed = false;

  /// 換帳號、登出或重新整理時遞增；舊的載入看到不同的 generation 就丟棄結果。
  int _generation = 0;

  ProgressProvider(this._riot, this._client, this._api,
      {Future<void> Function(Duration)? delay})
      : _delay = delay ?? Future<void>.delayed {
    _riot.addListener(_onRiot);
  }

  AccountXp? get xp => _xp;
  ContractsSnapshot? get contracts => _contracts;
  ProgressReference? get ref => _ref;
  String? get error => _error;

  /// 參考資料下載失敗的訊息（收藏頁用）。
  String? get refError => _refError;
  bool get isLoading => _isLoading;

  String? get _puuid => _riot.isLoggedIn ? _riot.session?.puuid : null;

  void _onRiot() {
    if ((_loadedFor != null || _isLoading) && _puuid != _loadedFor) _reset();
  }

  /// 清空 Riot 資料並作廢進行中的載入（參考資料是公開的，保留）。
  void _reset() {
    _generation++;
    _xp = null;
    _contracts = null;
    _error = null;
    _loadedFor = null;
    _isLoading = false;
    _notify();
  }

  Future<void> load() async {
    final puuid = _puuid;
    final s = _riot.session;
    if (puuid == null || s == null || _isLoading) return;
    // 已為目前帳號載入過就不重抓（失敗時用 refresh 重試），避免畫面重建時反覆請求。
    if (_loadedFor == puuid) return;
    final gen = ++_generation;
    _isLoading = true;
    _error = null;
    _loadedFor = puuid;
    _notify();

    final errors = <String>[];
    var authFailed = false;
    Future<void> fetch<T>(
        Future<T> Function() call, void Function(T) store, String label) async {
      try {
        final v = await withRiotRetry(call, delay: _delay);
        if (gen == _generation) store(v);
      } on RiotApiException catch (e) {
        if (e.isAuthError) authFailed = true;
        errors.add(e.message);
      } catch (_) {
        errors.add('$label：回應格式不符');
      }
    }

    try {
      // 同時最多 2 個 Riot 請求（等級、合約）。
      await Future.wait([
        fetch(() => _client.fetchAccountXp(s), (v) => _xp = v, '取得帳號等級'),
        fetch(
            () => _client.fetchContracts(s), (v) => _contracts = v, '取得通行證與任務'),
      ]);
      if (gen != _generation) return;
      if (authFailed) {
        // AGENTS.md 第 4 節：授權失敗時立即登出並刪除保存的登入資訊。
        _riot.expire();
        return;
      }
      if (_ref == null) {
        try {
          _ref = await _fetchRef();
        } catch (_) {
          errors.add('無法下載通行證與任務的顯示資料');
          _refError = '無法下載顯示資料';
        }
      }
      if (gen == _generation) _error = errors.isEmpty ? null : errors.join('；');
    } finally {
      if (gen == _generation) {
        _isLoading = false;
        _notify();
      }
    }
  }

  /// 進行中的參考資料下載；load 與 ensureReference 同時需要時共用，只下載一次。
  Future<ProgressReference>? _refFetch;

  Future<ProgressReference> _fetchRef() =>
      _refFetch ??= _api.fetch().whenComplete(() => _refFetch = null);

  /// 只確保公開參考資料已下載（收藏頁用）；不送 Riot 請求。
  Future<void> ensureReference() async {
    if (_ref != null || _refLoading) return;
    _refLoading = true;
    _refError = null;
    _notify();
    try {
      _ref = await _fetchRef();
      _refError = null;
    } catch (_) {
      _refError = '無法下載顯示資料';
    }
    _refLoading = false;
    _notify();
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
