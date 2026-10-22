# 延長登入：一鍵重新登入與 App 背景續期（2026-10-22）

使用者核准（2026-10-22，「A 和 B 都做」）。不新增 Riot 端點，token 保存方式不變（AGENTS.md 第 4 節）；B 改寫了 AGENTS.md 第 3 節原本「不做自動續期」的規定。

## 為什麼拿不到 refresh token
- 目前的登入網址是 OAuth 隱含流程（`response_type=token id_token`，client `play-valorant-web-prod`），規格（RFC 6749 §4.2.2）不發 refresh token。
- 改用 `response_type=code`：code 會送到 playvalorant.com，而且換 token 的 `POST auth.riotgames.com/token` 要 Riot 核准的 RSO client secret。
- RSO 只給通過審核的正式產品，token 也不能讀 `pd.*.a.pvp.net` 的商店。
- 社群的「Cookie Reauth」就是重開同一個登入網址：Riot 還記得使用者（`ssid` cookie）時直接跳轉，不用輸入密碼。

## A. 一鍵重新登入（網頁與 App）
- `RiotProvider.needsRelogin`：曾經登入但已過期（含重新開頁時讀到過期的登入資訊，`SessionStorage.expiredOnLoad`）；按「登出」後為 false。
- 各頁遇到 401／403 改呼叫 `RiotProvider.expire()`（刪除 token、提示重新登入、保留自動續期），不再等同使用者登出。
- 提醒列（`ExpiryBanner`）在快到期與已過期時都顯示；「重新登入」在網頁版會同時開新分頁到 Riot 登入頁並切到登入頁。

## B. App 背景續期（只有 Android／iOS App）
- App 內登入成功時 `login(autoRenew: true)` 記下 `riotAutoRenew`（不含 token）；貼網址或分享登入則清掉。
- `RiotAutoRenew`（包在 MaterialApp 的 builder 外層）每分鐘檢查：可續期、且剩不到 10 分鐘或已過期時，
  放一個 1×1、不接收點擊的 `SilentRiotLogin` 內嵌頁，只開 `riotLoginUrl`，攔下跳轉網址交給 `RiotProvider.renew`。
- 不注入 JavaScript、不讀 cookie、不保存 cookie：cookie 只由 WebView 自己帶。
- 45 秒沒跳轉（Riot 要求輸入密碼）就放棄；5 分鐘後再試，連續失敗 3 次停止，等使用者自己登入。
- `renew` 失敗時不登出；換成另一個帳號時清掉前一個帳號的錢包與已擁有資料。
- 按「登出」：清掉 `riotAutoRenew`，並清除 WebView 的 cookie（`clearRiotWebLogin`）。

## 風險（已告知使用者）
- 等於 Cookie Reauth，Riot 可能視為自動化登入；Riot 也可能擋內嵌網頁登入。
- 手機被別人拿走時，在 Riot 登入記錄過期前（約數週，依 Riot 設定）對方都能讀取帳號資料。用完請按「登出」。
- 沒有實機驗證隱藏的內嵌頁在 Android／iOS 上能否正常跳轉；失敗時只會退回到提醒列。

## 測試
- `RiotProvider`：autoRenew 旗標、renew 成功／網址無效／失敗不登出、過期與重新開頁的 needsRelogin、登出清除與 onLogout。
- `RiotAutoRenew`：還很久才過期不動作、快到期時續期、貼網址登入不續期、網頁版不續期、沒有跳轉時逾時並在 3 次後停止。
- 提醒列：過期後顯示「Riot 登入已過期」，登出後消失。
