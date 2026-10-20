# 對戰紀錄與單場詳情 設計規格

- 日期：2026-10-20
- 狀態：待使用者審閱
- 前置：`2026-10-19-manual-shop-wishlist-design.md` 第 10 節（Riot 登入）；探查結果見分支 `spike/match-probe`（用完即丟）

## 1. 目標與範圍

### 使用者明確提出
- 新增「對戰紀錄」功能：列出自己最近的對戰，點進去可以看單場所有玩家的資料。
- **顯示所有玩家的名稱與 Riot ID（`名稱#Tag`）**。
- 先不做「當前對局（進行中）」查看。
- 與網頁 UI 優化**同時進行**：資料層先在 `feature/match-history` 分支完成；頁面與路由等 UI 優化合併後再接上，直接使用新的導覽殼層與深色主題。

### 推定（審閱時請確認）
- 個人自用、只在本機執行。
- 一頁載入 10 場，用「載入更多」往前翻。

### 已知風險（已告知使用者）
- `match-details` 沒有「隱藏名稱」標記，所以可能顯示當時在遊戲中隱藏名稱的玩家名稱。頁面上會用小字提醒：「名稱資料來自 Riot，請勿公開或分享他人資訊」。
- 使用 Riot 未公開的 API（使用者已接受這項風險，見前置規格 10.1）。

### 不做（YAGNI）
- 進行中對局、回合時間軸、擊殺地圖、經濟圖表、查詢其他玩家的紀錄、匯出。

## 2. 資料來源（2026-10-20 實測，全部回應 200，瀏覽器可直接呼叫）

| 端點 | 用途 |
|---|---|
| `GET pd.{shard}.a.pvp.net/match-history/v1/history/{puuid}?startIndex=&endIndex=` | 場次列表：`History[]{MatchID, GameStartTime, QueueID}` 與 `Total` |
| `GET pd.{shard}.a.pvp.net/match-details/v1/matches/{matchId}` | 單場詳情：`matchInfo`、`players[]`、`teams[]`、`roundResults[]`、`kills[]` |
| `GET pd.{shard}.a.pvp.net/mmr/v1/players/{puuid}/competitiveupdates?startIndex=&endIndex=` | 自己每場的牌位與 RR 變化：`Matches[]{MatchID, TierAfterUpdate, RankedRatingEarned, …}` |
| `GET pd.{shard}.a.pvp.net/mmr/v1/players/{puuid}` | 目前牌位：`LatestCompetitiveUpdate` |
| `GET valorant-api.com/v1/agents?isPlayableCharacter=true&language=zh-TW` | 特務 uuid 對應名稱與圖示 |
| `GET valorant-api.com/v1/maps?language=zh-TW` | 地圖：用 `mapUrl` 對應 `matchInfo.mapId`，取得名稱與縮圖 |
| `GET valorant-api.com/v1/competitivetiers?language=zh-TW` | 牌位編號對應名稱與圖示（取最後一個賽季的 `tiers`） |

pd 的請求標頭與商店相同（Authorization、X-Riot-Entitlements-JWT、X-Riot-ClientVersion、X-Riot-ClientPlatform）。

### 實測確認的 `match-details` 欄位
- `matchInfo`：`matchId`、`mapId`、`queueID`、`gameMode`、`isRanked`、`gameLengthMillis`、`gameStartMillis`、`isCompleted`、`seasonId`
- `players[]`：`subject`、`gameName`、`tagLine`、`teamId`、`partyId`、`characterId`、`stats{score, roundsPlayed, kills, deaths, assists}`、`competitiveTier`、`accountLevel`、`playerCard`、`isObserver`
- `teams[]`：用於勝負與比分（實測有 2 筆；欄位以 `teamId`、`won`、`roundsWon` 為準，若不存在則改從 `roundResults` 計算，見 4.3）
- `roundResults[].playerStats[].damage[]{receiver, damage, legshots, bodyshots, headshots}`：用於計算爆頭率

## 3. 模型（純資料）

```
MatchRef     { matchId, startTime, queueId }
MatchSummary { matchId, startTime, queueId, mapId, durationMs, isRanked,
               myTeamId, won (bool?), myScore, enemyScore,
               myAgentId, kills, deaths, assists, rrChange (int?), tierAfter (int?) }
PlayerLine   { puuid, riotId ('名稱#Tag'), teamId, partyId, agentId, tier, accountLevel,
               kills, deaths, assists, score, acs, headshotPercent (double?), isMe }
MatchDetail  { summary: MatchSummary, teams: Map<teamId, List<PlayerLine>> }   // 每隊依 score 由高到低
RankInfo     { tier, rr }
MatchReference { agents: Map<uuid,(name,iconUrl)>, maps: Map<mapUrl,(name,imageUrl)>, tiers: Map<int,(name,iconUrl)> }
```

## 4. 轉換規則（`logic/match_mapper.dart`，純函式）

1. `riotId`：`gameName` 為空時顯示「未知玩家」，否則為 `gameName#tagLine`。
2. `acs = score / roundsPlayed`（四捨五入到整數；`roundsPlayed == 0` 時為 0）。
3. 比分與勝負：優先使用 `teams[]` 的 `won` 和 `roundsWon`；沒有的話，從 `roundResults[].winningTeam` 計數。
4. `headshotPercent`：加總該玩家在所有回合 `damage[]` 的 headshots、bodyshots、legshots，結果為 `headshots / 三者總和 × 100`；總和為 0 時為 null。
5. 觀戰者（`isObserver == true`）不列入計分板。
6. 模式名稱由 `queueId` 對應：competitive→競技、unrated→一般、swiftplay→超速衝點、spikerush→輻能搶攻、deathmatch→死鬥、ggteam→軍備升級、hurm→團隊死鬥、premier→Premier、其他→原字串。
7. RR 變化：用 `MatchID` 對應 competitiveupdates 的 `RankedRatingEarned`；對不到時為 null，不顯示。

## 5. 服務與狀態

- `MatchClient(RiotClient 的 http.Client)`：`fetchHistory(session, start, count)`、`fetchMatch(session, matchId)`、`fetchCompetitiveUpdates(session, count)`、`fetchRank(session)`。錯誤沿用 `RiotApiException`，訊息不含 token。
- `MatchReferenceApi` 加 `MatchReferenceCache`：shared_preferences key `match_reference_v1`，做法與造型目錄相同（第一次下載，之後讀快取）。
- `MatchHistoryProvider`：
  - 欄位：`List<MatchSummary> summaries`、`bool hasMore`、`isLoading`、`String? error`
  - `loadFirstPage()`、`loadMore()`：一頁 10 場，每場需要詳情才能算出比分與 K/D/A，所以同一頁並行請求，最多同時 4 個
  - `detail(matchId)`：記憶體快取
  - 遇到 401 時呼叫 `RiotProvider.logout()`，並回傳「登入已過期，請重新登入」
- 資料只放在記憶體（與 Riot session 一致），不寫入 localStorage。

## 6. 畫面（UI 優化合併後實作，使用新的殼層與主題）

- **對戰紀錄 `/matches`**：
  - 頂端顯示目前牌位（圖示、名稱、RR），以及最近 5 場的 RR 變化。
  - 場次卡片：地圖縮圖、模式、勝或敗（綠或紅）、比分、自己的特務圖示、K/D/A、RR 變化、開始時間。
  - 最下方有「載入更多」。
  - 未登入時顯示「登入 Riot 以查看對戰紀錄」，並導向 `/riot-login`。
  - 頁尾小字：「名稱資料來自 Riot，請勿公開或分享他人資訊」。
- **單場詳情 `/matches/:id`**：
  - 標頭：地圖、模式、比分、時長、日期。
  - 兩隊計分板，欄位依序為：特務、`名稱#Tag`、牌位、K/D/A、ACS、爆頭率、等級。
  - 自己那一列反白。同一個 `partyId` 且人數大於 1 的玩家，前面加上相同顏色的組隊標記。
- 導覽：在新的側邊導覽加入「對戰紀錄」。

## 7. 錯誤處理

| 情況 | 行為 |
|---|---|
| 未登入或 session 過期 | 顯示登入引導；401 會自動登出 |
| 某一場的詳情失敗 | 該卡片顯示「無法載入這場」，其他場次不受影響 |
| 參考資料（特務、地圖、牌位）下載失敗 | 用 uuid 縮寫和佔位圖示顯示，不阻擋列表 |
| 欄位缺漏或格式不符 | 該欄顯示「—」，不崩潰 |

## 8. 測試

- 單元測試：
  - `match_mapper` 的規則 1 到 7，fixture 依實測的欄位結構撰寫，玩家名稱一律使用假資料。
  - `MatchClient` 用 `MockClient` 驗證 URL、標頭、分頁參數，以及 401 的處理。
  - `MatchHistoryProvider` 驗證分頁、並行上限、單場失敗、401 登出。
- Widget 測試：兩個頁面的主要狀態（未登入、載入中、列表、詳情、單場失敗）。
- 實測：使用者登入後，由 Claude 在內建瀏覽器驗證列表與詳情。

## 9. 分工與整合

- **第一階段（現在，`feature/match-history` worktree）**：模型、轉換、`MatchClient`、參考資料、Provider，以及對應的測試。不動 `main.dart` 和現有頁面。
- **第二階段（UI 優化合併到 master 之後）**：把分支 rebase 或合併到最新 master，在新殼層上加入兩個頁面、路由和導覽項目，然後實測。
