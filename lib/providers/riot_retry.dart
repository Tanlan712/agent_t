import '../services/riot_client.dart';

/// 依 AGENTS.md 第 3 節重試：429 或連線失敗（瀏覽器裡限流回應可能沒有 CORS 標頭）時，
/// 依 Retry-After 或 2s／4s／8s 退避，最多重試 [maxRetries] 次。
Future<T> withRiotRetry<T>(
  Future<T> Function() call, {
  required Future<void> Function(Duration) delay,
  int maxRetries = 3,
}) async {
  for (var attempt = 0;; attempt++) {
    try {
      return await call();
    } on RiotApiException catch (e) {
      final retryable = e.statusCode == 429 || e.statusCode == null;
      if (!retryable || attempt >= maxRetries) rethrow;
      await delay(e.retryAfter ?? Duration(seconds: 2 << attempt));
    }
  }
}
