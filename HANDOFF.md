# 交接：多帳號切換

- 分支：`claude/project-thread-0mn0sk`（WIP commit ff9e141，基於 master 6acf82f，尚未開 PR）
- 需求：多帳號切換不用再次登入（新功能 → 要開 PR，使用者同意前不合併）

## 已完成
- `lib/storage/session_storage.dart`：改成帳號清單（`riotAccounts` + `riotActiveAccount`），`SavedAccount` 模型；舊的 `riotSession`／`riotAutoRenew` 自動轉移。過期只刪 token、保留帳號；登出刪整個帳號。
- `lib/providers/riot_provider.dart`：`accounts`、`activePuuid`、`switchAccount`、`removeAccount`、`prepareNewLogin`（App 新增帳號前清內嵌頁 cookie）、`timeLeftOf`；`renew` 拿到不同 puuid 時拒絕（`otherAccountMessage`）；`onAccountChanged`／`onAccountRemoved` 回呼。
- 各帳號自己的商店：`ShopStorage.loadFor/saveFor/removeFor`、`ShopProvider.switchAccount/forgetAccount`，在 `main.dart` 接上。
- UI：`lib/widgets/account_list.dart`（已保存帳號清單，點一下切換、右側登出）；`riot_login_page.dart` 加「新增其他帳號」。
- `RiotAutoRenew`：切換帳號時重設失敗次數。
- 測試：`test/providers/multi_account_test.dart`（新）；`app_harness.dart` 加 `storeSession`、`onLogout` 參數；改了 `riot_renew_test`、`quick_login_test` 的斷言。

## 還沒做
1. 1 個測試失敗：multi_account_test「已登入時按『新增其他帳號』顯示登入方式」，`scrollUntilVisible(find.text('完成登入'))` 那段（大概要指定 scrollable，或改用 `ensureVisible`）。其餘 1632 個測試都過；`flutter analyze` 沒有新的 warning。
2. **等使用者決定**（決定卡已在討論串）：A＝App 用原生程式（MainActivity.kt／AppDelegate.swift 的 MethodChannel `valorant_shop_tracker/riot_cookies`）讀出並保存每個帳號的 Riot cookie（ssid），切換時放回內嵌頁 → 幾週內免密碼；B＝只存各帳號 token（1 小時內秒切）。建議 A。A 會違反 AGENTS.md §3（不得讀取／保存 ssid），所以使用者同意前不能寫；auto mode 分類器也擋過一次。
   - 選 B 的話：App 內登入帳號 X 時，要把其他帳號的 `autoRenew` 設成 false（內嵌頁只記得最後一個帳號）。
3. 更新 AGENTS.md §4（允許保存多個帳號的 token），選 A 的話還要更新 §3；寫規格到 `docs/superpowers/`。
4. 網頁版要另外說明：Riot 會直接登入瀏覽器記得的帳號，新增帳號要先登出 Riot 或用無痕視窗（UI 文字已經寫了）。
5. 開 draft PR，用 `flutter build web` 檢查。

## 注意事項
- 雲端容器沒有 Flutter：要從 storage.googleapis.com 下載 3.24.5（和 CI 同版本）。
- 已存的 token 不得出現在 log 或測試裡（只能用 `fakeJwt`）。
