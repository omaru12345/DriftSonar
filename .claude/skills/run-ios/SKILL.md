---
name: run-ios
description: DriftSonarApp を iOS シミュレータで起動し、主要動線（初期セットアップ→Timeline→Radar→Profile→投稿）をスクリーンショットで駆動・検証する手順。triggers on 「アプリを起動」「シミュレータで動かす」「スモークテスト」「スクショで確認」「run the app」「launch DriftSonar」「画面を確認」など、DriftSonar の iOS アプリを実際に動かして見たいとき。
---

# run-ios — DriftSonarApp をシミュレータで起動・駆動する

DriftSonar（iOS / SwiftUI）を **実際に起動して画面を見る／主要動線を駆動する**ための検証済み手順。
ユニットテストではなく、ユーザーが触れるアプリそのものを起動する。

## 重要な前提（このプロジェクト固有値）

| 項目 | 値 |
|------|----|
| scheme | `DriftSonarApp` |
| bundle id | `com.driftsonar.app` |
| project | `DriftSonarApp/DriftSonarApp/DriftSonarApp.xcodeproj` |
| 最低 iOS | 17.0（シミュレータは iPhone 17 等で可） |

## 基本フロー（最短）

```bash
DEV="<iPhone シミュレータの UDID>"   # xcrun simctl list devices available | grep -i iphone
APP="$HOME/Library/Developer/Xcode/DerivedData/DriftSonarApp-*/Build/Products/Release-iphonesimulator/DriftSonarApp.app"

# 1. ビルド（提出構成に合わせ Release。Debug なら -configuration Debug）
xcodebuild -project DriftSonarApp/DriftSonarApp/DriftSonarApp.xcodeproj -scheme DriftSonarApp \
  -configuration Release -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation build

# 2. 起動
xcrun simctl boot "$DEV"; open -a Simulator; sleep 8
xcrun simctl install "$DEV" $APP
xcrun simctl launch "$DEV" com.driftsonar.app

# 3. スクショ（必ず画像を Read して目視する。空白/クラッシュは起動失敗）
xcrun simctl io "$DEV" screenshot /tmp/ds-launch.png
```

初回起動は `InitialSetupView`（ニックネーム必須）から始まる。ここを越えないと Timeline 等へ進めない。

## UI を駆動する（タップ・入力）

タップ・テキスト入力には **OS レベルの工夫が要る**（simctl にタップ機能はない）。
詳細・座標計算・既知のハマりどころは **[references/drive.md](references/drive.md)** を参照。

要点だけ:
- **タップ**: `cliclick c:X,Y`（`brew install cliclick`）。System Events の `click at` は TCC で `-25204` 失敗するので使わない。
- **テキスト入力**: 日本語 IME を回避するため `xcrun simctl pbcopy` でクリップボードに入れ `Cmd+V` で確定貼り付け。
- **座標**: スクショのピクセル位置 → シミュレータ窓の画面座標へ換算（[references/drive.md](references/drive.md) に式と較正値）。

## 終了

```bash
xcrun simctl shutdown "$DEV"
```

## 検証で見るべきもの（このアプリ）

- 初期セットアップ: タイトルが「Welcome to **DriftSonar**」（旧 Whisper でない）
- Timeline 空状態 / Radar 空状態: **イルカイラスト**が出る
- Radar: シミュレータは BLE 非搭載 → **「Bluetoothをオンにしてください」バナー**が正しく出る
- Profile: 暗号鍵・署名鍵の**フィンガープリントが別々に**表示される（鍵生成パイプラインの動作確認）
