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
