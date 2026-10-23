import 'package:http/http.dart' as http;

/// valorant-api.com 的共用 GET 客戶端：同一網址同時只下載一次，
/// 成功的回應在這次開啟期間重複使用（目錄、對戰參考、通行證都會要武器與特務）。
/// 非 GET 或失敗的回應不快取。
class SharedGetClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, Future<_Cached>> _entries = {};

  SharedGetClient([http.Client? inner]) : _inner = inner ?? http.Client();

  /// 查詢參數排序後的網址，讓參數順序不同的請求共用。
  static String keyOf(Uri url) {
    final params = url.queryParametersAll.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return url
        .replace(
            queryParameters: params.isEmpty ? null : Map.fromEntries(params))
        .toString();
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method != 'GET') return _inner.send(request);
    final key = keyOf(request.url);
    final future = _entries[key] ??= _fetch(request);
    final _Cached c;
    try {
      c = await future;
    } catch (_) {
      if (identical(_entries[key], future)) _entries.remove(key);
      rethrow;
    }
    if (c.status != 200 && identical(_entries[key], future)) {
      _entries.remove(key);
    }
    return http.StreamedResponse(Stream.value(c.body), c.status,
        contentLength: c.body.length,
        request: request,
        headers: c.headers,
        reasonPhrase: c.reason);
  }

  Future<_Cached> _fetch(http.BaseRequest request) async {
    final copy = http.Request('GET', request.url)
      ..headers.addAll(request.headers);
    final res = await _inner.send(copy);
    final body = await res.stream.toBytes();
    return _Cached(res.statusCode, res.headers, body, res.reasonPhrase);
  }

  void clear() => _entries.clear();

  @override
  void close() {
    // 共用的客戶端在整個 App 期間都要用，個別頁面關閉時不關掉。
  }
}

class _Cached {
  final int status;
  final Map<String, String> headers;
  final List<int> body;
  final String? reason;

  const _Cached(this.status, this.headers, this.body, this.reason);
}

/// App 內所有 valorant-api.com 請求預設共用的客戶端。
final valorantApiHttp = SharedGetClient();
