import 'package:flutter/foundation.dart';

import '../services/riot_client.dart';
import 'riot_provider.dart';
import 'riot_retry.dart';

/// 自己擁有的收藏（只讀 GET）：登入期間快取在記憶體，登出或換帳號時清空。
class CollectionProvider with ChangeNotifier {
  static const types = [
    ItemTypes.skinLevel,
    ItemTypes.skinChroma,
    ItemTypes.agent,
    ItemTypes.buddyLevel,
    ItemTypes.spray,
    ItemTypes.playerCard,
    ItemTypes.title,
  ];

  final RiotProvider _riot;
  final RiotClient _client;
  final Future<void> Function(Duration) _delay;
  final int maxConcurrent;

  final Map<String, Set<String>> _owned = {};
  final Map<String, String> _errors = {};
  String? _loadedFor;
  bool _isLoading = false;
  bool _disposed = false;

  CollectionProvider(this._riot, this._client,
      {Future<void> Function(Duration)? delay, this.maxConcurrent = 2})
      : _delay = delay ?? Future<void>.delayed {
    _riot.addListener(_onRiot);
  }

  Map<String, Set<String>> get owned => Map.unmodifiable(_owned);
  Map<String, String> get errors => Map.unmodifiable(_errors);
  bool get isLoading => _isLoading;

  String? get _puuid => _riot.isLoggedIn ? _riot.session?.puuid : null;

  void _onRiot() {
    if (_loadedFor != null && _puuid != _loadedFor) _clear();
  }

  void _clear() {
    _owned.clear();
    _errors.clear();
    _loadedFor = null;
    _notify();
  }

  /// 已為目前帳號載入過就不重抓（失敗的分類用 [refresh] 重試），避免畫面重建時反覆請求。
  Future<void> load() async {
    final puuid = _puuid;
    final s = _riot.session;
    if (puuid == null || s == null || _isLoading) return;
    if (_loadedFor == puuid) return;
    _isLoading = true;
    _errors.clear();
    _loadedFor = puuid;
    _notify();

    final queue = [...types];
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        final type = queue.removeAt(0);
        try {
          final ids = await withRiotRetry(
              () => _client.fetchEntitlements(s, type),
              delay: _delay);
          if (_puuid != puuid) return;
          _owned[type] = ids;
        } on RiotApiException catch (e) {
          if (_puuid != puuid) return;
          _errors[type] = e.message;
        }
        _notify();
      }
    }

    await Future.wait([
      for (var i = 0; i < maxConcurrent && i < types.length; i++) worker(),
    ]);
    _isLoading = false;
    _notify();
  }

  Future<void> refresh() async {
    _owned.clear();
    _errors.clear();
    _loadedFor = null;
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
