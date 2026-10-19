import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 讀取 [key] 的 JSON；不存在或損壞時回傳 [fallback]。
T readPrefsJson<T>(
  SharedPreferences prefs,
  String key,
  T Function(Object? json) parse,
  T fallback,
) {
  final raw = prefs.getString(key);
  if (raw == null) return fallback;
  try {
    return parse(jsonDecode(raw));
  } catch (e) {
    debugPrint('$key 資料損壞，改用預設值：$e');
    return fallback;
  }
}

Future<bool> writePrefsJson(SharedPreferences prefs, String key, Object json) =>
    prefs.setString(key, jsonEncode(json));
