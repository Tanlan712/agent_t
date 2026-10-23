import 'dart:convert';

/// Riot 官方購買紀錄的一筆（從客服網站的紀錄表格讀出的文字解析而來）。
class PurchaseRecord {
  final DateTime? date;
  final String item;

  /// 這筆得到的 VP；表格裡沒有 VP 數字時為 null。
  final int? vp;

  /// 付款金額的原始文字（含幣別，例如「NT$ 990」）；沒有時為 null。
  final String? price;

  const PurchaseRecord({this.date, required this.item, this.vp, this.price});

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) => PurchaseRecord(
        date: DateTime.tryParse(json['date'] as String? ?? ''),
        item: json['item'] as String? ?? '',
        vp: json['vp'] as int?,
        price: json['price'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (date != null) 'date': date!.toIso8601String(),
        'item': item,
        if (vp != null) 'vp': vp,
        if (price != null) 'price': price,
      };
}

/// 按下「匯入」時在官方購買紀錄頁執行的唯讀腳本（AGENTS.md 第 3 節）：
/// 只讀表格（或 role="row"）每一列各格的文字，回傳 JSON 字串。
/// 不讀 cookie、storage、表單，不送請求、不點擊。
const purchaseScrapeScript = '''
(() => {
  const text = (el) => (el.innerText || el.textContent || '').trim();
  let rows = Array.from(document.querySelectorAll('table tr'));
  if (rows.length === 0) rows = Array.from(document.querySelectorAll('[role="row"]'));
  const out = rows.map((row) => {
    let cells = Array.from(row.querySelectorAll('th, td, [role="cell"], [role="gridcell"], [role="columnheader"]'));
    if (cells.length === 0) cells = Array.from(row.children);
    return cells.map(text);
  }).filter((cells) => cells.some((c) => c.length > 0));
  return JSON.stringify(out);
})()
''';

/// 只有這個網站的頁面可以執行 [purchaseScrapeScript]。
const purchaseHistoryHost = 'support.riotgames.com';

/// 內嵌頁允許前往的網址：Riot 的網站（客服網站與 Riot 登入）。
/// 子框架（例如登入頁的人機驗證）不限制。
bool allowPurchaseNavigation(String url, {bool isMainFrame = true}) {
  if (!isMainFrame) return true;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  return uri.host == 'riotgames.com' || uri.host.endsWith('.riotgames.com');
}

/// 腳本的回傳值：Android 會把字串再包一層 JSON，iOS 直接是字串。
List<List<String>> decodeScrapeResult(Object? result) {
  Object? value = result;
  for (var i = 0; i < 2 && value is String; i++) {
    try {
      value = jsonDecode(value);
    } catch (_) {
      return const [];
    }
  }
  if (value is! List) return const [];
  return [
    for (final row in value)
      if (row is List) [for (final c in row) '$c'.trim()],
  ];
}

final _isoDate = RegExp(r'(\d{4})[-/.年](\d{1,2})[-/.月](\d{1,2})');
final _usDate = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})');
final _vp = RegExp(r'([\d,]+)\s*(VP|V-Points|VALORANT\s*Points|點)',
    caseSensitive: false);
final _money = RegExp(
    r'(NT\$|US\$|HK\$|\$|€|£|¥|₩|TWD|USD|HKD)\s*[\d,.]+|[\d,.]+\s*(TWD|USD|HKD|元)');

DateTime? _date(String s) {
  if (_isoDate.firstMatch(s) case final m?) {
    return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }
  if (_usDate.firstMatch(s) case final m?) {
    return DateTime(int.parse(m[3]!), int.parse(m[1]!), int.parse(m[2]!));
  }
  return null;
}

/// 把表格各列解析成紀錄：每列找日期、VP 數量、金額，剩下最長的文字當品項。
/// 沒有日期也沒有 VP／金額的列（例如標題列）略過。格式寬鬆，Riot 改版時仍盡量讀得到。
List<PurchaseRecord> parsePurchaseRows(List<List<String>> rows) {
  final records = <PurchaseRecord>[];
  for (final row in rows) {
    DateTime? date;
    int? vp;
    String? price;
    final rest = <String>[];
    for (final cell in row) {
      if (cell.isEmpty) continue;
      final d = date == null ? _date(cell) : null;
      if (d != null) {
        date = d;
        continue;
      }
      final v = vp == null ? _vp.firstMatch(cell) : null;
      if (v != null) {
        vp = int.tryParse(v[1]!.replaceAll(',', ''));
        // 「1000 VP」這種格子本身就是品項名稱時，也留給品項。
        rest.add(cell);
        continue;
      }
      final m = price == null ? _money.firstMatch(cell) : null;
      if (m != null) {
        price = m[0]!.trim();
        continue;
      }
      rest.add(cell);
    }
    if (date == null && vp == null && price == null) continue;
    rest.sort((a, b) => b.length.compareTo(a.length));
    records.add(PurchaseRecord(
      date: date,
      item: rest.isEmpty ? '購買' : rest.first,
      vp: vp,
      price: price,
    ));
  }
  return records;
}

/// 官方紀錄裡記錄到的 VP 合計。
int purchasedVp(List<PurchaseRecord> records) =>
    records.fold(0, (sum, r) => sum + (r.vp ?? 0));
