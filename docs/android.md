# Android App

同一份程式碼建置成自己側載安裝的 APK（AGENTS.md 第 3 節「Android App」）。
和網頁版的差別只有登入：設定 → Riot 帳號 →「在 App 內登入 Riot」，在 Riot 官方頁面登入後會自動回到 App。

## 安裝

1. 手機開啟 <https://github.com/Tanlan712/agent_t/releases/latest/download/Agent-T.apk> 下載。
2. 開啟下載的檔案，依提示允許「安裝不明來源的應用程式」。
3. 之後 master 每次更新（文件除外），GitHub Actions 會自動建出新版。

## App 內更新

開啟 App 時會查 GitHub 最新的 Release（`app-v{建置編號}`），比 App 的版本新就在頂端顯示「有新版」。
按「更新」會在 App 內下載 `Agent-T.apk`（核對 GitHub 提供的 SHA-256），再開啟 Android 的安裝畫面，按「更新」即可，
登入與本機資料會保留。設定 →「App 更新」可以手動檢查、或關掉開啟時的自動檢查。

- 第一次更新時 Android 會要求允許 Agent T「安裝不明應用程式」，允許後回到 App 會接著安裝。
- **需要固定簽章**（下一節）。新版和手機上的版本簽章不同時，Android 不允許覆蓋，
  App 會顯示「新版簽章不同」，這時只能移除舊版、用瀏覽器重新下載安裝。
- 只連 `api.github.com`（查版本）與 `github.com` 的 Release 下載網址，不帶任何帳號資料或 token。
- iOS 的未簽章 IPA 要用自己的 Apple ID 重新簽章，無法在 App 內更新。

## 固定簽章（建議設定一次）

沒有設定時，CI 用每次都不同的 debug 金鑰簽章，安裝新版前要先移除舊版（登入狀態與本機資料會一起清掉），
App 內更新也無法使用。在自己的電腦產生一把金鑰，存進 GitHub secrets，之後的版本就能直接覆蓋安裝：

```bash
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias valshop
base64 -w0 release.jks   # macOS：base64 -i release.jks
```

Windows（PowerShell；`keytool` 在 JDK 或 Android Studio 的 `jbr\bin` 裡），base64 直接複製到剪貼簿：

```powershell
keytool -genkey -v -keystore release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias valshop
[Convert]::ToBase64String([IO.File]::ReadAllBytes("release.jks")) | Set-Clipboard
```

到 repo 的 Settings → Secrets and variables → Actions 新增：

| 名稱 | 內容 |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | 上面 base64 的輸出 |
| `ANDROID_KEYSTORE_PASSWORD` | 金鑰庫密碼 |
| `ANDROID_KEY_ALIAS` | `valshop` |
| `ANDROID_KEY_PASSWORD` | 金鑰密碼 |

`release.jks` 自己保管好，不要放進 repo（`android/.gitignore` 已排除 `*.jks` 與 `key.properties`）。
弄丟金鑰就無法再發出能覆蓋安裝的新版。

設定好之後的**第一個**新版，簽章和手機上用 debug 金鑰的舊版不同，還是要移除舊版、用瀏覽器下載安裝一次；
從那一版開始，之後的更新都能在 App 內完成。

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
