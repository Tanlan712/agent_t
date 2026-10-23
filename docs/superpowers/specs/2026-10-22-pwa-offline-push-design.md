# PWA 加強：離線開啟、安裝按鈕、新版本提示、商店刷新通知（2026-10-22）

使用者核准（2026-10-22，四項全做）。不新增 Riot 端點，token 的保存方式不變（AGENTS.md 第 4 節）。
只影響網頁版（含加到主畫面的 PWA）；Android／iOS App 沒有這些功能，`createPwaPlatform()` 回傳不支援。

## 1. Service worker（`web/share_login_sw.js`，仍然只有這一支）
- 分享登入不變（規格 2026-10-22-share-login-design.md）；POST 只攔截 `share-login`，其他 POST 不經過。
- 本站 GET：network-first。有網路時一律向伺服器確認（頁面原樣送出，其他檔案 `cache: 'no-cache'`），成功的回應存到 `agent-t-shell-v1`；
  離線時用快取，頁面請求找不到時回傳首頁（hash 路由）。
- 公開 CDN（`www.gstatic.com` 的 CanvasKit、`fonts.gstatic.com`／`fonts.googleapis.com` 字型）：cache-first。
- `media.valorant-api.com` 的造型圖片：cache-first，最多 600 筆，超過從最早的刪。
- `app_build.json` 不快取。Riot 的主機（auth、pd、glz、shared）完全不攔截：請求帶 token，不能進快取。
- service worker 的 fetch 只轉送頁面自己發出的 GET，不自己帶資料往外送。
- `push`：顯示通知；`notificationclick`：聚焦已開的視窗或開新視窗到 `./#/`。

## 2. 離線開啟
- 商店、錢包、收藏原本就存在 localStorage（ShopStorage 等），所以離線開啟後看到的是上次同步的資料。
- 畫面頂端顯示「離線中：顯示上次儲存的資料」提示列（`PwaBanners`，包在 MaterialApp builder 最外層），恢復連線就消失。

## 3. 新版本提示
- `deploy.yml` 建置時帶入 `--dart-define=APP_BUILD=<commit sha>`，建置後寫出 `build/web/app_build.json` = `{"build": sha}`。
- App 啟動時、每 30 分鐘、回到前景、恢復連線時，以 `cache: 'no-store'` 讀 `app_build.json?t=…`；和自己的 APP_BUILD 不同就顯示
  「有新版本 → 重新整理／稍後」。本機建置（APP_BUILD 為空）不檢查。

## 4. 安裝 App 卡（設定頁，只在網頁版）
- 瀏覽器有 `beforeinstallprompt`：顯示「安裝 App」按鈕（事件在 `flutter_bootstrap.js` 先攔下）。
- iPhone／iPad 未安裝：顯示「分享 → 加入主畫面」教學。已用獨立視窗開啟：顯示已安裝。其他：說明從瀏覽器選單安裝。

## 5. 商店刷新通知
- 設定頁「商店刷新通知」卡：開啟通知（要求權限並以 VAPID 公鑰訂閱）、測試通知（本機顯示，不經伺服器）、複製訂閱資料、取消訂閱。
- VAPID 公鑰放 repo variable `VAPID_PUBLIC_KEY`，經 dart-define 帶入；沒有設定時卡片只顯示設定說明。
- `.github/workflows/shop-push.yml`：cron `0 0 * * *`（UTC，台灣 08:00）與手動執行，用 `tool/shop_push/send.mjs`（web-push 3.6.7）
  對 secret `PUSH_SUBSCRIPTIONS`（JSON 陣列）送固定內容的通知；私鑰在 secret `VAPID_PRIVATE_KEY`。
- repo 是公開的：私鑰與訂閱只經環境變數傳入，log 只寫「第 N 筆：已送出／失敗（狀態碼）」，不印訂閱網址、金鑰或錯誤內容。
- 通知內容固定，不連 Riot、不讀帳號資料。設定步驟見 `docs/push.md`。

## 已知限制
- iPhone 只有加到主畫面（iOS 16.4 以上）才收得到通知。
- GitHub 排程可能延遲幾分鐘到一小時。
- 訂閱失效（清除網站資料、重新安裝）時要重新訂閱並更新 secret。
- 原生 APK／iOS 的通知未規劃，需再問使用者。
- 第一次離線開啟前，至少要有網路開過一次（CanvasKit 與字型才會在快取裡）。
