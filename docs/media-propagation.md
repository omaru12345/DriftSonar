# DriftSonar — メディア伝播戦略（TASK-184 / EP-037）

公開 Post への画像・動画添付（EP-037 #219）を BLE mesh でどう伝播させるかの設計決定。
本書は後続の実装 TASK（#221〜#226）の前提となる。

- **Status**: 設計決定（Approved）。実装は #225（TASK-189）以降。
- **影響箇所**: `PostDomain/PostSerializer.swift`, `PostDomain/Post.swift`, `PostDomain/PostSigningService.swift`, `MeshDomain/MeshForwardingService.swift`

---

## 1. 制約の再確認（なぜ「テキストと同じ経路」が成立しないか）

| 項目 | 現状値 | 出典 |
|---|---|---|
| BLE wire MTU | 512 B | `PostSerializer.maxPayloadBytes` |
| ヘッダ | 125 B | `PostSerializer.headerSize` |
| テキスト content 上限 | 387 B | `PostSerializer.maxBLEContentBytes` |
| mesh cache 上限 | 100 件 | `MeshForwardingService.Config.maxCacheSize` |
| cache TTL | 24h | `cacheTTLInterval` |
| 1 author rate limit | 10 件 / 60s | `rateLimitPerSender` |
| 署名対象 | canonical fields（**ttl/hopCount は対象外**） | `PostSigningService` |

画像（数百KB〜）・動画（数MB）は 512B の 1 パケットに**収まらない**。
かつ mesh は「すれ違いで偶然広がる（Drift）」store-and-forward で、cache は **100 件**しか持たない。
ここにメディア本体を流すと、1 本の動画チャンクで cache が即溢れ、テキストTLが全滅する。よってメディア本体を mesh にフラッディングする設計は採らない。

---

## 2. 候補比較

### 案A: サムネ＋参照ハッシュを mesh 伝播し、本体はオンデマンド取得（採用）
mesh には極小プレースホルダ（BlurHash）＋コンテンツハッシュ参照だけを流す。本体は、閲覧時に**直接接続している近接ピア**から content-addressed で取得する。

- ✅ mesh の伝播特性・cache 容量・電池コストを現状維持（descriptor は数十バイト）。
- ✅ 「本体が来ないこともある＝劣化表示」がコアバリュー（記録に残らない / オフグリッド）と整合。
- ✅ content-addressed（SHA-256）なので取得経路に依らず完全性検証可能。
- ⚠️ 本体取得は近接ピアが本体を保持している時のみ成立（保証なし＝仕様）。

### 案B: メディア全体をチャンク分割し store-and-forward で多ホップ再構成（不採用・部分流用）
本体を固定長チャンクに割り、mesh 全体で多ホップ再構成する。

- ❌ cache 100 件・24h purge と致命的に不整合。1MB を 256B チャンク化＝約 4000 片で TL を破壊。
- ❌ 間欠的・無順序な opportunistic mesh での欠落耐性つき多ホップ再構成は信頼性が低い。
- ❌ 電池・帯域コストがフラッディングで増幅。
- ◯ ただし**チャンク転送のメカニズム自体**は案Aのオンデマンド取得（point-to-point）に流用する。

### 決定
**案A（mesh=軽量 descriptor のみ）＋ 案Bのチャンク転送を point-to-point の本体取得にのみ流用するハイブリッド**を採用する。
mesh トポロジは案A、本体転送は 1 接続セッション内の selective-repeat（多ホップ再構成は行わない）。

---

## 3. パラメータ決定

### メディア生成時の上限（#222 / TASK-186 で強制）
| 種別 | 上限 | 備考 |
|---|---|---|
| 画像（圧縮後） | ≤ 256 KB / 長辺 ≤ 2048px / JPEG q≈0.7 | EXIF・GPS を除去 |
| 動画（トランスコード後） | ≤ 2 MB / ≤ 15s / 720p H.264 + AAC | poster サムネ生成 |
| 1 投稿あたり添付数 | 画像最大 4 / 動画 1 | Twitter 同等 |

### 投稿に載せる media descriptor（mesh を流れる部分）
- **インラインプレースホルダ = BlurHash 文字列（≤ 40 B、4×3 成分）**。ほぼ 0 バイトでぼかしプレビューを即時表示。
- **コンテンツ参照 = SHA-256（32 B）**。本体の content address であり、署名対象（後述）。
- descriptor 1 件 ≈ `type(1) + width(2) + height(2) + byteSize(4) + chunkCount(2) + sha256(32) + blurhashLen(1) + blurhash(≤40) [+ video: durationMs(2)]` ≈ **最大 86 B**。
- 複数画像時は **先頭 1 枚のみ blurhash インライン**、2 枚目以降は参照のみ（`type+dims+sha256` ≈ 41 B/枚）。
  - 例: 画像 4 枚 ≈ 86 + 3×41 = 209 B の descriptor。
- → メディア投稿は **1 パケット（512 B）に収まる**。その代わり **text content 予算が縮む**（descriptor 分を差し引く）。`CreatePostUseCase` 側でメディア有り投稿の text 上限を動的に算出して強制する（#221 / #223）。

### オンデマンド本体取得プロトコル（point-to-point・mesh フラッディングしない）
- 専用 BLE characteristic を 1 本追加（`mediaCharacteristicUUID`、design-notes.md の UUID 体系に連番追加）。
- 閲覧時、本体未取得なら直接接続ピアへ `WANT(sha256)` を送る。
- 保持側がチャンクをストリーム返答: `sha256(32) + chunkIndex(2) + totalChunks(2) + chunkLen(2) + payload(≤256)`。
- 欠落・順序: 受信側が受領 index の bitmap を持ち、未達 index を再要求（**selective repeat**）。1 接続セッション内なので多ホップ再構成は不要。
- 完全性: 全チャンク結合後に SHA-256 を再計算し descriptor の値と一致を検証。不一致は破棄。
- サイズ上限: 上限 2 MB / 256B チャンク ≈ 8192 片（chunkIndex は UInt16=65535 で十分）。

---

## 4. プロトコルバージョン整合・後方互換（#225 の前提）

現行 `PostSerializer.protocolVersion = 1`。version byte は「非互換を mis-decode せず明示的に弾く」ために存在する。

### 決定: メディア投稿は **protocolVersion = 2**、media descriptor を **署名対象（canonical fields）に含める**
- v2 投稿を受けた **v1 ノードは `unsupportedVersion(2)` で drop**（既存実装どおり安全に無視。mis-decode しない）。
- v2 ノードで本体未取得 → **BlurHash プレースホルダで劣化表示**し、閲覧時にオンデマンド取得を試みる。
- **テキストのみ投稿は version=1 のまま不変**（完全に相互運用）。
- mesh は descriptor しか運ばないので cache（100 件）・TL 伝播特性は維持。

### なぜ「v1 にもテキストだけ見せる（trailer 方式）」を採らないか
descriptor を署名に**含めないと**、悪意あるピアが media 参照（sha256）を差し替え可能になり、UGC の完全性が破綻する。
descriptor を署名に含めると、v1 検証器は同じ canonical 範囲を計算できず署名不一致で drop する＝結局 v1 はテキストも表示できない。
**完全性（署名で media を束縛）を後方互換（旧ノードでのテキスト表示）より優先**し、version=2 で旧ノードは安全 drop とする。新規ネットワークで実質 legacy ノードが少ない点も後押し。

> 代替案（trailer を 512B 以内に収め署名対象外）は本書で却下。理由は上記の完全性破綻と、`decode` の `dataTooLarge` 制約（512B 超で drop）に抵触しうるため。

---

## 5. コアバリュー / 電池 / プライバシー評価

| 観点 | 評価 |
|---|---|
| オフグリッド | サーバ不在。本体は content-addressed で近接ピアからのみ取得。本体が永遠に来ない＝仕様（劣化表示）で、思想と整合。✅ |
| 記録に残らない | 取得済み本体も Post と同じ 24h purge（`cacheTTLInterval` に揃える）対象。✅ |
| 電池 | mesh が運ぶのは数十バイトの descriptor のみ＝フラッディングコスト不変。重い転送は閲覧時・近接時のみの opt-in、上限で有界。✅ |
| プライバシー | EXIF/GPS は生成時に除去（#222）。content-hash addressing は内容を漏らさない。残存リスク: `WANT(sha256)` は「その投稿の本体に興味がある」ことを**直接ピアにのみ**露出。MVP では許容、要記録。⚠️ |
| モデレーション | BlurHash で取得前プレビュー可、本体は自動取得しない（露出低減）。通報は post id で非表示。詳細は #226。 |

---

## 6. 後続 TASK への引き渡し

- **#221 (TASK-185)**: `MediaAttachment` 値型 ＋ descriptor を `Post` / `PostSigningService` の canonical 範囲に追加。`CreatePostUseCase` のメディア有り text 上限を動的算出。
- **#222 (TASK-186)**: 圧縮・トランスコード・サムネ・EXIF 除去・SHA-256 算出・上限強制（§3 の値）。
- **#223 (TASK-187)** / **#224 (TASK-188)**: BlurHash プレースホルダ→本体差し替えの UI、全画面ビューア。
- **#225 (TASK-189)** ✅ Core 実装済み: `PostSerializer` を version=2 拡張（メディア descriptor を content の後ろに付与、テキストのみは v1 のままバイト不変、未知 version は `unsupportedVersion` で安全 drop ＝ v1 ノードは v2 を無視）。`MediaAttachment.decodeDescriptor`（`canonicalBytes` の逆）。`CreatePostUseCase` がメディア投稿を v2 で store-and-forward キャッシュ（descriptor のみ mesh を流れる）。`MediaChunkProtocol`（WANT / CHUNK フレーム + `MediaChunker`）と `MediaReassembler`（selective-repeat・順序/欠落/重複/タイムアウト・SHA-256 検証・堅牢デコード）。`mediaCharacteristicUUID`（…678E）追加。Core テスト +30（v2 wire / 転送プロトコル）。
  - **残（BLE 実機オーケストレーション）**: `mediaCharacteristicUUID` 経由の WANT write → CHUNK notify ストリームの CoreBluetooth 配線と、閲覧時の取得トリガ／`progress` を使った劣化表示 UI。プロトコル・再構成ロジックは Core で実装・テスト済みで、残りは 2 台必須の transport 結線のみ（`*Design.swift` 同様の前方準備）。
- **#226 (TASK-190)**: 取得前プレビュー前提のモデレーション・容量上限・審査対応。
