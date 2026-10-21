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
    if (_loadedFor != null && _puuid != _loadedFor) {
      _xp = null;
      _contracts = null;
      _error = null;
      _loadedFor = null;
      _notify();
    }
  }

  Future<void> load() async {
    final puuid = _puuid;
    final s = _riot.session;
    if (puuid == null || s == null || _isLoading) return;
    // 已為目前帳號載入過就不重抓（失敗時用 refresh 重試），避免畫面重建時反覆請求。
    if (_loadedFor == puuid) return;
    _isLoading = true;
    _error = null;
    _loadedFor = puuid;
    _notify();

    final errors = <String>[];
    // 同時最多 2 個 Riot 請求（等級、合約）。
    await Future.wait([
      () async {
        try {
          final v = await withRiotRetry(() => _client.fetchAccountXp(s),
              delay: _delay);
          if (_puuid == puuid) _xp = v;
        } on RiotApiException catch (e) {
          errors.add(e.message);
        }
      }(),
      () async {
        try {
          final v = await withRiotRetry(() => _client.fetchContracts(s),
              delay: _delay);
          if (_puuid == puuid) _contracts = v;
        } on RiotApiException catch (e) {
          errors.add(e.message);
        }
      }(),
    ]);
    if (_ref == null) {
      try {
        _ref = await _api.fetch();
      } catch (_) {
        errors.add('無法下載通行證與任務的顯示資料');
      }
    }
    if (_puuid == puuid) _error = errors.isEmpty ? null : errors.join('；');
    _isLoading = false;
    _notify();
  }

  /// 只確保公開參考資料已下載（收藏頁用）；不送 Riot 請求。
  Future<void> ensureReference() async {
    if (_ref != null || _refLoading) return;
    _refLoading = true;
    try {
      _ref = await _api.fetch();
      _refError = null;
    } catch (_) {
      _refError = '無法下載顯示資料';
    }
    _refLoading = false;
    _notify();
  }

  Future<void> refresh() async {
    _loadedFor = null;
    _error = null;
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
