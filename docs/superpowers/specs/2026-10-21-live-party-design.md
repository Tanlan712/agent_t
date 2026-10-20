# 即時對局：隊伍階段 設計規格

- 日期：2026-10-21
- 狀態：使用者已核准設計
- 依據：AGENTS.md 第 1 節（防外掛，絕對禁止）、第 2 節（使用者核准即時對局，只能 GET glz、間隔至少 5 秒）

## 1. 目標與範圍

- 新增「即時對局」頁（`/live`），這次只做**隊伍階段**：顯示目前隊伍的狀態與成員。
- 不做：選角、對局中（之後再分階段加入）、任何寫入操作（邀請、踢人、準備、排隊、改公開設定）。

## 2. 實測依據（2026-10-21，使用者帳號，瀏覽器直接呼叫）

- `glz-ap-1.ap.a.pvp.net` 沒有被 CORS 擋下；不在該階段時回 404，並附 JSON（`httpStatus, errorCode, message`）。
- `GET /parties/v1/players/{puuid}` 回 200，欄位：`Subject, Version, CurrentPartyID, Invites, Requests, PlatformInfo, IsCrossPlayEnabled`。
- `GET /parties/v1/parties/{partyId}` 回 200，與本功能有關的欄位：
  - 隊伍：`ID, State`（實測值 `CUSTOM_GAME_SETUP`）、`Accessibility`（`CLOSED`）、`MatchmakingData.QueueID`（`unrated`）、`QueueEntryTime`、`EligibleQueues`。
  - 成員 `Members[]`：`Subject, CompetitiveTier, PlayerIdentity, SeasonalBadgeInfo, IsOwner, IsReady, Pings, …`。
  - `PlayerIdentity`：`Subject, PlayerCardID, PlayerTitleID, AccountLevel, PreferredLevelBorderID, Incognito, HideAccountLevel`。
  - 成員資料裡沒有名稱。

## 3. 行為

### 更新
- 頁面開著、而且已登入時才更新；進入頁面立即更新一次，之後**每 10 秒**更新一次。
- 離開頁面就停止；另外提供「重新整理」按鈕。
- 上一輪還沒結束時，跳過這一輪，避免請求重疊。

### 顯示
- **隊伍狀態列**：狀態、佇列名稱、公開或不公開；配對中時加上已排隊的時間。
  - 狀態對照：`DEFAULT` 是「大廳」、`MATCHMAKING` 是「配對中」、`MATCHMADE_GAME_STARTING` 是「對戰即將開始」、`CUSTOM_GAME_SETUP` 是「自訂對戰設定」；其他值直接顯示原值。
- **成員卡片**：玩家卡小圖（來自 valorant-api.com 的 `smallart`）、Riot ID、等級、牌位圖示，以及隊長和準備標記。自己排在第一位。

### 隱私（AGENTS.md 第 2 節：不得去匿名化）
- 成員開了 `Incognito`：名稱顯示「已隱藏名稱」，**不送去 name-service 查詢**，也不能點進他的玩家頁。
- 成員開了 `HideAccountLevel`：不顯示等級。
- 他人牌位：先查他的 MMR，`IsActRankBadgeHidden` 為 false 才顯示 `CompetitiveTier`。
  - 確認中、對方隱藏、查詢失敗時，都不顯示牌位。
  - 每人只查一次並快取；如果失敗，下一輪再試。
- 自己的資料永遠顯示。
- 名稱用 name-service 查詢，每人快取一次；失敗時下一輪再試。

### 點擊
- 點其他成員進入他的玩家頁（賽後對戰紀錄）；點自己切到 `/matches`；開了 `Incognito` 的成員不能點。

### 錯誤
| 情況 | 行為 |
|---|---|
| 隊伍端點回 404 | 顯示「遊戲沒有開啟，或目前不在大廳」，下一輪繼續檢查 |
| 401 | 登出，停止更新，顯示「登入已過期，請重新登入」 |
| 其他錯誤 | 顯示錯誤訊息，下一輪自動重試 |
| 未登入 | 引導到 Riot 登入頁，不更新 |

## 4. 結構

| 檔案 | 責任 |
|---|---|
| `lib/models/live_models.dart` | `LiveParty`、`PartyMember` |
| `lib/logic/live_mapper.dart` | `mapParty(json)`、`partyStateLabel(state)`（純函式） |
| `lib/services/riot_client.dart` | 新增 `getGlz(s, path, {label})`：與 `getPd` 相同的標頭，主機是 `glz-{shard}-1.{shard}.a.pvp.net` |
| `lib/services/live_client.dart` | `fetchPartyId(s)`（404 時回 null）、`fetchParty(s, id)` |
| `lib/providers/live_party_provider.dart` | 輪詢（計時器可以注入）、名稱與牌位公開狀態的快取、錯誤處理 |
| `lib/screens/live_page.dart` | 頁面；在 `initState` 建立 provider 並 start，在 `dispose` 時 stop |

## 5. 測試（TDD）

- mapper：欄位對照、成員排序、狀態文字、缺少欄位時不會崩潰。
- LiveClient：主機與路徑正確；404 回 null；401 丟出例外。
- Provider：
  - 只對沒開 `Incognito` 的成員查名稱。
  - 牌位只有在確認公開後才給。
  - 404 顯示沒有隊伍；401 會登出並停止。
  - 上一輪還在進行時跳過這一輪。
  - 停止後不再發出請求，也不呼叫 notifyListeners。
- 頁面：
  - 狀態列與成員卡片正確。
  - 隱藏名稱、隱藏等級、隱藏牌位都不顯示。
  - 點擊時的導頁行為正確。
  - 側邊導覽有「即時對局」。
- 實測：使用者在大廳時打開頁面，確認成員、名稱、隱私開關與更新頻率。
