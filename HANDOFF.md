# VP 儲值紀錄 — 交接

- 分支：`claude/project-thread-ae16rz`（已 push，尚未開 PR，未合併 master）
- 結論：Riot 遊戲 token 能讀的端點沒有儲值／交易紀錄 API，錢包只回傳目前餘額。

## 已完成（全部測試通過 1663 個，analyze 無 error/warning）
- `lib/providers/wallet_log_provider.dart` + `storage/wallet_log_storage.dart`（key `wallet_log_v1`，依 puuid 分帳號）+ `models/wallet_log.dart` + `logic/wallet_history.dart`
- `RiotProvider.onWallet` 在每次 sync 後回呼（傳原始造型等級 ItemID），main.dart 接上；不另外送請求
- 新頁 `/wallet`「錢包紀錄」（`screens/wallet_page.dart`）：目前 VP、記錄到的儲值／花費合計、每筆變化（儲值 +N / 花費 N / 新造型名稱）、清除紀錄、從 Riot 更新按鈕
- 導覽、EVA 名稱、英文標籤都加了 `/wallet`
- AGENTS.md §3 錢包那列補上「使用者決定 2026-10-22」說明（無新端點）
- E 主題側邊抽屜改成 SingleChildScrollView（多一個項目在 900 高會 overflow）
- 測試：`test/providers/wallet_log_provider_test.dart`、`test/screens/wallet_page_test.dart`

## 待辦
- 使用者還沒在決定卡上確認做法（建議選項：本機記錄錢包變化）；確認後開 draft PR
- 沒有實機測試

## 注意
- 只記得到有開 App 同步的時段；兩次同步之間的儲值+花費會合併成淨變化
- 跑測試時 `dart format lib test` 會改到無關檔案，只 format 自己改的檔
