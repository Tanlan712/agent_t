# Android App

同一份程式碼建置成自己側載安裝的 APK（AGENTS.md 第 3 節「Android App」）。
和網頁版的差別只有登入：設定 → Riot 帳號 →「在 App 內登入 Riot」，在 Riot 官方頁面登入後會自動回到 App。

## 安裝

1. 手機開啟 <https://github.com/Tanlan712/valorant_shop_tracker/releases/latest/download/valorant-shop-tracker.apk> 下載。
2. 開啟下載的檔案，依提示允許「安裝不明來源的應用程式」。
3. 之後 master 每次更新（文件除外），GitHub Actions 會自動建出新版，重新下載安裝即可覆蓋。

## 固定簽章（建議設定一次）

沒有設定時，CI 用每次都不同的 debug 金鑰簽章，安裝新版前可能要先移除舊版（登入狀態與本機資料會一起清掉）。
在自己的電腦產生一把金鑰，存進 GitHub secrets，之後的版本就能直接覆蓋安裝：

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias valshop
base64 -w0 release.jks   # macOS：base64 -i release.jks
```

到 repo 的 Settings → Secrets and variables → Actions 新增：

| 名稱 | 內容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 上面 base64 的輸出 |
| `ANDROID_KEYSTORE_PASSWORD` | 金鑰庫密碼 |
| `ANDROID_KEY_ALIAS` | `valshop` |
| `ANDROID_KEY_PASSWORD` | 金鑰密碼 |

`release.jks` 自己保管好，不要放進 repo（`android/.gitignore` 已排除 `*.jks` 與 `key.properties`）。

## 本機建置

```bash
flutter build apk --release   # 輸出 build/app/outputs/flutter-apk/app-release.apk
```

## 更換圖示

設定頁「App 圖示」可以換成預設或 A、C、D、F1、F2 主題的圖示。換完桌面可能要幾秒才更新；
有些桌面啟動器會把已經放在主畫面的捷徑移除，從 App 清單重新拖出來即可。

## 已知限制

- Riot 登入頁可能擋內嵌網頁或要求驗證碼；登入不了時改用同一頁下方的網頁登入方式（貼網址）。
- token 約 1 小時過期，App 不會自動續期；Riot 頁面若勾了「保持登入」，再按一次登入通常不用重新輸入密碼。
- 「切換帳號」按鈕會清除內嵌頁保存的 Riot 登入記錄。
