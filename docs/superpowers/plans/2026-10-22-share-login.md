# Android 分享登入 Implementation Plan

**Goal:** 在 playvalorant.com 跳轉頁按「分享」選本 App 就登入（Android PWA）。

**Spec:** `docs/superpowers/specs/2026-10-22-share-login-design.md`

## Global Constraints
- 不新增 Riot 端點；token 只在這支手機的瀏覽器內傳遞，不寫入 log（AGENTS.md 第 3、4 節）。
- `lib/` 不可用 `dart:io`；Web 專用程式碼以條件匯入隔開，`flutter test` 走 stub。

## Tasks
- [x] 1. 測試 `findRiotRedirect`（`test/services/riot_auth_test.dart`）→ 在 `lib/services/riot_auth.dart` 實作。
- [x] 2. 測試登入頁接收分享文字（`test/screens/share_login_test.dart`）→ `lib/services/shared_login.dart`（條件匯入 stub／web）與 `RiotLoginPage.takeShared`。
- [x] 3. 測試設定檔（`test/build/share_target_test.dart`）→ `web/manifest.json`、`web/share_login_sw.js`、`web/flutter_bootstrap.js`、`web/index.html`。
- [x] 4. AGENTS.md 第 4 節記錄使用者決定與風險。
- [x] 5. `flutter analyze`、`flutter test`、`flutter build web --base-href /valorant_shop_tracker/` 全部通過。
