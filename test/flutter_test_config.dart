import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:valorant_shop_tracker/theme/app_palette.dart';
import 'package:valorant_shop_tracker/widgets/theme/eva/eva_header.dart';

/// 測試不連網：google_fonts 不在執行時下載字體（App 在測試裡用系統字體）。
/// 每個測試開始前把目前配色重設為預設主題，避免測試之間互相影響。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUp(AppPalette.reset);
  // EVA 代碼行在凌晨 0～5 點會換成夜間版（E6）；固定在白天，測試結果才不受執行時間影響
  // （CI 用 UTC，台灣早上 8～13 點就是 UTC 的凌晨）。需要夜間的測試自己設定。
  setUp(() => EvaCodeLine.now = () => DateTime(2026, 10, 21, 12));
  await testMain();
}
