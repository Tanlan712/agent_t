# Riot API 欄位紀錄

這份文件記錄本專案**實際讀取過**的 Riot 端點與欄位，方便之後新增顯示欄位時查詢。

- 只記錄欄位名稱、型別和實測得到的意義，**不記錄任何玩家的實際資料或 token**。
- 欄位標記：
  - ✅ 實測確認（日期為使用者帳號實測的日期）
  - 📄 依社群文件 [valapidocs](https://valapidocs.techchrism.me/)，尚未實測
  - 🧩 App 目前使用中
- 所有端點都是 Riot 未公開的 API，格式可能隨時改變。使用規則見 [AGENTS.md](../AGENTS.md)。
- 讀到新的欄位時，**必須更新這份文件**。

## 共用

- 標頭：`Authorization: Bearer {access_token}`、`X-Riot-Entitlements-JWT`、`X-Riot-ClientVersion`、`X-Riot-ClientPlatform`（固定的 base64 PC 平台描述）。
- `pd.{shard}.a.pvp.net`、`glz-{shard}-1.{shard}.a.pvp.net` 都**有** CORS 標頭，可以從瀏覽器直接讀取 ✅ 2026-10-20／21。
- `auth.riotgames.com/userinfo` 與 `riot-geo` 的回應**沒有** CORS 標頭，會被瀏覽器擋下 ✅。
  因此 puuid 改從 access_token（JWT）的 `sub` 取得，名稱改從 id_token 的 `acct` 取得，shard 由使用者選擇。

## 登入與授權

| 端點 | 欄位 |
|---|---|
| `POST entitlements.auth.riotgames.com/api/token/v1` | `entitlements_token` 🧩 |
| access_token（JWT payload） | `sub` = 自己的 puuid 🧩 |
| id_token（JWT payload） | `acct.game_name`、`acct.tag_line` 🧩 |
| `GET valorant-api.com/v1/version` | `data.riotClientVersion` 🧩 |

## 商店與帳號（pd）

### `POST /store/v3/storefront/{puuid}`（失敗時改用 `GET /store/v2/storefront/{puuid}`）🧩
- `SkinsPanelLayout`
  - `SingleItemOffers[]`（造型等級 ID）
  - `SingleItemStoreOffers[]`：`OfferID`、`IsDirectPurchase`、`Cost{幣別ID: 數量}`、`Rewards[]{ItemTypeID, ItemID, Quantity}`
  - `SingleItemOffersRemainingDurationInSeconds`
- `BonusStore`（夜市，可能不存在）
  - `BonusStoreOffers[]`：`BonusOfferID`、`Offer`、`DiscountPercent`、`DiscountCosts`、`IsSeen`
  - `BonusStoreRemainingDurationInSeconds`
- `FeaturedBundle`
  - `Bundle{ID, DataAssetID, CurrencyID, TotalBaseCost, TotalDiscountedCost, DurationRemainingInSeconds}`
  - `Bundles[]`：同時上架的所有精選組合包（欄位同 `Bundle`）；有時優先使用，沒有時用單一的 `Bundle`。
    每個的 `DurationRemainingInSeconds` 是該組合包自己的剩餘秒數，顯示為「剩餘 N 天 H 小時」。
  - `BundleRemainingDurationInSeconds`（組合包沒有自己的秒數時的後備值）

### `GET /store/v1/wallet/{puuid}` 🧩
- `Balances{幣別ID: 數量}`
  - VP `85ad13f7-3d1b-5128-9eb2-7cd8ee0b5741`
  - 輻能點數 `e59aa87c-4cbf-517a-5983-6e81511be9b7`
  - 王國幣 `85ca954a-41f2-ce94-9b45-8ca3dd39a00d`

### `GET /store/v1/entitlements/{puuid}/{ItemTypeID}` 🧩
- `Entitlements[]{TypeID, ItemID}`；造型等級的 ItemTypeID 是 `e7c63390-eda7-46e0-bb7a-a6abdacd2433`。

## 對戰紀錄（pd）

### `GET /match-history/v1/history/{puuid}?startIndex&endIndex&queue` ✅ 🧩
- `Subject`、`BeginIndex`、`EndIndex`、`Total`
- `History[]{MatchID, GameStartTime, QueueID}`
- 實測：
  - 查**他人**時，一次範圍超過 10 場會回 400，所以 App 分段請求，每次 10 場 ✅ 2026-10-21。
  - `queue` 參數（例如 `unrated`、`competitive`）可以只取同模式的場次 ✅ 2026-10-21。
  - 他人的紀錄可以查詢（200）✅ 2026-10-20。

### `GET /match-details/v1/matches/{matchId}` ✅ 2026-10-20
- 頂層：`matchInfo, players, bots, coaches, teams, roundResults, matchMvp, hasTempValues, kills`
  - `matchMvp`：全場 MVP 的 puuid 🧩。實測 20 場都等於表現分數最高的人。
- `matchInfo`：`matchId, mapId, gamePodId, gameLoopZone, gameServerAddress, gameVersion, gameLengthMillis, gameStartMillis, provisioningFlowID, isCompleted, isEarlyCompletion, customGameName, forcePostProcessing, queueID, gameMode, isRanked, isMatchSampled, seasonId, completionState, platformType, premierMatchInfo, partyRRPenalties, shouldMatchDisablePenalties, newMapLossReductionModifier, isReplayRecorded`
  - 🧩 使用中：`matchId, mapId, queueID, gameLengthMillis, gameStartMillis, isRanked, seasonId`
- `teams[]`：`teamId, won, roundsWon, roundsPlayed, mvp`（mvp 是隊伍 MVP 的 puuid）🧩
- `players[]`：
  - 基本：`subject, gameName, tagLine, platformInfo{platformType, platformOS, platformOSVersion, platformChipset, platformDevice}, teamId, partyId, characterId, competitiveTier, isObserver, playerCard, playerTitle, accountLevel, sessionPlaytimeMinutes, roundDamage[], participationPeriods[]`
    - **實測 `gameName`／`tagLine` 全部是空字串**，名稱要另外用 name-service 查詢 ✅。
    - 一般模式的 `competitiveTier` 全部是 0 ✅。
  - `stats`：`score, roundsPlayed, kills, deaths, assists, playtimeMillis, abilityCasts{grenadeCasts, ability1Casts, ability2Casts, ultimateCasts}, TempValueA, TempValueB, TempValueC, TempValueD`（Temp 值意義不明）
  - `behaviorFactors`：`afkRounds, collisions, commsRatingRecovery, damageParticipationOutgoing, friendlyFireIncoming, friendlyFireOutgoing, mouseMovement, selfDamage, stayedInSpawnRounds`
  - `newPlayerExperienceDetails`：新手教學相關，未使用
  - `scores`（**遊戲內「表現分數」**，欄位名稱是沒有文件的 TempValue）✅ 2026-10-21：

    | 欄位 | 意義（對照遊戲內「分數細項」） |
    |---|---|
    | `TempValueF` | **表現分數**（0～500）🧩 |
    | `TempValueG` | 戰鬥分（0～500） |
    | `TempValueH` | 輔助分（0～500） |
    | `TempValueA` | 每回合傷害 |
    | `TempValueI` | 調整後擊殺／回合 |
    | `TempValueJ` | 調整後死亡／回合（負值） |
    | `TempValueB` | 以命換命／回合 |
    | `TempValueC` | 助攻／回合 |
    | `TempValueD` | 戰略工具使用／回合 |
    | `TempValueE` | 安裝／回合（只在有安裝時出現） |
    | `TempValueL.TempValueO` | 等級：`pass`／`merit`／`distinction` |
    | `TempValueL.TempValueM`、`TempValueN` | 戰鬥／輔助的整體衝擊（`up`／`down`／`neutral`／`double_*`） |
    | `TempValueL.TempValueP` | 衝擊：`damage, deathImpact, killImpact, trades` |
    | `TempValueL.TempValueQ` | 衝擊：`assists, defuses, plants, utilityUsage` |
    | `TempValueT.TempValueR` | 平均線 250 |
    | `TempValueT.TempValueU` | 上限 500 |
    | `TempValueT.TempValueS` | 等級門檻 `{pass: 0, merit: 330, distinction: 420}` |

    - 反推公式（200 筆樣本）：表現分數 = clamp(250 + k·(0.75·G + 0.25·H − 250), 0, 500)。
      k 在競技／一般約 0.993，在超速衝點約 0.963。G 與 H 依特務或角色的基準正規化，App 無法自行重算。
- `roundResults[]`：`roundNum, roundResult, roundCeremony, winningTeam, winningTeamRole, bombPlanter, bombDefuser, firstBloodPlayer, plantRoundTime, plantPlayerLocations, plantLocation, plantSite, defuseRoundTime, defusePlayerLocations, defuseLocation, playerStats, roundResultCode, playerEconomies, playerScores`
  - `firstBloodPlayer`：該回合首殺者的 puuid 🧩
  - `playerStats[]`：`subject, kills[], damage[], score, economy, ability, wasAfk, wasPenalized, stayedInSpawn`
    - `damage[]`：`receiver, damage, headshots, bodyshots, legshots` 🧩
    - `kills[]`：`killer, victim, roundTime` 等（首殺的備援規則用到 `roundTime`）🧩
  - `playerScores[]`：`subject, score`
  - ⚠️ `plantPlayerLocations`、`defusePlayerLocations`、`kills[].playerLocations` 等位置資料：只能用於賽後；**不得**用在即時對局（AGENTS.md 第 2 節）。

### `GET /mmr/v1/players/{puuid}/competitiveupdates?startIndex&endIndex` ✅ 🧩
- `Matches[]{MatchID, QueueID, TierBeforeUpdate, TierAfterUpdate, RankedRatingBeforeUpdate, RankedRatingAfterUpdate, RankedRatingEarned}`
- 實測 `RankedRatingEarned` 都是 0，RR 變化改用前後牌位計算 ✅。

### `GET /mmr/v1/players/{puuid}` 🧩
- `LatestCompetitiveUpdate{MatchID, TierAfterUpdate, RankedRatingAfterUpdate}`：自己的頁首牌位用這個 ✅。
- `QueueSkills.competitive.SeasonalInfoBySeasonID[seasonId]{SeasonID, CompetitiveTier, RankedRating, NumberOfWins}`：他人的這季牌位用這個 ✅ 2026-10-21（他人可以查詢）。
- `IsActRankBadgeHidden` ✅ 2026-10-21：實測有這個欄位，隱藏牌位的玩家為 true。使用者決定忽略這個欄位，照樣顯示牌位。
- `IsLeaderboardAnonymized` 📄：尚未實測。

### `PUT /name-service/v2/players`（body：puuid 陣列）✅ 🧩
- 回應 `[]{Subject, GameName, TagLine}`；可能有名稱為空的項目。

## 即時對局（glz）

### `GET /parties/v1/players/{puuid}` ✅ 2026-10-21
- `Subject, Version, CurrentPartyID, Invites, Requests, PlatformInfo, IsCrossPlayEnabled`

### `GET /parties/v1/parties/{partyId}` ✅ 2026-10-21
- 隊伍：`ID, MUCName, VoiceRoomID, Version, ClientVersion, Members, State, PreviousState, StateTransitionReason, Accessibility, CustomGameData, MatchmakingData, Invites, Requests, QueueEntryTime, ErrorNotification, RestrictedSeconds, EligibleQueues, QueueIneligibilities, CheatData, XPBonuses, InviteCode`
  - `State` 實測值：`CUSTOM_GAME_SETUP`、`DEFAULT`；`Accessibility` 實測值：`CLOSED`
  - `QueueEntryTime`：離開佇列回到大廳後，**仍保留上一次排隊的時間** ✅，所以只能在 `State == MATCHMAKING` 時當作排隊開始時間。沒有排隊紀錄時是 `0001-01-01T00:00:00Z`。
  - `MatchmakingData`：`QueueID, PreferredGamePods, SkillDisparityRRPenalty, MaxPartySize`
  - `CheatData`：只記錄欄位名稱，**不讀取、不使用**。
- `Members[]`：`Subject, CompetitiveTier, PlayerIdentity, SeasonalBadgeInfo, IsOwner, QueueEligibleRemainingAccountLevels, Pings, IsReady, IsModerator, UseBroadcastHUD, PlatformType, PreferredAgentInfo, PremierPrestige, JoinedAt`
  - `PlayerIdentity`：`Subject, PlayerCardID, PlayerTitleID, AccountLevel, PreferredLevelBorderID, Incognito, HideAccountLevel`
    - `Incognito`：成員隱藏名稱。使用者決定照樣查詢並顯示名稱，不加標籤。
    - `HideAccountLevel`：成員隱藏等級。使用者決定照樣顯示（自己的資料上也會出現這個開關）。

### `GET /pregame/v1/players/{puuid}` ✅ 2026-10-21
- 不在選角時回 404：`{httpStatus, errorCode, message}`。
- 選角中回 `Subject, MatchID, Version` ✅ 2026-10-21。

### `GET /pregame/v1/matches/{matchId}` ✅ 2026-10-21（競技、選角中）
- 頂層：`ID, Version, Teams, AllyTeam, EnemyTeam, ObserverSubjects, MatchCoaches, EnemyTeamSize, EnemyTeamLockCount, PregameState, LastUpdated, MapID, MapSelectPool, BannedMapIDs, CastedVotes, MapSelectSteps, MapSelectStep, Team1, GamePodID, Mode, LocalAccessibleAgents, VoiceSessionID, MUCName, TeamMatchToken, QueueID, ProvisioningFlowID, IsRanked, PhaseTimeRemainingNS, StepTimeRemainingNS, altModesFlagADA, TournamentMetadata, RosterMetadata, GameRules`
  - `PregameState` 實測值：`character_select_active`；`PhaseTimeRemainingNS`：剩餘時間（奈秒）
  - `MapID`、`Mode`（例如 `/Game/GameModes/Bomb/BombGameMode.BombGameMode_C`）、`QueueID`、`IsRanked`
  - **`EnemyTeam` 為 null**：選角時看不到對手；只有 `EnemyTeamSize`（人數）與 `EnemyTeamLockCount`（已鎖定人數）
  - `Teams` 只有我方 1 隊；`AllyTeam`：`TeamID, TeamNumber, Players`
  - `GameRules`：`AccoladesEnabled, AllowLenientSurrender, ReplayRecordMatch`
  - ⛔ `TeamMatchToken`、`VoiceSessionID`、`MUCName`：憑證類，不得讀取內容、顯示、記錄或傳送。
- `AllyTeam.Players[]`：`Subject, CharacterID, CharacterSelectionState, PregamePlayerState, CompetitiveTier, PlayerIdentity, SeasonalBadgeInfo, IsCaptain, PlatformType, PremierPrestige`
  - `CharacterSelectionState`：空字串（尚未選）／`selected`／`locked`（依社群文件）
  - `PregamePlayerState` 實測值：`joined`
  - `CompetitiveTier`：選角時有實際牌位

### `GET /core-game/v1/players/{puuid}` ✅ 2026-10-21（競技場次、對局中）
- 不在對局時回 404。對局中回 `Subject, MatchID, Version`。

### `GET /core-game/v1/matches/{matchId}` ✅ 2026-10-21
- 頂層：`MatchID, Version, State, MapID, ModeID, ProvisioningFlow, GamePodID, AllMUCName, TeamMUCName, TeamVoiceID, TeamMatchToken, IsReconnectable, ConnectionDetails, PostGameDetails, Players, MatchmakingData`
  - `State` 實測值：`IN_PROGRESS`；`MapID` 例如 `/Game/Maps/Triad/Triad`；`ProvisioningFlow`：`Matchmaking`
  - `MatchmakingData`：`QueueID`（實測 `competitive`）、`IsRanked`
  - `PostGameDetails`：對局中為 null
  - ⛔ `ConnectionDetails`（`GameServerHosts, GameServerHost, GameServerPort, GameServerObfuscatedIP, GameClientHash, PlayerKey`）、`TeamMatchToken`、`TeamVoiceID`、`AllMUCName`、`TeamMUCName`：
    遊戲伺服器連線資訊與語音／聊天憑證，**絕對不得讀取內容、顯示、記錄或傳送**。
- `Players[]`（10 人）：`Subject, TeamID, TeamNumber, CharacterID, bonsaiBloomline, PlayerIdentity, SeasonalBadgeInfo, IsCoach, IsAssociated, PlatformType, PremierPrestige`
  - `TeamID`：`Blue`／`Red`；`CharacterID`：特務 UUID
  - `PlayerIdentity`：與隊伍相同（`PlayerCardID, PlayerTitleID, AccountLevel, PreferredLevelBorderID, Incognito, HideAccountLevel`）
  - `SeasonalBadgeInfo`：`SeasonID, NumberOfWins, WinsByTier{tier: 勝場}, Rank, LeaderboardRank`
    - 實測 `Rank` 大多是 0（包括自己），**不能當成即時牌位**；為 0 時改用 MMR 查 `SeasonID` 那一季的牌位。
  - 實測多數玩家的 `AccountLevel` 是 0（推測對方隱藏等級時 Riot 直接給 0）。
  - `bonsaiBloomline`：`bloomlineFlourishID, bloomlineShortLevel, bloomlineHypeID`（意義不明，未使用）
  - 沒有名稱與 partyId；名稱要用 name-service 查詢。

### `GET /core-game/v1/matches/{matchId}/loadouts` ✅ 2026-10-21（對局中，使用者決定讀取）
- `Loadouts[]`（10 人）：`Subject, CharacterID, Loadout`
- `Loadout`：`Subject, Expressions{AESSelections}, DynamicOptions, Items`
- `Items`：以**武器 ID** 為 key 的物件（實測 21 項），每項 `{ID, TypeID, Sockets}`
  - `Sockets` 以 socket 類型 ID 為 key，每項 `{ID, Item{ID, TypeID}}`。依社群文件：
    - `bcef87d6-209b-46c6-8b19-fbe40bd95abc`：造型（skin）
    - `e7c63390-eda7-46e0-bb7a-a6abdacd2433`：造型等級（skin level，與商店／已擁有造型相同的 ID）
    - `3ad1b2b2-acdb-4524-852f-954a76ddae0a`：炫彩（chroma）
    - `dd3bf334-87f3-40bd-b043-682a57a8dc3a`：吊飾（buddy，有裝才有；📄 本次未見）
  - 實測 21 項都有造型 socket；沒有換造型時是預設造型。
- `pregame/v1/matches/{id}/loadouts`：📄 尚未實測。

## 收藏、等級、通行證（pd，使用者決定 2026-10-21，只能 GET）

### `GET /store/v1/entitlements/{puuid}/{ItemTypeID}` ✅ 2026-10-21 🧩
- 回應 `{ItemTypeID, Entitlements[]}`；各類型都回 200。
- ItemTypeID（📄 valapidocs，✅ 2026-10-21 皆回 200）：造型等級 `e7c63390-…a2433`（App 已用於「已擁有造型」🧩）、炫彩 `3ad1b2b2-acdb-4524-852f-954a76ddae0a`、
  特務 `01bb38e1-da47-4e6a-9b3d-945fe4655707`、吊飾 `dd3bf334-87f3-40bd-b043-682a57a8dc3a`、噴漆 `d5f120f8-ff8c-4aac-92ea-f2b5acbe9475`、
  玩家卡片 `3f296c07-64c3-494c-923b-fe692a4fa1bd`、稱號 `de7caa6b-adf7-4588-bbd1-143831e786c6`。
- 實測：初始特務**不在** Entitlements 裡（新帳號只回 2 個特務）；App 以 valorant-api `/v1/agents` 的 `isBaseContent == true`（5 位）補上 ✅ 2026-10-21。

### `GET /account-xp/v1/players/{puuid}` ✅ 2026-10-21 🧩
- `{Version, Subject, Progress{Level, XP}, History[], LastTimeGrantedFirstWin, NextTimeFirstWinAvailable}`
- `History[]{ID, CreatedAt, MatchStart, StartProgress{Level, XP}, EndProgress{Level, XP}, XPDelta, XPSources[], XPMultipliers[]}`（實測 5 筆）。
- `XP` 是目前等級內累積的經驗；每級需要的經驗值 📄 待確認。

### `GET /contracts/v1/contracts/{puuid}` ✅ 2026-10-21 🧩
- `{Version, Subject, Contracts[], ActiveRecruitmentEventProgress, Missions[], MissionMetadata{WeeklyRefillTime}, BTEMilestone}`
- `Contracts[]{ContractDefinitionID, ContractProgression{Version, TotalProgressionEarned}, ProgressionLevelReached, ProgressionTowardsNextLevel}`：
  `ContractDefinitionID` 對應 valorant-api `/v1/contracts` 的 `uuid`；通行證是 `content.relationType == "Season"` 的那一份。
- `Missions[]{ID, Objectives{objectiveUuid: 進度}, Complete, ExpirationTime}`：`ID` 對應 valorant-api `/v1/missions` 的 `uuid`。
- 不得呼叫 `POST …/special/{id}`（啟用合約）。

## 定價、目前裝備、排隊懲罰（pd，使用者決定 2026-10-22，只能 GET）

### `GET /store/v1/offers/`（不使用）
- 實測 2026-10-22：v1 與 v2 都回 **404** ✅。實際定價改從 storefront 回應累積：
  `SingleItemStoreOffers[].Cost`、`BonusStoreOffers[].Offer.Cost`（夜市原價），
  以及 `FeaturedBundle.Bundles[].Items[]{Item{ItemTypeID, ItemID, Amount}, BasePrice, CurrencyID, DiscountedPrice}` 裡造型等級的 `BasePrice` 📄 🧩。

### `GET /personalization/v3/players/{puuid}/playerloadout` 🧩
- v2 實測回 **404**，v3 回 200 ✅ 2026-10-22。
- 頂層欄位 ✅：`Guns`、`ActiveExpressions`、`DynamicOptions`、`Identity`、`Incognito`（v2 的 `Sprays` 換成 `ActiveExpressions`）。
- 每一項的內容尚未實測 📄：
  - `Guns[]`：`ID`（武器）、`SkinID`、`SkinLevelID`、`ChromaID`、`CharmLevelID`（吊飾等級，有裝才有）
  - `ActiveExpressions[]`：App 推測為 `{TypeID, AssetID}`；`TypeID` 不是噴漆（`d5f120f8-…`）時略過，
    valorant-api 找不到的 ID 不顯示。
  - `Identity`：`PlayerCardID`、`PlayerTitleID`、`AccountLevel`、`PreferredLevelBorderID`、`HideAccountLevel`
- 「目前裝備」分頁只用 GET；同一路徑的 `PUT` 只在「遠端操作」同意後由換造型使用（見下方「遠端操作」）。

### `GET /restrictions/v3/penalties` ✅ 2026-10-22 🧩
- 回 200，**有** CORS 標頭（網頁版可讀）✅。實測帳號沒有懲罰：`Subject`、`Penalties: []`、`Version`。
- 有懲罰時每一項的格式**仍未知**。App 寬鬆讀取：到期時間（`Expiry`／`ExpirationTime`／`EndTime`，ISO 或毫秒）、`GamesRemaining`、
  名稱含 `Effect` 且不是 null 的 key（例如 `QueueDelayEffect`、`QueueRestrictionEffect`、`RankedRestrictionEffect`、`RMSNotificationEffect`）。
  遇到真的懲罰時要補上實際欄位。

## 公開遊戲資料（valorant-api.com）🧩

- `/v1/weapons/skins`、`/v1/bundles`、`/v1/agents`、`/v1/maps`、`/v1/competitivetiers`、`/v1/playercards`、`/v1/gamemodes` 等；回傳格式都是 `{status, data}`。
- 牌位圖示來自 `competitivetiers` 最後一季的 `tiers[]{tier, tierName, smallIcon}`；tier 0「牌階未定」的圖示是官方的問號圖。
- 玩家卡圖片：`https://media.valorant-api.com/playercards/{PlayerCardID}/smallart.png`。
- `/v1/contracts` ✅ 2026-10-21（88 項）：`{uuid, displayName, displayIcon, shipIt, useLevelVPCostOverride, levelVPCostOverride, freeRewardScheduleUuid, content, assetPath}`；
  `content{relationType, relationUuid, chapters[], premiumRewardScheduleUuid, premiumVPCost}`；
  `chapters[]{isEpilogue, levels[], freeRewards}`；`levels[]{reward, xp, vpCost, isPurchasableWithVP, doughCost, isPurchasableWithDough}`；`reward{type, uuid, amount, isHighlighted}`，type 有 `EquippableSkinLevel`、`EquippableCharmLevel`、`Spray`、`PlayerCard`、`Title`、`Currency` ✅ 2026-10-21 🧩。
- `/v1/missions` ✅ 2026-10-21（983 項）：`{uuid, displayName, title, type, xpGrant, progressToComplete, activationDate, expirationDate, tags, objectives[]{objectiveUuid, value}, assetPath}`。
- 資料庫詳細頁（規格 `2026-10-21-database-details-design.md`）✅ 2026-10-21 實測：
  - `/v1/weapons`：`{uuid, displayName, category, displayIcon, shopData{cost, category, categoryText}, weaponStats, skins[]}`；`category` 為 `EEquippableCategory::{Sidearm, SMG, Shotgun, Rifle, Sniper, Heavy, Melee}`，近戰的 `shopData`、`weaponStats` 為 null。
    `weaponStats{fireRate, magazineSize, runSpeedMultiplier, equipTimeSeconds, reloadTimeSeconds, firstBulletAccuracy, shotgunPelletCount, wallPenetration, feature, fireMode, altFireType, adsStats, altShotgunStats, airBurstStats, damageRanges[]}`；
    `wallPenetration` 為 `EWallPenetrationDisplayType::{Low, Medium, High}`；`fireMode` 只有 `EWeaponFireModeDisplayType::SemiAutomatic` 或 null（全自動）；`feature` 為 `EWeaponStatsFeature::{ROFIncrease, Silenced, DualZoom}` 或 null；`altFireType` 為 `EWeaponAltFireDisplayType::{ADS, Shotgun, AirBurst}` 或 null；
    `adsStats{zoomMultiplier, fireRate, runSpeedMultiplier, burstCount, firstBulletAccuracy}`；`damageRanges[]{rangeStartMeters, rangeEndMeters, headDamage, bodyDamage, legDamage}`。
  - `skins[]{uuid, displayName, themeUuid, contentTierUuid, displayIcon, levels[]{uuid, displayName, displayIcon, streamedVideo}, chromas[]{uuid, displayName, displayIcon, fullRender, swatch, streamedVideo}}`。
  - `/v1/themes`：`{uuid, displayName, displayIcon, storeFeaturedImage}`。`/v1/bundles` 沒有內含項目；以「組合包 `displayName` = 主題 `displayName`」配對 `skins[].themeUuid`，實測 328 個組合包有 290 個配得到。
  - `/v1/maps`：`{uuid, displayName, displayIcon（小地圖，27 張中 9 張為 null）, splash, coordinates, tacticalDescription, xMultiplier, yMultiplier, xScalarToAdd, yScalarToAdd, callouts[]{regionName, superRegionName, location{x, y, z}}}`；
    小地圖位置 `u = location.y × xMultiplier + xScalarToAdd`、`v = location.x × yMultiplier + yScalarToAdd`。
  - `/v1/agents`：`{uuid, displayName, description, displayIcon, fullPortrait, background, role{displayName}, abilities[]{slot, displayName, description, displayIcon}, recruitmentData}`；`slot` 為 `Grenade`（C）、`Ability1`（Q）、`Ability2`（E）、`Ultimate`（X）、`Passive`。沒有技能價格欄位。

## 遠端操作（寫入，使用者同意後）⚠️ 未實測

依社群文件（valapidocs、valclient）撰寫，**沒有用真實帳號測試過**；實測後請把 ⚠️ 改成 ✅ 並補上實際欄位。
規則見 AGENTS.md 第 3 節「遠端操作」。

### `GET`／`PUT pd /personalization/v3/players/{puuid}/playerloadout`（GET ✅ 2026-10-22，PUT ⚠️）
- **v2 回 404**（2026-10-22 實測），改用 v3。
- 頂層 ✅：`Guns, ActiveExpressions, DynamicOptions, Identity, Incognito`（v3 用 `ActiveExpressions` 取代 `Sprays`）
- `Guns[]`：`ID`（武器 UUID）、`SkinID`、`SkinLevelID`、`ChromaID`、`CharmInstanceID`、`CharmID`、`CharmLevelID`、`Attachments`
  - 🧩 使用中：`ID, SkinID, SkinLevelID, ChromaID`；PUT 時其餘欄位原樣寫回。
- `ChromaID` 用 valorant-api 造型 `chromas` 的 UUID；`chromas[0]` 是基本款（不在 entitlements 裡）。

### `POST glz /pregame/v1/matches/{matchId}/select/{agentId}`、`…/lock/{agentId}` ⚠️
- 沒有內容；回應是更新後的選角資料（不使用）。

### `POST glz /parties/v1/parties/{partyId}/…` ⚠️
- `members/{puuid}/setReady`：`{"ready": bool}`
- `invitecode`：回應是隊伍資料，代碼在 `InviteCode`
- `matchmaking/join`、`matchmaking/leave`：沒有內容
- `queue`：`{"queueID": "competitive"}`；可選的模式來自隊伍的 `EligibleQueues`
- `accessibility`：`{"accessibility": "OPEN" | "CLOSED"}`
- `invites/name/{name}/tag/{tag}`：沒有內容
- `makecustomgame`、`startcustomgame`：沒有內容；`makedefault?queueID=unrated`：沒有內容
- `customgamesettings`：`{Map, Mode, UseBots, GamePod, GameRules}`（原本的 `CustomGameData.Settings` 只換 `Map`）
- `customgamemembership/{TeamOne|TeamTwo|TeamSpectate}`：`{"playerToPutOnTeam": puuid}`
- 隊伍的 `CustomGameData`：`Settings{Map, Mode, UseBots, GamePod, GameRules}`、`Membership{teamOne, teamTwo, teamSpectate, …}[]{Subject}`

### `DELETE glz /parties/v1/players/{puuid}` ⚠️
- 隊長把成員移出隊伍；沒有內容。

### `POST glz /pregame/v1/matches/{matchId}/quit`、`POST glz /core-game/v1/players/{puuid}/disassociate/{matchId}` ⚠️
- 逃跑／離開對局，會被懲罰；沒有內容。

### `POST pd /contracts/v1/contracts/{puuid}/special/{contractId}` ⚠️
- 啟用特務合約；`GET contracts` 的 `ActiveSpecialContract` 是目前啟用的合約。
