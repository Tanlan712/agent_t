import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_shop_tracker/theme/app_palette.dart';

/// 測試不連網：google_fonts 不在執行時下載字體（App 在測試裡用系統字體）。
/// 每個測試開始前把目前配色重設為預設主題，避免測試之間互相影響。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(AppPalette.reset);
  await testMain();
}
