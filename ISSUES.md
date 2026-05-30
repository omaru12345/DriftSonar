# DriftSonar — Issue Backlog

## ラベル定義

### エリア (Area)
| ラベル | 説明 |
|--------|------|
| `ios` | iOS アプリ層 (SwiftUI, ViewModel, Info.plist) |
| `ble` | Bluetooth LE / Core Bluetooth |
| `crypto` | 暗号・署名 (Curve25519, AES-GCM) |
| `swiftdata` | SwiftData 永続化 |
| `ui` | UI/UX |
| `networking` | メッシュ伝播・プロトコル設計 |
| `security` | セキュリティ・プライバシー |
| `devops` | CI/CD・ビルド・ツール |
| `test` | テスト |

### タイプ (Type)
| ラベル | 説明 |
|--------|------|
| `feat` | 新機能 |
| `bug` | バグ修正 |
| `chore` | 設定・整理 |
| `refactor` | リファクタリング |
| `docs` | ドキュメント |

### 優先度 (Priority)
| ラベル | 意味 |
|--------|------|
| `P0` | Critical — これがないとアプリとして動かない |
| `P1` | High — MVP に必須 |
| `P2` | Medium — 品質・UX 向上 |
| `P3` | Low — Nice to have |

---

## EPIC 一覧

| ID | タイトル | 優先度 | 状態 |
|----|----------|--------|------|
| [EP-001](#ep-001-ble-コアセットアップ) | BLE コアセットアップ | P0 | ✅ 完了 |
| [EP-002](#ep-002-post-ドメイン) | Post ドメイン | P0 | ✅ 完了 |
| [EP-003](#ep-003-store-and-forward-メッシュ伝播) | Store-and-Forward メッシュ伝播 | P0 | 🔄 進行中（P0/P1完了、P2残り）|
| [EP-004](#ep-004-タイムライン-ui) | タイムライン UI | P1 | ✅ 完了 |
| [EP-005](#ep-005-セキュリティ--署名) | セキュリティ・署名 | P1 | 🔄 進行中（P1完了、P2一部完了）|
| [EP-006](#ep-006-スパム--フラッディング対策) | スパム・フラッディング対策 | P1 | 🔄 進行中（P1/P2完了、P3残り）|
| [EP-007](#ep-007-アイデンティティ管理) | アイデンティティ管理 | P2 | 🔄 進行中（P2完了、P3設計済み）|
| [EP-008](#ep-008-開発インフラ--ci) | 開発インフラ・CI | P2 | 🔄 進行中（主要タスク完了）|
| [EP-009](#ep-009-ブランディング--ux) | ブランディング・UX | P3 | 🔄 進行中（主要タスク完了）|
| [EP-010](#ep-010-既知バグ修正) | 既知バグ修正 | P0 | ✅ 完了 |
| [EP-011](#ep-011-secretmessage-送受信完成) | SecretMessage 送受信完成 | P1 | ✅ 完了 |
| [EP-012](#ep-012-store-and-forward-ui統合bleドメイン層接続) | Store-and-Forward UI統合（BLE↔ドメイン層接続） | P1 | ✅ 完了 |
| [EP-013](#ep-013-シミュレーター向けデバッグ機能開発と実機テスト) | シミュレーター向けデバッグ機能開発と実機テスト | P2 | ⬜ 未着手 |
| [EP-014](#ep-014-ニックネームシステム) | ニックネームシステム | P1 | ✅ 完了 |
| [EP-015](#ep-015-通知システム) | 通知システム | P2 | 🔄 進行中（P2完了、P3残り）|
| [EP-016](#ep-016-timeline-ux-改善) | Timeline UX 改善 | P2 | ✅ 完了 |
| [EP-017](#ep-017-ble-信頼性向上) | BLE 信頼性向上 | P2 | ✅ 完了 |
| [EP-018](#ep-018-品質安定性) | 品質・安定性 | P2 | ✅ 完了 |
| [EP-019](#ep-019-app-store-準備) | App Store 準備 | P3 | ⬜ 未着手 |
| [EP-020](#ep-020-匿名投稿実装) | 匿名投稿実装 | P3 | ✅ 完了 |
| [EP-021](#ep-021-ビジュアルアイデンティティ--マスコット) | ビジュアルアイデンティティ・マスコット | P3 | ✅ 完了 |
| [EP-022](#ep-022-収益化モデル構築) | 収益化モデル構築 | P3 | ⬜ 未着手 |
| [EP-023](#ep-023-コールドスタート体験の改善) | コールドスタート体験の改善 | P2 | ⬜ 未着手 |
| [EP-024](#ep-024-secretmessage-前方秘匿性forward-secrecy) | SecretMessage 前方秘匿性（Forward Secrecy） | P2 | ⬜ 未着手 |
| [EP-025](#ep-025-相手の鍵検証safety-number) | 相手の鍵検証（Safety Number） | P2 | ⬜ 未着手 |
| [EP-026](#ep-026-公開タイムライン体験の拡張) | 公開タイムライン体験の拡張 | P3 | ⬜ 未着手 |
| [EP-027](#ep-027-uxui-磨き込み) | UX/UI 磨き込み | P2 | 🔄 進行中 |
| [EP-028](#ep-028-バッテリー省電力と診断) | バッテリー・省電力と診断 | P2 | ⬜ 未着手 |
| [EP-029](#ep-029-データライフサイクルとプライバシー実務) | データライフサイクルとプライバシー実務 | P2 | ⬜ 未着手 |
| [EP-030](#ep-030-堅牢性とエラーハンドリング) | 堅牢性とエラーハンドリング | P2 | ✅ 完了 |
| [EP-031](#ep-031-国際化と配信戦略) | 国際化と配信戦略 | P3 | ⬜ 未着手 |
| [EP-032](#ep-032-テスト拡充app層uiスナップショット) | テスト拡充（App層・UI・スナップショット） | P2 | ⬜ 未着手 |
| [EP-033](#ep-033-メッシュプロトコルのバージョニングと将来互換) | メッシュプロトコルのバージョニングと将来互換 | P2 | ⬜ 未着手 |
| [EP-034](#ep-034-app-store-対策審査リスク低減) | App Store 対策（審査リスク低減） | P2 | ⬜ 未着手 |
| [EP-035](#ep-035-メッシュセキュリティ堅牢化脅威モデル) | メッシュ・セキュリティ堅牢化（脅威モデル） | P2 | ⬜ 未着手 |
| [EP-036](#ep-036-メッシュ伝播シミュレーションと負荷テスト) | メッシュ伝播シミュレーションと負荷テスト | P2 | ⬜ 未着手 |

---

## EP-001: BLE コアセットアップ

**概要**: MultipeerConnectivity から Core Bluetooth へ完全移行し、BLE が動作する最小構成を完成させる。

**Priority**: `P0` | **Labels**: `ios` `ble` `chore`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-001](#task-001) | EncounterViewModel を BLEEncounterService に切り替え | `ios` `ble` `refactor` | P0 | ✅ |
| [TASK-002](#task-002) | Info.plist に NSBluetoothAlwaysUsageDescription 追加 | `ios` `chore` | P0 | ✅ |
| [TASK-003](#task-003) | Xcode Background Modes に bluetooth-central / bluetooth-peripheral 追加 | `ios` `chore` | P0 | ✅ |
| [TASK-004](#task-004) | BLEEncounterService に接続済みピアへのメッセージ送信 Characteristic 追加 | `ble` `feat` | P1 | ✅ |
| [TASK-005](#task-005) | BLE 接続時にキャッシュメッセージをピアへ転送するロジック | `ble` `networking` `feat` | P1 | ✅ |
| [TASK-006](#task-006) | メッセージID による重複転送排除 | `ble` `networking` `feat` | P1 | ✅ |
| [TASK-051](#task-051) | EncounterService プロトコルに stop() を追加 | `ble` `feat` | P1 | ✅ |
| [TASK-052](#task-052) | BLE マネージャーを専用 DispatchQueue で動かす | `ble` `chore` | P2 | ✅ |
| [TASK-053](#task-053) | peripheral.identifier ローテーション対策（公開鍵ハッシュで重複排除） | `ble` `security` `feat` | P2 | ✅ |

---

### TASK-001
**EncounterViewModel を BLEEncounterService に切り替え**

`ios` `ble` `refactor` `P0`

`EncounterViewModel.swift` の `MCPeerEncounterService` を `BLEEncounterService` に1行差し替え。
`EncounterService` プロトコルに両者が準拠しているためワンライン変更。

- [x] `EncounterViewModel.swift` の import / インスタンス化を `BLEEncounterService` に変更
- [ ] ビルド確認

**影響ファイル**: `DriftSonarApp/ViewModels/EncounterViewModel.swift`

---

### TASK-002
**Info.plist に NSBluetoothAlwaysUsageDescription 追加**

`ios` `chore` `P0`

BLE を使用するために iOS から要求される Usage Description を Info.plist に追加。

- [x] `NSBluetoothAlwaysUsageDescription` キーと説明文を追加

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Info.plist`

---

### TASK-003
**Xcode Background Modes に bluetooth-central / bluetooth-peripheral 追加**

`ios` `chore` `P0`

バックグラウンドでの BLE スキャン・アドバタイズを継続するためのケーパビリティ設定。

- [x] Xcode Signing & Capabilities → Background Modes → `bluetooth-central` をオン
- [x] Xcode Signing & Capabilities → Background Modes → `bluetooth-peripheral` をオン

---

### TASK-004
**BLEEncounterService に送信 Characteristic を追加**

`ble` `feat` `P1`

現在は公開鍵の「読み取り」のみ。メッセージを送るための Write Characteristic が必要。

- [ ] `DriftSonarBLE` に `messageCharacteristicUUID` を定義
- [ ] `CBPeripheralManager` に Write プロパティの Characteristic を追加
- [ ] 受信コールバック `peripheralManager(_:didReceiveWrite:)` を実装

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`

---

### TASK-005
**BLE 接続時にキャッシュメッセージをピアへ転送**

`ble` `networking` `feat` `P1`

Store-and-Forward の BLE レイヤー実装。接続確立時にローカルキャッシュを相手に push する。

- [ ] 接続完了コールバックでキャッシュ取得 → Characteristic Write を順次実行
- [ ] 転送完了後に切断

**依存**: TASK-004, EP-003

---

### TASK-006
**メッセージID による重複転送排除**

`ble` `networking` `feat` `P1`

同じメッセージを無限ループで転送しないための既知 ID セット管理。

- [ ] `seenMessageIDs: Set<UUID>` をサービス内に保持
- [ ] 受信時に既知なら棄却、未知なら処理 + セットに追加
- [ ] セットのサイズ上限設定（例：10,000件）

---

## EP-002: Post ドメイン

**概要**: SNS の核となる「投稿」の設計・実装。

**Priority**: `P0` | **Labels**: `feat` `swiftdata` `crypto`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-007](#task-007) | Post モデル定義 | `feat` | P0 | ✅ |
| [TASK-008](#task-008) | PostRepository プロトコル定義 | `feat` | P0 | ✅ |
| [TASK-009](#task-009) | SwiftData PostRepository 実装 | `swiftdata` `feat` | P0 | ✅ |
| [TASK-010](#task-010) | Post 投稿 UseCase 実装 | `feat` | P1 | ✅ |
| [TASK-011](#task-011) | Post BLE シリアライズ/デシリアライズ | `networking` `feat` | P1 | ✅ |
| [TASK-012](#task-012) | ローカルタイムライン取得 UseCase | `swiftdata` `feat` | P1 | ✅ |

---

### TASK-007
**Post モデル定義**

`feat` `P0`

メッシュ伝播に必要な全フィールドを持つ不変値型として定義。

- [ ] `Post` struct を `PostDomain/` に作成
  - `id: UUID`
  - `content: String`
  - `authorPublicKey: Data` (32 byte Curve25519)
  - `timestamp: Date`
  - `signature: Data` (64 byte Ed25519、後で追加)
  - `ttl: Int` (残り転送可能ホップ数)
  - `hopCount: Int` (経由ノード数)
- [ ] `PostDomain/` ディレクトリを `DriftSonarCore/Sources/DriftSonarCore/` に作成

---

### TASK-008
**PostRepository プロトコル定義**

`feat` `P0`

- [ ] `PostRepository` プロトコルを定義
  - `save(_ post: Post) throws`
  - `fetchTimeline(limit: Int) throws -> [Post]`
  - `exists(id: UUID) throws -> Bool`
  - `delete(id: UUID) throws`

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/PostDomain/PostRepository.swift`（新規）

---

### TASK-009
**SwiftData PostRepository 実装**

`swiftdata` `feat` `P0`

- [ ] `@Model class PostModel` を SwiftData で定義
- [ ] `SwiftDataPostRepository: PostRepository` を実装
- [ ] `PostModel` ↔ `Post` の変換ロジック

**依存**: TASK-007, TASK-008

---

### TASK-010
**Post 投稿 UseCase 実装**

`feat` `P1`

- [ ] `CreatePostUseCase` を実装
  - 入力: content, 自分の秘密鍵
  - 処理: Post 生成 → 署名（EP-005 後）→ Repository.save
- [ ] `CreatePostRequest` DTO を定義

**依存**: TASK-007, TASK-008, TASK-009

---

### TASK-011
**Post BLE シリアライズ/デシリアライズ**

`networking` `feat` `P1`

BLE Characteristic の MTU (デフォルト 20byte、最大 512byte) を考慮したバイト列変換。

- [ ] `Post` → `Data` エンコーダ（MessagePack または独自バイナリ形式）
- [ ] `Data` → `Post` デコーダ（バリデーション付き）
- [ ] MTU 超過時の分割送信設計

**依存**: TASK-007

---

### TASK-012
**ローカルタイムライン取得 UseCase**

`swiftdata` `feat` `P1`

- [ ] `FetchTimelineUseCase` を実装（最新N件、日時降順）
- [ ] ページネーション対応

**依存**: TASK-008, TASK-009

---

## EP-003: Store-and-Forward メッシュ伝播

**概要**: オフライン中継。デバイスが一時的に保存し次のピアに届ける仕組み。

**Priority**: `P0` | **Labels**: `networking` `swiftdata` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-013](#task-013) | MessageCache モデルと SwiftData 実装 | `swiftdata` `feat` | P0 | ✅ |
| [TASK-014](#task-014) | TTL デクリメントと期限切れキャッシュ削除 | `networking` `feat` | P1 | ✅ |
| [TASK-015](#task-015) | ピア接続時のキャッシュ同期プロトコル | `ble` `networking` `feat` | P1 | ✅ |
| [TASK-016](#task-016) | 転送優先度ロジック | `networking` `feat` | P2 | ✅ |
| [TASK-017](#task-017) | キャッシュサイズ上限とエビクションポリシー | `swiftdata` `chore` | P2 | ✅ |

---

### TASK-013
**MessageCache モデルと SwiftData 実装**

`swiftdata` `feat` `P0`

受信メッセージをローカルに保持するキャッシュ層。

- [ ] `CachedMessage` モデル（postId, data, receivedAt, ttl, forwardedCount）
- [ ] `@Model class CachedMessageModel` を定義
- [ ] `MessageCacheRepository` プロトコルと SwiftData 実装

---

### TASK-014
**TTL デクリメントと期限切れキャッシュ削除**

`networking` `feat` `P1`

- [ ] 転送時に TTL を -1 する処理
- [ ] TTL = 0 のメッセージを転送しない
- [ ] 定期バックグラウンドタスクで期限切れを削除（例：24時間後）

**依存**: TASK-013

---

### TASK-015
**ピア接続時のキャッシュ同期プロトコル**

`ble` `networking` `feat` `P1`

- [ ] 接続時に相手が持っていない Post を特定するネゴシエーション手順の設計
- [ ] 既知 ID リストの交換プロトコル（コンパクト表現: Bloom Filter 検討）
- [ ] 同期完了後の切断シーケンス

**依存**: TASK-004, TASK-013

---

### TASK-016
**転送優先度ロジック**

`networking` `feat` `P2`

- [x] 新しいもの優先（timestamp desc）か拡散度が低いもの優先（hopCount asc）を選択 → `ForwardPriority` enum で設定可能
- [x] バンド幅制限内での送信件数上限設定 → `forwardBatchSize` で制御

---

### TASK-017
**キャッシュサイズ上限とエビクションポリシー**

`swiftdata` `chore` `P2`

- [ ] キャッシュ上限（例：100 件 or 10MB）を定義
- [ ] 上限超過時は古い/拡散済みのメッセージを優先削除

---

## EP-004: タイムライン UI

**概要**: SNS のメイン画面となるタイムライン表示・投稿機能の実装。

**Priority**: `P1` | **Labels**: `ui` `ios` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-018](#task-018) | TimelineView の基本実装 | `ui` `ios` `feat` | P1 | ✅ |
| [TASK-019](#task-019) | TimelineViewModel 実装 | `ios` `feat` | P1 | ✅ |
| [TASK-020](#task-020) | 投稿作成画面 (ComposeView) | `ui` `ios` `feat` | P1 | ✅ |
| [TASK-021](#task-021) | ContentView にタイムラインを組み込む | `ui` `ios` `refactor` | P1 | ✅ |
| [TASK-022](#task-022) | ホップ数・伝播距離の表示 | `ui` `ios` `feat` | P2 | ✅ |
| [TASK-023](#task-023) | Pull-to-refresh で BLE スキャントリガー | `ui` `ios` `ble` `feat` | P2 | ✅ |
| [TASK-024](#task-024) | 空状態 UI（近くにユーザーがいない） | `ui` `ios` `feat` | P2 | ✅ |

---

### TASK-018
**TimelineView の基本実装**

`ui` `ios` `feat` `P1`

- [ ] `List` / `LazyVStack` で投稿一覧を表示
- [ ] `PostRowView` コンポーネント（content, authorKey短縮表示, timestamp, hopCount）
- [ ] Skeleton ローディング状態

**依存**: EP-002

---

### TASK-019
**TimelineViewModel 実装**

`ios` `feat` `P1`

- [ ] `@Observable TimelineViewModel` を実装
- [ ] `FetchTimelineUseCase` を呼び出し `[Post]` を保持
- [ ] BLE 発見イベントで自動リフレッシュ

**依存**: TASK-012, TASK-018

---

### TASK-020
**投稿作成画面 (ComposeView)**

`ui` `ios` `feat` `P1`

- [ ] テキスト入力 + 投稿ボタン
- [ ] 文字数カウント・上限制限（例：280文字）
- [ ] 投稿後にタイムラインへ戻る

**依存**: TASK-010

---

### TASK-021
**ContentView にタイムラインを組み込む**

`ui` `ios` `refactor` `P1`

- [ ] 現在の 3 タブ（Encounter, SecretMessage）に Timeline タブを追加
- [ ] 未使用の `Item.swift` を削除

---

### TASK-022
**ホップ数・伝播距離の表示**

`ui` `ios` `feat` `P2`

- [x] `hopCount` を「N人経由」と表示
- [x] ホップ数に応じた色グラデーション（直接=青、2以下=緑、3-5=橙、6+=赤）

---

### TASK-023
**Pull-to-refresh で BLE スキャントリガー**

`ui` `ios` `ble` `feat` `P2`

- [x] `.refreshable` モディファイアで `viewModel.refresh()` を呼び出す（ローカル DB から最新取得）

---

### TASK-024
**空状態 UI**

`ui` `ios` `feat` `P2`

- [x] ピアが 0 件のときの空状態イラスト + メッセージ（`EmptyTimelineView` 実装済み）
- [x] 友人招待 QR コードへのリンク（プロフィールタブに QR 表示機能を追加）

---

## EP-005: セキュリティ・署名

**概要**: 投稿のなりすまし・改ざん防止のための署名システム。

**Priority**: `P1` | **Labels**: `crypto` `security` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-025](#task-025) | Ed25519 署名生成の実装 | `crypto` `feat` | P1 | ✅ |
| [TASK-026](#task-026) | 受信 Post の署名検証 | `crypto` `security` `feat` | P1 | ✅ |
| [TASK-027](#task-027) | 署名失敗 Post の棄却処理 | `security` `feat` | P1 | ✅ |
| [TASK-028](#task-028) | BLE アドバタイズ情報の最小化 | `ble` `security` `feat` | P2 | ✅ |
| [TASK-029](#task-029) | ローカルデータの暗号化保存 | `security` `swiftdata` `feat` | P2 | ✅ |
| [TASK-030](#task-030) | 投稿の匿名オプション設計 | `security` `feat` | P3 | ✅ |
| [TASK-054](#task-054) | HKDF の salt を空 Data() からプロトコル固有定数に変更 | `crypto` `security` `bug` | P1 | ✅ |

---

### TASK-025
**Ed25519 署名生成の実装**

`crypto` `feat` `P1`

現在は Curve25519 を鍵共有のみに使用。署名には Ed25519 が適切。

- [ ] `CryptoKit.Curve25519.Signing` を使った署名生成を `SecretMessageService` または新 `SigningService` に追加
- [ ] Post 生成時に `signature` フィールドを設定

**注意**: Curve25519 の鍵ペアは X25519（鍵共有）と Ed25519（署名）で異なる。鍵ペア設計を見直す。

---

### TASK-026
**受信 Post の署名検証**

`crypto` `security` `feat` `P1`

- [ ] `authorPublicKey` + `signature` で署名検証
- [ ] 検証ロジックを `PostVerificationService` として実装

**依存**: TASK-025

---

### TASK-027
**署名失敗 Post の棄却処理**

`security` `feat` `P1`

- [ ] 署名検証失敗時に受信・保存・転送をすべてスキップ
- [ ] ログに記録（デバッグ用）

**依存**: TASK-026

---

### TASK-028
**BLE アドバタイズ情報の最小化**

`ble` `security` `feat` `P2`

- [x] アドバタイズから `CBAdvertisementDataLocalNameKey: "DriftSonar"` を除去（サービス UUID のみ残す）
- [x] サービス UUID がトラッキングに使われるリスクを評価：固定 UUID は避けられないが Local Name 削除で最小化

---

### TASK-029
**ローカルデータの暗号化保存**

`security` `swiftdata` `feat` `P2`

- [x] SwiftData ストアを暗号化（`FileManager.setAttributes([.protectionKey: .complete])` を ModelContainer 生成後に適用）
- [x] 秘密鍵を Keychain に移行（TASK-035 完了済み）

---

### TASK-030
**投稿の匿名オプション設計**

`security` `feat` `P3`

- [x] 1回限り鍵ペアを生成して匿名投稿する仕組みの設計（`AnonymousPostDesign.swift` に設計書を記述）
- [x] ユーザーの通常プロファイルと分離（ephemeral key は非永続化）

---

## EP-006: スパム・フラッディング対策

**概要**: 悪意あるノードによる大量メッセージ攻撃への対策。

**Priority**: `P1` | **Labels**: `security` `networking`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-031](#task-031) | TTL グローバル上限設定 | `networking` `feat` | P1 | ✅ |
| [TASK-032](#task-032) | 送信者レートリミット | `security` `networking` `feat` | P2 | ✅ |
| [TASK-033](#task-033) | ローカルブロックリスト（公開鍵ミュート） | `security` `swiftdata` `feat` | P2 | ✅ |
| [TASK-034](#task-034) | Proof-of-Work 軽量実装の検討 | `security` `feat` | P3 | ✅ |

---

### TASK-031
**TTL グローバル上限設定**

`networking` `feat` `P1`

- [ ] `DriftSonarConstants.maxTTL = 7` など定数を定義
- [ ] 受信時に TTL > maxTTL なら棄却

---

### TASK-032
**送信者レートリミット**

`security` `networking` `feat` `P2`

- [ ] 同一 `authorPublicKey` から 1 分以内に N 件超の受信で棄却
- [ ] `[Data: [Date]]` で送信者ごとの受信履歴を管理

---

### TASK-033
**ローカルブロックリスト**

`security` `swiftdata` `feat` `P2`

- [x] `BlockedKey` モデルを SwiftData で実装（`BlockDomain/BlockedKeyModel.swift`）
- [x] ブロックした公開鍵からの受信・表示をスキップ（TimelineView で `@Query` + フィルタ）
- [x] UI: EncounterView のピア行を長押し → コンテキストメニューでブロック

---

### TASK-034
**Proof-of-Work 軽量実装の検討**

`security` `feat` `P3`

- [x] Hashcash 方式の PoW コスト設計（モバイルバッテリーへの影響評価）→ `ProofOfWorkDesign.swift` に記述
- [x] 実装 or 見送りの意思決定 → difficulty 18 推奨、MVP では任意。設計書に詳細記述。

---

## EP-007: アイデンティティ管理

**概要**: 鍵のセキュア保存・ローテーション・複数デバイス対応。

**Priority**: `P2` | **Labels**: `security` `ios` `crypto`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-035](#task-035) | 秘密鍵を Keychain に移行 | `security` `ios` `feat` | P2 | ✅ |
| [TASK-036](#task-036) | Secure Enclave での秘密鍵保護 | `security` `ios` `feat` | P2 | ✅ |
| [TASK-055](#task-055) | UserProfile ドメインモデルから privateKey を除去してリポジトリ層のみに閉じる | `security` `refactor` | P2 | ✅ |
| [TASK-037](#task-037) | 公開鍵フィンガープリント表示 | `ui` `crypto` `feat` | P2 | ✅ |
| [TASK-038](#task-038) | 鍵ローテーション設計 | `crypto` `security` `feat` | P3 | ✅ |
| [TASK-039](#task-039) | 複数デバイス対応の設計方針策定 | `security` `docs` | P3 | ✅ |

---

### TASK-035
**秘密鍵を Keychain に移行**

`security` `ios` `feat` `P2`

- [ ] `SwiftDataUserRepository` から秘密鍵を Keychain (`kSecClassKey`) に移行
- [ ] 既存ユーザーのマイグレーション処理

---

### TASK-036
**Secure Enclave での秘密鍵保護**

`security` `ios` `feat` `P2`

- [x] `SecureEnclave.P256.Signing.PrivateKey` の利用可否確認 → Curve25519 は SE 非対応と確認
- [x] SE 対応鍵への切り替え → `CreateProfileUseCase.swift` にコメントで評価結果を記述（Keychain で継続）

---

### TASK-037
**公開鍵フィンガープリント表示**

`ui` `crypto` `feat` `P2`

- [ ] 公開鍵 32byte の SHA-256 先頭 8byte を hex 表示
- [ ] プロフィール画面・Encounter 一覧に表示

---

### TASK-038
**鍵ローテーション設計**

`crypto` `security` `feat` `P3`

- [x] 旧鍵から新鍵への移行アナウンスメッセージの形式設計（`KeyRotationDesign.swift` に記述）
- [x] 旧鍵で署名された投稿の扱いルール（同設計書に記述）

---

### TASK-039
**複数デバイス対応の設計方針策定**

`security` `docs` `P3`

- [x] 同一ユーザーの複数デバイスで同じ公開鍵を使う方法の設計（`MultiDeviceDesign.swift` に記述）
- [x] iCloud Keychain 経由の秘密鍵同期の可否確認（同設計書に記述。`kSecAttrSynchronizable` で可能）

---

## EP-008: 開発インフラ・CI

**概要**: 継続的インテグレーション・ビルド品質の向上。

**Priority**: `P2` | **Labels**: `devops` `test` `chore`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-040](#task-040) | DriftSonarApp.xcodeproj の DriftSonarCore 依存確認 | `ios` `chore` | P2 | ✅ |
| [TASK-041](#task-041) | Item.swift (未使用) 削除 | `ios` `chore` | P2 | ✅ |
| [TASK-042](#task-042) | GitHub Actions でユニットテスト自動実行 | `devops` `test` `chore` | P2 | ✅ |
| [TASK-043](#task-043) | SwiftLint 導入 | `devops` `chore` | P2 | ✅ |
| [TASK-044](#task-044) | テストカバレッジレポート設定 | `devops` `test` `chore` | P3 | ✅ |
| [TASK-045](#task-045) | BLEEncounterService のユニットテスト追加 | `test` `ble` | P2 | ✅ |

---

### TASK-040
**DriftSonarApp の DriftSonarCore 依存確認・修正**

`ios` `chore` `P2`

- [x] Xcode で `DriftSonarApp.xcodeproj` を開き DriftSonarCore のローカルパッケージ参照を確認
- [x] ビルドエラーがあれば修正

---

### TASK-041
**Item.swift 削除**

`ios` `chore` `P2`

- [x] `DriftSonarApp/Item.swift` のコードを削除（ファイルを空化。Xcode 上での削除は手動で実施すること）

---

### TASK-042
**GitHub Actions でユニットテスト自動実行**

`devops` `test` `chore` `P2`

- [ ] `.github/workflows/test.yml` を作成
- [ ] `xcodebuild test` で `DriftSonarCore` のテストを実行
- [ ] PR ごとに実行するトリガー設定

---

### TASK-043
**SwiftLint 導入**

`devops` `chore` `P2`

- [x] SwiftLint を `Package.swift` のプラグインとして追加（`SwiftLintBuildToolPlugin`）
- [x] `.swiftlint.yml` の初期設定（`DriftSonarCore/.swiftlint.yml` 作成）

---

### TASK-044
**テストカバレッジレポート設定**

`devops` `test` `chore` `P3`

- [x] Xcode Coverage を有効化（`--enable-code-coverage`）
- [x] GitHub Actions でカバレッジを Codecov 等にアップロード

---

### TASK-045
**BLEEncounterService のユニットテスト追加**

`test` `ble` `P2`

- [x] `BLEEncounterServiceTests.swift` を作成
- [x] `MockEncounterService` を使ったプロトコル準拠テスト + 公開 API テスト（CB ハードウェア不要な範囲）

---

## EP-009: ブランディング・UX

**概要**: アプリのビジュアルアイデンティティとユーザー獲得。

**Priority**: `P3` | **Labels**: `ui` `ios`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-046](#task-046) | アプリアイコンデザイン | `ui` `ios` | P3 | ✅ (TASK-113で統合) |
| [TASK-047](#task-047) | AccentColor 設定 | `ui` `ios` `chore` | P3 | ✅ |
| [TASK-048](#task-048) | ダークモード対応確認 | `ui` `ios` `chore` | P3 | ✅ |
| [TASK-049](#task-049) | 友人招待 QR コード機能 | `ui` `ios` `feat` | P3 | ✅ |
| [TASK-050](#task-050) | 伝播経路の波紋アニメーション | `ui` `ios` `feat` | P3 | ✅ |
| [TASK-071](#task-071) | InitialSetupView のタイトルを「Whisper」→「DriftSonar」に修正 | `ui` `bug` | P2 | ✅ |

---

### TASK-071
**InitialSetupView のタイトルを「Whisper」→「DriftSonar」に修正**

`ui` `bug` `P2`

`InitialSetupView.swift:37` の `navigationTitle("Welcome to Whisper")` が旧アプリ名のまま残っている。
初回起動時に表示されるウェルカム画面に誤ったブランド名が出てしまう。

- [ ] `"Welcome to Whisper"` を `"Welcome to DriftSonar"` に変更

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/InitialSetupView.swift`

---

## EP-010: 既知バグ修正

**概要**: コードレビューで発見したバグ・コンパイルエラー・残存ブランド名の修正。

**Priority**: `P0` | **Labels**: `bug` `ios` `ui`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-056](#task-056) | SecretMessageViewModel — `encrypt(message:)` → `encrypt(plainText:)` コンパイルエラー修正 | `bug` `ios` `crypto` | P0 | ✅ |
| [TASK-057](#task-057) | ContentView — InitialSetupViewModel を `@State` に修正 | `bug` `ios` | P1 | ✅ |
| [TASK-058](#task-058) | EncounterView — "Whisper users" → "DriftSonar users" 文言修正 | `bug` `ui` | P1 | ✅ |
| [TASK-059](#task-059) | EncounterView — onAppear 毎に setupService が呼ばれる二重初期化を防止 | `bug` `ios` `ble` | P1 | ✅ |
| [TASK-060](#task-060) | EncounterViewModel — BLE 移行後に不要な `myNickname` パラメータを削除 | `refactor` `ios` | P2 | ✅ |

---

### TASK-056
**SecretMessageViewModel — encrypt 引数ラベルのコンパイルエラー修正**

`bug` `ios` `crypto` `P0`

`SecretMessageViewModel.swift:36` で `secretService.encrypt(message: draftMessage, ...)` と呼んでいるが、
`SecretMessageService.encrypt` の第1引数ラベルは `plainText:` のためコンパイルエラーになる。

- [ ] `message:` → `plainText:` に修正
- [ ] ビルド確認

**影響ファイル**: `DriftSonarApp/ViewModels/SecretMessageViewModel.swift:36`

---

### TASK-057
**ContentView — InitialSetupViewModel を `@State` に修正**

`bug` `ios` `P1`

`ContentView.swift:50` の `let viewModel = InitialSetupViewModel()` は `@State` を使っていないため、
SwiftUI が body を再計算するたびに新しい ViewModel インスタンスが生成される。

- [ ] `@State private var setupViewModel = InitialSetupViewModel()` に変更
- [ ] `InitialSetupView(viewModel: setupViewModel)` に合わせて参照先を修正

**影響ファイル**: `DriftSonarApp/ContentView.swift:50`

---

### TASK-058
**EncounterView — 旧ブランド名 "Whisper" の文言修正**

`bug` `ui` `P1`

`EncounterView.swift:28` に `"Searching for Whisper users..."` という旧アプリ名が残存している。

- [ ] `"Searching for DriftSonar users nearby..."` または同等の文言に修正

**影響ファイル**: `DriftSonarApp/Views/EncounterView.swift:28`

---

### TASK-059
**EncounterView — onAppear での setupService 二重初期化を防止**

`bug` `ios` `ble` `P1`

`EncounterView.swift:85` の `.onAppear` で毎回 `setupService` が呼ばれる。
画面を離れて戻るたびに新しい `BLEEncounterService` インスタンスが生成され、
旧 BLE マネージャーが解放されないまま複数動作する可能性がある。

- [ ] ViewModel に `isSetup: Bool` フラグを持ち、初回のみ実行するガード追加
  ```swift
  guard !isSetup else { return }
  isSetup = true
  setupService(...)
  ```
- [ ] または `.task` モディファイアに切り替えて重複実行を防ぐ

**影響ファイル**: `DriftSonarApp/Views/EncounterView.swift:85`、`DriftSonarApp/ViewModels/EncounterViewModel.swift`

---

### TASK-060
**EncounterViewModel — BLE 移行後の不要パラメータ削除**

`refactor` `ios` `P2`

BLE 移行（TASK-001）完了後、`setupService(myNickname:myPublicKey:)` の `myNickname` は
`MCPeerID` 用に使われていたが BLE では不要になる。

- [ ] `myNickname` パラメータを削除し `setupService(myPublicKey:)` に整理
- [ ] `EncounterView` の呼び出し箇所を更新

**依存**: TASK-001

---

## EP-011: SecretMessage 送受信完成

**概要**: 現在は暗号化した結果を `let _ =` で捨てており送受信が一切機能していない。実際に BLE でメッセージを届けるフローを完成させる。

**Priority**: `P1` | **Labels**: `feat` `ble` `swiftdata` `crypto` `ui`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-061](#task-061) | EncounterHistoryRepository の SwiftData 実装 | `swiftdata` `feat` | P1 | ✅ |
| [TASK-062](#task-062) | 暗号化メッセージ（EncryptedMessage）の SwiftData 永続化 | `swiftdata` `feat` | P1 | ✅ |
| [TASK-063](#task-063) | 送信メッセージを BLE 配信キューに積む | `ble` `networking` `feat` | P1 | ✅ |
| [TASK-064](#task-064) | BLE 経由の受信メッセージを復号して表示 | `ble` `crypto` `ui` `feat` | P1 | ✅ |
| [TASK-065](#task-065) | SecretMessageView のタイトルを peerId → ニックネームに改善 | `ui` `feat` | P2 | ✅ |

---

### TASK-061
**EncounterHistoryRepository の SwiftData 実装**

`swiftdata` `feat` `P1`

`Repositories.swift` に `EncounterHistoryRepository` プロトコルが定義されているが実装がない。
Encounter 履歴の永続化が未実現のため次回起動時に消える。

- [ ] `SwiftDataEncounterHistoryRepository: EncounterHistoryRepository` を実装
- [ ] `@Model class EncounteredEventModel` を定義（peerId, peerPublicKey, encounteredAt）
- [ ] `DriftSonarAppApp.swift` の ModelContainer に追加

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/ProfileDomain/` (新規ファイル追加)

---

### TASK-062
**暗号化メッセージの SwiftData 永続化**

`swiftdata` `feat` `P1`

`SecretMessageViewModel.sendMessage()` は暗号化後に `let _ = try secretService.encrypt(...)` で結果を捨てている。
暗号文を保存するモデルとリポジトリが必要。

- [ ] `@Model class SecretMessageModel` を定義（id, encryptedData, otherPeerId, isMine, timestamp）
- [ ] `SecretMessageRepository` プロトコルを定義（save, fetchMessages(for:)）
- [ ] `SwiftDataSecretMessageRepository` を実装

---

### TASK-063
**送信メッセージを BLE 配信キューに積む**

`ble` `networking` `feat` `P1`

暗号化・保存した後、相手に届けるための BLE 配信キュー登録が必要。

- [ ] `OutboundMessageQueue` を設計（otherPeerId, encryptedData, createdAt, status）
- [ ] `EncounterService` の接続イベント発火時にキューから該当ピア宛のメッセージを送信
- [ ] 送信完了後にキューからメッセージを削除 or status 更新

**依存**: TASK-004, TASK-062

---

### TASK-064
**BLE 経由の受信メッセージを復号して表示**

`ble` `crypto` `ui` `feat` `P1`

送信フローの逆。BLE で受信した暗号化バイト列を復号して `SecretMessageView` に表示する。

- [ ] `BLEEncounterService` の Write Characteristic 受信ハンドラで暗号化バイト列を取得
- [ ] `SecretMessageService.decrypt(...)` で復号
- [ ] 復号結果を `SecretMessageRepository` に保存 + `onMessageReceived` コールバックで ViewModel に通知
- [ ] `SecretMessageView` がリアルタイムで更新される仕組みを実装

**依存**: TASK-004, TASK-062

---

### TASK-065
**SecretMessageView のタイトルを peerId → ニックネームに改善**

`ui` `feat` `P2`

`SecretMessageView.swift:58` の `.navigationTitle(viewModel.otherPeerId)` は
Core Bluetooth の UUID（例: `F47AC10B-58CC-...`）が表示されて UX が悪い。

- [ ] `EncounteredEvent` にオプショナルの `nickname: String?` フィールドを追加
- [ ] BLE 接続時に相手のニックネーム Characteristic を追加（または公開鍵フィンガープリントで代替）
- [ ] タイトルに短縮 ID or ニックネームを表示

---

## EP-001 追加 TASK 詳細

### TASK-051
**EncounterService プロトコルに stop() を追加**

`ble` `feat` `P1`

現在 `EncounterService` プロトコルに `stop()` がないため、BLE スキャン・アドバタイズを止める手段がない。
画面遷移・バックグラウンド移行・バッテリー節約のために必要。

- [ ] `EncounterService` プロトコルに `func stop()` を追加
- [ ] `BLEEncounterService` に実装（`centralManager.stopScan()` + `peripheralManager.stopAdvertising()`）
- [ ] `MCPeerEncounterService` と `MockEncounterService` にも実装
- [ ] `EncounterViewModel` に `stopDiscovery()` を追加

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/EncounterService.swift`、`BLEEncounterService.swift`

---

### TASK-052
**BLE マネージャーを専用 DispatchQueue で動かす**

`ble` `chore` `P2`

`BLEEncounterService.swift:42-43` の `queue: nil` はメインキューで動作する。
メッセージ転送が増えるとメインスレッドのブロックリスクがある。

- [x] `private let bleQueue = DispatchQueue(label: "com.driftsonar.ble", qos: .userInitiated)` を定義
- [x] `CBCentralManager(delegate:queue:bleQueue)` / `CBPeripheralManager(delegate:queue:bleQueue)` に変更
- [x] コールバック内の UI 更新は `DispatchQueue.main.async` でラップ

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`

---

### TASK-053
**peripheral.identifier ローテーション対策**

`ble` `security` `feat` `P2`

`seenPeerIDs: Set<UUID>` は Core Bluetooth の `peripheral.identifier` で重複排除しているが、
iOS は BLE アドレスを定期的にローテーションするため、同一ピアが新しい UUID で再スキャンされる可能性がある。

- [x] 公開鍵 Data のハッシュ（SHA-256）を重複排除キーに変更
- [x] `seenPublicKeyHashes: Set<Data>` を追加（UUID レベルの seenPeerIDs は接続管理で維持）
- [x] 公開鍵取得後に重複チェック（onEncounter のみ抑制、転送は継続）

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`

---

## EP-005 追加 TASK 詳細

### TASK-054
**HKDF の salt を空 Data() からプロトコル固有定数に変更**

`crypto` `security` `bug` `P1`

`SecretMessageService.swift:14` の `salt: Data()` は HKDF に空の salt を使用している。
RFC 5869 では salt なしは all-zero として扱われ、プロトコル固有の salt を使うことが強く推奨されている。

- [ ] `"DriftSonar-SecretMessage-v1".data(using: .utf8)!` など固定文字列を salt に設定
- [ ] `sharedInfo` も同様にプロトコル識別子を設定（例: `"DriftSonar-HKDF-Info"`）
- [ ] 既存の暗号化データとの非互換を考慮（既存チャットは復号不能になるため、移行バージョンを設計）

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/SecretMessageDomain/SecretMessageService.swift`

---

## EP-007 追加 TASK 詳細

### TASK-055
**UserProfile ドメインモデルから privateKey を除去**

`security` `refactor` `P2`

`UserProfile.swift:8` に `privateKey: Data` が含まれており、ドメインモデルを通じて秘密鍵が
ViewModel → View まで流れる設計になっている。秘密鍵はリポジトリ/Keychain 層のみで扱うべき。

- [ ] `UserProfile` から `privateKey` を削除
- [ ] `UserProfileModel` (SwiftData) の `privateKey` は Keychain 移行（TASK-035）まで暫定維持
- [ ] `EncounterView` → `SecretMessageView` への `myPrivateKey` 受け渡しを見直し
  （`SecretMessageViewModel` が直接リポジトリから秘密鍵を取得する設計に変更）

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/ProfileDomain/UserProfile.swift`、`DriftSonarApp/Views/EncounterView.swift`

---

---

## EP-012: Store-and-Forward UI統合（BLE↔ドメイン層接続）

**概要**: `MeshForwardingService` と `BLEEncounterService` はドメイン層で完成しているが、UI層（ViewModel/View）への接続が抜けているため実際のすれ違い伝播が動いていない。App層でサービスを共有インスタンス化し、EncounterViewModel と TimelineViewModel を繋ぐことで「DS のすれ違い通信」を実現する。

**Priority**: `P1` | **Labels**: `ios` `ble` `networking` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-066](#task-066) | App層でBLE・Meshサービスの共有インスタンス化 | `ios` `networking` `feat` | P1 | ✅ |
| [TASK-067](#task-067) | EncounterViewModelにMeshForwardingServiceを接続 | `ios` `ble` `networking` `feat` | P1 | ✅ |
| [TASK-068](#task-068) | 自分の投稿をメッシュキャッシュに追加（転送対象化） | `ios` `networking` `feat` | P1 | ✅ |
| [TASK-069](#task-069) | BLE受信Post → タイムライン自動リフレッシュ | `ios` `ble` `ui` `feat` | P1 | ✅ |
| [TASK-070](#task-070) | デバッグログ追加（転送状況の可視化） | `ios` `ble` `networking` `chore` | P2 | ✅ |

---

### TASK-066
**App層でBLE・Meshサービスの共有インスタンス化**

`ios` `networking` `feat` `P1`

現在 `EncounterView` は `@State private var viewModel = EncounterViewModel()` でローカルにBLEサービスを生成している。
一方 `PostTimelineView` はBLEと無関係に動いており、2つのViewが同じサービスインスタンスを共有できていない。
`ContentView` に `@Observable` な `AppServices` クラスを作り、BLE・Mesh・PostRepository を一元管理して各Viewに渡す。

- [x] `AppServices.swift` を `DriftSonarApp/` に作成（`BLEEncounterService`, `MeshForwardingService`, `SwiftDataPostRepository`, `SwiftDataMessageCacheRepository` を保持）
- [x] `ContentView` で `@State private var appServices = AppServices()` としてインスタンス化
- [x] `EncounterView` と `PostTimelineView` に `appServices` を引数で渡す（または `@Environment` 経由）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/ContentView.swift`（新規: `AppServices.swift`）
**依存**: TASK-067, TASK-068, TASK-069

---

### TASK-067
**EncounterViewModelにMeshForwardingServiceを接続**

`ios` `ble` `networking` `feat` `P1`

`BLEEncounterService.forwardingService` が `nil` のままのため、ピアと接続しても `forwardCachedMessages(to:)` が何もしない。
`EncounterViewModel.setupService()` 内で `MeshForwardingService` をセットすることで、次回ピアと出会ったとき自動でキャッシュ投稿が転送される。

- [x] `EncounterViewModel.setupService(myPublicKey:)` に `bleService: BLEEncounterService` 引数を追加（外部インスタンスを受け取る形に変更）
- [x] `AppServices.init` 内で `ble.forwardingService = mesh` をセット
- [x] `EncounterView.onAppear` の `setupService` 呼び出しを更新

**影響ファイル**: `DriftSonarApp/DriftSonarApp/ViewModels/EncounterViewModel.swift`, `DriftSonarApp/DriftSonarApp/Views/EncounterView.swift`
**依存**: TASK-066

---

### TASK-068
**自分の投稿をメッシュキャッシュに追加（転送対象化）**

`ios` `networking` `feat` `P1`

自分が書いた投稿は `SwiftDataPostRepository` には保存されるが、`MessageCacheRepository` には追加されていない。
すれ違いで他端末に届けるためには、自分の投稿もキャッシュに入れて転送対象にする必要がある。

- [x] `CreatePostUseCase` に `cacheRepository: MessageCacheRepository?` 依存を追加（optional、後方互換）
- [x] `execute()` 内で投稿保存後に `CachedMessage` を生成して `cacheRepository.save()` を呼ぶ
- [x] `TimelineViewModel.setup()` に `cacheRepository` 引数を追加し `CreatePostUseCase` に渡す
- [x] キャッシュ登録時の TTL は `Post.ttl`（デフォルト7）をそのまま使用

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/PostDomain/CreatePostUseCase.swift`, `DriftSonarApp/DriftSonarApp/ViewModels/TimelineViewModel.swift`
**依存**: TASK-066

---

### TASK-069
**BLE受信Post → タイムライン自動リフレッシュ**

`ios` `ble` `ui` `feat` `P1`

`BLEEncounterService.onMessageReceived` は現在どこにも接続されておらず、BLEで受信した投稿がタイムラインに反映されない。
`AppServices` 経由でコールバックを `TimelineViewModel.refresh()` に繋ぎ、ピアからメッセージを受け取ったら即座にタイムラインが更新されるようにする。

- [x] `AppServices` 内で `bleService.onMessageReceived` を設定し `timelineViewModel.refresh()` を呼ぶ
- [x] `PostTimelineView` が `AppServices` の `timelineViewModel` を参照するよう変更
- [ ] 受信直後の重複リフレッシュ防止（短時間に複数受信した場合はデバウンス 0.5s）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/ContentView.swift`, `DriftSonarApp/DriftSonarApp/ViewModels/TimelineViewModel.swift`
**依存**: TASK-066, TASK-067

---

### TASK-070
**デバッグログ追加（転送状況の可視化）**

`ios` `ble` `networking` `chore` `P2`

Store-and-Forward が実際に機能しているか確認できるデバッグ情報がない。
開発中に転送の動作を追跡できるよう、主要な転送イベントにログを追加する。

- [x] `MeshForwardingService.receive(payload:)` の受信・棄却・転送時に `print("[Mesh] ...")` ログを追加
- [x] `BLEEncounterService.forwardCachedMessages(to:)` で転送件数をログ出力
- [x] `BLEEncounterService` でピア発見イベントをログ出力
- [ ] （オプション）デバッグビルド時のみ Timeline 下部にメッシュ統計バッジ表示（受信件数、転送件数）

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/MeshForwardingService.swift`, `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`, `DriftSonarApp/DriftSonarApp/ViewModels/EncounterViewModel.swift`
**依存**: TASK-067, TASK-069

---

## 優先順位まとめ

```
Phase 1 (P0 — 動くようにする):
  EP-010 (TASK-056 コンパイルエラー) → EP-001 (TASK-001〜003)
  → EP-002 (TASK-007〜009) → EP-003 (TASK-013)

Phase 2 (P1 — MVP):
  EP-010 (TASK-057〜059) → EP-001 (TASK-004〜006, TASK-051)
  → EP-005 (TASK-054 HKDF salt) → EP-002 (TASK-010〜012)
  → EP-003 (TASK-014〜015) → EP-011 (TASK-061〜064)
  → EP-004 → EP-005 (残り) → EP-006 (TASK-031)
  → EP-012 (TASK-066→067→068→069)

Phase 3 (P2 — 品質・セキュリティ):
  EP-010 (TASK-060) → EP-001 (TASK-052〜053)
  → EP-006 (TASK-032〜033) → EP-007 (TASK-055含む) → EP-008 → EP-011 (TASK-065)
  → EP-012 (TASK-070) → EP-013 (TASK-072→073) → EP-009 (TASK-071)

Phase 4 (P3 — 仕上げ):
  EP-006 (TASK-034) → EP-007 (TASK-038〜039) → EP-008 (TASK-044) → EP-009
```

---

## EP-013: シミュレーター向けデバッグ機能開発と実機テスト

**概要**: iOS シミュレーターでは Core Bluetooth が動かないため BLE 転送をそのままテストできない。疑似BLE受信ボタン等のデバッグ機能を追加して実機なしでも Store-and-Forward の動作を確認できるようにし、その後実機2台で本番動作を検証する。

**Priority**: `P2` | **Labels**: `ios` `ui` `ble` `networking` `devops` `test` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-072](#task-072) | Radar タブに「疑似BLE受信」デバッグボタンを追加 | `ios` `ui` `devops` `feat` | P2 | ✅ |
| [TASK-073](#task-073) | 実機2台によるBLEすれ違い転送の動作検証 | `ios` `ble` `networking` `test` | P2 | ⬜ |

---

### TASK-072
**Radar タブに「疑似BLE受信」デバッグボタンを追加**

`ios` `ui` `devops` `feat` `P2`

iOS シミュレーターでは Core Bluetooth が動かず BLE 転送を直接テストできない。
デバッグビルド時のみ Radar タブに「Simulate BLE Receive」ボタンを表示し、
`MeshForwardingService.receive()` に疑似ペイロードを渡すことで
Timeline 自動更新までの一連フローをシミュレーターで確認できるようにする。

- [ ] `#if DEBUG` ブロックで Radar タブ下部にデバッグボタンを追加
- [ ] ボタンタップで `Post(content: "テスト投稿（疑似BLE受信）", authorPublicKey: Data(repeating: 0x99, count: 32))` を `PostSerializer.encode` → `appServices.meshService.receive()` に渡す
- [ ] Timeline が自動更新されること、hopCount が 1・TTL が 6 で表示されることをシミュレーターで確認

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/EncounterView.swift`
**依存**: EP-012（AppServices 共有インスタンス）

---

### TASK-073
**実機2台によるBLEすれ違い転送の動作検証**

`ios` `ble` `networking` `test` `P2`

シミュレーターでは確認できない実際の BLE 転送を実機2台で検証する。
Xcode Console の `[BLE]`/`[Mesh]` ログで転送の成否を確認し、問題があれば修正する。

- [ ] iPhone 2台に実機ビルドをインストール（Signing & Capabilities → Team 設定）
- [ ] iPhone A で投稿を作成し、2台を近づけて iPhone B の Timeline に届くか確認
- [ ] Xcode Console で `[BLE] Forwarding N cached post(s)` と `[Mesh] Received new post` ログが出ることを確認
- [ ] 問題があれば原因を特定して修正

**依存**: TASK-072（デバッグ機能で事前フロー確認済みであること）

---

## EP-014: ニックネームシステム

**概要**: 現在ユーザーは公開鍵ハッシュ（32byte hex）でしか識別できない。ニックネームを設定・BLE 経由で交換することで、Timeline・Encounter・SecretMessage すべてで人間が読める名前を表示できるようにする。

**Priority**: `P1` | **Labels**: `ios` `ble` `ui` `swiftdata` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-074](#task-074) | UserProfile ドメインモデルに nickname フィールド追加 | `feat` `swiftdata` | P1 | ✅ |
| [TASK-075](#task-075) | InitialSetupView にニックネーム入力フォーム追加 | `ui` `ios` `feat` | P1 | ✅ |
| [TASK-076](#task-076) | BLE Characteristic でニックネームを公開・受信 | `ble` `feat` | P1 | ✅ |
| [TASK-077](#task-077) | EncounteredEventModel にニックネームを保存 | `swiftdata` `feat` | P1 | ✅ |
| [TASK-078](#task-078) | TimelineView の著者表示をニックネーム優先に変更 | `ui` `ios` `feat` | P2 | ✅ |
| [TASK-079](#task-079) | EncounterView ピア行にニックネーム表示 | `ui` `ios` `feat` | P2 | ✅ |
| [TASK-080](#task-080) | SecretMessageView タイトルをニックネームに変更（TASK-065 完成） | `ui` `ios` `feat` | P2 | ✅ |

---

### TASK-074
**UserProfile ドメインモデルに nickname フィールド追加**

`feat` `swiftdata` `P1`

`UserProfile.swift` に `nickname: String` を追加し、`UserProfileModel`（SwiftData）にも反映する。

- [ ] `UserProfile` struct に `nickname: String` を追加（デフォルト値 `""` or optional）
- [ ] `UserProfileModel` に `nickname: String` カラム追加
- [ ] `CreateProfileUseCase` でニックネームを受け取り保存
- [ ] `UserProfileRepository.fetchMyProfile()` でニックネームを返す

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/ProfileDomain/UserProfile.swift`、`UserProfileModel.swift`

---

### TASK-075
**InitialSetupView にニックネーム入力フォーム追加**

`ui` `ios` `feat` `P1`

初回起動時のセットアップ画面でニックネームを入力できるようにする。現在はユーザー名入力がない。

- [ ] `InitialSetupView` に `TextField("ニックネーム（例: Alice）", text: $nickname)` を追加
- [ ] 入力バリデーション（1文字以上、20文字以下）
- [ ] 「はじめる」ボタン押下時に `CreateProfileUseCase` にニックネームを渡す
- [ ] キーボード dismiss 対応（`.onSubmit` or ツールバー）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/InitialSetupView.swift`、`DriftSonarApp/DriftSonarApp/ViewModels/InitialSetupViewModel.swift`

**依存**: TASK-074

---

### TASK-076
**BLE Characteristic でニックネームを公開・受信**

`ble` `feat` `P1`

BLE 接続時に相手のニックネームを読み取れるよう、新しい GATT Characteristic を追加する。

- [ ] `DriftSonarBLE` に `nicknameCharacteristicUUID` を定義（新規 UUID）
- [ ] `BLEEncounterService` の Peripheral に ニックネーム Read Characteristic を追加
- [ ] 自分のニックネームを Characteristic の value に設定（`UserProfileRepository` から取得）
- [ ] Central 側で接続後にニックネーム Characteristic を読み取る処理を追加
- [ ] 読み取り完了後、`onEncounter` コールバックに `nickname` を含めて通知

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`

**依存**: TASK-074

---

### TASK-077
**EncounteredEventModel にニックネームを保存**

`swiftdata` `feat` `P1`

BLE で受け取ったニックネームを永続化し、次回起動後も表示できるようにする。

- [ ] `EncounteredEventModel` に `nickname: String?` カラム追加
- [ ] `EncounteredEvent` ドメインモデルにも `nickname: String?` を追加
- [ ] `BLEEncounterService` の `onEncounter` でニックネームを含めて通知
- [ ] `EncounterHistoryRepository.save()` でニックネームを保存

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/ProfileDomain/`（EncounteredEvent 関連）

**依存**: TASK-076

---

### TASK-078
**TimelineView の著者表示をニックネーム優先に変更**

`ui` `ios` `feat` `P2`

現在 `PostRowView` では `authorPublicKey` の hex 短縮表示のみ。EncounterHistory からニックネームを引いて優先表示する。

- [ ] `TimelineViewModel` に `resolveNickname(for publicKey: Data) -> String` ヘルパーを追加（EncounterHistoryRepository から検索）
- [ ] `PostRowView` の著者欄に ニックネーム優先、なければ公開鍵短縮表示（`fingerprint(8byte)`）
- [ ] 自分の投稿には「自分」または設定したニックネームを表示

**依存**: TASK-077

---

### TASK-079
**EncounterView ピア行にニックネーム表示**

`ui` `ios` `feat` `P2`

`EncounterView` のピア一覧でニックネームを表示。現在は UUID 文字列が表示されている。

- [ ] `EncounteredEvent` の `nickname` を `EncounterViewModel` 経由で EncounterView に渡す
- [ ] `EncounterRowView`（または相当箇所）でニックネームを優先表示
- [ ] ニックネームがない場合は公開鍵フィンガープリントを表示

**依存**: TASK-077

---

### TASK-080
**SecretMessageView タイトルをニックネームに変更**

`ui` `ios` `feat` `P2`

TASK-065 の未解決残件。`.navigationTitle(viewModel.otherPeerId)` で Core Bluetooth UUID が表示される問題を解消。

- [ ] `SecretMessageViewModel` に `peerNickname: String?` プロパティを追加
- [ ] `EncounterHistoryRepository` から `otherPeerId` に対応するニックネームを取得
- [ ] `.navigationTitle` にニックネーム優先、なければ短縮フィンガープリントを表示

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/SecretMessageView.swift`、`DriftSonarApp/DriftSonarApp/ViewModels/SecretMessageViewModel.swift`

**依存**: TASK-077

---

## EP-015: 通知システム

**概要**: バックグラウンドで新規 Post・DM を受信した際にローカル通知を送り、未読件数をタブバッジで表示する。

**Priority**: `P2` | **Labels**: `ios` `ble` `ui` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-081](#task-081) | UNUserNotificationCenter 権限リクエスト実装 | `ios` `feat` | P2 | ✅ |
| [TASK-082](#task-082) | 新規 Post 受信時のローカル通知送信 | `ios` `ble` `feat` | P2 | ✅ |
| [TASK-083](#task-083) | SecretMessage 受信時のローカル通知送信 | `ios` `ble` `crypto` `feat` | P2 | ✅ |
| [TASK-084](#task-084) | Timeline タブに未読バッジカウント表示 | `ui` `ios` `feat` | P2 | ✅ |
| [TASK-085](#task-085) | 通知タップで該当タブを開く（ディープリンク） | `ios` `feat` | P3 | ✅ |

---

### TASK-081
**UNUserNotificationCenter 権限リクエスト実装**

`ios` `feat` `P2`

ローカル通知を送るために iOS の通知権限が必要。初回起動時または初回 Post 受信前に権限を要求する。

- [ ] `AppServices` または `DriftSonarAppApp.swift` で `UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])` を呼ぶ
- [ ] Info.plist に `NSUserNotificationUsageDescription` を追加
- [ ] 権限拒否の場合は通知をサイレントにスキップ

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/DriftSonarAppApp.swift`

---

### TASK-082
**新規 Post 受信時のローカル通知送信**

`ios` `ble` `feat` `P2`

`AppServices.bleService.onMessageReceived` コールバックでローカル通知を送信。

- [ ] `NotificationService` ユーティリティを作成（`sendPostNotification(post:)` メソッド）
- [ ] 通知内容：タイトル「新しい投稿が届きました」、本文は content の先頭 50文字
- [ ] アプリがフォアグラウンドの場合は通知を送らない（`UNUserNotificationCenterDelegate` で制御）
- [ ] アプリがバックグラウンドの場合のみ送信

**依存**: TASK-081

---

### TASK-083
**SecretMessage 受信時のローカル通知送信**

`ios` `ble` `crypto` `feat` `P2`

DM 受信時に通知を送る。内容は暗号化されているためプレビューは表示しない。

- [ ] `AppServices` の SecretMessage 受信コールバックで `NotificationService.sendDMNotification(from:)` を呼ぶ
- [ ] 通知内容：タイトル「新しい DM」、本文「暗号化されたメッセージが届きました」
- [ ] フォアグラウンド時はスキップ

**依存**: TASK-082（NotificationService 共通化）

---

### TASK-084
**Timeline タブに未読バッジカウント表示**

`ui` `ios` `feat` `P2`

BLE 受信した Post の未読件数をタブバーのバッジに表示し、Timeline を開いたら消える。

- [ ] `AppServices` に `unreadPostCount: Int` を追加
- [ ] `bleService.onMessageReceived` で `unreadPostCount += 1`
- [ ] `PostTimelineView` が表示されたら `unreadPostCount = 0`
- [ ] `TabView` の Timeline アイテムに `.badge(appServices.unreadPostCount)` を設定

**依存**: TASK-069（BLE受信→Timeline更新の接続）

---

### TASK-085
**通知タップで該当タブを開く（ディープリンク）**

`ios` `feat` `P3`

通知をタップしたとき、Timeline または DM タブを自動的に開く。

- [x] `UNUserNotificationCenterDelegate.userNotificationCenter(_:didReceive:)` を実装
- [x] 通知カテゴリ（`"POST"` / `"DM"`）に応じて `AppServices.selectedTab` を切り替える
- [x] `ContentView` の `TabView(selection: $appServices.selectedTab)` に対応

**依存**: TASK-082, TASK-083

---

## EP-016: Timeline UX 改善

**概要**: Timeline の操作性と使いやすさを改善する。投稿の詳細表示・ブロック操作・スクロール挙動などの細かい UX 改善。

**Priority**: `P2` | **Labels**: `ui` `ios` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-086](#task-086) | PostRowView に長押しコンテキストメニュー追加 | `ui` `ios` `feat` | P2 | ✅ |
| [TASK-087](#task-087) | コンテキストメニューから「このユーザーをブロック」 | `ui` `ios` `security` `feat` | P2 | ✅ |
| [TASK-088](#task-088) | Timeline でブロックユーザー投稿をフィルタリング | `ui` `ios` `security` `feat` | P2 | ✅ |
| [TASK-089](#task-089) | ComposeView 投稿中スピナー表示 | `ui` `ios` `feat` | P2 | ✅ |
| [TASK-090](#task-090) | 新着受信時にスクロール位置を最上部に移動 | `ui` `ios` `feat` | P2 | ✅ |

---

### TASK-086
**PostRowView に長押しコンテキストメニュー追加**

`ui` `ios` `feat` `P2`

投稿行を長押しするとアクションメニューが出るようにする。

- [ ] `PostRowView` に `.contextMenu { }` を追加
- [ ] 「テキストをコピー」アクション（`UIPasteboard.general.string = post.content`）
- [ ] 「投稿者情報を見る」アクション（公開鍵フィンガープリントを Alert で表示）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/TimelineView.swift`

---

### TASK-087
**コンテキストメニューから「このユーザーをブロック」**

`ui` `ios` `security` `feat` `P2`

Timeline から直接ブロック操作できるようにする（現在は EncounterView のみ）。

- [ ] TASK-086 のコンテキストメニューに「このユーザーをブロック」を追加
- [ ] タップ時に確認 Alert（`"このユーザーの投稿を非表示にしますか？"`）を表示
- [ ] 確認後 `BlockRepository.block(publicKey:)` を呼ぶ
- [ ] 成功後に Timeline を即時リフレッシュ

**依存**: TASK-086

---

### TASK-088
**Timeline でブロックユーザー投稿をフィルタリング**

`ui` `ios` `security` `feat` `P2`

`BlockDomain` は実装済みだが、Timeline の表示フィルタリングが未実装の場合は実装する。

- [ ] `FetchTimelineUseCase` にブロックリストチェックを追加（または `TimelineViewModel` でフィルタ）
- [ ] `BlockRepository.fetchAll()` でブロック済み公開鍵リストを取得
- [ ] `posts.filter { !blockedKeys.contains($0.authorPublicKey) }` で除外
- [ ] ブロック後にリアルタイムで非表示になることを確認

---

### TASK-089
**ComposeView 投稿中スピナー表示**

`ui` `ios` `feat` `P2`

「投稿」ボタンを押してから完了するまでのフィードバックがない。ローディング表示を追加。

- [ ] `TimelineViewModel` に `isPosting: Bool` を追加
- [ ] 投稿開始時に `isPosting = true`、完了時に `false`
- [ ] 「投稿」ボタンに `.disabled(isPosting)` と `ProgressView` を組み合わせたラベル表示
- [ ] 投稿失敗時にエラーアラートを表示

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/ComposeView.swift`、`DriftSonarApp/DriftSonarApp/ViewModels/TimelineViewModel.swift`

---

### TASK-090
**新着受信時にスクロール位置を最上部に移動**

`ui` `ios` `feat` `P2`

BLE で新しい投稿を受信したとき、ユーザーが自動的に最新投稿を見られるようにする。

- [ ] `PostTimelineView` に `ScrollViewReader` を追加
- [ ] `timelineViewModel.posts` の変化を `onChange` で監視
- [ ] 新着受信時（投稿数増加）に `scrollProxy.scrollTo("top", anchor: .top)` を呼ぶ
- [ ] スクロール中の場合はジャンプしないよう制御（オプション）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/TimelineView.swift`

---

## EP-017: BLE 信頼性向上

**概要**: 実機での BLE 接続安定性・メッセージ重複排除の堅牢化・エラー処理の改善。

**Priority**: `P2` | **Labels**: `ble` `ios` `networking`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-091](#task-091) | BLE Characteristic write 失敗時リトライロジック | `ble` `networking` `feat` | P2 | ✅ |
| [TASK-092](#task-092) | seenMessageIDs を UserDefaults に永続化 | `ble` `networking` `chore` | P2 | ✅ |
| [TASK-093](#task-093) | BLE 電源 OFF 時の UI バナー表示 | `ble` `ui` `feat` | P2 | ✅ |
| [TASK-094](#task-094) | バックグラウンド復帰時の BLE 再スタートロジック | `ble` `ios` `feat` | P2 | ✅ |
| [TASK-095](#task-095) | 接続タイムアウト（30秒）と強制切断処理 | `ble` `networking` `feat` | P2 | ✅ |

---

### TASK-091
**BLE Characteristic write 失敗時リトライロジック**

`ble` `networking` `feat` `P2`

`peripheral.writeValue(_:for:type:)` が `.withResponse` で失敗した場合、現在はエラーを無視している。

- [ ] `peripheral(_:didWriteValueFor:error:)` コールバックでエラーを検出
- [ ] エラー時に最大3回まで 1秒間隔でリトライ
- [ ] リトライ上限超過時にキューから削除してログ出力

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`

---

### TASK-092
**seenMessageIDs を UserDefaults に永続化**

`ble` `networking` `chore` `P2`

現在 `seenMessageIDs: Set<UUID>` はインメモリのみ。アプリ再起動後に同じメッセージを再受信・再転送するリスクがある。

- [ ] `seenMessageIDs` を `UserDefaults` に保存（`[String]` に変換して `codable` で保存）
- [ ] アプリ起動時に `UserDefaults` からロード
- [ ] セットが 10,000 件を超えたら古い順に削除（メモリ節約）
- [ ] `MeshForwardingService` の `processedIDs` も同様に永続化

---

### TASK-093
**BLE 電源 OFF 時の UI バナー表示**

`ble` `ui` `feat` `P2`

Bluetooth が OFF になったときユーザーに通知する。現在は何もフィードバックがない。

- [ ] `BLEEncounterService` に `bluetoothState: CBManagerState` プロパティを追加（`@Published` or callback）
- [ ] `AppServices` 経由で `EncounterViewModel` に状態を公開
- [ ] `EncounterView` に `.overlay` または `.safeAreaInset` で「Bluetoothをオンにしてください」バナーを表示
- [ ] Bluetooth が ON に戻ったらバナーを消す

---

### TASK-094
**バックグラウンド復帰時の BLE 再スタートロジック**

`ble` `ios` `feat` `P2`

アプリがバックグラウンドから復帰したとき、BLE スキャン・アドバタイズが停止していることがある。

- [ ] `ScenePhase.active` への遷移を `ContentView` の `.onChange(of: scenePhase)` で検知
- [ ] `appServices.bleService.restart()` を呼ぶ（`stop()` → `execute(command:)` の順）
- [ ] `BLEEncounterService` に `restart()` メソッドを追加

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/ContentView.swift`、`BLEEncounterService.swift`

---

### TASK-095
**接続タイムアウト（30秒）と強制切断処理**

`ble` `networking` `feat` `P2`

ピアと接続後、応答がない場合に無限待機するリスクがある。タイムアウトを実装する。

- [ ] 接続後 30秒以内に公開鍵 Characteristic の読み取りが完了しない場合、`centralManager.cancelPeripheralConnection(peripheral)` を呼ぶ
- [ ] タイムアウト用の `DispatchWorkItem` を接続時にスケジュール、成功時はキャンセル
- [ ] タイムアウト発生をログに記録

---

## EP-018: 品質・安定性

**概要**: 未実装のまま残っている防御ロジック（TTL上限・レートリミット・エビクション）の実装、デバウンス、テスト強化。

**Priority**: `P2` | **Labels**: `networking` `security` `test` `ios`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-096](#task-096) | Timeline 更新デバウンス実装（TASK-069 残件） | `ios` `ui` `feat` | P2 | ✅ |
| [TASK-097](#task-097) | TTL グローバル上限チェック実装（TASK-031 残件） | `networking` `security` `feat` | P2 | ✅ |
| [TASK-098](#task-098) | 送信者レートリミット実装（TASK-032 残件） | `networking` `security` `feat` | P2 | ✅ |
| [TASK-099](#task-099) | キャッシュエビクション実装（TASK-017 残件） | `swiftdata` `networking` `feat` | P2 | ✅ |
| [TASK-100](#task-100) | TimelineViewModel ユニットテスト追加 | `test` `ios` | P2 | ✅ |
| [TASK-101](#task-101) | MeshForwardingService 境界テスト拡充 | `test` `networking` | P2 | ✅ |
| [TASK-102](#task-102) | GitHub Actions Swift test ワークフロー作成（TASK-042 実装） | `devops` `test` | P2 | ✅ |

---

### TASK-096
**Timeline 更新デバウンス実装**

`ios` `ui` `feat` `P2`

TASK-069 の残件。短時間に複数の BLE メッセージを受信した場合、`refresh()` が連続で呼ばれて無駄な DB 読み込みが発生する。

- [ ] `TimelineViewModel` に `debounceRefreshTask: Task?` を持たせる
- [ ] `refresh()` 呼び出し時に既存タスクをキャンセルし、0.5秒後に実際のフェッチを実行
- [ ] `Task.sleep(nanoseconds:)` で実装（または `Combine Debounce`）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/ViewModels/TimelineViewModel.swift`

---

### TASK-097
**TTL グローバル上限チェック実装**

`networking` `security` `feat` `P2`

TASK-031 の設計で決まった `maxTTL = 7` チェックが実際のコードに入っていることを確認・実装。

- [ ] `DriftSonarCore` に `DriftSonarConstants.swift` を作成（`maxTTL = 7`、`maxHopCount = 20` 等）
- [ ] `MeshForwardingService.receive(payload:)` で `post.ttl > DriftSonarConstants.maxTTL` なら棄却
- [ ] `PostSerializer.decode()` で TTL が負値の場合も棄却

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/MeshForwardingService.swift`

---

### TASK-098
**送信者レートリミット実装**

`networking` `security` `feat` `P2`

TASK-032 の設計。同一 `authorPublicKey` から 1分間に 10件超で棄却。

- [ ] `MeshForwardingService` に `senderHistory: [Data: [Date]]` を追加
- [ ] 受信時に履歴チェック：1分以内に 10件超なら棄却
- [ ] 古い履歴は定期クリーンアップ（受信時に 1分超のエントリを削除）
- [ ] レートリミット発動をログに記録

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/MeshForwardingService.swift`

---

### TASK-099
**キャッシュエビクション実装**

`swiftdata` `networking` `feat` `P2`

TASK-017 の残件。キャッシュが 200件を超えたら古い・拡散済みメッセージを削除。

- [ ] `MessageCacheRepository` に `count() -> Int` メソッドを追加
- [ ] `SwiftDataMessageCacheRepository.save()` 後に件数チェック
- [ ] 200件超過時は `forwardedCount` 最大かつ `receivedAt` 最古のものから削除（最大 50件ずつ削除）
- [ ] エビクション実行をログに記録

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/`

---

### TASK-100
**TimelineViewModel ユニットテスト追加**

`test` `ios` `P2`

`TimelineViewModel` のビジネスロジックをテストする。

- [ ] `InMemoryPostRepository` を用いたテスト用 ViewModel を作成
- [ ] 投稿追加後に `posts` が更新されることを確認
- [ ] `refresh()` がリポジトリを再フェッチすることを確認
- [ ] デバウンス動作のテスト（連続 refresh でも 1回だけ DB アクセス）

**影響ファイル**: `DriftSonarCore/Tests/DriftSonarCoreTests/`（新規）

---

### TASK-101
**MeshForwardingService 境界テスト拡充**

`test` `networking` `P2`

既存の `MeshForwardingServiceTests` に境界値テストを追加。

- [ ] TTL = 0 のメッセージは転送されないことを確認
- [ ] TTL > maxTTL のメッセージは棄却されることを確認
- [ ] 同一メッセージ ID の重複受信が棄却されることを確認
- [ ] レートリミット超過時の棄却テスト（TASK-098 実装後）

---

### TASK-102
**GitHub Actions Swift test ワークフロー作成**

`devops` `test` `P2`

TASK-042 の実装（`.github/workflows/test.yml` 未作成）。

- [ ] `.github/workflows/test.yml` を作成
- [ ] `swift test` で `DriftSonarCore` のテストを実行（`ubuntu-latest` または `macos-latest`）
- [ ] PR 作成時に自動実行
- [ ] テスト失敗時に PR マージをブロック（`required status checks` 設定）

**影響ファイル**: `.github/workflows/test.yml`（新規）

---

## EP-019: App Store 準備

**概要**: TestFlight / App Store 公開に向けた準備。アイコン・メタデータ・バージョン管理・プライバシーポリシー。

**Priority**: `P3` | **Labels**: `ios` `devops` `chore`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-103](#task-103) | アプリアイコン制作・設置（TASK-046 実装） | `ui` `ios` | P3 | ✅ (TASK-113で達成) |
| [TASK-104](#task-104) | バージョン番号・ビルド番号管理の整備 | `devops` `chore` | P3 | ✅ |
| [TASK-105](#task-105) | Privacy Policy URL の設置（App Store 必須） | `ios` `chore` | P3 | ✅ |
| [TASK-106](#task-106) | App Store 配布設定（Signing・Archive・公開） | `devops` `ios` `chore` | P3 | 🔄 (コード側完了/Apple側未) |
| [TASK-107](#task-107) | App Store スクリーンショット用デモ投稿シード | `ios` `devops` `chore` | P3 | ✅ |

---

### TASK-103
**アプリアイコン制作・設置**

`ui` `ios` `P3`

TASK-046 の実装。`Assets.xcassets/AppIcon.appiconset` にアイコン画像を設置する。

**→ TASK-113（イルカ × ソナー波）で達成済み。** 以下を満たす:
- [x] アイコンデザイン（1024x1024px 基本デザイン）→ Imagen 4 生成（TASK-113）
- [x] `AppIcon.appiconset/Contents.json` を整備 → 最新 Xcode の単一 1024 形式（ライト/ダーク/tinted の3バリアント、全サイズは Xcode が自動生成）
- [x] Xcode でビルドして正しく表示されることを確認 → BUILD SUCCEEDED 確認済み

---

### TASK-104
**バージョン番号・ビルド番号管理の整備**

`devops` `chore` `P3`

現在のバージョン番号を確認し、CI で自動インクリメントできる仕組みを整える。

- [x] `DriftSonarApp.xcodeproj` の `MARKETING_VERSION`（CFBundleShortVersionString）を `0.1.0` に設定
- [x] `CURRENT_PROJECT_VERSION`（CFBundleVersion）を `1` に設定
- [x] GitHub Actions でのビルド番号自動インクリメント設定（`agvtool`）

---

### TASK-105
**Privacy Policy URL の設置**

`ios` `chore` `P3`

App Store 申請時にプライバシーポリシー URL が必要。最小限の内容で準備する。

- [x] プライバシーポリシードキュメントを作成（収集情報なし・BLE P2P 伝播・E2E 暗号 DM・匿名投稿を明記）→ `docs/privacy-policy.md`（日英併記ソース）＋ `docs/privacy-policy.html`（自己完結スタイル付き、GitHub Pages 公開用）
- [x] GitHub Pages でホスト完了 → **https://omaru12345.github.io/DriftSonar/privacy-policy.html**（main / docs フォルダ、HTTP 200 配信確認済み）。App Store Connect への URL 登録は TASK-106 の審査提出時に実施
- [x] `PrivacyInfo.xcprivacy` を作成（`NSPrivacyTracking=false`・収集データなし・UserDefaults を Required Reason API `CA92.1` で申告）→ 同期ルートグループ配置でビルド時にバンドルへ自動同梱を確認

**影響ファイル**: `docs/privacy-policy.md`、`docs/privacy-policy.html`、`DriftSonarApp/DriftSonarApp/DriftSonarApp/PrivacyInfo.xcprivacy`

---

### TASK-106
**App Store 配布設定（公開）**

`devops` `ios` `chore` `P3`

詳細な手順は `docs/app-store-release.md`（公開プレイブック）を参照。実機テスト（TASK-073）は一旦スキップして公開フロー習得を優先。

**コード側準備（完了 ✅）**
- [x] Bundle ID を `com.driftsonar.app` に変更（旧 `com.whisper.DriftSonarApp` を排除）
- [x] 表示名 `CFBundleDisplayName = DriftSonar` を Info.plist に追加
- [x] 暗号輸出申告 `ITSAppUsesNonExemptEncryption = false`（標準暗号として適用除外）を Info.plist に追加
- [x] Deployment Target を `26.2` → `17.0` に変更し配布範囲拡大（Core が `.iOS(.v17)` 設計のため安全。Debug/Release 両ビルド成功確認）
- [x] 上記変更でビルド成功を確認（`com.driftsonar.app`）

**Apple 側作業（要アカウント・未着手 ⬜）**
- [ ] Apple Developer Program 登録（年99ドル・未登録）
- [ ] Xcode で Team 設定（`DEVELOPMENT_TEAM`）＋自動署名
- [ ] App Store Connect でアプリ登録（Bundle ID `com.driftsonar.app`）
- [ ] メタデータ・スクショ・App Privacy（Data Not Collected）入力
- [ ] Any iOS Device で Archive → Organizer → App Store Connect へアップロード
- [ ] 審査提出（Review Notes に「近接2台で伝播・単体でUI確認可」を明記、デモ動画推奨）
- [ ] （任意・後回し）GitHub Actions での自動ビルド・アップロード（`fastlane`/`xcodebuild`）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp.xcodeproj/project.pbxproj`、`DriftSonarApp/DriftSonarApp/DriftSonarApp/Info.plist`、`docs/app-store-release.md`（新規）

---

### TASK-107
**App Store スクリーンショット用デモ投稿シード**

`ios` `devops` `chore` `P3`

スクリーンショット撮影用に見栄えのするデモデータを簡単に投入できる仕組みを作る。

- [x] `#if DEBUG` ブロックで「デモデータ投入」ボタンを設定画面に追加
- [x] ボタンタップで 5件のサンプル投稿（多様な hopCount・ニックネーム付き）を SwiftData に保存
- [ ] Simulator のスクリーンショット設定（端末種別・言語）を確認

---

## EP-020: 匿名投稿実装

**概要**: `AnonymousPostDesign.swift` に設計済みの匿名投稿（使い捨て鍵ペア）を実装する。通常の投稿フローと分離し、UI からオプトインできるようにする。

**Priority**: `P3` | **Labels**: `crypto` `security` `ios` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-108](#task-108) | EphemeralKeyService 実装 | `crypto` `security` `feat` | P3 | ✅ |
| [TASK-109](#task-109) | ComposeView に「匿名で投稿」トグル追加 | `ui` `ios` `feat` | P3 | ✅ |
| [TASK-110](#task-110) | 匿名モードでの CreatePostUseCase 分岐 | `ios` `crypto` `feat` | P3 | ✅ |
| [TASK-111](#task-111) | 匿名投稿の UI 差別化（アイコン・ラベル） | `ui` `ios` `feat` | P3 | ✅ |

---

### TASK-108
**EphemeralKeyService 実装**

`crypto` `security` `feat` `P3`

`AnonymousPostDesign.swift` の設計に基づき、使い捨て Ed25519 鍵ペアを生成するサービスを実装。

- [ ] `EphemeralKeyService.generateKeyPair() -> (signingKey: Curve25519.Signing.PrivateKey, publicKey: Data)` を実装
- [ ] 生成した鍵は非永続化（Keychain に保存しない）
- [ ] 同一セッション内での再利用防止（投稿ごとに新しいペアを生成）

**参考**: `DriftSonarCore/Sources/DriftSonarCore/SecretMessageDomain/AnonymousPostDesign.swift`

---

### TASK-109
**ComposeView に「匿名で投稿」トグル追加**

`ui` `ios` `feat` `P3`

- [ ] `ComposeView` にトグルスイッチ「匿名で投稿」を追加
- [ ] トグル ON 時に「アイコン」または「匿名」ラベルを表示
- [ ] `TimelineViewModel.createPost(content:isAnonymous:)` に `isAnonymous` パラメータを追加

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/ComposeView.swift`

**依存**: TASK-108

---

### TASK-110
**匿名モードでの CreatePostUseCase 分岐**

`ios` `crypto` `feat` `P3`

- [ ] `CreatePostRequest` に `isAnonymous: Bool` フラグを追加
- [ ] `isAnonymous = true` 時は `EphemeralKeyService.generateKeyPair()` の鍵を使って署名
- [ ] `isAnonymous = false` 時は通常の Keychain 鍵で署名（既存フロー）
- [ ] 匿名投稿の `authorPublicKey` は使い捨て公開鍵（受信側は通常と同じ検証フロー）

**依存**: TASK-108, TASK-109

---

### TASK-111
**匿名投稿の UI 差別化**

`ui` `ios` `feat` `P3`

匿名投稿が Timeline に表示されたとき、視覚的に区別できるようにする。

- [ ] `Post` に `isAnonymous: Bool` フラグを追加（または `authorPublicKey` が使い捨て鍵ならば匿名とみなす）
- [ ] `PostRowView` で匿名投稿には「🎭 匿名」または「Anonymous」ラベルを表示
- [ ] 匿名投稿行のアイコンを通常と異なるスタイルに変更

**依存**: TASK-110

---

## EP-021: ビジュアルアイデンティティ・マスコット

**概要**: DriftSonar のコンセプト（Sonar + Drift = 水・音波・漂流）を体現するビジュアルアイデンティティを整備する。
マスコットキャラはイルカ。配色は白背景＋水色（#40C8E0 系）のフラットデザイン。Twitter の反転イメージ（青背景に白鳥 → 白背景に水色イルカ）。

**コンセプトメモ**:
- カラーパレット: 背景 `#FFFFFF`、メインカラー `#40C8E0`（明るい水色）、アクセント `#1AA7C0`（やや深い水色）
- 輪郭線なし（アウトラインレス）のフラットイルカシルエット
- 音波（ソナー波）を組み合わせるとコンセプトが伝わりやすい
- 「漂う」「つながる」イメージ — 固い印象は不要

**Priority**: `P3` | **Labels**: `ui` `ios`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-112](#task-112) | カラーパレット定義・AccentColor 更新 | `ui` `ios` `chore` | P3 | ✅ |
| [TASK-113](#task-113) | アプリアイコン制作（イルカ × ソナー波） | `ui` `ios` | P3 | ✅ |
| [TASK-114](#task-114) | LaunchScreen / スプラッシュ統一 | `ui` `ios` | P3 | ✅ |
| [TASK-115](#task-115) | Timeline・Radar の空状態イラスト | `ui` `ios` | P3 | ✅ |

---

### TASK-112
**カラーパレット定義・AccentColor 更新**

`ui` `ios` `chore` `P3`

現在の AccentColor（深青緑系）をデザイン定義に合わせて更新し、アプリ全体の色を統一する。

- [ ] `Assets.xcassets/AccentColor` を `#40C8E0`（水色）に変更
- [ ] Light / Dark モード両対応（Dark は `#1AA7C0` に落とす）
- [ ] `Color` 拡張に `Color.sonar`（`#40C8E0`）・`Color.drift`（`#1AA7C0`）を定義して各 View から参照できるようにする

**影響ファイル**: `Assets.xcassets/AccentColor.colorset/Contents.json`、新規 `DriftSonarApp/DriftSonarApp/Extensions/Color+DriftSonar.swift`

---

### TASK-113
**アプリアイコン制作（イルカ × ソナー波）**

`ui` `ios` `P3`

デザイン仕様:
- **背景**: 白 `#FFFFFF`
- **イルカシルエット**: 水色 `#40C8E0`、アウトラインレス（塗りのみ）、右上に跳ねるポーズ
- **ソナー波**: イルカの口元から半円状に 2〜3 本の弧（同じ水色、透明度を変えてグラデーション感）
- **スタイル**: フラット、シャドウなし、角丸はシステムの角丸に委ねる（1024×1024 px 正方形で納品）
- Twitter と色が逆 — 白地に水色キャラ

制作フロー:
- [x] 1024×1024 px PNG を生成（Imagen 4 / `imagen-4.0-generate-001` で AI 生成、2026-03-31）
- [x] ライト版 `AppIcon-1024.png`・ダーク版 `AppIcon-1024-dark.png` を `Assets.xcassets/AppIcon.appiconset` に配置
- [x] ビルド検証 → BUILD SUCCEEDED 確認済み

**備考**: 旧アイコンがかもめ風に見えたため Imagen 4 で再生成。SVG 素材は未作成（P3残課題）。

**参考**: TASK-046（旧アイコンタスク、本タスクで統合）

---

### TASK-114
**LaunchScreen / スプラッシュ統一**

`ui` `ios` `P3`

- [x] LaunchScreen.storyboard を廃止し、Info.plist の `UILaunchScreen` キーで白背景＋水色イルカロゴを表示（storyboard なし・`UIColorName=LaunchScreenBackground`〔白〕・`UIImageName=DriftSonarLogo`）
- [x] アイコンと同じイルカ画像（小さめ）を中央配置（`DriftSonarLogo.imageset` 1x/2x/3x PNG・`UIImageRespectsSafeAreaInsets=true`）

**依存**: TASK-113

---

### TASK-115
**Timeline・Radar の空状態イラスト**

`ui` `ios` `P3`

現在の `EmptyTimelineView` / 空状態 View はテキストのみ。イルカのイラストを入れて愛着が湧くようにする。

- [x] 小さいイルカイラストは `DriftSonarLogo`（TASK-113 の PNG）を流用（別アセット追加は不要と判断）
- [x] `EmptyTimelineView`: イルカ + "まだ投稿がありません" + "BLE 圏内に誰かがいるとメッセージが流れてきます"（`TimelineView.swift`）
- [x] Radar（EncounterView）空状態: `EmptyRadarView` を新設しイルカ + "近くにユーザーがいません" + "人が集まる場所へ行ってみましょう"（旧 "No peers found yet..." プレーンテキストを置換）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/EncounterView.swift`（`EmptyRadarView` 新設）、`TimelineView.swift`（既存 `EmptyTimelineView`）

**依存**: TASK-113

---

### TASK-116
**アプリアイコン SVG 素材の作成**

`ui` `ios` `P3`

TASK-113 では Imagen 4 で PNG を直接生成したため、ベクター素材（SVG）が未作成。
TASK-114（LaunchScreen）や将来の解像度対応のために正式な SVG を用意する。

- [x] 1024×1024 px SVG を制作（`design/app-icon.svg`、viewBox 1024）
- [x] Imagen 4 生成の PNG を `potrace` でトレースしイルカ本体（目の穴含む）を抽出、ソナー波3本はパラメトリック円弧で再構成
- [x] SVG を `Assets.xcassets` 外の `design/` フォルダに保存

**備考**: ベクターツール（Figma 等）ではなく `potrace` で PNG をトレース。色は `<style>`（dolphin `#1AA7C0` / sonar `#40C8E0`）で一元管理。`xmllint` 妥当性確認済み・`qlmanage` 描画で元アイコン再現を確認。
**影響ファイル**: `design/app-icon.svg`（新規）
**依存**: TASK-113（PNG は配置済み）

---

## EP-022: 収益化モデル構築

**概要**: App Store 掲載を最優先し収益化は後回しとするが、将来の収益化方針を残す。広告は本アプリの差別化（サーバーレス・無トラッキング・edge 完結・個々人の秘密の話に閉じた SNS）と矛盾するため最終手段。優先は買い切り／プレミアム IAP／投げ銭などサーバー不要・端末内完結の手段。方針の詳細は `docs/monetization.md` を参照。

**Priority**: `P3` | **Labels**: `ios` `devops` `chore`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-117](#task-117) | 収益化方針の意思決定（広告 vs 買い切り vs IAP vs 投げ銭） | `ios` `docs` | P3 | ⬜ |
| [TASK-118](#task-118) | プレミアム機能候補の洗い出し（サーバー不要・端末内完結） | `ios` `docs` | P3 | ⬜ |
| [TASK-119](#task-119) | StoreKit 2 による IAP／投げ銭の技術検証 | `ios` `devops` | P3 | ⬜ |

---

### TASK-117
**収益化方針の意思決定（広告 vs 買い切り vs IAP vs 投げ銭）**

`ios` `docs` `P3`

`docs/monetization.md` の比較を踏まえ、最初に採る収益化手段を1つ決定する。
広告は privacy 整合（`PrivacyInfo.xcprivacy` の `NSPrivacyTracking=false`・収集データなし、プライバシーポリシーの「広告 SDK・トラッキング一切なし」）と矛盾するため、採用する場合はそれらの全面書き換えが前提になることを意思決定の判断材料とする。

- [ ] App Store リリース後のユーザー反応を確認してから判断する（リリース前は確定しない）
- [ ] `docs/monetization.md` の選択肢から第一候補を決定し、決定理由を同ファイルに追記
- [ ] 広告を選ぶ場合は privacy 整合を捨てる影響範囲（ATT・SDK 追加・ポリシー改訂）を明記

**影響ファイル**: `docs/monetization.md`
**依存**: EP-019（App Store 掲載が先）

---

### TASK-118
**プレミアム機能候補の洗い出し（サーバー不要・端末内完結）**

`ios` `docs` `P3`

無料 + プレミアム IAP を採る場合の有料機能候補を、サーバーレス原則を崩さない範囲で洗い出す。

- [ ] カスタムテーマ・アイコンなど見た目系の候補を列挙
- [ ] 伝播統計の可視化、メッセージ保存上限解放など機能系の候補を列挙
- [ ] 各候補が「端末内完結で実装可能か」を ○／× で評価
- [ ] `docs/monetization.md` に候補リストとして追記

**影響ファイル**: `docs/monetization.md`
**依存**: TASK-117

---

### TASK-119
**StoreKit 2 による IAP／投げ銭の技術検証**

`ios` `devops` `P3`

採用方針が IAP／投げ銭の場合、StoreKit 2 で端末内完結（バックエンドなし）の購入フローが組めるか技術検証する。

- [ ] StoreKit 2 の `Product` / `Transaction` で Consumable（投げ銭）・Non-Consumable（買い切り機能解放）を試作
- [ ] レシート検証をサーバーなし（オンデバイス検証）で完結できるか確認
- [ ] App Store Connect の課金アイテム登録フローを確認
- [ ] サンドボックス環境で購入・復元をテスト

**影響ファイル**: 未定（StoreKit 連携の新規ファイル）
**依存**: TASK-117

---

## EP-023: コールドスタート体験の改善

**概要**: BLE メッシュ SNS の宿命的課題。「近くに誰もいない」と何も起きず初回離脱につながる。すれ違い不在時でも価値を感じられる導線（履歴可視化・デモ伝播体験・能動的ガイド）を整備し、最初の数日を乗り越えられるようにする。

**Priority**: `P2` | **Labels**: `ios` `ui` `ble` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-120](#task-120) | すれ違い履歴のタイムライン的可視化 | `ios` `ui` `swiftdata` `feat` | P2 | ⬜ |
| [TASK-121](#task-121) | 初回オンボーディングでのデモ伝播体験 | `ios` `ui` `feat` | P2 | ⬜ |
| [TASK-122](#task-122) | Radar 空状態の能動的ガイド強化 | `ios` `ui` `feat` | P3 | ⬜ |
| [TASK-123](#task-123) | 圏内不在時に自分の過去投稿をリプレイ表示 | `ios` `ui` `feat` | P3 | ⬜ |

---

### TASK-120
**すれ違い履歴のタイムライン的可視化**

`ios` `ui` `swiftdata` `feat` `P2`

`EncounteredEventModel`（encounteredAt・nickname を保持）が永続化されているのに、ユーザーが「いつ・誰と・何人すれ違ったか」を振り返る画面がない。すれ違いそのものを体験価値として可視化する。

- [ ] `EncounterHistoryRepository` に履歴一覧取得（日時降順・件数制限）を追加
- [ ] すれ違い履歴 View を新設（日付セクション + ニックネーム/フィンガープリント + 時刻）
- [ ] Radar タブまたは Profile からの導線を追加
- [ ] 履歴 0 件時の空状態（EP-021 のイルカ流用）

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/ProfileDomain/Repositories.swift`、`DriftSonarApp/DriftSonarApp/Views/`（新規 View）
**依存**: TASK-061, TASK-077

---

### TASK-121
**初回オンボーディングでのデモ伝播体験**

`ios` `ui` `feat` `P2`

初回起動直後は圏内に誰もおらず Timeline が空のまま離脱しやすい。TASK-072 の疑似 BLE 受信フローを応用し、オンボーディングの最後に「すれ違いで投稿が流れてくる」体験を1回だけ演出してコアバリューを伝える。

- [ ] オンボーディング完了時に1回だけ疑似 Post を `MeshForwardingService.receive()` 経由で注入
- [ ] 「近くの誰かから投稿が届きました」と波紋アニメーション（TASK-050）で演出
- [ ] デモ投稿はシステム由来と分かる体裁にし、本物の投稿と混同させない
- [ ] 2回目以降の起動では発火しない（UserDefaults フラグ）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/InitialSetupView.swift`、`DriftSonarApp/DriftSonarApp/ViewModels/`
**依存**: TASK-072, EP-012

---

### TASK-122
**Radar 空状態の能動的ガイド強化**

`ios` `ui` `feat` `P3`

`EmptyRadarView`（TASK-115）はイルカ + テキストのみ。ユーザーが次に取れる行動を能動的に促す。

- [ ] 最後にすれ違った日時を表示（「前回のすれ違い: 3時間前」）
- [ ] 「人が集まる場所で開くと届きやすい」等の具体ヒントをローテーション表示
- [ ] 友人招待 QR（TASK-049）への明示的な導線ボタンを設置

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/EncounterView.swift`
**依存**: TASK-115, TASK-049

---

### TASK-123
**圏内不在時に自分の過去投稿をリプレイ表示**

`ios` `ui` `feat` `P3`

Timeline が完全に空だと無価値に見える。受信投稿が無い間は自分の過去投稿を控えめに表示し、空白を避ける。

- [ ] 受信 Post が 0 件のとき、自分の投稿を「あなたの投稿」セクションとして表示
- [ ] 受信投稿が来たら通常 Timeline に切り替え
- [ ] 自分の投稿のみの状態であることが分かる視覚表現

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/TimelineView.swift`、`DriftSonarApp/DriftSonarApp/ViewModels/TimelineViewModel.swift`

---

## EP-024: SecretMessage 前方秘匿性（Forward Secrecy）

**概要**: 現在の DM は長期 Curve25519(X25519) 鍵の共有秘密を HKDF で固定鍵化し AES-GCM で暗号化する**静的方式**（`SecretMessageService`）。長期秘密鍵が漏洩すると過去・未来すべての DM が復号可能で前方秘匿性がない。「秘密の話に閉じる」というコアバリューに直結するため、メッセージ毎エフェメラル鍵で秘匿性を底上げする。`EncryptedMessage` は現在 `data` のみで鍵情報を運んでいないため、ワイヤーフォーマット拡張が前提。

**Priority**: `P2` | **Labels**: `crypto` `security` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-124](#task-124) | 脅威モデルと方式比較ドキュメント作成 | `crypto` `security` `docs` | P2 | ⬜ |
| [TASK-125](#task-125) | EncryptedMessage ワイヤーフォーマット拡張（version + ephemeral pubkey） | `crypto` `networking` `feat` | P2 | ⬜ |
| [TASK-126](#task-126) | 送信側エフェメラル鍵での暗号化実装 | `crypto` `feat` | P2 | ⬜ |
| [TASK-127](#task-127) | 受信側の復号 + 旧フォーマット後方互換 | `crypto` `feat` | P2 | ⬜ |
| [TASK-128](#task-128) | 前方秘匿性・後方互換の暗号テスト追加 | `test` `crypto` | P2 | ⬜ |

---

### TASK-124
**脅威モデルと方式比較ドキュメント作成**

`crypto` `security` `docs` `P2`

実装前に、どこまでの前方秘匿性を狙うか方針を確定する。BLE すれ違いという非同期・片方向に近い通信特性では完全な Double Ratchet はハンドシェイク往復が成立しにくいため、現実的な落としどころを決める。

- [ ] 脅威モデル整理（長期鍵漏洩・端末押収・MITM）
- [ ] 方式比較: ①現状静的 ②送信毎エフェメラル送信者鍵（ephemeral-static / sealed-sender 風）③Double Ratchet
- [ ] BLE 非同期伝播との相性評価（往復ハンドシェイクの可否）
- [ ] 第一段階として②を採用する前提で、得られる秘匿性の範囲と限界を明記
- [ ] `docs/secret-message-forward-secrecy.md` に記述

**影響ファイル**: `docs/secret-message-forward-secrecy.md`（新規）

---

### TASK-125
**EncryptedMessage ワイヤーフォーマット拡張**

`crypto` `networking` `feat` `P2`

`EncryptedMessage` は `data: Data` のみで、エフェメラル公開鍵を運べない。バージョン識別子付きのフォーマットへ拡張する。

- [ ] 先頭1バイトに version（v1=旧静的 / v2=エフェメラル）を持たせる
- [ ] v2 は `version(1) + ephemeralPublicKey(32) + ciphertext` のレイアウトを定義
- [ ] エンコード/デコードヘルパーを `EncryptedMessage` に追加（バリデーション付き）
- [ ] 不正バイト列は `DecryptionError.invalidData` で棄却

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/SecretMessageDomain/EncryptedMessage.swift`
**依存**: TASK-124

---

### TASK-126
**送信側エフェメラル鍵での暗号化実装**

`crypto` `feat` `P2`

送信ごとに使い捨ての X25519 鍵ペアを生成し、その秘密鍵と受信者の長期公開鍵で共有秘密を作る。送信者の長期秘密鍵が漏れても過去 DM の鍵は再現できないため前方秘匿性が向上する。

- [ ] `SecretMessageService.encrypt` に v2 経路を追加（ephemeral X25519 鍵生成 → 共有秘密 → HKDF → AES-GCM）
- [ ] HKDF salt はプロトコル定数を継続、sharedInfo に version を含める
- [ ] エフェメラル公開鍵を `EncryptedMessage`(v2) に格納（TASK-125 のフォーマット）
- [ ] 送信側エフェメラル秘密鍵は暗号化後に破棄（保持しない）

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/SecretMessageDomain/SecretMessageService.swift`
**依存**: TASK-125

---

### TASK-127
**受信側の復号 + 旧フォーマット後方互換**

`crypto` `feat` `P2`

受信側は version を見て分岐する。v2 はメッセージ内のエフェメラル公開鍵と自分の長期秘密鍵で共有秘密を再計算、v1 は従来通り送信者長期公開鍵で復号し既存チャットを壊さない。

- [ ] `decrypt` を version 分岐に変更（v1=従来 / v2=ephemeral）
- [ ] v2 は `ephemeralPublicKey` + `receiverPrivateKey` で共有秘密を導出
- [ ] 既存の v1 暗号文がそのまま復号できることを確認（破壊的変更を避ける）
- [ ] 未知 version は明示的にエラー

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/SecretMessageDomain/SecretMessageService.swift`
**依存**: TASK-126

---

### TASK-128
**前方秘匿性・後方互換の暗号テスト追加**

`test` `crypto` `P2`

- [ ] v2: 同一平文を2回暗号化すると ephemeral 鍵が異なり暗号文も鍵も異なることを確認
- [ ] v2: 正しい受信者のみ復号でき、別鍵では `authenticationFailed` になることを確認
- [ ] v1 暗号文が引き続き復号できる後方互換テスト
- [ ] 改ざん（1バイト書き換え）で復号が失敗することを確認

**影響ファイル**: `DriftSonarCore/Tests/DriftSonarCoreTests/`
**依存**: TASK-126, TASK-127

---

## EP-025: 相手の鍵検証（Safety Number）

**概要**: DM 相手の公開鍵は BLE 経由で受け取った値を無条件に信用しており、なりすまし・中間者攻撃を検知する手段がない。Signal の Safety Number 相当の、双方の公開鍵から決定的に導く検証用フィンガープリント（数列 + QR）を導入し、対面で突合できるようにする。QR 表示・フィンガープリント基盤（TASK-037 / TASK-049）が既にあるため活用する。

**Priority**: `P2` | **Labels**: `crypto` `security` `ui` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-129](#task-129) | Safety Number 生成ロジック実装 | `crypto` `feat` | P2 | ⬜ |
| [TASK-130](#task-130) | DM の「安全番号を確認」画面（数列 + QR） | `ui` `crypto` `feat` | P2 | ⬜ |
| [TASK-131](#task-131) | QR スキャンによる安全番号突合と verified 保存 | `ui` `crypto` `swiftdata` `feat` | P2 | ⬜ |
| [TASK-132](#task-132) | 検証済みバッジ表示・鍵変更検知の警告 | `ui` `security` `feat` | P2 | ⬜ |

---

### TASK-129
**Safety Number 生成ロジック実装**

`crypto` `feat` `P2`

双方の長期公開鍵から、順序非依存（どちらの端末でも同じ）で決定的な検証コードを生成する。

- [ ] 2つの公開鍵を正規順（バイト列ソート）で連結 → SHA-256 ハッシュ
- [ ] ハッシュを 60桁程度の数列（5桁×ブロック）に変換する `SafetyNumber` 値型を実装
- [ ] 自分と相手どちらの端末でも同一値になることをテスト
- [ ] QR 用のコンパクト表現（ハッシュ生バイト）も提供

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/SecretMessageDomain/`（新規 `SafetyNumber.swift`）
**参考**: `ProfileDomain/PublicKeyFingerprint.swift`

---

### TASK-130
**DM の「安全番号を確認」画面（数列 + QR）**

`ui` `crypto` `feat` `P2`

`SecretMessageView` から相手との安全番号を確認できる画面を追加する。

- [ ] ナビゲーションバー等から「安全番号を確認」へ遷移
- [ ] 安全番号の数列をブロック区切りで表示
- [ ] 同じ安全番号を QR コードとして表示（対面突合用）
- [ ] 「相手と数列が一致すれば安全」の説明文を表示

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/SecretMessageView.swift`（新規検証 View 追加）
**依存**: TASK-129

---

### TASK-131
**QR スキャンによる安全番号突合と verified 保存**

`ui` `crypto` `swiftdata` `feat` `P2`

相手の QR を読み取り、自端末で計算した安全番号と一致するか自動判定して検証済み状態を永続化する。

- [ ] カメラで相手の安全番号 QR をスキャン
- [ ] 自端末計算値と突合し一致/不一致を判定
- [ ] 検証結果（相手公開鍵 + verifiedAt）を SwiftData に保存
- [ ] NSCameraUsageDescription を Info.plist に追加

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/`、`DriftSonarApp/DriftSonarApp/DriftSonarApp/Info.plist`、新規検証状態モデル
**依存**: TASK-129, TASK-130

---

### TASK-132
**検証済みバッジ表示・鍵変更検知の警告**

`ui` `security` `feat` `P2`

検証済みの相手にはバッジを表示し、相手の公開鍵が以前と変わった場合は検証を無効化して警告する。

- [ ] 検証済みの相手の DM・Encounter 行に「✓ 確認済み」バッジを表示
- [ ] 保存済み公開鍵と今回の公開鍵が異なる場合は verified をリセット
- [ ] 鍵変更時に「相手の鍵が変わりました。再確認してください」と警告
- [ ] 未検証/検証済み/鍵変更の3状態を視覚的に区別

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/SecretMessageView.swift`、`EncounterView.swift`
**依存**: TASK-131

---

## EP-026: 公開タイムライン体験の拡張

**概要**: 現状の公開タイムラインは「漂ってきた投稿を眺めるだけ」で、返信・リアクションがない。エンゲージメントを足したいが、「記録に残らない」「あえてオフグリッド」「あえて軽い」というコンセプトと衝突しうるため、**まず方針決定**してから設計に進む。実装着手は App Store 公開後・コンセプト整合性の確認後とする。

**Priority**: `P3` | **Labels**: `ui` `ios` `networking` `feat`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-133](#task-133) | 反応/返信のコンセプト整合性の意思決定 | `docs` `ui` | P3 | ⬜ |
| [TASK-134](#task-134) | 軽量リアクションのメッシュ伝播設計 | `networking` `ui` `feat` | P3 | ⬜ |
| [TASK-135](#task-135) | 投稿への返信（スレッド）の伝播表現設計 | `networking` `feat` | P3 | ⬜ |

---

### TASK-133
**反応/返信のコンセプト整合性の意思決定**

`docs` `ui` `P3`

エンゲージメント機能がコアバリュー（記録に残らない・edge 完結・あえて軽い）と矛盾しないかを先に判断する。「機能を足さない」も選択肢として扱う。

- [ ] リアクション/返信が「漂う SNS」コンセプトを壊さないかを評価
- [ ] 足す場合の最小形（既読/到達ではなく ephemeral な感情表現程度に留める等）の方針を決定
- [ ] 「あえて足さない」結論も許容し、決定理由を記録
- [ ] `docs/concept.md` または新規ドキュメントに方針を追記

**影響ファイル**: `docs/concept.md`

---

### TASK-134
**軽量リアクションのメッシュ伝播設計**

`networking` `ui` `feat` `P3`

TASK-133 で「足す」決定の場合のみ。投稿 ID に対する軽量リアクション（👀 / ♻️ 等）を、メッシュ伝播で集計する仕組みを設計する。

- [ ] リアクションのデータ構造設計（targetPostId + 種別 + 署名）
- [ ] Post と同様に TTL 付きでメッシュ伝播・重複排除する方式の設計
- [ ] 集計値の表示方法（正確な数ではなく「漂ってきた反応」程度の曖昧表示も検討）
- [ ] スパム耐性（EP-006 のレートリミット流用）

**依存**: TASK-133

---

### TASK-135
**投稿への返信（スレッド）の伝播表現設計**

`networking` `feat` `P3`

TASK-133 で「足す」決定の場合のみ。返信を独立した Post として親 ID 参照で伝播させる設計を検討する。親投稿が手元にない端末での表示も含めて考える。

- [ ] 返信を `parentPostId` 付き Post として扱う案を設計
- [ ] 親投稿未到達時の表示（「元の投稿は届いていません」プレースホルダ）
- [ ] スレッドが伝播で断片化する前提の UX 設計
- [ ] 既存 PostSerializer/メッシュ伝播への影響範囲を洗い出し

**依存**: TASK-133

---

## EP-027: UX/UI 磨き込み

**概要**: 機能は揃っているが UI に粗が残る。①表示言語が英語/日本語で混在、②`Color.sonar`/`Color.drift`（TASK-112）を定義済みなのに各 View では未適用で `.blue` がハードコード、③「TTL」など開発者向け用語の露出、④プロフィール編集・設定画面の不在、⑤DM/アクセシビリティの作り込み不足、を解消し、コンセプト（白地＋水色イルカ・フラット）に沿った一貫した体験へ仕上げる。

**Priority**: `P2` | **Labels**: `ui` `ios`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-136](#task-136) | 表示言語の統一（方針決定 + String Catalog 導入） | `ui` `ios` `chore` | P2 | ⬜ |
| [TASK-137](#task-137) | ブランドカラーの全面適用（ハードコード .blue 排除） | `ui` `ios` `chore` | P2 | ⬜ |
| [TASK-138](#task-138) | PostRowView の情報設計改善（脱専門用語・アバター・体裁） | `ui` `ios` `feat` | P2 | ⬜ |
| [TASK-139](#task-139) | プロフィール編集機能（nickname/bio を後から変更） | `ui` `ios` `feat` | P2 | ⬜ |
| [TASK-140](#task-140) | 設定画面の新設（通知・ブロック管理・アプリについて） | `ui` `ios` `feat` | P2 | ⬜ |
| [TASK-141](#task-141) | SecretMessage 画面の作り込み（空状態・時刻・E2E 表示） | `ui` `ios` `feat` | P2 | ⬜ |
| [TASK-142](#task-142) | ComposeView 投稿フィードバックの修正（スピナー不発バグ） | `ui` `ios` `bug` | P2 | ✅ |
| [TASK-143](#task-143) | アクセシビリティ対応（VoiceOver・Dynamic Type） | `ui` `ios` `chore` | P2 | ⬜ |
| [TASK-144](#task-144) | 初回オンボーディングの作り込み（コンセプト説明・権限プライミング） | `ui` `ios` `feat` | P2 | ⬜ |

---

### TASK-136
**表示言語の統一（方針決定 + String Catalog 導入）**

`ui` `ios` `chore` `P2`

英語と日本語が画面ごとに混在している（例: `InitialSetupView` は全英語、`ComposeView`/空状態は日本語、タブ名・Radar は英語）。言語方針を決め、ハードコード文字列を集約する。

- [ ] 方針決定: 日本語統一 / 英語統一 / 日英ローカライズ のいずれかを選ぶ（ターゲットユーザー前提を明記）
- [ ] String Catalog（`.xcstrings`）を導入し、ハードコード文字列を移行
- [ ] 全画面のコピーを方針に揃える（特に `InitialSetupView`・`EncounterView`・タブ名・navigationTitle）
- [ ] 残存する旧文言・トーン不一致を一掃

**影響ファイル**: 全 View、新規 `Localizable.xcstrings`

---

### TASK-137
**ブランドカラーの全面適用（ハードコード .blue 排除）**

`ui` `ios` `chore` `P2`

TASK-112 で `Color.sonar`(#40C8E0)/`Color.drift`(#1AA7C0) を定義したが各 View で未使用。`SecretMessageView` のバブル・送信ボタンは `Color.blue` のままでブランドと不整合。

- [ ] `SecretMessageView` の自分バブル背景・送信アイコンをブランドカラーに変更
- [ ] アプリ全体でハードコードされた `.blue` を洗い出してブランドカラー or `.accentColor` に統一
- [ ] `hopBadge` の配色（直接=青…）がブランド水色と衝突しないか見直し
- [ ] Light/Dark 双方で発色を確認

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/SecretMessageView.swift`、`TimelineView.swift` ほか

---

### TASK-138
**PostRowView の情報設計改善（脱専門用語・アバター・体裁）**

`ui` `ios` `feat` `P2`

`PostRowView` は「TTL 6」という開発者向け用語をそのまま表示し、投稿者は小さな caption のみで視認性が低い。

- [ ] 「TTL n」をユーザー向け表現に変更（例: 残り寿命のアイコン化、または非表示／デバッグ時のみ）
- [ ] 公開鍵由来の identicon（決定的な色/図形アバター）を投稿者に付与
- [ ] 行をカード体裁または余白調整で可読性を向上（コンセプトのフラット感に合わせる）
- [ ] hopCount バッジとの情報量バランスを調整

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/TimelineView.swift`

---

### TASK-139
**プロフィール編集機能（nickname/bio を後から変更）**

`ui` `ios` `feat` `P2`

セットアップ後に nickname/bio を変更する導線がなく、`ProfileView` は表示専用。

- [ ] `ProfileView` に編集画面（シート）への導線を追加
- [ ] nickname/bio を編集し `UserProfileRepository` 経由で更新（バリデーションは TASK-075 と統一）
- [ ] nickname 変更を BLE Characteristic（TASK-076）の公開値へ反映
- [ ] 公開鍵は不変であることを UI で明示（編集対象外）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/ContentView.swift`（ProfileView）、`ProfileDomain/`

---

### TASK-140
**設定画面の新設（通知・ブロック管理・アプリについて）**

`ui` `ios` `feat` `P2`

通知の ON/OFF、ブロック済みユーザーの解除、アプリ情報（バージョン・プライバシーポリシー）への入り口がない。

- [ ] Profile またはツールバーから「設定」への導線を追加
- [ ] 通知許可状態の表示と設定アプリへの導線
- [ ] ブロック済み公開鍵の一覧表示・解除（`BlockedKeyModel` の削除）
- [ ] アプリについて（バージョン・プライバシーポリシー URL・OSS ライセンス等）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/`（新規 SettingsView）

---

### TASK-141
**SecretMessage 画面の作り込み（空状態・時刻・E2E 表示）**

`ui` `ios` `feat` `P2`

`SecretMessageView` はメッセージ0件時が空白・各メッセージに時刻がなく・E2E 暗号であることの明示もない。

- [ ] メッセージ0件時の空状態（「まだメッセージはありません」＋ E2E 説明）
- [ ] 各メッセージバブルに送信時刻を表示
- [ ] 画面に「🔒 端末間で暗号化」等の安心バッジを表示（EP-025 の検証バッジと整合）
- [ ] 送信ボタン・バブルのブランドカラー化（TASK-137 と連携）

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/SecretMessageView.swift`
**依存**: TASK-137

---

### TASK-142
**ComposeView 投稿フィードバックの修正（スピナー不発バグ）**

`ui` `ios` `bug` `P2`

`ComposeView` は `isPosting = true` の直後に同期で `false` に戻し `dismiss()` するため、`ProgressView`（TASK-089）が一度も表示されない。

- [x] 投稿処理の完了を待ってから `isPosting` を戻す（`onSubmit` を `async -> AppError?` 化し `Task` 内で完了待ち）
- [x] 投稿成功までシートを閉じず、失敗時はエラー表示してシートを維持（成功時のみ `dismiss()`、失敗は `postError` をシート内 `errorAlert` で提示）
- [x] 投稿中は二重送信を防止（投稿中はボタンを `ProgressView` に差し替え、キャンセルも `isPosting` で無効化）

**実装メモ**: `TimelineViewModel.createPost` を戻り値 `AppError?`（nil=成功）に変更し post 失敗を `self.error`（fetch 専用）から分離。`ComposeView` は `Task` で `await onSubmit` の完了を待ち、成功時のみ閉じる。TASK-154 の `errorAlert` をシート内で再利用。

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/ComposeView.swift`、`TimelineView.swift`、`ViewModels/TimelineViewModel.swift`

---

### TASK-143
**アクセシビリティ対応（VoiceOver・Dynamic Type）**

`ui` `ios` `chore` `P2`

アイコンのみのボタン（送信・投稿作成・QR）に `accessibilityLabel` がなく VoiceOver で意味が伝わらない。

- [ ] アイコンボタンに `accessibilityLabel` を付与（送信・新規投稿・QR表示・ブロック等）
- [ ] hopCount/TTL バッジに読み上げ用ラベルを付与
- [ ] Dynamic Type（特大文字）でレイアウト崩れがないか確認・修正
- [ ] 色のみで意味を伝えている箇所にテキスト/形を補完（hopBadge は対応済みか確認）

**影響ファイル**: 全 View

---

### TASK-144
**初回オンボーディングの作り込み（コンセプト説明・権限プライミング）**

`ui` `ios` `feat` `P2`

`InitialSetupView` は素の Form のみで、DriftSonar が何のアプリか・なぜ Bluetooth/通知が要るかの説明がない。初回離脱の一因。

- [ ] セットアップ前にコンセプト紹介（オフライン伝播・E2E DM・秘密に閉じた SNS）の数ページを表示
- [ ] Bluetooth/通知の権限を要求する前に理由を説明するプライミング画面
- [ ] 既存のニックネーム/bio 入力へ自然につなげる
- [ ] EP-023 のデモ伝播体験（TASK-121）と接続

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/InitialSetupView.swift`（新規オンボーディング View）
**依存**: TASK-121（任意連携）

---

## EP-028: バッテリー・省電力と診断

**概要**: `BLEEncounterService` は常時スキャン（`CBCentralManagerScanOptionAllowDuplicatesKey: false`）＋常時アドバタイズで、デューティサイクリングやバッテリー状態に応じた制御がない。常時 BLE 動作はバッテリーを著しく消費し、実利用での継続率を下げる。取得済みだが未活用の RSSI を近接度に活かし、メッシュ/BLE の動作状況を可視化する診断面も整える。

**Priority**: `P2` | **Labels**: `ble` `ios` `networking`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-145](#task-145) | BLE スキャンのデューティサイクリング（間欠スキャン） | `ble` `ios` `feat` | P2 | ⬜ |
| [TASK-146](#task-146) | バッテリー残量・低電力モードに応じた挙動調整 | `ble` `ios` `feat` | P2 | ⬜ |
| [TASK-147](#task-147) | RSSI を使った近接度フィルタ・表示 | `ble` `ui` `feat` | P3 | ⬜ |
| [TASK-148](#task-148) | メッシュ/BLE 診断画面（受信・転送・接続統計） | `ios` `ui` `networking` `feat` | P2 | ⬜ |

---

### TASK-145
**BLE スキャンのデューティサイクリング（間欠スキャン）**

`ble` `ios` `feat` `P2`

現状は連続スキャンのため電力消費が大きい。一定周期でスキャン ON/OFF を切り替える間欠スキャンに変更し、発見性能と電力のバランスを取る。

- [ ] スキャン ON 秒 / OFF 秒の周期をパラメータ化（例: 10秒 ON / 20秒 OFF）
- [ ] アドバタイズは継続しつつスキャンのみ間欠化（受動発見を優先）
- [ ] フォアグラウンド/バックグラウンドで周期を変える
- [ ] 周期はデバッグで調整できるよう定数化

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`

---

### TASK-146
**バッテリー残量・低電力モードに応じた挙動調整**

`ble` `ios` `feat` `P2`

低バッテリー時に常時 BLE が継続すると体験が悪い。電力状態に応じてスキャン頻度を落とす。

- [ ] `ProcessInfo.isLowPowerModeEnabled` を監視
- [ ] 低電力モード時はスキャン周期を延長 or 一時停止
- [ ] バッテリー残量しきい値（例: 20%未満）で省電力モードに移行
- [ ] 省電力中であることを Radar 画面で軽く明示

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`、`DriftSonarApp/DriftSonarApp/Views/EncounterView.swift`
**依存**: TASK-145

---

### TASK-147
**RSSI を使った近接度フィルタ・表示**

`ble` `ui` `feat` `P3`

`didDiscover` で RSSI を取得済みだが未活用。近接度の可視化や、極端に遠いピアの接続抑制に使う。

- [ ] ピア行に電波強度（近い/普通/遠い）を表示
- [ ] RSSI が一定値未満のピアへの接続試行を抑制（任意）
- [ ] RSSI の揺らぎをならす平滑化（移動平均）

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/BLEEncounterService.swift`、`DriftSonarApp/DriftSonarApp/Views/EncounterView.swift`

---

### TASK-148
**メッシュ/BLE 診断画面（受信・転送・接続統計）**

`ios` `ui` `networking` `feat` `P2`

TASK-070 のオプション残件（メッシュ統計バッジ）を発展させ、伝播が機能しているかをユーザー/開発者が確認できる診断画面を作る。

- [ ] 受信件数・転送件数・棄却件数・接続中ピア数を集計
- [ ] 設定画面（TASK-140）配下に診断画面を配置
- [ ] デバッグビルドでは詳細ログ、リリースでは要約のみ
- [ ] TASK-070 の統計バッジ案をここに統合

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/MeshForwardingService.swift`、`DriftSonarApp/DriftSonarApp/Views/`（新規診断 View）
**依存**: TASK-070, TASK-140

---

## EP-029: データライフサイクルとプライバシー実務

**概要**: コアバリューは「記録に残らない会話」だが、実装上は投稿・DM・すれ違い履歴がすべて永続化され、消す手段もない。コンセプトと実装の乖離を埋める。投稿/キャッシュの自動失効、DM の消えるメッセージ、全データ消去（パニックワイプ）を整備し、エクスポート可否はコンセプトと照らして方針決定する。

**Priority**: `P2` | **Labels**: `swiftdata` `security` `ios`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-149](#task-149) | 投稿・キャッシュ自動失効の実動作確認と有効期限の可視化 | `swiftdata` `networking` `feat` | P2 | ⬜ |
| [TASK-150](#task-150) | 消えるメッセージ（DM 自動削除オプション） | `swiftdata` `crypto` `feat` | P3 | ⬜ |
| [TASK-151](#task-151) | 全データ消去（パニックワイプ） | `security` `swiftdata` `feat` | P2 | ⬜ |
| [TASK-152](#task-152) | データエクスポート/バックアップ方針の決定 | `security` `docs` | P3 | ⬜ |

---

### TASK-149
**投稿・キャッシュ自動失効の実動作確認と有効期限の可視化**

`swiftdata` `networking` `feat` `P2`

TASK-014（TTL/期限切れ削除）・TASK-017/099（エビクション）が設計・実装済みだが、定期削除が実際に走っているか・ユーザーに有効期限が見えるかは未確認。コンセプト「記録に残らない」を体験として担保する。

- [ ] 期限切れ投稿/キャッシュの定期削除が実機・起動時に確実に走ることを確認（必要ならスケジューラ追加）
- [ ] 投稿に「あと N 時間で消えます」等の残り寿命表示（TASK-138 と整合）
- [ ] 失効ポリシー（保持期間）を定数として一元化・ドキュメント化
- [ ] 削除イベントを診断（TASK-148）に反映

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/`、`PostDomain/`
**依存**: TASK-014, TASK-099

---

### TASK-150
**消えるメッセージ（DM 自動削除オプション）**

`swiftdata` `crypto` `feat` `P3`

「記録に残らない」を DM にも適用。閲覧後または一定時間で DM を自動削除するオプションを設ける。

- [ ] `SecretMessageModel` に有効期限/閲覧後削除フラグを追加
- [ ] 会話ごとに消える設定を切り替えられる UI
- [ ] 期限到来・閲覧後の自動削除処理
- [ ] 相手側にも同じ削除指示を伝播する設計（不可なら自端末のみと明記）

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/SecretMessageDomain/`、`DriftSonarApp/DriftSonarApp/Views/SecretMessageView.swift`

---

### TASK-151
**全データ消去（パニックワイプ）**

`security` `swiftdata` `feat` `P2`

端末押収・紛失時に備え、投稿・DM・すれ違い履歴・鍵を一括消去する機能を設ける。

- [ ] 設定画面（TASK-140）に「すべてのデータを消去」を配置（二重確認）
- [ ] SwiftData の全モデル削除 + Keychain の鍵削除 + UserDefaults クリア
- [ ] 消去後は初回セットアップ状態に戻る
- [ ] （任意）パスコード/Face ID による保護や偽装パスコード等は別途検討

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/`（SettingsView）、`ProfileDomain/KeychainService.swift`
**依存**: TASK-140

---

### TASK-152
**データエクスポート/バックアップ方針の決定**

`security` `docs` `P3`

エクスポート/バックアップは利便性とコンセプト（記録に残らない・edge 完結）が衝突するため、足すか否かを先に判断する。

- [ ] エクスポート/iCloud バックアップがコンセプトと矛盾しないか評価
- [ ] 採用する場合は端末内完結・暗号化エクスポートの範囲を定義
- [ ] 鍵バックアップ（EP-007 の複数デバイス設計）との関係を整理
- [ ] 結論を `docs/` に記録（足さない判断も可）

**影響ファイル**: `docs/`（新規 or 既存設計ドキュメント）
**依存**: TASK-039

---

## EP-030: 堅牢性とエラーハンドリング

**概要**: Keychain ロード失敗を `?? Data()` で無音フォールバックしている箇所があり（`EncounterView.swift:92`・`TimelineView.swift:76`）、鍵取得失敗時に空データで署名/復号が静かに壊れる。失敗を握りつぶさず、ユーザーに伝わる形でハンドリングし、起動時の整合性も担保する。

**Priority**: `P2` | **Labels**: `ios` `security`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-153](#task-153) | Keychain ロード失敗の安全な処理（無音フォールバック排除） | `security` `ios` `bug` | P2 | ✅ |
| [TASK-154](#task-154) | ユーザー向けエラー表示の統一 | `ui` `ios` `feat` | P2 | ✅ |
| [TASK-155](#task-155) | 起動時の鍵・プロファイル整合性チェック | `security` `ios` `feat` | P2 | ✅ |

---

### TASK-153
**Keychain ロード失敗の安全な処理（無音フォールバック排除）**

`security` `ios` `bug` `P2`

`(try? KeychainService.load(...)) ?? Data()` は失敗時に空 Data を使い、無効な署名・復号不能を引き起こす。失敗を明示的に扱う。

- [x] `EncounterView.swift:92`・`TimelineView.swift:76` の `?? Data()` を排除
- [x] 鍵が取得できない場合は投稿/送信を中止しエラー提示（TASK-154 と連携）
- [x] 鍵取得ロジックを View から外し、ViewModel/サービス層に集約
- [x] 同様パターンが他にないか全体を点検（`SwiftDataUserRepository.getUser()` の `?? Data()` も loud failure 化）

**実装メモ**: `KeychainService` に typed accessor（`loadAgreementPrivateKey()` / `loadSigningPrivateKey()`）を追加し鍵取得を集約。`TimelineViewModel.createPost` は署名鍵を内部ロードし失敗時は `errorMessage` で中止、`SecretMessageViewModel` は agreement 鍵を `setup` でロードし `myPrivateKey: Data?` の guard で送受信を保護。View 層は Keychain を直接触らなくなった。

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/EncounterView.swift`、`TimelineView.swift`、`SecretMessageView.swift`、`ViewModels/TimelineViewModel.swift`、`SecretMessageViewModel.swift`、`DriftSonarCore/.../KeychainService.swift`、`SwiftDataUserRepository.swift`
**依存**: TASK-055

---

### TASK-154
**ユーザー向けエラー表示の統一**

`ui` `ios` `feat` `P2`

暗号化失敗・BLE 失敗・投稿失敗などのエラーが握りつぶされたり ad hoc に表示されている。統一した提示方法を整える。

- [x] 共通のエラー表示（アラート）を定義（`AppError` + `.errorAlert(_:onRetry:)` View 修飾子）
- [x] 暗号失敗・鍵不在・BLE 不可・投稿失敗を分類し適切なメッセージを出す
- [x] リカバリ可能なものは再試行導線を提供（`isRetryable` + `onRetry` で「再試行」ボタン表示）
- [x] 機微情報をエラー文に出さない（crypto/Keychain の `localizedDescription` は出力せず定型文に統一）

**実装メモ**: `AppError`（`keyUnavailable` / `encryptionFailed` / `bluetoothUnavailable` / `postFailed` / `message(String)`）と `errorAlert` 修飾子を新設。`TimelineViewModel` / `SecretMessageViewModel` の `errorMessage: String?` を `error: AppError?` に統一し、`TimelineView` の `.constant` バインディング誤用も解消。BLE 不可は既存の常時バナー（TASK-093）に集約済みのため再アラートせず。フォーム入力検証（`InitialSetupViewModel`）は別パターンのためインライン表示を維持。

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/AppError.swift`（新規）、`Views/TimelineView.swift`、`SecretMessageView.swift`、`ViewModels/TimelineViewModel.swift`、`SecretMessageViewModel.swift`

---

### TASK-155
**起動時の鍵・プロファイル整合性チェック**

`security` `ios` `feat` `P2`

プロファイルは存在するが Keychain の鍵が欠落、等の不整合状態を起動時に検知して自己修復 or 案内する。

- [x] 起動時に「プロファイル有 ⇔ 対応する鍵が Keychain に有」を検証
- [x] 不整合時の挙動を定義（`ProfileIntegrityErrorView` で案内＋再セットアップ導線。全データ消去は TASK-151 に委譲）
- [x] 公開鍵とプロファイルの対応が壊れていないか確認（秘密鍵から公開鍵を導出して突合し `keyMismatch` を検出）
- [x] 検証ロジックを `AppServices` 初期化時に実行

**実装メモ**: Core に `ProfileIntegrity.verify(publicKey:signingPublicKey:) -> Status(.ok/.keysMissing/.keyMismatch)` を新設（Keychain から秘密鍵をロードし X25519/Ed25519 公開鍵を導出して突合）。`AppServices.init` で実行し `integrityStatus` を保持、`ContentView` が `.ok` 以外なら `ProfileIntegrityErrorView` を表示。回復は対象プロファイル＋Keychain 鍵を削除して初期セットアップへ戻す。Core ユニットテスト3件追加。

**影響ファイル**: `DriftSonarCore/.../ProfileIntegrity.swift`（新規）、`DriftSonarApp/DriftSonarApp/DriftSonarApp/AppServices.swift`、`ContentView.swift`、`Tests/.../ProfileIntegrityTests.swift`（新規）
**依存**: TASK-153

---

## EP-031: 国際化と配信戦略

**概要**: TASK-136（アプリ内の言語統一・String Catalog）を前提に、App Store 上の配信地域・対応言語・メタデータのローカライズを決める。アプリ内 i18n（TASK-136）とは別に、ストア掲載面（説明・キーワード・スクショ・権限文言）の多言語化と配信地域戦略を扱う。

**Priority**: `P3` | **Labels**: `ios` `devops` `docs`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-156](#task-156) | 配信地域・対応言語の決定とローカライズ範囲確定 | `docs` `ios` | P3 | ⬜ |
| [TASK-157](#task-157) | App Store メタデータのローカライズ（説明・キーワード・スクショ） | `ios` `devops` | P3 | ⬜ |
| [TASK-158](#task-158) | 権限文言・システムダイアログの多言語化 | `ios` `chore` | P3 | ⬜ |

---

### TASK-156
**配信地域・対応言語の決定とローカライズ範囲確定**

`docs` `ios` `P3`

最初にどの国・言語で出すかを決める。BLE すれ違いは人口密度に依存するため、初期はターゲット地域を絞る戦略も検討する。

- [ ] 初期配信地域（例: 日本のみ → 段階拡大）を決定
- [ ] 対応言語（日本語/英語/その他）の優先順位を決定
- [ ] ローカライズ対象範囲（アプリ内のみ / ストア掲載も）を確定
- [ ] 決定理由を `docs/` に記録

**影響ファイル**: `docs/`（新規 or 既存配信ドキュメント）
**依存**: TASK-136

---

### TASK-157
**App Store メタデータのローカライズ（説明・キーワード・スクショ）**

`ios` `devops` `P3`

App Store Connect の掲載情報を対応言語ごとに用意する。

- [ ] アプリ説明文・サブタイトル・キーワードを言語別に作成
- [ ] スクリーンショットを言語別に用意（デモシード TASK-107 を活用）
- [ ] What's New（リリースノート）の多言語テンプレート
- [ ] ASO（キーワード最適化）を TASK-156 の地域戦略と整合

**影響ファイル**: App Store Connect（コード外）、`docs/app-store-release.md`
**依存**: TASK-156, TASK-107

---

### TASK-158
**権限文言・システムダイアログの多言語化**

`ios` `chore` `P3`

Bluetooth・通知・カメラ（TASK-131）等の Usage Description を対応言語にローカライズする。

- [ ] `InfoPlist.xcstrings`（または言語別 InfoPlist.strings）で Usage Description を多言語化
- [ ] 位置情報を追跡しない旨を各言語で明記（TASK-172 と整合）
- [ ] システムアラート文言の翻訳レビュー

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/Info.plist`、新規 InfoPlist ローカライズ
**依存**: TASK-136, TASK-172

---

## EP-032: テスト拡充（App層・UI・スナップショット）

**概要**: `DriftSonarCore`（Swift Package）には unit テストがあるが、App ターゲット（`DriftSonarApp.xcodeproj`）にはテストターゲットが一切なく、ViewModel・View・主要動線のテストカバレッジがゼロ。App 層の単体テスト・XCUITest・スナップショットテストを整備し、UI リグレッションを防ぐ。

**Priority**: `P2` | **Labels**: `test` `ios` `devops`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-159](#task-159) | App ターゲットに単体テストを追加し ViewModel をテスト | `test` `ios` | P2 | ⬜ |
| [TASK-160](#task-160) | 主要動線の XCUITest（初期設定→投稿→Radar→DM） | `test` `ios` | P2 | ⬜ |
| [TASK-161](#task-161) | スナップショットテスト導入（主要 View の見た目回帰） | `test` `ios` `devops` | P3 | ⬜ |
| [TASK-162](#task-162) | CI に App テストを統合 | `devops` `test` | P2 | ⬜ |

---

### TASK-159
**App ターゲットに単体テストを追加し ViewModel をテスト**

`test` `ios` `P2`

App ターゲットにテストターゲットがないため、`TimelineViewModel`・`EncounterViewModel`・`SecretMessageViewModel`・`InitialSetupViewModel` がテストされていない。

- [ ] `DriftSonarApp.xcodeproj` に Unit Test ターゲットを追加
- [ ] ViewModel のビジネスロジック（投稿生成・refresh・エラー処理）をテスト
- [ ] モック/InMemory リポジトリを用意（Core 側の既存パターン流用）
- [ ] `?? Data()` 是正（TASK-153）後の鍵不在ハンドリングをテスト

**影響ファイル**: `DriftSonarApp/`（新規テストターゲット）
**依存**: TASK-153

---

### TASK-160
**主要動線の XCUITest（初期設定→投稿→Radar→DM）**

`test` `ios` `P2`

UI 主要フローの回帰を自動検出する。run-ios スキルの手動スモークを自動化する位置づけ。

- [ ] UI Test ターゲットを追加
- [ ] 初期セットアップ（ニックネーム入力→プロフィール作成）の動線テスト
- [ ] 投稿作成→Timeline 反映の動線テスト
- [ ] Radar 表示・デモデータ投入（DEBUG）の動線テスト
- [ ] アクセシビリティ識別子を主要要素に付与（TASK-143 と連携）

**影響ファイル**: `DriftSonarApp/`（新規 UITest ターゲット）
**依存**: TASK-143（識別子）

---

### TASK-161
**スナップショットテスト導入（主要 View の見た目回帰）**

`test` `ios` `devops` `P3`

ブランドカラー適用（TASK-137）や UX 改修（EP-027）での意図しない見た目崩れを検出する。

- [ ] スナップショットテスト基盤を導入（swift-snapshot-testing 等の採用可否を判断）
- [ ] `PostRowView`・`EmptyTimelineView`・`MessageBubble` 等の主要コンポーネントを対象
- [ ] Light/Dark・Dynamic Type の主要バリアントを撮影
- [ ] 基準画像の管理方針を決定

**影響ファイル**: `DriftSonarApp/`（新規テスト）
**依存**: TASK-137

---

### TASK-162
**CI に App テストを統合**

`devops` `test` `P2`

EP-008（TASK-042/102）で Core のテストを CI 実行する基盤がある。App 層テストも CI に載せる。

- [ ] `xcodebuild test` で App の Unit/UI テストを実行するジョブを追加
- [ ] Simulator 指定・実行時間の最適化
- [ ] テスト失敗時に PR をブロック
- [ ] カバレッジを既存レポート（TASK-044）に合流

**影響ファイル**: `.github/workflows/`
**依存**: TASK-159, TASK-102

---

## EP-033: メッシュプロトコルのバージョニングと将来互換

**概要**: `PostSerializer` の wire format は固定レイアウトで**プロトコルバージョンを持たない**。一度配布すると、フィールド追加やレイアウト変更で旧バージョンとのメッシュ伝播が壊れ、互換性ネゴシエーションの手段もない。分散・非同期で更新が揃わない mesh では将来互換が死活問題。バージョン識別と未知データの扱いを定義する。

**Priority**: `P2` | **Labels**: `networking` `crypto`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-163](#task-163) | PostSerializer にプロトコルバージョンを導入 | `networking` `feat` | P2 | ⬜ |
| [TASK-164](#task-164) | 未知バージョン/未知フィールドの前方互換ポリシー策定 | `networking` `docs` `feat` | P2 | ⬜ |
| [TASK-165](#task-165) | ピア間プロトコルバージョンのネゴシエーション設計 | `ble` `networking` `feat` | P3 | ⬜ |
| [TASK-166](#task-166) | BLE サービス/Characteristic UUID のバージョニング方針 | `ble` `networking` `docs` | P3 | ⬜ |

---

### TASK-163
**PostSerializer にプロトコルバージョンを導入**

`networking` `feat` `P2`

`PostSerializer` の先頭にバージョンバイトを追加し、将来のフォーマット拡張に備える。配布前に入れておかないと後付けが困難。

- [ ] wire format 先頭1バイトに `protocolVersion`（v1）を追加
- [ ] `decode` で version を読み、未対応 version は明示エラー
- [ ] 既存テスト（PostDomainTests）をバージョン付きに更新
- [ ] `EncryptedMessage`（EP-024 TASK-125）のバージョニングと方針を揃える

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/PostDomain/PostSerializer.swift`
**依存**: TASK-125（方針統一）

---

### TASK-164
**未知バージョン/未知フィールドの前方互換ポリシー策定**

`networking` `docs` `feat` `P2`

新しい版が増やしたフィールドを、古い版が受け取ったときどう振る舞うか（棄却 vs 既知部分のみ処理して転送）を決める。mesh では「理解できないが転送はする」が伝播維持に重要。

- [ ] 未知 version の Post を「棄却」か「中身を解さず転送のみ」かを決定
- [ ] TLV 等の拡張可能フォーマットへの移行可否を評価
- [ ] 署名検証と未知フィールドの関係を整理（署名対象範囲の固定）
- [ ] ポリシーを `docs/` に記録

**影響ファイル**: `docs/`（新規プロトコル仕様）、`MeshDomain/`
**依存**: TASK-163

---

### TASK-165
**ピア間プロトコルバージョンのネゴシエーション設計**

`ble` `networking` `feat` `P3`

BLE 接続時に相手の対応バージョンを把握し、共通の最小バージョンで通信する仕組みを設計する。

- [ ] バージョン交換用の Characteristic or アドバタイズ拡張を設計
- [ ] 共通バージョンへのフォールバック規則を定義
- [ ] 非互換ピアとの接続時の挙動を定義
- [ ] TASK-015（キャッシュ同期プロトコル）との整合

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/EncounterDomain/`
**依存**: TASK-163, TASK-164

---

### TASK-166
**BLE サービス/Characteristic UUID のバージョニング方針**

`ble` `networking` `docs` `P3`

将来 GATT 構成を変える場合に、サービス UUID や Characteristic UUID をどう増設/移行するかの方針を決める。

- [ ] サービス UUID をバージョンで変える/固定するの方針決定
- [ ] 新旧 Characteristic の併存・段階移行の手順
- [ ] 旧版アプリとの相互運用の限界を明記
- [ ] `docs/design-notes.md` の BLE UUID 節に追記

**影響ファイル**: `docs/design-notes.md`、`EncounterDomain/`
**依存**: TASK-165

---

## EP-034: App Store 対策（審査リスク低減）

**概要**: EP-019（提出メカニクス）とは別に、**審査を通すための実装・申告・審査メモ**を整える。本アプリはサーバーレスの匿名 UGC・バックグラウンド BLE・E2E 暗号という、Apple が厳しく見る要素が揃っているため、ガイドライン整合を能動的に作り込む。リジェクト要因と対策は Gemini による App Store Review Guidelines 分析を反映。

**Priority**: `P2` | **Labels**: `ios` `security` `devops` `docs`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-167](#task-167) | UGC モデレーション要件の充足（EULA・通報・即時ブロック・NGワード） | `ios` `security` `feat` | P1 | ⬜ |
| [TASK-168](#task-168) | 17+ 年齢確認ゲートとレーティング設定 | `ios` `feat` | P2 | ⬜ |
| [TASK-169](#task-169) | バックグラウンド BLE のユーザー制御と正当性明記 | `ble` `ios` `feat` | P2 | ⬜ |
| [TASK-170](#task-170) | 単独端末で機能が伝わるデモ手段と審査用デモ動画 | `ios` `devops` `feat` | P1 | ⬜ |
| [TASK-171](#task-171) | 暗号輸出申告の再評価（ITSAppUsesNonExemptEncryption） | `ios` `security` `docs` | P2 | ⬜ |
| [TASK-172](#task-172) | プライバシー権限文言の強化（位置情報非追跡の明記） | `ios` `chore` | P2 | ⬜ |

---

### TASK-167
**UGC モデレーション要件の充足（EULA・通報・即時ブロック・NGワード）**

`ios` `security` `feat` `P1`

GL 1.2（User Generated Content）はサーバーレス匿名 SNS で最大のリジェクト要因。中央監視ができない代わりに、端末側の自律モデレーションで「不快コンテンツを即時遮断できる」ことを証明する。ブロック（TASK-033/087）は実装済みだが、EULA 同意・通報・NG ワードが欠けている。

- [ ] 初回起動時に「不適切コンテンツ禁止」EULA への同意を必須化
- [ ] 投稿・ユーザー単位の「通報」機能（サーバーなしのため通報＝即時ローカル遮断として機能）
- [ ] ブロックの即時反映を担保（既存 TASK-033/087 を仕様として明文化）
- [ ] ローカル NG ワードフィルタ（該当投稿を伏せ字/非表示）
- [ ] 審査メモに「完全オフラインのため即時ブロックで 24h 対応要件を満たす」と明記

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/`、`BlockDomain/`、`docs/app-store-release.md`
**依存**: TASK-033, TASK-087

---

### TASK-168
**17+ 年齢確認ゲートとレーティング設定**

`ios` `feat` `P2`

匿名・無監視 SNS は成人向けコンテンツの温床とみなされやすく、子供の安全性で厳しく審査される。

- [ ] App Store Connect の年齢レーティングを 17+ に設定
- [ ] 初回起動時に年齢確認ゲート（17歳以上か）を表示
- [ ] レーティングとガイドラインの整合を審査メモに記載
- [ ] （任意）画像を扱う場合の端末内 NSFW 検出は別途検討（現状テキストのみなら明記）

**影響ファイル**: App Store Connect、`DriftSonarApp/DriftSonarApp/Views/`（オンボーディング、TASK-144 と連携）
**依存**: TASK-144

---

### TASK-169
**バックグラウンド BLE のユーザー制御と正当性明記**

`ble` `ios` `feat` `P2`

GL 2.5.4。バックグラウンド BLE はコア機能であることの主張と、ユーザー制御の両方が要る。

- [ ] 設定画面（TASK-140）に「バックグラウンド通信オン/オフ」トグルを追加
- [ ] オン時に「バッテリーを消費します」警告を表示
- [ ] 審査メモに「Store-and-Forward mesh のコア機能であり背景 BLE が主目的」と明記
- [ ] 省電力制御（EP-028）と挙動を整合

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/`（SettingsView）、`EncounterDomain/`、`docs/app-store-release.md`
**依存**: TASK-140, TASK-145

---

### TASK-170
**単独端末で機能が伝わるデモ手段と審査用デモ動画**

`ios` `devops` `feat` `P1`

GL 4.2 / 2.1。審査員は基本 1 台でテストするため、周囲に端末がなく「真っ白な画面」だと最小機能未達でリジェクトされる。

- [ ] 周囲に端末がなくても機能が試せる導線（案内ボット/システムメッセージ、または単独でも投稿が見える）を実装（EP-023 TASK-121/123 と連携）
- [ ] 実機 2 台での伝播・E2E DM の動作を録画したデモ動画を用意
- [ ] 審査メモにデモ動画 URL と「近接 2 台で伝播・単体で UI 確認可」を明記
- [ ] DEBUG の疑似 BLE 受信（TASK-072）をリリースでも安全に使えるデモモード化を検討

**影響ファイル**: `DriftSonarApp/DriftSonarApp/Views/`、`docs/app-store-release.md`
**依存**: TASK-121, TASK-123, TASK-072

---

### TASK-171
**暗号輸出申告の再評価（ITSAppUsesNonExemptEncryption）**

`ios` `security` `docs` `P2`

TASK-106 で `ITSAppUsesNonExemptEncryption = false`（適用除外）と申告したが、E2E 暗号 DM がコア機能のため `false` が正しいか再評価が必要。誤申告はコンプライアンス違反になる。

- [ ] 使用暗号（Curve25519/AES-GCM/HKDF）が適用除外カテゴリに該当するか精査
- [ ] 該当しない場合は `true` に変更し、自己分類報告（ERN/年次）の要否を確認
- [ ] App Store Connect の暗号化質問への正しい回答を確定
- [ ] 結論と根拠を `docs/app-store-release.md` に記録

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/Info.plist`、`docs/app-store-release.md`
**依存**: TASK-106

---

### TASK-172
**プライバシー権限文言の強化（位置情報非追跡の明記）**

`ios` `chore` `P2`

GL 5.1。すれ違い通信は「裏で位置情報を追跡しているのでは」と疑われやすい。権限文言で明確に否定する。

- [ ] `NSBluetoothAlwaysUsageDescription` 等に「近接オフライン通信のみに使用・位置情報は追跡しない」と明記（英語版も "Location is NOT tracked."）
- [ ] `CoreLocation` を import/要求していないことを確認・維持
- [ ] プライバシーポリシー（TASK-105）に「サーバー不在・端末間直接・識別子は使い捨て公開鍵」を明記済みか確認
- [ ] `PrivacyInfo.xcprivacy`（TASK-105）の申告と矛盾がないか確認

**影響ファイル**: `DriftSonarApp/DriftSonarApp/DriftSonarApp/Info.plist`、`docs/privacy-policy.md`
**依存**: TASK-105

---

## EP-035: メッシュ・セキュリティ堅牢化（脅威モデル）

**概要**: EP-006（スパム・フラッディング）は per-author レートリミット/PoW/ブロックを扱うが、mesh 特有の悪用に対する堅牢化が手薄。`MeshForwardingService.receive` は dedup・レートリミット・署名検証・`ttl>0` を見るが、**タイムスタンプ検証がない**（署名は timestamp を含むため転送中の改ざんは防げるが、著者自身が未来日時を付与すれば Timeline 最上位に永久固定できる）。per-author レートリミットは**使い捨て鍵の乱造（Sybil）で回避可能**。攻撃面を体系化し対策を入れる。

**Priority**: `P2` | **Labels**: `security` `networking` `crypto`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-173](#task-173) | 未来日時・異常タイムスタンプ投稿の棄却（pinning 対策） | `security` `networking` `feat` | P2 | ⬜ |
| [TASK-174](#task-174) | TTL 上限の受信時強制（maxTTL）の実装確認・補強 | `networking` `security` `feat` | P2 | ⬜ |
| [TASK-175](#task-175) | Sybil 耐性の強化（使い捨て鍵乱造への対策） | `security` `networking` `feat` | P3 | ⬜ |
| [TASK-176](#task-176) | 不正・巨大・異常ペイロードのファジングと堅牢デコード | `test` `security` `networking` | P2 | ⬜ |
| [TASK-177](#task-177) | リプレイ耐性の評価（seenIDs エビクション後）と緩和 | `security` `networking` `feat` | P3 | ⬜ |
| [TASK-178](#task-178) | 脅威モデル文書の整備（攻撃面と対策のマッピング） | `security` `docs` | P2 | ⬜ |

---

### TASK-173
**未来日時・異常タイムスタンプ投稿の棄却（pinning 対策）**

`security` `networking` `feat` `P2`

著者が遠い未来の `timestamp` を付けた投稿は署名上は正当だが、`timestamp desc` 表示で Timeline 上位に固定され続ける。受信時に妥当な時刻範囲かを検証する。

- [ ] 受信時に `post.timestamp` が「現在 + 許容スキュー（例: 数分）」を超えたら棄却
- [ ] 極端に古い（保持期間より前）投稿の扱いを定義
- [ ] 端末間クロックスキューの許容幅を定数化
- [ ] 棄却をログ/診断（TASK-148）に反映

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/MeshForwardingService.swift`

---

### TASK-174
**TTL 上限の受信時強制（maxTTL）の実装確認・補強**

`networking` `security` `feat` `P2`

TASK-097 で `maxTTL` 上限チェックを入れた想定だが、`receive` 経路で実際に `ttl > maxTTL` を棄却しているか確認し、未実装/抜けがあれば補強する。過大 TTL は伝播範囲の悪用につながる。

- [ ] `receive` で `post.ttl > DriftSonarConstants.maxTTL` を棄却していることを確認
- [ ] 負値・異常 hopCount の扱いを確認・補強
- [ ] `maxHopCount` 上限の強制を確認
- [ ] 境界テスト（TASK-101）に上限ケースを追加

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/MeshForwardingService.swift`
**依存**: TASK-097

---

### TASK-175
**Sybil 耐性の強化（使い捨て鍵乱造への対策）**

`security` `networking` `feat` `P3`

レートリミットは `authorPublicKey` 単位のため、攻撃者が鍵を量産すれば回避できる。匿名投稿（使い捨て鍵）と両立する範囲で Sybil コストを上げる。

- [ ] PoW（TASK-034 設計）の任意適用 → 条件付き必須化の再検討
- [ ] 鍵あたり/単位時間あたりの全体流量上限（グローバルレートリミット）を検討
- [ ] 信頼済み（検証済み EP-025）ピア経由を優先する転送ポリシーを検討
- [ ] 匿名投稿（EP-020）とのトレードオフを明記

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/`
**依存**: TASK-034, TASK-098

---

### TASK-176
**不正・巨大・異常ペイロードのファジングと堅牢デコード**

`test` `security` `networking` `P2`

`PostSerializer.decode` は固定レイアウト前提。境界・不正バイト列・スライス起点ずれ等で安全に失敗するかをファジングで検証する。

- [ ] ランダム/破損バイト列を decode に流して必ず例外で安全に失敗することを確認
- [ ] `data` がサブスライス（非ゼロ起点）でも正しく動くか確認・修正
- [ ] contentLength 詐称（実データより大きい/小さい）への耐性
- [ ] 受信処理全体がクラッシュしないことをテストで担保

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/PostDomain/PostSerializer.swift`、`DriftSonarCore/Tests/`

---

### TASK-177
**リプレイ耐性の評価（seenIDs エビクション後）と緩和**

`security` `networking` `feat` `P3`

`seenMessageIDs` は永続化（TASK-092）されるが上限でエビクションされる。古い投稿が再注入されると、上限超過後に再伝播するリプレイの余地がある。

- [ ] seenIDs エビクション後の再受信挙動を評価
- [ ] タイムスタンプ失効（TASK-173/149）との併用でリプレイ窓を狭める
- [ ] エビクション戦略（古い ID から削除）とリプレイ耐性のトレードオフを整理
- [ ] 必要なら失効済み ID の軽量サマリ（Bloom Filter 等）を検討

**影響ファイル**: `DriftSonarCore/Sources/DriftSonarCore/MeshDomain/`
**依存**: TASK-092, TASK-173

---

### TASK-178
**脅威モデル文書の整備（攻撃面と対策のマッピング）**

`security` `docs` `P2`

個別対策が EPIC をまたいで散在しているため、攻撃面を一覧化し、各対策（実装済/未）の対応表を作る。

- [ ] 攻撃面の列挙（なりすまし・改ざん・リプレイ・Sybil・フラッディング・pinning・DoS・トラッキング）
- [ ] 各攻撃に対する現状の防御と残リスクをマッピング
- [ ] E2E DM の脅威（MITM・前方秘匿性）も統合（EP-024/025 参照）
- [ ] `docs/threat-model.md` に集約

**影響ファイル**: `docs/threat-model.md`（新規）
**依存**: EP-005, EP-006, EP-024, EP-025

---

## EP-036: メッシュ伝播シミュレーションと負荷テスト

**概要**: 現状テストは単一 `MeshForwardingService` の境界検証どまりで、複数ノードにまたがる伝播挙動（到達率・収束・分断耐性）や大規模データ時の性能を検証できていない。実機を増やさずに mesh の振る舞いを再現できるソフトウェアシミュレータと負荷テストを用意する。

**Priority**: `P2` | **Labels**: `test` `networking` `devops`

| TASK ID | タイトル | Labels | Priority | 状態 |
|---------|----------|--------|----------|------|
| [TASK-179](#task-179) | ソフトウェア多ノード mesh シミュレータ | `test` `networking` | P2 | ⬜ |
| [TASK-180](#task-180) | 伝播特性テスト（到達率・ホップ分布・収束時間） | `test` `networking` | P2 | ⬜ |
| [TASK-181](#task-181) | ネットワーク分断・再結合シナリオのテスト | `test` `networking` | P3 | ⬜ |
| [TASK-182](#task-182) | 大規模データでの永続化・メモリ性能テスト | `test` `swiftdata` | P2 | ⬜ |

---

### TASK-179
**ソフトウェア多ノード mesh シミュレータ**

`test` `networking` `P2`

CB ハードウェアなしで、N 個の `MeshForwardingService` を接続グラフで結び、すれ違い（接続イベント）を擬似的に発火させて伝播を再現するテスト基盤を作る。

- [ ] N ノード生成と、ノード間「接触」で `forwardable()`→`receive()` を回すハーネス
- [ ] 接続グラフ（ランダム/格子/スモールワールド）を切り替え可能に
- [ ] 時間ステップを進めて伝播を観測できる API
- [ ] 既存 `MeshForwardingServiceTests` から再利用できる形に整理

**影響ファイル**: `DriftSonarCore/Tests/DriftSonarCoreTests/`（新規シミュレータ）

---

### TASK-180
**伝播特性テスト（到達率・ホップ分布・収束時間）**

`test` `networking` `P2`

シミュレータ（TASK-179）上で、投稿が何割のノードに・何ステップで届くかを定量化し、TTL/バッチサイズ等のパラメータ影響を検証する。

- [ ] 1 投稿の最終到達率を測定
- [ ] ホップ数分布と TTL 消費の関係を検証
- [ ] 収束（これ以上広がらない）までのステップ数を測定
- [ ] `maxTTL`・`forwardBatchSize`・優先度ポリシーの感度分析

**影響ファイル**: `DriftSonarCore/Tests/DriftSonarCoreTests/`
**依存**: TASK-179

---

### TASK-181
**ネットワーク分断・再結合シナリオのテスト**

`test` `networking` `P3`

mesh を 2 群に分断 → 別々に投稿 → 再結合したときに、互いの投稿が正しく同期・伝播するかを検証する（Store-and-Forward の核心）。

- [ ] グラフを分断し各群で投稿が閉じることを確認
- [ ] 再結合（橋渡しノード）で双方向に伝播することを確認
- [ ] 再結合時の重複排除・TTL 消費が正しいことを確認
- [ ] キャッシュ同期（TASK-015）の挙動を検証

**影響ファイル**: `DriftSonarCore/Tests/DriftSonarCoreTests/`
**依存**: TASK-179

---

### TASK-182
**大規模データでの永続化・メモリ性能テスト**

`test` `swiftdata` `P2`

数千件の投稿・キャッシュ・`seenMessageIDs` 上限近傍での SwiftData クエリ性能とメモリ使用を検証し、エビクション（TASK-099）が効くことを確認する。

- [ ] 数千件投入時の Timeline フェッチ・フィルタ性能を測定
- [ ] `seenMessageIDs` 上限近傍での受信処理コストを測定
- [ ] キャッシュエビクション（TASK-099）が上限を維持することを確認
- [ ] メモリピークと永続化サイズの上限を把握

**影響ファイル**: `DriftSonarCore/Tests/DriftSonarCoreTests/`、`DriftSonarApp/`（必要なら）
**依存**: TASK-099
