/// Android「分享」登入：取出 service worker 暫存的分享內容（取出後即刪除）。
/// Web 以外的平台（含 flutter test）沒有分享內容，一律回傳 null。
library;

export 'shared_login/stub.dart'
    if (dart.library.js_interop) 'shared_login/web.dart';
