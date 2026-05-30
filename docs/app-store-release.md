# DriftSonar — App Store 公開手順書（学習用プレイブック）

iOS アプリを初めて App Store に出すための実践手順。DriftSonar 固有の設定値・注意点を埋め込んである。
**実機テスト（TASK-073）は一旦スキップ**して公開フローの習得を優先する前提。

関連: GitHub Issues #19 (EP-019) / #140 (TASK-105) / #141 (TASK-106)、`docs/privacy-policy.md`

---

## 0. 前提と現在地

### コード側（このリポジトリ）で準備済み ✅
| 項目 | 状態 |
|------|------|
| Bundle ID | `com.driftsonar.app`（旧 `com.whisper.*` から変更済み） |
| 表示名 | `CFBundleDisplayName = DriftSonar`（ホーム画面表示） |
| バージョン | `MARKETING_VERSION = 0.1.0` / `CURRENT_PROJECT_VERSION = 1` |
| 署名方式 | `CODE_SIGN_STYLE = Automatic`（自動署名） |
| 暗号輸出申告 | `ITSAppUsesNonExemptEncryption = false`（標準暗号として適用除外） |
| アプリアイコン | 設置済み（1024 単一形式・ライト/ダーク/tinted） |
| Background Modes | `bluetooth-central` / `bluetooth-peripheral`（Info.plist） |
| 権限説明文 | `NSBluetoothAlwaysUsageDescription` 設定済み |
| プライバシーマニフェスト | `PrivacyInfo.xcprivacy`（収集なし・トラッキングなし） |
| プライバシーポリシー | `docs/privacy-policy.html`（ホスト待ち＝TASK-105） |

### あなたが Apple 側で手を動かす必要がある作業（以降の手順）
Developer 登録 → 署名 → App Store Connect 登録 → メタデータ → Archive/アップロード → 審査提出。

### Deployment Target（対応済み ✅）
`IPHONEOS_DEPLOYMENT_TARGET` を `26.2` → **`17.0`** に変更済み（配布範囲を iOS 17+ に拡大）。
Core パッケージが元々 `.iOS(.v17)`・コードも `@available(iOS 17, *)` 設計のため iOS 17 が安全な下限。
Debug / Release 両構成でビルド成功・API 非互換ゼロを確認済み。

---

## 1. Apple Developer Program 登録（未登録 → ここから）

1. https://developer.apple.com/programs/ にアクセスし「Enroll」。
2. Apple ID（2ファクタ認証必須）でログイン。
3. **個人（Individual）** か **法人（Organization）** を選択。個人が手軽（表示される販売者名が本名になる点だけ注意）。
4. 年額 **99 USD** を支払う。
5. 審査に **数時間〜2日**。承認されると App Store Connect が使えるようになる。

> 登録完了まで、署名・Archive・公開はできない。コード側準備（このリポジトリ）は完了しているので待つだけ。

---

## 2. Xcode で署名設定（Developer 登録後）

1. Xcode で `DriftSonarApp/DriftSonarApp/DriftSonarApp.xcodeproj` を開く。
2. TARGETS → DriftSonarApp → **Signing & Capabilities**。
3. **Team** に登録した Apple Developer アカウントを選択（`DEVELOPMENT_TEAM` が自動で入る）。
4. 「Automatically manage signing」にチェック（自動で証明書・Provisioning Profile を作成）。
5. Bundle Identifier が `com.driftsonar.app` になっていることを確認。
6. Background Modes に Bluetooth 2項目が出ていることを確認（Info.plist 由来）。

---

## 3. App Store Connect でアプリ登録

1. https://appstoreconnect.apple.com → My Apps → **＋ → New App**。
2. 入力:
   - Platform: iOS
   - Name: **DriftSonar**（App Store 表示名。重複不可・後で変更可）
   - Primary Language: 日本語 など
   - Bundle ID: `com.driftsonar.app`（Xcode で一度ビルド/登録すると候補に出る。出ない場合は Developer Portal → Identifiers で先に登録）
   - SKU: 任意の管理用文字列（例 `driftsonar-001`）
3. 作成すると、このアプリのメタデータ入力画面に進める。

---

## 4. メタデータ入力

| 項目 | DriftSonar 向けメモ |
|------|---------------------|
| サブタイトル | 例「すれ違いで漂うオフグリッド SNS」 |
| 説明文 | サーバーレス・BLE メッシュ・E2E 暗号 DM・記録に残らない、を訴求（`docs/concept.md` 参照） |
| キーワード | bluetooth, mesh, offline, privacy, sns, e2e |
| カテゴリ | Social Networking |
| サポート URL | 必須。GitHub リポジトリ or 簡易ページで可 |
| **プライバシーポリシー URL** | **必須**。TASK-105 のホスト先 URL（後述） |
| 年齢制限 | 質問に回答して自動設定 |

### プライバシーポリシーのホスト（TASK-105 完了 ✅）
GitHub Pages で配信済み。App Store Connect の「プライバシーポリシー URL」に以下を登録するだけ:

**https://omaru12345.github.io/DriftSonar/privacy-policy.html**

（リポジトリ https://github.com/omaru12345/DriftSonar の main / docs フォルダから配信、HTTP 200 確認済み）

---

## 5. App Privacy（プライバシー栄養ラベル）

App Store Connect → App Privacy で申告。DriftSonar は:
- **Data Not Collected**（データ収集なし）を選択 ＝ サーバーレスで開発者は何も受け取らない。
- これは `PrivacyInfo.xcprivacy`（`NSPrivacyTracking=false`・収集データ空）と整合する。

---

## 6. スクリーンショット

- 必須: **6.9インチ（iPhone 16 Pro Max 等）** のスクショ。シミュレータで撮影可。
- デモ投稿シード（TASK-107、`#if DEBUG` の「デモデータ投入」）で見栄えするタイムラインを用意して撮影。
- ⚠️ ただしデモ投入ボタンは DEBUG ビルド限定。スクショ撮影は DEBUG ビルドのシミュレータで行う。

---

## 7. Archive とアップロード

実機不要。シミュレータではなく **「Any iOS Device (arm64)」** を選んで Archive する。

1. Xcode 上部のデバイス選択を **Any iOS Device (arm64)**。
2. メニュー Product → **Archive**（Release 構成でビルドされる）。
3. 完了すると **Organizer** が開く。
4. **Distribute App → App Store Connect → Upload**。
5. 自動署名なら証明書・プロファイルは自動。アップロード完了まで待つ。

> CLI 派なら `xcodebuild -scheme DriftSonarApp -archivePath build/DriftSonar.xcarchive archive` →
> `xcodebuild -exportArchive ...`（要 ExportOptions.plist）。学習目的なら GUI の Organizer が分かりやすい。

---

## 8. 審査提出時の最重要注意（BLE アプリ特有のリスク）

**DriftSonar は2台ないと本来の機能を体験できない** → 審査担当が「機能を確認できない」として **リジェクトしやすい**。対策:

- **App Review への注記（Review Notes）** に、メッシュ伝播は近接2台のすれ違いで動作する旨と、単体ではタイムライン/投稿/UI が確認できることを明記。
- 可能なら **デモ動画**（2台で投稿が伝播する様子）を用意してリンクを注記に貼る。
- BLE の常時利用・Background Modes について「近接ユーザー検出とメッセージ伝播のため」と用途を説明。
- アカウント不要アプリなので **デモアカウントは不要**である旨も明記。

### その他のリジェクト要因
- **Minimum Functionality**: 単体で何もできないと見なされない様、空状態 UI やデモ性を担保（デモシード・空状態イラスト実装済み）。
- **暗号**: `ITSAppUsesNonExemptEncryption=false` で標準暗号の適用除外を申告済み（CryptoKit のみ使用前提）。

---

## 9. リリース

1. ビルドが「処理完了」になったら、App Store Connect のバージョンに紐付け。
2. メタデータ・スクショ・プライバシーをすべて埋める。
3. **Submit for Review**。
4. 審査通過後、手動 or 自動でリリース。

---

## 当面のクリティカルパス（あなたの次の一手）

```
1. Apple Developer Program 登録（数時間〜2日待ち）   ← まずここ
2. 並行して: このリポジトリを GitHub に push → Pages でプライバシーポリシー公開（TASK-105）
3. 登録完了後: Xcode で Team 設定 → Archive → アップロード（TASK-106）
4. App Store Connect でメタデータ・スクショ・プライバシー入力 → 審査提出
```
