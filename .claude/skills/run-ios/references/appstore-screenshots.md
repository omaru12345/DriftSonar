# App Store 申請用スクリーンショットの撮り方（run-ios 応用）

親フロー `app-store-release` / `appstore-metadata` から呼ばれる、DriftSonar 固有の撮影手順。

## 端末・ビルド
- **6.9インチ機（iPhone 17 Pro Max, 1320×2868）** を使う＝App Store の `APP_IPHONE_67` 枠で受理される。
- **DEBUG ビルド**（デモ投稿シードが `#if DEBUG` のため）。`-configuration Debug` で simulator 向けビルド。

## 状態バーを綺麗に
```bash
xcrun simctl status_bar "$DEV" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
# 終了時: xcrun simctl status_bar "$DEV" clear
```

## デモ投稿を出す（賑わうタイムライン）
1. 初期セットアップ（EULA同意→ニックネーム/bio入力→作成）を通す。
2. **プロフィールタブ →「デモデータを投入」→「投入する」**（5件シード）。
3. ⚠️ **TabView の onAppear が再発火せず Timeline が更新されない** → `xcrun simctl terminate`＋`launch` で**再起動**すると永続データが読み直されて表示される。

## タップは idb（座標は describe-all で）
```bash
idb ui tap --udid "$DEV" <x> <y>          # 論理座標＝ピクセル/3（17 Pro Max は 440×956pt）
idb ui describe-all --udid "$DEV"          # ボタンの frame を取得（右上の小ボタンも外さない）
```
日本語入力は `xcrun simctl pbcopy "$DEV"` → `Cmd+V` 貼り付け（IME 回避）。

## 撮る画面（マーケ向け）と避ける画面
- ◎ タイムライン（デモ投稿）／投稿作成（本文入り）／プロフィール（鍵・bio）／コミュニティガイドライン（EULA）／オンボーディング。
- ✗ **レーダー**: シミュレータに BLE が無く「Bluetoothをオンにしてください」バナー＋「Simulate BLE Receive」DEBUGボタンが映る → 除外（実機なら可）。
- ✗ DEBUG 専用 UI（TTL ラベル等）が目立つ画面。

## 投入
`appstore-metadata/scripts/upload_screens.py` に `<version_loc_id>` とファイルを渡す。`assetDeliveryState=COMPLETE` を確認。
