---
updated: 2026-03-29
---

# DriftSonar アーキテクチャ図

## 全体構成

```mermaid
flowchart TD
    subgraph App["DriftSonarApp (SwiftUI)"]
        CV[ContentView\nTabView ルーター]
        EV[EncounterView\n波紋レーダーUI]
        TV[PostTimelineView\nタイムライン]
        SMV[SecretMessageView\nDM UI]
        ISV[InitialSetupView\nオンボーディング]
    end

    subgraph ViewModels["ViewModels (@Observable)"]
        EVM[EncounterViewModel]
        TVM[TimelineViewModel]
        SMVM[SecretMessageViewModel]
        ISVM[InitialSetupViewModel]
    end

    subgraph Core["DriftSonarCore (Swift Package)"]
        BLE[BLEEncounterService\nCBCentral + CBPeripheral]
        MFS[MeshForwardingService\nStore-and-Forward]
        PS[PostSigningService\nEd25519署名]
        SMS[SecretMessageService\nCurve25519 + AES-GCM]
        KS[KeychainService\n秘密鍵管理]
    end

    subgraph Storage["永続化 (SwiftData)"]
        PostDB[(PostModel\nタイムライン)]
        EncDB[(EncounteredEventModel\n出会い履歴)]
        MeshDB[(CachedMessageModel\n転送キャッシュ)]
        SMDB[(SecretMessageModel\n暗号化DM)]
        UserDB[(UserProfileModel\nプロファイル)]
        BlockDB[(BlockedKeyModel\nブロックリスト)]
    end

    CV --> EV & TV & SMV
    EV --> EVM --> BLE
    TV --> TVM --> PS
    SMV --> SMVM --> SMS
    ISV --> ISVM --> KS

    BLE -->|onEncounter| EVM
    BLE -->|受信Post| MFS
    MFS -->|転送| BLE
    TVM --> PostDB
    EVM --> EncDB
    MFS --> MeshDB
    SMVM --> SMDB
    ISVM --> UserDB
```

## BLE メッシュ通信フロー

```mermaid
sequenceDiagram
    participant A as デバイスA (Central+Peripheral)
    participant B as デバイスB (Central+Peripheral)
    participant C as デバイスC

    Note over A,B: スキャン / アドバタイズ同時実行
    A->>B: CBCentral がスキャン → 接続
    B-->>A: GATT Read: publicKey (32bytes)
    A->>A: onEncounter 発火 (Main Queue)
    Note over A: dedup: seenPublicKeyHashes チェック

    A->>B: Write: messageCharacteristic (Post wire format)
    B->>B: MeshForwardingService.receive()\n署名検証・TTL確認・キャッシュ保存
    B->>C: 次の出会い時に転送 (TTL--, hopCount++)
```

## ドメインモデル関係

```mermaid
erDiagram
    UserProfile {
        string id
        string nickname
        string bio
        Data publicKey
        Data signingPublicKey
    }
    Post {
        UUID id
        string content
        Data authorPublicKey
        Data signature
        int ttl
        int hopCount
    }
    CachedMessage {
        UUID messageId
        Data serializedPost
        int ttl
        int forwardedCount
    }
    EncounteredEvent {
        string peerId
        Data peerPublicKey
    }
    SecretMessage {
        UUID id
        Data otherPublicKey
        Data encryptedData
    }
    BlockedKey {
        Data publicKey
        Date blockedAt
    }

    UserProfile ||--o{ Post : "signs"
    UserProfile ||--o{ SecretMessage : "exchanges"
    Post ||--o| CachedMessage : "serialized into"
    EncounteredEvent }o--|| UserProfile : "peer publicKey"
```

## View → ViewModel → Domain レイヤー

```mermaid
flowchart LR
    subgraph Views
        EV[EncounterView]
        TV[PostTimelineView]
        CV2[ComposeView]
        SMV[SecretMessageView]
        ISV[InitialSetupView]
    end

    subgraph ViewModels
        EVM[EncounterViewModel\nonEncounter callback]
        TVM[TimelineViewModel\nfetch/create]
        SMVM[SecretMessageViewModel\nencrypt/decrypt]
        ISVM[InitialSetupViewModel\nkey generation]
    end

    subgraph Domain
        BLE[BLEEncounterService]
        CPU[CreatePostUseCase\n+ PostSigningService]
        FTU[FetchTimelineUseCase]
        SMS[SecretMessageService\nECDH + AES-GCM]
        GPU[CreateProfileUseCase\nkey pair生成]
    end

    EV -->|setupService| EVM --> BLE
    TV -->|setup| TVM --> CPU & FTU
    CV2 -->|onSubmit| TVM
    SMV -->|setup| SMVM --> SMS
    ISV -->|createProfile| ISVM --> GPU
```

## 暗号化方式

```mermaid
flowchart TD
    subgraph PostSigning["Post 署名 (Ed25519)"]
        PS1[canonical bytes\nid+authorPublicKey+timestamp+content]
        PS2[Ed25519.sign(canonicalBytes, privateKey)]
        PS3[署名付きPost]
        PS1 --> PS2 --> PS3
    end

    subgraph E2E["Direct Message 暗号化 (Curve25519 + AES-GCM)"]
        E1[ECDH\nsenderPrivKey + receiverPubKey]
        E2[HKDF\nsalt: DriftSonar-SecretMessage-v1]
        E3[AES-256-GCM seal]
        E4[EncryptedMessage]
        E1 --> E2 --> E3 --> E4
    end

    subgraph Storage["秘密鍵保管 (Keychain)"]
        K1[signingPrivateKey\nkSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        K2[agreementPrivateKey\n同上]
    end
```

## BLE UUID 定義

```mermaid
flowchart LR
    SVC[Service UUID\n4A7D5C3B-...-E0F123456789]
    SVC --> PK[publicKey Characteristic\n...678A - Read]
    SVC --> MSG[message Characteristic\n...678B - Write: Post]
    SVC --> DM[directMessage Characteristic\n...678C - Write: DM]
```
