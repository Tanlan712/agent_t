import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logic/shop_time.dart';
import '../models/current_shop.dart';

/// Android 主畫面小工具要顯示的內容：今天的每日商店（名稱、價格）、到期時間、夜市。
/// 只含商店資料，不含 token 或帳號資訊。沒有每日商店時為 null。
Map<String, dynamic>? homeWidgetData(CurrentShop shop,
    String? Function(String skinUuid) nameOf, DateTime now) {
  final expires = shop.dailyExpiresAt;
  if (shop.daily.isEmpty || expires == null) return null;
  return {
    'lines': [
      for (final e in shop.daily)
        {'name': nameOf(e.skinUuid) ?? '未知造型', 'price': e.price},
    ],
    'expiresAt': expires.millisecondsSinceEpoch,
    if (isNightMarketActive(shop, now))
      'night': '夜市開放中（${shop.nightMarket.length} 款）',
  };
}

/// 把商店送到 Android 主畫面小工具（channel `agent_t/home_widget`）。網頁版與 iOS 不做任何事。
class HomeWidgetSync {
  static const _channel = MethodChannel('agent_t/home_widget');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String? _last;

  Future<void> push(CurrentShop shop, String? Function(String) nameOf,
      {DateTime Function() now = DateTime.now}) async {
    if (!supported) return;
    final data = homeWidgetData(shop, nameOf, now());
    if (data == null) return;
    final json = jsonEncode(data);
    if (json == _last) return;
    _last = json;
    try {
      await _channel.invokeMethod<void>('update', json);
    } catch (e) {
      debugPrint('更新主畫面小工具失敗：${e.runtimeType}');
      _last = null;
    }
  }
}
