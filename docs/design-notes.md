# DriftSonar — 重要な設計メモ

## BLEEncounterService の仕組み

**UUID定義**:
- `serviceUUID` = `4A7D5C3B-1E2F-4A6B-8C9D-E0F123456789`
- `publicKeyCharacteristicUUID` = `4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678A`
- `messageCharacteristicUUID` = `4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678B`
- `directMessageCharacteristicUUID` = `4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678C`
- `nicknameCharacteristicUUID` = `4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678D`
- `mediaCharacteristicUUID` = `4A7D5C3B-1E2F-4A6B-8C9D-E0F12345678E`（オンデマンドメディア本体取得・TASK-189）

**アーキテクチャ**:
- 各デバイスが Peripheral（公開鍵をGATTで公開）と Central（スキャン→接続→読取→切断）を同時担当
- CBコールバックはすべて `bleQueue`（`DispatchQueue(label:"com.driftsonar.ble")`）で処理
- `onEncounter` は Main Queue に dispatch して UI へ通知
- `@unchecked Sendable` 準拠（Swift 6 厳格同時性対応）
- CBUUID static プロパティは `nonisolated(unsafe)` で宣言

## Xcodeプロジェクト構造の注意点

- `DriftSonarApp/DriftSonarApp/DriftSonarApp/` 内は `PBXFileSystemSynchronizedRootGroup` で自動管理
- `Views/` と `ViewModels/` は明示的 PBXGroup — **新ファイル追加時は `project.pbxproj` を手動編集が必要**
- `Info.plist` は `PBXFileSystemSynchronizedBuildFileExceptionSet` で Resources から除外済み（二重処理防止）
- `TimelineView` は SwiftUI 組み込み型と衝突するため **`PostTimelineView`** として定義

## 秘密鍵の取り出し方（UI層）

`UserProfileModel` には秘密鍵は含まれない（Keychainのみ）。

```swift
let signingKey = (try? KeychainService.load(
    account: KeychainService.signingPrivateKeyAccount
)) ?? Data()
let agreementKey = (try? KeychainService.load(
    account: KeychainService.agreementPrivateKeyAccount
)) ?? Data()
```

## EncounterService プロトコル

```swift
public protocol EncounterService {
    var onEncounter: ((EncounteredEvent) -> Void)? { get set }
    func execute(command: StartDiscoveryCommand) throws
    func stop()
}
```

## SwiftData Predicate の注意点

外部変数を `#Predicate` 内で使う場合はローカル定数に先に代入すること。

```swift
let peerId = event.peerId  // ← 必須
let descriptor = FetchDescriptor<EncounteredEventModel>(
    predicate: #Predicate { $0.peerId == peerId }
)
```

## スナップショットテスト（TASK-161）の基準画像 運用方針

swift-snapshot-testing で主要 View の見た目回帰を検出する（`DriftSonarAppTests/*SnapshotTests.swift`）。

- **記録環境の固定**：基準画像は **iPhone 17 / iOS 26.2 シミュレータ・@3x** で撮影する。別デバイス／別 OS ではピクセルが一致しないため、更新時も必ずこの環境で撮る。`perceptualPrecision: 0.98` でサブピクセルの誤差だけ許容。
- **基準画像の置き場所とコミット**：`DriftSonarAppTests/__Snapshots__/<TestClass>/` に PNG を **Git 管理でコミット**する。初回は基準不在で自動記録され fail するので、生成物をコミット→再実行して green を確認する（記録と検証を必ず分ける）。
- **意図した見た目変更の更新手順**：対象の `.png` を削除して再実行（自動再記録→fail）→ 差分を目視確認 → コミット → 再実行で green。デザイン変更 PR ではこの再撮影を差分に含める。
- **決定論を保つ**：時刻・ロケール依存を排除する。相対時刻は `Date()` からの固定オフセット、絶対時刻は固定エポック（今日以外）を使い、`\.locale` は `ja_JP` に固定。アニメーション（例: PostRowView の drift-in）は開始状態が opacity 0 になり得るため、`PostRowView.driftedInIds` を事前シードして初期フレームから可視にする。
- **対象**：`EmptyTimelineView` / `PostRowView` / `MessageBubble`。Light・Dark と Dynamic Type（accessibility3）の主要バリアントを撮る。
- **CI では実行しない＝ローカル専用ゲート（TASK-162 / #197）**：GitHub ホストランナー（macos-26）は Xcode 26.2・iOS 26.2 を記録環境と一致させても、物理 Mac とテキストレンダリングが微妙に異なり `perceptualPrecision 0.98` でも全滅する（"does not match reference"）。基準画像は撮影マシンでのみ正となるため、CI（`app-test.yml`）は `-skip-testing` でスナップショット3クラスを除外し、unit / UI のみをゲートする。スナップショット回帰は **push 前にローカルでフル `xcodebuild test` を回して**担保する。
