# DriftSonar 引き継ぎ書

Bluetooth LE mesh で WiFi なしにメッセージが伝播する iOS 専用 SNS。**主要機能は実装完了済みで、現在は App Store 審査対応（build 6 の再提出）フェーズ**。

## 目的と現在地

- **コアバリュー**: 「記録に残らない会話」「あえてオフグリッド」。bitchat（Jack Dorsey）着想。サーバー完全非依存の edge 完結。
- **2層構造**: 公開タイムライン＝Store-and-Forward メッシュで漂い広がる層（閉じない）／DM（SecretMessage）＝Curve25519 + AES-GCM の E2E 暗号で本人間に閉じる層。詳細 → [concept.md](concept.md)
- **現在地**（git log / GitHub Issues より）:
  - App Store 審査で GL1.2（報告先連絡先）・GL2.1（BLE 自動開始＋定期再ゴシップ）・GL5.1.1（アカウント削除）のリジェクト対応済み。build 6（重複通知修正 TASK-193 含む）まで作成済み。
  - **次の一手: Issue #230（TASK-194, P1）= build 6 での App Store 再提出**。
  - その後の候補: EP-038（#231, P2）ビジュアルアイデンティティ刷新 "Drift/漂着"（TASK-195〜202）、#227 メディアのオンデマンド BLE transport 実機結線、#228 日英 i18n。
  - 収益化は掲載後に検討（[monetization.md](monetization.md)、EP-022）。
- ブランチは `main` が最新。ローカルに feature ブランチ 3 本（`feature-media-attachment-model` / `feature-maruo-compose-media-ui` / `feature-maruo-timeline-media-viewer`）が残存するが、いずれも `main` にマージ済み（`git branch --merged main` で確認）。掃除して良い。

## アーキテクチャ / 構成

- **技術スタック**: SwiftUI（iOS 17+）+ Swift Package（swift-tools 6.2、Swift 6 厳格同時性）+ SwiftData + Core Bluetooth + CryptoKit + SwiftLint（ビルドプラグイン）。
- **構成**（作業前に `.claude/diagrams/architecture.md` も参照）:

```
DriftSonarApp/DriftSonarApp/          ← SwiftUI iOS アプリ（.xcodeproj）
  ├── DriftSonarApp/                  ← 同期ルートグループ（ContentView 等）
  ├── ViewModels/                     ← Encounter / InitialSetup / SecretMessage / Timeline
  └── Views/                          ← EncounterView / PostTimelineView / ComposeView / SecretMessageView 等
DriftSonarCore/Sources/DriftSonarCore/
  ├── EncounterDomain/                ← BLEEncounterService（Core Bluetooth 実装）
  ├── MeshDomain/                     ← Store-and-Forward メッシュ中継
  ├── PostDomain/ MediaDomain/        ← 投稿・メディア（BLE 伝播 v2 wire、docs/media-propagation.md）
  ├── SecretMessageDomain/            ← Curve25519 + AES-GCM E2E 暗号
  ├── ProfileDomain/                  ← プロファイル・鍵管理（秘密鍵は Keychain のみ）
  └── BlockDomain/ ModerationDomain/  ← ブロック・UGC モデレーション
```

- BLE は各端末が Peripheral（GATT で公開鍵公開）と Central（スキャン→接続→読取→切断）を同時担当。サービス/キャラクタリスティック UUID の正典 → [design-notes.md](design-notes.md)

## 重要な判断・制約・gotcha

- **Xcode プロジェクト**: `Views/` `ViewModels/` は明示的 PBXGroup のため**新ファイル追加時は `project.pbxproj` の手動編集が必要**（同期ルートグループ配下は自動）。`TimelineView` は SwiftUI 組み込みと衝突するので `PostTimelineView` 命名。
- **ビルド**: `-skipPackagePluginValidation` が必須（SwiftLint プラグイン承認スキップ）。
- **並行性**: CB コールバックは `bleQueue` 上で処理、UI 通知は Main Queue へ dispatch。`@unchecked Sendable` / `nonisolated(unsafe)` を意図的に使用。
- **SwiftData**: `#Predicate` 内で外部変数を使う場合はローカル定数へ先に代入必須。`PostModel.mediaData` は optional（マイグレーション失敗回避のため。非 optional 化は不可）。
- **鍵管理**: `UserProfileModel` に秘密鍵は含まれない。`KeychainService.load(account:)` で取得（コード例 → [design-notes.md](design-notes.md)）。
- **審査対応の経緯**: GL2.1 対策として BLE は起動時自動開始＋定期再ゴシップ。GL1.2 対策で設定画面に報告先連絡先、GL5.1.1 対策でアカウント削除機能あり。再提出時はこれらの回帰に注意。
- **配布設定**: Bundle ID `com.driftsonar.app`、Deployment Target iOS 17.0、iPhone 専用（device family=1）、`ITSAppUsesNonExemptEncryption = false`。公開手順の詳細 → [app-store-release.md](app-store-release.md)
- **コンセプト上の注意**: 「閉じる」のは DM・ローカルデータ・鍵のみ。公開タイムラインは閉じない。UI コピーやポリシー文言でこの区別を崩さないこと。

## 規約

- **Issue 管理は GitHub Issues が正**（旧 ISSUES.md は 2026-05-31 に全 217 件移行済み・削除）。タイトルに旧 ID（`[EP-XXX]` / `[TASK-XXX]`）保持。EPIC=親（`epic` ラベル）、TASK=子。一覧: `gh issue list -R omaru12345/DriftSonar`
- **メインブランチは `main`**（knowledge-cycle の `dev` 規約とは異なる）。ブランチ命名はグローバル規約どおり `feature-{name}-{description}` 等、Issue 番号は入れない。ベースブランチ名を付けずに HEAD から切る。
- コミットメッセージは `feat:` `fix:` `build:` prefix + 日本語 + 末尾に `(TASK-XXX)` 参照が慣例（git log 参照）。
- 読んでいないコードは変更しない（編集前に必ず Read）。CLAUDE.md には常時必要な情報のみ（Progressive Disclosure）。

## 実行と検証

```bash
# アプリビルド（シミュレータ向け）
xcodebuild \
  -project DriftSonarApp/DriftSonarApp/DriftSonarApp.xcodeproj \
  -scheme DriftSonarApp \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation \
  build

# コアのテスト（CI と同等。CI は macos-15 + Xcode 16.3）
cd DriftSonarCore && swift test --parallel
```

- シミュレータでの起動・主要動線のスモークテストは `.claude/skills/run-ios` スキル（「アプリを起動」等で発火）。
- CI: `.github/workflows/test.yml`（DriftSonarCore 変更時に swift test + Codecov）、`bump-build-number.yml` あり。

## メタ

- 生成日: 2026-07-05 / 生成モデル: Fable5
- 根拠: リポジトリの CLAUDE.md・docs/（concept / design-notes / app-store-release / monetization / media-propagation）・`.claude/diagrams/architecture.md`（存在確認のみ）・`git log`・`git branch`・`gh issue list`・`Package.swift`・`.github/workflows/test.yml`
- 未確認事項: App Store Connect 側の最新審査ステータス（リポジトリ外）
