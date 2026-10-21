# 我的收藏、通行證與任務（設計規格）

- 日期：2026-10-21
- 狀態：使用者已核准端點與收藏範圍，CORS 探查通過；待審閱本規格
- 端點核准：AGENTS.md 第 3 節（2026-10-21 使用者決定）；欄位：`docs/api-fields.md`「收藏、等級、通行證」

## 0. 目的與成功條件

讓使用者在網頁看到**自己的**：

1. 擁有的收藏：造型（依武器分組、可看預覽影片）、特務、吊飾、噴漆、玩家卡片、稱號。
2. 帳號等級與經驗。
3. 目前通行證：階級進度與各階獎勵。
4. 每日／每週任務與進度。

成功條件：登入後兩個新頁面能顯示上述資料；未登入、載入中、失敗都有明確狀態；
`flutter analyze` 無新 warning、`flutter test` 全過、`flutter build web` 成功；375／768／1024／1440 不 overflow。

## 1. 限制

- 只用 AGENTS.md 第 3 節已核准的 **GET**：`store/v1/entitlements/{puuid}/{ItemTypeID}`、`account-xp/v1/players/{puuid}`、`contracts/v1/contracts/{puuid}`，
  以及 valorant-api.com 公開資料。**不得**啟用合約或任何寫入。
- 只讀使用者自己（登入者）的 puuid；不查他人。
- 請求頻率：背景同時最多 2 個；429／連線失敗依 `Retry-After` 或 2s／4s／8s 退避，最多重試 3 次。
  資料在同一個登入期間快取在記憶體，進頁面不重抓，頁面上有「重新整理」按鈕；登出時清空。
- token 規則不變（AGENTS.md 第 4 節）；錯誤訊息不含 token。
- 不新增套件：造型影片用 `url_launcher` 在新分頁開啟 `streamedVideo`（MP4）。
- 顏色只來自 `AppColors`；不用 emoji；沿用 Bento 元件（`PanelCard`、`BentoGrid`、`KpiTile`、`EmptyState`、`StatusChip`）。

## 2. 資料

### Riot（pd）
| 資料 | 來源欄位 |
|---|---|
| 擁有物品 | `Entitlements[].ItemID`，依 ItemTypeID 分類 |
| 等級 | `Progress.Level`、`Progress.XP` |
| 合約 | `Contracts[]{ContractDefinitionID, ProgressionLevelReached, ProgressionTowardsNextLevel, ContractProgression.TotalProgressionEarned}` |
| 任務 | `Missions[]{ID, Objectives{uuid: 進度}, Complete, ExpirationTime}`、`MissionMetadata.WeeklyRefillTime` |

### valorant-api.com（`language=zh-TW`）
| 用途 | 端點與欄位 |
|---|---|
| 造型名稱、武器、圖、影片 | `/v1/weapons`：`skins[].levels[]{uuid, displayName, displayIcon, streamedVideo}`、`skins[].chromas[]{uuid, displayName, swatch, fullRender, streamedVideo}`，武器 `displayName` |
| 特務 | `/v1/agents?isPlayableCharacter=true`：`uuid, displayName, displayIcon, role.displayName, isBaseContent` |
| 吊飾 | `/v1/buddies`：`levels[]{uuid}` → 吊飾 `displayName, displayIcon`（Entitlements 是吊飾**等級** uuid） |
| 噴漆 | `/v1/sprays`：`uuid, displayName, displayIcon` |
| 玩家卡片 | `/v1/playercards`：`uuid, displayName, smallArt` |
| 稱號 | `/v1/playertitles`：`uuid, titleText` |
| 合約定義 | `/v1/contracts`：`uuid, displayName, content{relationType, relationUuid, chapters[]{levels[]{reward, xp}, freeRewards}}` |
| 賽季 | `/v1/seasons`：`uuid, displayName, startTime, endTime` |
| 任務定義 | `/v1/missions`：`uuid, title, type, xpGrant, progressToComplete` |

- 吊飾、玩家卡片、噴漆等 valorant-api 回應以 uuid 小寫比對。
- **特務**：擁有 = Entitlements 的特務 ∪ `isBaseContent == true` 的特務（初始特務不在 Entitlements 裡，已實測）。
- **目前通行證**：合約定義 `content.relationType == "Season"` 且 `relationUuid` 對應的賽季 `startTime ≤ 現在 < endTime`；
  找不到時顯示「目前沒有進行中的通行證」。玩家的進度取 `Contracts[]` 中 `ContractDefinitionID` 相同的那筆，沒有時視為 0 階。
- **通行證階級**：把所有 `chapters[].levels[]` 依序攤平，第 n 項是第 n 階（1 起算）；`ProgressionLevelReached` 是已達成的階數；
  下一階進度 = `ProgressionTowardsNextLevel / levels[下一階].xp`。每章的 `freeRewards` 視為該章最後一階附帶的免費獎勵。
- **獎勵名稱**：`reward{type, uuid, amount}`，type 對應：`EquippableSkinLevel`→造型等級、`EquippableCharmLevel`→吊飾等級、`Spray`、`PlayerCard`、`Title`、
  `Currency`（顯示「貨幣 ×amount」）；查不到時顯示「未知獎勵」。
- **任務**：`ID` 對應 `/v1/missions` 的 `uuid`；名稱 `title`；類型由 `type` 判斷：含 `Daily` → 每日、含 `Weekly` → 每週，其餘 → 其他；
  進度 = Objectives 數值總和，目標 = `progressToComplete`（0 時以 1 計）；`Complete == true` 視為完成。

## 3. 頁面

導覽「主要」組新增兩項（手機在「更多」）：
- `/collection`「我的收藏」（圖示 `Icons.collections_bookmark`）
- `/progress`「通行證與任務」（圖示 `Icons.military_tech`）

### 我的收藏
- 頁首副標：「共 N 件」。
- 分頁（`TabBar`）：造型、特務、吊飾、噴漆、玩家卡片、稱號；每個分頁標題後面顯示數量。
- 造型：依武器分組（`SectionHeader` 武器名＋數量），組內等寬卡片網格（每格至少 220）：圖、造型名稱、擁有的炫彩色票（`swatch`）。
  擁有的造型＝擁有的造型**等級**所屬的造型；顯示最高擁有等級的圖與名稱。有 `streamedVideo` 的擁有等級顯示「預覽影片」按鈕，點擊在新分頁開啟。
- 特務：網格，頭像、名稱、角色；初始特務加「初始」StatusChip。
- 吊飾、噴漆、玩家卡片：圖片網格＋名稱。稱號：文字列表。
- 某分頁沒有項目：EmptyState「還沒有這類收藏」。

### 通行證與任務
- 第 1 列 KPI（Bento）：帳號等級、本級經驗（`XP`）、通行證階級（`N / 總階數`）、每週任務刷新（`WeeklyRefillTime` 倒數，`X 天 Y 小時`）。
- 通行證卡（span 12）：名稱、下一階進度條（LinearProgressIndicator，顏色 `primary`）、`下一階 a / b XP`；
  獎勵橫向網格，每格：階數、獎勵圖示或名稱；已達成的顯示 `Icons.check_circle`（win 色），下一階以 primary 外框標示。
- 任務卡：每日（span 6）、每週（span 6，6 欄以下上下排）。每列：名稱、進度條、`a / b`、`+xpGrant XP`；完成的加「完成」StatusChip。
- 沒有通行證或沒有任務：對應卡片內 EmptyState。

### 狀態
- 未登入：EmptyState＋「登入 Riot」。
- 載入中：卡片內骨架（`SkeletonBox`）。
- 失敗：錯誤訊息＋「重試」；部分分類失敗不影響其他分類（各自顯示錯誤）。

## 4. 架構

- `RiotClient`：新增 `fetchEntitlements(s, itemTypeId) → Set<String>`、`fetchAccountXp(s) → Map`、`fetchContracts(s) → Map`（沿用 `getPd`）。
- `lib/models/account_progress.dart`：`AccountXp`、`ContractProgress`、`MissionProgress`、`ContractsSnapshot` 與 JSON 解析。
- `lib/services/progress_reference_api.dart`：下載第 2 節 valorant-api 資料，轉成 `ProgressReference`（以小寫 uuid 為 key）。
- `lib/logic/progress_logic.dart`：純函式——`ownedAgents`、`groupOwnedSkins`、`currentBattlePass`、`flattenTiers`、`resolveReward`、`joinMissions`。
- `lib/providers/collection_provider.dart`、`progress_provider.dart`：登入期間快取；`load()`、`refresh()`；同時最多 2 個請求、退避重試；登出清空。
- 頁面：`lib/screens/collection_page.dart`、`progress_page.dart`；路由加入 `app_routes.dart`，導覽加入 `nav_items.dart`。

## 5. 測試

- 解析：用 fixture（只含假 uuid）測 entitlements、account-xp、contracts 的解析與缺欄位容錯。
- 邏輯：初始特務合併、造型分組（多等級只算一次、取最高等級）、目前通行證選擇（賽季時間邊界、找不到）、階級攤平與下一階進度、獎勵名稱對應（含未知）、任務類型與進度。
- Provider：同時最多 2 個請求、429 依 Retry-After 退避、登出清空、重新整理會重抓。
- 頁面：未登入、載入中、失敗與重試、有資料時的分頁數量、影片按鈕呼叫 launcher、通行證進度與獎勵、任務分組。
- responsive sweep 自動涵蓋兩個新路由。

## 6. 不做

- 不顯示他人的收藏或進度。
- 不啟用合約、不購買通行證階級、不更換裝備。
- 不在頁面內嵌播放影片（需要新套件；使用者要時再另議）。
