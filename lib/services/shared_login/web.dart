import 'dart:js_interop';

import 'package:flutter/foundation.dart';

/// 定義在 web/flutter_bootstrap.js。
@JS('valorantTakeSharedLogin')
external JSPromise<JSString?> _take();

Future<String?> takeSharedLogin() async {
  try {
    return (await _take().toDart)?.toDart;
  } catch (e) {
    // 內容可能含 token，只記錄類型。
    debugPrint('讀取分享登入失敗：${e.runtimeType}');
    return null;
  }
}
