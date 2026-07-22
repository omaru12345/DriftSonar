# DriftSonar — Claude Code セッションガイド

## プロジェクト概要
Bluetooth LE meshを使ってWiFiなしでメッセージが伝播するSNSアプリ。
bitchat（Jack Dorsey）にヒントを得た。「記録に残らない会話」「あえてオフグリッド」がコアバリュー。
iOS専用（SwiftUI + DriftSonarCore Swift Package）

**ポジショニング**: Obsidian の「サーバーに依存せず edge だけで完結する」思想を参考にしつつ、差別化として **個々人の秘密の話に閉じた SNS** を目指す。公開タイムラインは偶然の出会いで漂い広がる層、DM（SecretMessage）は信頼する相手との会話が E2E 暗号で本人間に閉じる層、という2層構造。詳細 → `docs/concept.md`

## 構成

```
DriftSonar/
├── DriftSonarApp/             ← SwiftUI iOSアプリ
│   └── DriftSonarApp/
│       ├── DriftSonarApp/     ← 同期ルートグループ（ContentView等）
│       ├── ViewModels/        ← EncounterViewModel / InitialSetupViewModel / SecretMessageViewModel / TimelineViewModel
│       └── Views/             ← EncounterView / InitialSetupView / PostTimelineView / ComposeView / SecretMessageView
└── DriftSonarCore/            ← Swift Package（コアロジック）
    └── Sources/DriftSonarCore/
        ├── EncounterDomain/   ← BLEEncounterService（Core Bluetooth実装）
        ├── PostDomain/        ← 投稿ドメイン
        ├── MeshDomain/        ← Store-and-Forward メッシュ
        ├── BlockDomain/       ← ブロックリスト
        ├── ProfileDomain/     ← ユーザープロファイル・鍵管理
        └── SecretMessageDomain/ ← Curve25519 + AES-GCM暗号化
```

## 実装状態

主要機能はすべて実装済み（BLE・メッシュ・E2E暗号・SwiftData・UI・SwiftLint）。
未対応はP3機能のみ（アプリアイコン・テストカバレッジ・匿名投稿・PoW等）→ GitHub Issues 参照。

> **Issue 管理は GitHub Issues が正**（旧 `ISSUES.md` は 2026-05-31 に全 217 件を GitHub へ移行し削除）。
> Issue タイトルに旧 ID（`[EP-XXX]` / `[TASK-XXX]`）を保持。EPIC=親 Issue（`epic` ラベル + タスクチェックリスト）、TASK=子 Issue（本文に親EPIC #参照）。
> 一覧: `gh issue list -R omaru12345/DriftSonar`

## ビルド

```bash
xcodebuild \
  -project DriftSonarApp/DriftSonarApp/DriftSonarApp.xcodeproj \
  -scheme DriftSonarApp \
  -destination 'generic/platform=iOS Simulator' \
  -skipPackagePluginValidation \
  build
```

> `-skipPackagePluginValidation` は SwiftLint ビルドプラグインの承認をスキップするために必要。

## Mermaid図（Code GraphContext）

- 作業開始前に `.claude/diagrams/architecture.md` を参照してプロジェクト構造を把握する
- 新機能追加・ドメイン構造変更時は図を更新
- 図の生成・更新は `skill-graph` スキルの `mermaid` ノードを参照

## 詳細ドキュメント

- BLE UUID・Xcodeプロジェクト構造・秘密鍵・SwiftData注意点 → `docs/design-notes.md`
- Issue管理 → GitHub Issues（`gh issue list -R omaru12345/DriftSonar`）

## CLAUDE.md・スキル最適化ルール（トークン節約）

- **CLAUDE.md には常時必要な情報のみ記載する**。詳細・参照情報は `docs/` サブフォルダに分離し、必要時のみ読み込む（Progressive Disclosure）
- **SKILL.md も同様**：スキル発火時に必要な手順のみ本文に、詳細は同フォルダ内の別ファイルへ（`[[wikilink]]` で参照）
- 新しい情報を CLAUDE.md / SKILL.md に追加する前に「毎回のセッションで本当に必要か」を確認する
- 参考: `~/.claude/notes/progressive-disclosure.md`

## 引き継ぎ書

- このプロジェクトの文脈・構成・現在地・次の一手は [docs/handoff.md](docs/handoff.md) に集約（Fable5 作成）。
