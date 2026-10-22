# PWA 加強：交接（2026-10-22）

分支：`claude/project-thread-kvpgt1`（WIP，尚未開 PR，不要直接合併到 master）
使用者選擇：四項全做（離線開啟、App 內安裝按鈕、新版本更新提示、商店刷新推播）。

## 已完成
- master 963058f：manifest 加 `shortcuts`（商店／對戰／即時／收藏）與 `launch_handler: focus-existing`。
- 分支 WIP（只改 web/，Dart 端還沒寫）：
  - `web/share_login_sw.js`（檔名沿用避免留下舊註冊）：分享登入不變；同站 GET 走 network-first（navigate 直接 fetch(request) 避免轉址錯誤，其他用 `cache:'no-cache'`）；
    www.gstatic.com／fonts.gstatic.com／fonts.googleapis.com cache-first；media.valorant-api.com cache-first 上限 600 筆；
    `app_build.json` 不快取；Riot 主機完全不攔截；`push` 顯示通知、`notificationclick` 打開 `./#/`。
  - `web/flutter_bootstrap.js`：`window.agentTPwa`（canInstall/install、isStandalone、isIos、isOnline/onOnlineChange、reload、
    notificationPermission、pushSubscription/subscribePush(vapidKey)/unsubscribePush、testNotification）。

## 待做
1. `lib/services/pwa.dart` + `pwa/stub.dart` + `pwa/web.dart`（照 `lib/services/shared_login*` 的條件匯入寫法，用 dart:js_interop 呼叫 agentTPwa）。
2. 離線提示列 + 更新提示列：包在 `main.dart` 的 MaterialApp `builder`（RiotAutoRenew 外層），頂端加條；注意 SafeArea 與 MediaQuery.removePadding。
3. 更新偵測：`deploy.yml` 建置加 `--dart-define=APP_BUILD=${{ github.sha }}`，建置後寫 `build/web/app_build.json` {"build": sha}；
   App 啟動後、每 30 分鐘、回到前景時以 no-store 抓 `app_build.json?t=…` 比對，不同就顯示「有新版本 → 重新整理」。APP_BUILD 為空（本機）時不檢查。
4. 設定頁加「安裝 App」卡（只在 kIsWeb）：可安裝→按鈕；iOS 未安裝→「分享 → 加入主畫面」教學；已 standalone→顯示已安裝。
5. 推播：設定頁「商店刷新通知」卡（訂閱、測試通知、複製訂閱 JSON）；VAPID 公鑰用 repo variable `VAPID_PUBLIC_KEY` 經 dart-define 帶入；
   新 workflow `.github/workflows/shop-push.yml`：cron `0 0 * * *`（UTC，台灣 08:00，GitHub 可能延遲）+ workflow_dispatch，
   用 node `web-push` 對 secret `PUSH_SUBSCRIPTIONS`（JSON 陣列）送通知，私鑰在 secret `VAPID_PRIVATE_KEY`。
   repo 是公開的：絕不可把私鑰或訂閱印到 Actions log。寫 `docs/push.md` 教使用者 `npx web-push generate-vapid-keys` 與設定 secrets。
   iPhone 只有加到主畫面（iOS 16.4+）才收得到。原生 APK／iOS 的本機通知未規劃，需再問使用者。
6. 測試：`test/build/share_target_test.dart` 的「service worker 不呼叫 fetch(」會失敗，要改成「Riot 主機（riotgames.com、pvp.net）不在快取清單、POST 只處理 share-login」；
   補 Dart 的單元／widget 測試；`flutter analyze`、`flutter test`、`flutter build web` 全過（CI 用 Flutter 3.24.5）。
7. 文件：AGENTS.md §4 目前寫「service worker…也不快取網站」，要記錄使用者決定（2026-10-22 選全部四項）並改寫；新增 spec
   `docs/superpowers/specs/2026-10-22-pwa-offline-push-design.md`（SW 註解已引用這個檔名）。
8. 推上分支、開 draft PR（新功能走 PR）。

## 注意
- 只能有一個 service worker（share_login_sw.js），不要再加。
- 用 Playwright 離線模式實測：離線開啟時 CanvasKit 與中文字型要已在快取，否則白畫面／缺字。
