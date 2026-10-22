# 全物品實際定價、目前裝備、排隊懲罰（2026-10-22）

使用者核准（2026-10-22）：從 API 調查清單選了這三項並要求製作。三個都是新的 `pd` 端點、**只能 GET**，
依 AGENTS.md 第 3 節各加一列。格式都只有社群文件（valapidocs，最後更新 2024-04），沒有用真帳號實測，
所以解析一律寬鬆：缺欄位、型別不符或多出未知欄位時略過該項，不讓整頁失敗。

## 1. 全物品實際定價（`GET /store/v1/offers/`）

- 回應（📄）：`Offers[]{OfferID, IsDirectPurchase, StartDate, Cost{幣別ID: 數量}, Rewards[]{ItemTypeID, ItemID, Quantity}}`，
  另有 `UpgradeCurrencyOffers[]`（不使用）。
- 解析 `OfferPrices`：只取 `Cost` 裡 VP（`85ad13f7-…`）大於 0 的 offer；每個 `Rewards[].ItemID`（轉小寫）對應到這個 VP 價。
  同一個 ItemID 出現多次時取第一個。沒有 VP 價的（例如輻能點數升級）略過。
- `OfferPriceProvider`：
  - 價格是所有玩家共用的公開定價，不含個人資料，所以存進 localStorage（`offer_prices_v1`，含抓取時間），
    登出後仍可顯示上次的定價。
  - 登入後背景更新：快取超過 24 小時或沒有快取時才重抓（`LoginPrefetcher` 最後一步）。失敗保留舊快取。
  - `priceOf(SkinInfo)`：用造型第一個等級的 uuid（`levelUuid`）查，查不到回傳 null。
- 使用處：
  - 手動編輯商店選造型時，預設價格優先用實際定價，沒有才用 `defaultPrice` 的推估值。`default_price.dart` 保留做為備援。
  - 選擇造型頁、願望清單的造型卡片顯示價格；願望清單副標題加上尚未擁有、有定價的造型總計（「N 款・未擁有共 N VP」）。
  - 沒有定價時不顯示價格（例如限定、無法直接購買的造型）。

## 2. 目前裝備（`GET /personalization/v2/players/{puuid}/playerloadout`）

- **只能 GET**；`PUT` 同一路徑會更換裝備，屬第 3 節禁止的寫入，絕對不用。
- 回應（📄）：`Subject, Version, Guns[]{ID(武器), SkinID, SkinLevelID, ChromaID, CharmID?, CharmLevelID?, Attachments}`、
  `Sprays[]{EquipSlotID, SprayID, SprayLevelID}`、`Identity{PlayerCardID, PlayerTitleID, AccountLevel, PreferredLevelBorderID, HideAccountLevel}`、`Incognito`。
- 解析 `PlayerLoadout`（ID 一律轉小寫，缺欄位的那把槍或噴漆略過）。
- 顯示：「我的收藏」新增最後一個分頁「目前裝備」（不改變原本預設打開的造型分頁）：
  - 依 valorant-api 的武器順序列出每把武器的造型（有炫彩用炫彩圖）、名稱與吊飾名稱。
  - 噴漆、玩家卡片、稱號各一列。valorant-api 找不到的 ID 顯示「未知物品」。
  - 讀取失敗時只有這個分頁顯示錯誤與「重試」，其他分頁不受影響。
- 只在打開收藏頁時讀取（不加進登入預讀），登入期間快取，換帳號或登出清空。

## 3. 排隊懲罰（`GET /restrictions/v3/penalties`）

- 回應（📄）：`Subject, Penalties[], Version`；社群文件沒有寫 `Penalties` 每一項的格式。
- 解析 `PenaltyStatus`（寬鬆）：
  - 每一項取：到期時間（`Expiry`／`ExpirationTime`／`EndTime` 其中一個，ISO 字串或毫秒數字）、
    剩餘場數（`GamesRemaining`，大於 0 才顯示）、效果（名稱含 `Effect`、值不是 null 的 key）。
  - 已知效果名稱翻成中文：`QueueDelayEffect` 排隊延遲、`QueueRestrictionEffect` 禁止排隊、
    `RankedRestrictionEffect` 禁止競技、`RMSNotificationEffect` 警告通知、`XPPenaltyEffect`／`XPPenaltyEffectV2` 經驗值懲罰、`GameBanEffect` 禁止遊戲；
    其他照原名顯示。不顯示任何 ID。
  - 已到期的項目不算進目前懲罰。
- 顯示：「通行證與任務」頁最上方一張小卡：沒有懲罰時顯示「目前沒有排隊懲罰」，有的話列出每項的效果、到期時間或剩餘場數；
  讀取失敗時顯示「無法取得排隊懲罰」與重試，不影響通行證內容。並註明「格式依社群文件推測，可能不完整」。
- 打開通行證頁時讀取，登入期間快取（重新整理按鈕一併重抓）。

## 共用規則

- 三個請求都走 `RiotClient.getPd`（全域同時最多 2 個 Riot 請求）與 `withRiotRetry`（429／連線失敗退避，最多 3 次）。
- 401／403 時依第 4 節 `RiotProvider.expire()`。
- 新欄位記錄到 `docs/api-fields.md`，標 📄（尚未實測）。

## 測試

- 解析：offers（VP 過濾、多個 reward、缺欄位）、loadout（大小寫、缺欄位、多噴漆）、penalties（空陣列、各種到期欄位、已到期、未知效果）。
- RiotClient：三個端點都是 GET、路徑正確、帶 pd 標頭。
- Provider：載入、快取、24 小時內不重抓、換帳號清空、授權失敗登出、失敗保留舊價格。
- 畫面：收藏頁「目前裝備」分頁、通行證頁懲罰卡、選造型預設價用實際定價、願望清單價格；375／1440 不溢出。
