# 玩家表現、最近 5 場與玩家對戰紀錄 設計規格

- 日期：2026-10-20
- 狀態：待使用者審閱
- 前置：`2026-10-20-match-history-design.md`（對戰紀錄，已合併 master `cc3974e`）

## 1. 目標與範圍

### 使用者明確提出
- 在單場詳情中，為每位玩家加入更完整的「分數表現」，內容包括：
  - **加強版數據**：K/D 比、ADR、首殺數、分數。
  - **遊戲內系統的評分**：**賽後表現評分**、**戰鬥分數（ACS）**、**全場 MVP 與隊伍 MVP**。
- 每位玩家都顯示他**最近 5 場**的表現，採用**背景分批載入**。
- **點擊玩家**時，可以查看他過去的對戰紀錄。

### 推定（審閱時請確認）
- 個人自用、只在本機執行，沿用「請勿公開或分享他人資訊」的提示。
- 玩家頁不顯示對方的牌位趨勢，因為那需要另一個端點，也會增加請求量。

### 不做（YAGNI）
- 其他玩家的牌位變化圖、回合時間軸、擊殺地圖、搜尋任意 Riot ID。

## 2. 待驗證的前提（實作第一步，需要使用者登入）

| # | 項目 | 驗證方式 | 不成立時的處理 |
|---|---|---|---|
| V1 | 能否用其他玩家的 puuid 呼叫 `match-history/v1/history/{puuid}` 與相關的 match-details | 用使用者的登入，查一位同場玩家 | 「最近 5 場」與玩家頁改為顯示「Riot 不提供這位玩家的紀錄」，其餘功能照做 |
| V2 | 賽後表現評分對應 `players[].scores` 裡的哪個欄位（欄位名稱是沒有文件的 `TempValueA`～`TempValueV`；實測結構包含 `damage`／`killImpact`／`deathImpact`／`trades`／`assists`／`defuses`／`plants`／`utilityUsage`／`distinction`／`merit`／`pass` 等子欄位） | 暫時性的除錯顯示列出自己那一列的原始數值，請使用者對照遊戲內同一場的評分 | 這一項暫不實作，其他功能照做 |
| V3 | MVP 判定 | 比對 `matchMvp`（若存在）與「全場最高分＝全場 MVP、另一隊最高分＝隊伍 MVP」的推算結果 | 以推算規則為準 |

除錯顯示只存在於驗證期間，完成後移除，不進入正式版本。

## 3. 加強版數據（`logic/match_mapper.dart`，純函式）

在 `PlayerLine` 新增以下欄位：
- `kd`：`kills / deaths`，deaths 為 0 時等於 kills。顯示到小數點後兩位。
- `adr`：該玩家在所有回合 `playerStats[].damage[].damage` 的總和 ÷ `roundsPlayed`，四捨五入；`roundsPlayed` 為 0 時為 0。
- `firstKills`：每回合 `kills[]` 中 `roundTime`（或 `gameTime`）最小的那一筆，算給它的 `killer`。
- `mvp`：`MvpKind { none, match, team }`。依 V3 的結果決定判定方式。
- `rating`：賽後表現評分，型別為 `double?`。依 V2 的結果決定欄位；沒有對應欄位時為 null，畫面顯示「—」。

計分板欄位依序為：特務、Riot ID（含 MVP 標籤）、牌位、評分、K/D/A、K/D、ACS、ADR、爆頭率、首殺、等級、最近 5 場。窄螢幕時保留水平捲動。

## 4. 最近 5 場（背景分批載入）

- 新元件 `RecentFormLoader`：
  - 打開詳情後，先顯示計分板，再把 10 位玩家依序放進佇列。
  - 每位玩家要做的事：查他的 match-history（取 5 場）→ 抓這 5 場的詳情 → 取出他自己那一列 → 產生 `RecentForm { List<FormGame> games, double? avgAcs }`，其中 `FormGame { matchId, won, acs, agentId }`。
- 並行上限：同時最多 2 個請求。
- 429 處理：依 `Retry-After` 等待，沒有這個標頭時退避 2s、4s、8s，最多重試 3 次。
- 快取：玩家與場次都快取在記憶體裡，並與 `MatchHistoryProvider` 共用新的 `MatchDetailCache`。同一場詳情只會抓一次。
- 離開詳情頁時取消尚未開始的工作。
- 顯示：
  - 「最近 5 場」欄位是 5 個小方塊，用勝或敗的顏色標示，方塊上寫 ACS，最右邊顯示平均 ACS。
  - 載入中顯示「…」，失敗、被 403 拒絕或 V1 不成立時顯示「—」。

## 5. 玩家頁

- 路由為 `/players/detail`，參數是 `{puuid, riotId}`。計分板上點玩家名稱就會進入；點自己則改為切到 `/matches`。
- 版面沿用對戰紀錄列表：頁首是對方的 Riot ID 和最近 5 場的平均 ACS，下面是他的對戰卡片（地圖、模式、勝負、比分、**他的**特務、K/D/A、ACS），可以載入更多。點卡片進入該場的詳情，可以一路往下點。
- 新增 `PlayerHistoryProvider`，一個 puuid 對應一份分頁紀錄，使用 `MatchDetailCache`。名稱一樣用 name-service 補上。

## 6. 錯誤處理

| 情況 | 行為 |
|---|---|
| 401 | 登出，顯示「登入已過期，請重新登入」（沿用現有規則） |
| 某位玩家 403、429 重試後仍失敗，或格式不符 | 只有那位玩家顯示「—」，不影響其他人和計分板 |
| 玩家頁第一頁失敗 | 顯示錯誤訊息與「重試」按鈕 |

## 7. 測試

- 單元測試：
  - K/D（deaths 為 0）、ADR（roundsPlayed 為 0）、首殺、MVP 判定、評分欄位對應。
  - `RecentFormLoader` 的並行上限、429 退避（時間要可以注入）、重試次數、快取去重、取消。
  - `PlayerHistoryProvider` 的分頁與錯誤。
- Widget 測試：計分板的新欄位與 MVP 標籤、最近 5 場的三種狀態（載入中、完成、失敗）、點玩家導頁、玩家頁。
- 實測：使用者登入後完成 V1 到 V3，再驗證計分板、最近 5 場與玩家頁。
