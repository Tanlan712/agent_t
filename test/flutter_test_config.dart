import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// 測試不連網：google_fonts 不在執行時下載字體（App 在測試裡用系統字體）。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
