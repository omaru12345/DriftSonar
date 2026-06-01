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
