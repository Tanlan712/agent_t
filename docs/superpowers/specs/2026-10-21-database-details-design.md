# 資料庫詳細頁：武器、地圖、組合包、特務（2026-10-21）

使用者要求（2026-10-21）：武器看全部數據並依類型分類；地圖點開看完整小地圖；組合包看每把槍的等級與其他顏色；特務看技能。
價格：公開資料沒有技能購買價與一般解鎖價，**不顯示價格**（使用者決定 2026-10-21）。

資料只來自 `valorant-api.com`（第 3 節允許的公開遊戲資料），不新增任何 Riot 請求。欄位記錄在 `docs/api-fields.md`。

## 1. 武器
- 列表依 `category` 分區，順序固定：手槍（Sidearm）、衝鋒槍（SMG）、霰彈槍（Shotgun）、步槍（Rifle）、狙擊槍（Sniper）、重型武器（Heavy）、近戰（Melee）。
  區名用 `shopData.categoryText`（zh-TW）；沒有時用上面的中文名。未知類別放最後一區「其他」。
- 點卡片進詳細頁：價格、射速、彈匣、換彈、裝備、移動速度倍率、首發精準度、射擊模式、穿牆（低／中／高）、特性（射速提升／消音／雙段縮放）、右鍵（開鏡／霰彈／空爆）、霰彈彈丸數（>1 才顯示）、開鏡數據（倍率、射速、移速、連發數、首發精準度）、傷害距離表（距離區間 × 頭／身／腿）。
- 欄位為 null 時顯示「—」；`weaponStats` 為 null（近戰）時顯示「無射擊數據」。

## 2. 地圖
- 點卡片進詳細頁：完整小地圖（`displayIcon`）放在 `InteractiveViewer` 內可縮放、拖曳。
- 「顯示地點名稱」開關：把 `callouts` 疊在小地圖上。座標換算（valorant-api 文件）：
  `u = location.y × xMultiplier + xScalarToAdd`，`v = location.x × yMultiplier + yScalarToAdd`（0～1，乘上圖片邊長）。
  標籤：`superRegionName` 與 `regionName` 相同時只顯示一次，否則「superRegionName regionName」。
- 沒有 `displayIcon` 時顯示「這張地圖沒有小地圖」；同時顯示戰術說明 `tacticalDescription`、座標 `coordinates`（有才顯示）。

## 3. 組合包
- 公開資料的組合包沒有內含項目。以「組合包名稱 = 主題 `/v1/themes` 名稱」找主題，再找 `themeUuid` 相同的造型（`/v1/weapons` 的 skins）。
  實測 328 個組合包有 290 個配得到；配不到顯示「這個組合包沒有槍枝造型資料」。同名組合包會顯示同一批造型，頁面註明「依主題名稱配對，同名組合包會顯示相同內容」。
- 組合包詳細頁：造型卡片列表；點造型進造型頁：所有等級（名稱、有影片時「預覽影片」開新分頁）與所有炫彩（`fullRender` 或 `displayIcon`、名稱、`swatch`）。
- 主題與武器資料在第一次點組合包時才下載，之後同一頁面重用。

## 4. 特務
- 點卡片進詳細頁：大頭像（`fullPortrait`）、定位、介紹 `description`、技能（依 C、Q、E、X、被動排序；`Grenade`→C、`Ability1`→Q、`Ability2`→E、`Ultimate`→X、`Passive`→被動），每個技能顯示圖示、名稱、按鍵、說明。

## 測試
- 解析與分類邏輯（含 null 欄位、未知類別、callout 座標、主題配對與同名、技能排序）為單元測試。
- 詳細頁 widget 測試（窄 375 與寬 1440 不溢出）；列表頁可注入 `ValorantApiService`（`http.Client`）測試點擊後進入詳細頁。
