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
  - `BundleRemainingDurationInSeconds`

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

### `GET /pregame/v1/players/{puuid}`、`GET /core-game/v1/players/{puuid}` ✅ 2026-10-21
- 不在該階段時回 404：`{httpStatus, errorCode, message}`。
- 在選角或對局中時的欄位：📄 `Subject, MatchID, Version`；詳細內容待實測後補上。

## 公開遊戲資料（valorant-api.com）🧩

- `/v1/weapons/skins`、`/v1/bundles`、`/v1/agents`、`/v1/maps`、`/v1/competitivetiers`、`/v1/playercards`、`/v1/gamemodes` 等；回傳格式都是 `{status, data}`。
- 牌位圖示來自 `competitivetiers` 最後一季的 `tiers[]{tier, tierName, smallIcon}`；tier 0「牌階未定」的圖示是官方的問號圖。
- 玩家卡圖片：`https://media.valorant-api.com/playercards/{PlayerCardID}/smallart.png`。
