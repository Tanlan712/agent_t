# 商店刷新通知設定

每天台灣時間早上 8 點左右（每日商店刷新，UTC 00:00），GitHub Actions 的「商店刷新通知」排程
（`.github/workflows/shop-push.yml`）會送一則通知到你訂閱的裝置。通知內容固定，不連 Riot、不讀帳號資料。
GitHub 的排程可能延遲幾分鐘到一小時。

> repo 是公開的。**私鑰與訂閱資料只能放在 Secrets**，不要貼在 issue、PR、程式碼或 Variables。

## 一次性設定

1. 在自己的電腦產生一組 VAPID 金鑰（需要 Node.js）：

   ```
   npx web-push generate-vapid-keys
   ```

   會印出 Public Key 與 Private Key。

2. 到 GitHub repo 的 **Settings → Secrets and variables → Actions**：
   - **Variables** 分頁新增 `VAPID_PUBLIC_KEY` = Public Key（公鑰可以公開，網頁會用到）。
   - **Secrets** 分頁新增 `VAPID_PRIVATE_KEY` = Private Key。

3. 到 **Actions → Deploy to GitHub Pages → Run workflow** 重新部署一次，網頁才會帶入公鑰。

## 每台裝置

1. 打開網站（iPhone／iPad 要先在 Safari「分享 → 加入主畫面」，再從主畫面開啟，iOS 16.4 以上）。
2. 設定頁的「商店刷新通知」按「開啟通知」，允許通知。
3. 按「測試通知」確認這台裝置看得到通知。
4. 按「複製訂閱資料」，到 Secrets 新增或更新 `PUSH_SUBSCRIPTIONS`，內容是 JSON 陣列：

   ```
   [ <第一台裝置的訂閱資料>, <第二台裝置的訂閱資料> ]
   ```

   只有一台裝置時也要包在 `[ ]` 裡。

5. 到 **Actions → 商店刷新通知 → Run workflow** 手動跑一次，確認收到通知。

## 疑難排解

- Actions 的 log 只會顯示「第 N 筆：已送出／失敗（狀態碼）」。
  狀態碼 404 或 410 表示那台裝置的訂閱已失效（清除網站資料、取消訂閱、重新安裝），請在那台裝置重新訂閱，再更新 secret。
- 手機 App（APK／iOS）目前沒有通知，只有網頁版（含加到主畫面的 PWA）有。
- 不想再收到通知：在設定頁按「取消訂閱」，並從 `PUSH_SUBSCRIPTIONS` 刪掉那一筆。
