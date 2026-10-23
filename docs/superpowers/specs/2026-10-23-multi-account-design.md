# 多帳號切換（2026-10-22／23）

使用者需求：多個 Riot 帳號之間切換，不用每次重新登入。2026-10-23 選擇方案 A（手機 App 保存各帳號的 Riot 登入 cookie）。

## 帳號清單
- `SessionStorage` 改成帳號清單 `riotAccounts`（puuid、名稱、shard、token、autoRenew、cookies）與目前帳號 `riotActiveAccount`；
  舊版的 `riotSession`／`riotAutoRenew` 讀到時自動轉移。
- token 過期只刪 token、保留帳號；登出刪除整個帳號（含 cookie）。
- 各帳號的商店分開保存（`ShopStorage.loadFor/saveFor/removeFor`），切換時換成該帳號的。
- 帳號頁列出已保存的帳號：點一下切換、右側登出；登入頁有「新增其他帳號」。

## 方案 A：手機 App 保存各帳號的 ssid
- 原生 MethodChannel `valorant_shop_tracker/riot_cookies`：`read` 回傳內嵌頁 `auth.riotgames.com` 的 `ssid`，
  `write` 放回 `ssid`（Path=/、Secure、HttpOnly）。Android 用 `CookieManager`，iOS 用 `WKWebsiteDataStore.default()`。
- App 內登入（autoRenew）與背景續期成功後讀出並保存 `ssid`。
- 切換帳號：清除內嵌頁的 Riot cookie → 放回目標帳號的 `ssid`（沒有就只清除）。目標的 token 已過期時，
  `RiotAutoRenew` 會在背景用這個 `ssid` 換新 token；`renew` 拿到別的 puuid 時拒絕。
- 新增其他帳號：先清除內嵌頁 cookie，Riot 才會顯示登入頁。
- 網頁版讀不到 Riot cookie：只保存 token，1 小時內可直接切換，過期要重新登入；
  新增帳號前要先在 Riot 網站登出或用無痕視窗（畫面上有說明）。

## 風險（已告知使用者）
- `ssid` 等同長期登入憑證，存在手機上；手機或備份外流時，對方在 cookie 過期前（約數週）都能登入。
- Riot 可能視為自動化登入（同社群的 Cookie Reauth）。
- 尚未實機驗證：Riot 是否接受放回的 `ssid`、`ssid` 是否需要其他 cookie 一起才有效。

## 測試
- `test/providers/multi_account_test.dart`：帳號清單、切換、過期、商店分開、方案 A 的保存／放回／登出刪除（假 ssid）。
