import 'package:flutter/foundation.dart';

import '../logic/match_mapper.dart';
import '../models/match_models.dart';
import '../models/riot_session.dart';
import '../services/match_client.dart';
import '../services/riot_client.dart';
import 'riot_provider.dart';

class MatchEntry {
  final MatchRef ref;
  final MatchDetail? detail;
  final bool failed;

  const MatchEntry({required this.ref, this.detail, this.failed = false});
}

/// 對戰紀錄分頁與單場詳情；資料只放在記憶體。
class MatchHistoryProvider with ChangeNotifier {
  static const notLoggedInMessage = '請先登入 Riot';
  static const expiredMessage = '登入已過期，請重新登入';

  final MatchClient _client;
  final RiotProvider _riot;
  final int pageSize;
  final int maxConcurrent;

  final List<MatchEntry> _entries = [];
  final Map<String, MatchDetail> _details = {};
  Map<String, int> _rr = {};
  RankInfo? _rank;
  int _total = 0;
  bool _isLoading = false;
  String? _error;

  MatchHistoryProvider(this._client, this._riot,
      {this.pageSize = 10, this.maxConcurrent = 4});

  List<MatchEntry> get entries => List.unmodifiable(_entries);
  bool get hasMore => _entries.length < _total;
  bool get isLoading => _isLoading;
  String? get error => _error;
  RankInfo? get rank => _rank;
  List<int> get recentRr => _rr.values.take(5).toList();
  MatchDetail? detail(String matchId) => _details[matchId];

  Future<void> loadFirstPage() async {
    _entries.clear();
    _details.clear();
    _rr = {};
    _rank = null;
    _total = 0;
    _error = null;
    final s = _session();
    if (s == null) return;
    await _guarded(s, () async {
      _rank = await _client.fetchRank(s);
      _rr = await _client.fetchRrChanges(s, 20);
      await _loadPage(s, 0);
    });
  }

  Future<void> loadMore() async {
    if (_isLoading || !hasMore) return;
    final s = _session();
    if (s == null) return;
    await _guarded(s, () => _loadPage(s, _entries.length));
  }

  RiotSession? _session() {
    final s = _riot.session;
    if (s == null || !_riot.isLoggedIn) {
      _error = notLoggedInMessage;
      notifyListeners();
      return null;
    }
    return s;
  }

  Future<void> _guarded(RiotSession s, Future<void> Function() body) async {
    _isLoading = true;
    notifyListeners();
    try {
      await body();
    } on RiotApiException catch (e) {
      if (e.isAuthError) {
        _riot.logout();
        _error = expiredMessage;
      } else {
        _error = e.message;
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadPage(RiotSession s, int start) async {
    final (refs, total) = await _client.fetchHistory(s, start, pageSize);
    _total = total;
    final results = List<MatchEntry?>.filled(refs.length, null);
    RiotApiException? authError;
    var next = 0;

    // 固定數量的 worker 從佇列取場次，同時最多 maxConcurrent 個請求。
    Future<void> worker() async {
      while (next < refs.length && authError == null) {
        final i = next++;
        final ref = refs[i];
        try {
          final json = await _client.fetchMatchJson(s, ref.matchId);
          final d = mapMatchDetail(json, s.puuid, rrChange: _rr[ref.matchId]);
          _details[ref.matchId] = d;
          results[i] = MatchEntry(ref: ref, detail: d);
        } on RiotApiException catch (e) {
          if (e.isAuthError) authError = e;
          results[i] = MatchEntry(ref: ref, failed: true);
        } catch (e) {
          debugPrint('對戰詳情解析失敗：${e.runtimeType}');
          results[i] = MatchEntry(ref: ref, failed: true);
        }
      }
    }

    final workers = refs.length < maxConcurrent ? refs.length : maxConcurrent;
    await Future.wait([for (var w = 0; w < workers; w++) worker()]);
    if (authError != null) throw authError!;
    _entries.addAll(results.whereType<MatchEntry>());
  }
}
