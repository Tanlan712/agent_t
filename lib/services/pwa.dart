/// PWA 功能：離線提示、安裝 App、新版本提示、商店刷新通知
/// （規格 docs/superpowers/specs/2026-10-22-pwa-offline-push-design.md）。
/// 網頁以外的平台（含 flutter test）一律回報不支援。
library;

export 'pwa/platform.dart';
export 'pwa/stub.dart' if (dart.library.js_interop) 'pwa/web.dart';
