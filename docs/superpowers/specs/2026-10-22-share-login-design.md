# Android「分享」登入（2026-10-22）

使用者核准（2026-10-22，選項 B）。不新增 Riot 端點，token 的保存方式不變（AGENTS.md 第 4 節）。

## 目標
手機上不用再「複製網址列 → 切回本站 → 貼上 → 按完成登入」：在 playvalorant.com 跳轉頁按瀏覽器的「分享」，選這個 App，就直接登入。
只支援把本站安裝成 App（PWA）的 Android Chrome／Edge；iOS Safari 不支援 Web Share Target，維持手動貼上。

## 1. manifest（`web/manifest.json`）
- `share_target`：`action` 為 `./share-login`，`method` 為 **POST**，`enctype` 為 `multipart/form-data`，參數 `title`／`text`／`url`。
  - 不用 GET：GET 會把 token 放進網址查詢字串，送到 GitHub Pages 並留在伺服器紀錄。
- 補上 `id`、`scope`、正式名稱與說明，分享選單才會顯示可辨識的名稱。

## 2. Service worker（`web/share_login_sw.js`）
- **只**攔截 POST 到 `share-login` 的請求；其他請求一律不攔截、不快取、不發出任何網路請求。
- 讀出表單的 `url`／`text`／`title`，整段文字存進 Cache Storage（快取名稱 `share-login`、鍵 `pending`，附時間戳記），
  然後以 303 轉到 `./#/riot-login`。token 不會離開這支手機。
- 啟用時刪除 Flutter 舊 service worker 留下的 `flutter-*` 快取。
- 不再使用 Flutter 預設的 `flutter_service_worker.js`（它會快取整個網站）：自訂 `web/flutter_bootstrap.js`，
  改註冊 `share_login_sw.js` 後再呼叫 `_flutter.loader.load()`。同一個 scope 只會有一個 service worker，新的會取代舊的。
- `flutter_bootstrap.js` 提供 `window.valorantTakeSharedLogin()`：讀出並**立即刪除** `pending`；超過 10 分鐘的資料直接丟棄。

## 3. 登入頁
- `RiotLoginPage` 開啟時呼叫一次 `takeSharedLogin()`（Web 以 `dart:js_interop` 呼叫上面的函式，其他平台回傳 null；可由建構子注入，方便測試）。
- 取得文字時：用 `findRiotRedirect` 找出含 `access_token=` 的那段網址，填入輸入框並自動執行「完成登入」；錯誤沿用現有訊息。
- 找不到登入資訊時顯示「分享的網址找不到登入資訊……」。
- 頁面加一行說明：Android 安裝成 App 後，可在跳轉頁按「分享」選本 App 直接登入。

## 已知風險與限制（要如實告知使用者）
- 如果 service worker 不在（例如清除了網站資料，但桌面上的 App 還在），分享時瀏覽器會把含 token 的表單直接 POST 到 GitHub Pages。
  GitHub 會收到這段資料（HTTPS 加密傳輸，通常不記錄請求內容，但無法保證）；伺服器回 405，登入不會成功。
  發生時請重新打開 App 一次（會重新註冊 service worker）再分享。
- Chrome 分享網址時是否保留 `#` 後面的片段，需要在實機確認；如果被拿掉，這個功能無法使用，只能回到手動貼上。
- 不再有 Flutter 的離線快取：沒網路時打不開網站（本來就需要網路才能用 Riot 資料）。

## 測試
- `findRiotRedirect`：只有網址、標題＋網址、多行文字、沒有 token、空字串。
- 登入頁：注入的分享文字有效時自動登入並顯示帳號；無效時顯示錯誤、不登入；沒有分享文字時不做任何事、只呼叫一次。
- 設定檔：manifest 的 `share_target` 是 POST、`action` 與 service worker 攔截的路徑一致；`flutter_bootstrap.js` 不註冊 `flutter_service_worker.js`；
  service worker 不呼叫 `fetch(`（不把資料往外送）。
