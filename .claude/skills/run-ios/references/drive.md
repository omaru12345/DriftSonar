# run-ios 詳細: シミュレータ UI の駆動（タップ・入力・座標）

`xcrun simctl` には「タップ」「文字入力」が無い。ヘッドレス環境では以下の組み合わせで駆動する。
（`idb` や XCUITest が使えるならそちらが安定。本書は idb 無し前提の検証済み手順。）

## ツール準備

```bash
brew install cliclick   # CGEvent でクリックを合成。System Events の click at は使わない
```

### なぜ System Events の click at を使わないか
`osascript -e 'tell application "System Events" to click at {x,y}'` は TCC（オートメーション権限）で
`-25204` エラーになり**クリックが飛ばない**。一方 `cliclick`（CGEventPost 方式）は通る。
※ `keystroke`（キー入力）は System Events でも通るので、文字入力だけは osascript を使ってよい。

## 座標の出し方（スクショpx → 画面座標）

1. シミュレータ窓の位置・サイズを取得:
   ```bash
   osascript -e 'tell application "System Events" to tell process "Simulator" to get {position, size} of window 1'
   # 例: 206, 64, 386, 831  → pos(px=206,py=64) size(w=386,h=831)
   ```
2. スクショのピクセル寸法を取得（例 iPhone 17 = 1206×2622px、論理 402×874pt @3x）:
   ```bash
   sips -g pixelWidth -g pixelHeight /tmp/ds.png
   ```
3. スクショ上で押したい要素のピクセル位置 (img_x, img_y) を読み取り、窓座標へ換算:
   ```
   screen_x = px + (img_x / img_w) * w
   screen_y = py + (img_y / img_h) * h
   ```
   ```bash
   cliclick c:$screen_x,$screen_y
   ```

### 較正の目安（iPhone 17・窓 206,64,386,831 の実測）
- 画面中央付近のボタン（縦比 ≈0.48）→ 画面 y ≈ 470 で命中
- 下部タブバー（Timeline/Radar/Profile、縦比 ≈0.94）→ 画面 y ≈ 822、x は Timeline≈315 / Radar≈399 / Profile≈483
- **右上の小さい円形ボタン（Compose 等）は Dynamic Island に近く命中しにくい**。±20pt ずらして数回試す。どうしても外すなら idb / XCUITest を検討。

## テキスト入力（日本語 IME を回避）

シミュレータのソフトキーボードが日本語 IME だと、`keystroke "Alice"` がローマ字変換されて
「あぃcえ」等になる。**クリップボード経由の貼り付け**で確定文字を入れる:

```bash
# 1. 対象 TextField をタップしてフォーカス（cliclick）
# 2. 既存の合成をキャンセル＋全消し（任意）
osascript -e 'tell application "Simulator" to activate' \
          -e 'tell application "System Events" to key code 53' \        # Esc: IME合成キャンセル
          -e 'tell application "System Events" to keystroke "a" using command down' \  # 全選択
          -e 'tell application "System Events" to key code 51'           # Delete
# 3. クリップボードに入れて貼り付け（IME を通らない）
printf "Alice" | xcrun simctl pbcopy "$DEV"
osascript -e 'tell application "Simulator" to activate' \
          -e 'tell application "System Events" to keystroke "v" using command down'
```

## 駆動シーケンス例（初期セットアップ → 各タブ）

```bash
DEV="<UDID>"
shot(){ xcrun simctl io "$DEV" screenshot "/tmp/$1.png"; }   # 各操作後に撮って Read で目視

# 初期セットアップ: ニックネーム欄にフォーカス済みなら貼り付け → Create ボタン
printf "Alice" | xcrun simctl pbcopy "$DEV"
osascript -e 'tell application "Simulator" to activate' -e 'tell application "System Events" to keystroke "v" using command down'; sleep 1
cliclick c:399,471      # Create Profile & Generate Keys
sleep 3; shot 01-timeline

# タブ移動
cliclick c:399,822; sleep 2; shot 02-radar     # Radar
cliclick c:483,822; sleep 2; shot 03-profile   # Profile
cliclick c:315,822; sleep 2; shot 04-timeline  # Timeline へ戻る
```

## トラブルシュート

| 症状 | 原因 / 対処 |
|------|------------|
| クリックが飛ばない / `-25204` | System Events の click at を使っている → `cliclick` に変える |
| 文字が「あぃcえ」等になる | 日本語 IME。クリップボード貼り付け方式に変える |
| タップが少しずれる | 窓が動いた可能性。`get {position, size}` を取り直して再計算 |
| 右上ボタンに当たらない | Dynamic Island 付近の小ターゲット。±20pt 試行 or idb / XCUITest 化 |
| 起動直後が真っ白/即終了 | ビルドや署名の問題。`xcrun simctl launch` の出力と Console を確認 |

## 安定駆動への発展（任意）

繰り返し E2E するなら:
- **idb**（`brew install facebook/fb/idb-companion` + `pip install fb-idb`）: `idb ui tap x y` で要素単位タップが安定。
- **XCUITest**: UI テストターゲットを追加し、アクセシビリティ識別子でタップ。CI でも回せる。
