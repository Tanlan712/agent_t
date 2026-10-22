# 我的收藏：點特務看等級（2026-10-22）

## 需求

使用者要求：在「我的收藏 › 特務」點特務，可以查看這個特務的等級。

## 設計

- 特務卡片可以點，開啟 `AgentLevelPage`（`lib/screens/details/agent_level_page.dart`），有返回鍵。
- 頁面上方是特務頭像、名稱與定位；下方是合約卡片：合約名稱、`第 X 階 / Y`、下一階經驗進度，以及依章節列出的每階獎勵（已達成打勾、下一階紅框）。
- 合約卡片與「通行證與任務」頁共用 `PassCard`（`lib/widgets/pass_card.dart`，從 `progress_page.dart` 抽出，行為不變）。
- `agentContract(snapshot, ref, agentUuid)`（`progress_logic.dart`）回傳 `BattlePass`：
  - 有進度紀錄時用 `ProgressionLevelReached`／`ProgressionTowardsNextLevel`；
  - 沒有紀錄（尚未開始）時從第 0 階開始；
  - 參考資料沒有這個特務的合約或合約沒有階級時回傳 null，頁面顯示「找不到這個特務的合約資料」。
- 合約資料還在讀取時顯示「讀取等級中…」，讀取失敗時顯示「無法取得等級」。

## 範圍與規則

- 不新增端點：只用已讀到的 `contracts/v1/contracts/{puuid}`（GET）與 valorant-api.com 的合約參考資料（AGENTS.md 第 3 節）。
- 不加入啟用合約或任何寫入（合約按鈕已依使用者決定移除）。

## 測試

- `test/logic/progress_logic_test.dart`：`agentContract` 有進度、尚未開始、沒有合約或沒有階級。
- `test/screens/collection_page_test.dart`：點特務開啟等級頁（1440 寬）；尚未開始的特務從第 0 階開始（375 寬，不溢出）；沒有合約資料時的說明。
