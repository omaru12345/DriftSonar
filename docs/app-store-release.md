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
| 暗号輸出申告 | `ITSAppUsesNonExemptEncryption = true`（マスマーケット例外／要 BIS 年次報告・下記参照） |
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
- **Minimum Functionality**: 単体で何もできないと見なされない様、空状態 UI やデモ性を担保。**初回起動時に「ようこそ」システム投稿を自動シードし、単独端末（審査員環境）でも Timeline が必ず非空になる**（TASK-170、Release ビルドでも有効）。詳細 → §8.2。
- **暗号輸出コンプライアンス（TASK-171 / #206）**: 下記「暗号輸出申告」節を参照。E2E 暗号 DM がコア機能のため `ITSAppUsesNonExemptEncryption=true`。

### 暗号輸出申告（ITSAppUsesNonExemptEncryption）

**結論**: `true`（旧 `false` は誤申告リスクのため是正）。

**根拠**:
- 使用暗号は CryptoKit の標準アルゴリズムのみ（X25519 鍵共有 / Ed25519 署名 / AES-GCM / HKDF / SHA-256・512、鍵保管 Keychain）。**独自・非公開の暗号アルゴリズムは実装していない。**
- Apple が `false`（申告不要）を許すのは、暗号が「OS 提供の HTTPS/TLS 呼び出し」「認証・デジタル署名・DRM 限定」等の**限定的除外**に収まる場合のみ。本アプリは **DM のユーザーコンテンツを E2E 暗号化するのがコア機能**で、この限定除外には該当しない → `false` は不適切。
- 標準暗号を用いるマスマーケット・アプリは **EAR Category 5 Part 2 のマスマーケット例外（5D992.c）** に該当し得る。

**App Store Connect の暗号化質問への回答**:
1. 「アプリは暗号を使用していますか？」→ **はい**
2. 「Category 5, Part 2 の例外に該当しますか？」→ **はい**（標準暗号・マスマーケット）

**運用側で必要な政府提出（コード外・要対応）**:
- 米 BIS（および NSA）への **年次自己分類レポート（annual self-classification report）** の提出義務がある（マスマーケット例外の利用条件）。**この政府提出は本リポの変更対象外**であり、公開運用者が別途対応すること。未提出のまま例外を主張すると輸出管理違反となり得る点に注意。
- 参考: Apple「Complying with Encryption Export Regulations」／BIS EAR §740.17。

---

## 8.1 UGC モデレーション（GL 1.2）— TASK-167 ✅

サーバーレス匿名 SNS で最大のリジェクト要因が **Guideline 1.2 (User Generated Content)**。中央監視ができない代わりに、**端末側の自律モデレーション**で「不快コンテンツを即時遮断できる」ことを証明する。実装済みの4点:

| 要件 | 実装 | 即時性 |
|---|---|---|
| 不適切コンテンツのフィルタ | `ContentFilter`（Core）が禁止語を検出し、Timeline 表示・コピーで伏せ字化 | 表示時に常時適用 |
| 通報 | 投稿コンテキストメニュー「この投稿を通報」→ 理由選択 → `ReportStore` に記録し**即座に非表示** | 即時（タップ後すぐ） |
| 不適切ユーザーのブロック | コンテキストメニュー「このユーザーをブロック」→ `BlockedKeyModel` を SwiftData に追加 | 即時（`@Query` ライブ更新で再描画） |
| 利用規約への同意 | 初回起動の `EULAGateView` で不適切コンテンツ禁止・ゼロトレランスへの同意を必須化 | 起動初回 |

### Review Notes に明記する文面（案）

> 本アプリは完全オフライン（サーバーなし）の P2P SNS です。中央サーバーがないため、モデレーションはすべて端末側で完結します。ユーザーは不快な投稿を「通報」で即座に非表示にでき、迷惑なユーザーを「ブロック」すると以降その相手の投稿が即時にすべて遮断されます（SwiftData のライブクエリで即反映）。通報・ブロックはネットワーク往復を伴わず端末内で完結するため、**Guideline 1.2 が求める「不適切コンテンツへの 24 時間以内の対応」を実質的に即時で満たします**。加えて、明白な不適切語は自動フィルタで伏せ字化され、初回起動時に不適切コンテンツ禁止規約への同意を必須化しています。

### 仕様メモ（ブロックの即時反映 = TASK-033 / TASK-087）

- `PostTimelineView` は `@Query private var blockedKeyModels` で**ブロックリストをライブ購読**しており、ブロック追加と同時に `visiblePosts` から該当著者の投稿が消える（アプリ再起動・再取得は不要）。
- 受信側でもブロック著者の投稿は表示されない。BLE 受信自体の遮断強化は別 Issue（脅威モデル系）で扱う。

---

## 8.2 単独端末デモ / Minimum Functionality（GL 4.2）— TASK-170 🔄

審査員は基本 1 台でテストするため、周囲に端末がなく Timeline が「真っ白」だと最小機能未達でリジェクトされやすい（GL 4.2 / 2.1）。**単独端末で主要動線が一通り体験できる導線はコード側で実装済み・Release ビルドで動作**する。残るのは実機2台のデモ動画（手作業）と提出時の Review Notes 追記のみ。

| 項目 | 状態 | 内容 |
|---|---|---|
| ようこそシステム投稿 | ✅ 実装済み | 初回起動時に `WelcomePost`（システム由来・送信者名「DriftSonar」・**ピン留めで消えない**）を 1 件シード。`AppServices.seedWelcomePostIfNeeded` が `UserDefaults("hasSeededWelcomePost")` ＋安定 UUID で二重投入を防止。Timeline が空にならないことを保証。 |
| デモ伝播投稿（すれ違い体験） | ✅ 実装済み | 初回に `DemoPropagationPost`（送信者「近くの漂流者」・センチネル鍵 `0xD6`×32・`hopCount 3`）を 1 件だけ**漂着アニメーション付きで**流し込む（`seedDemoPropagationIfNeeded` ＋ `demoArrivalPending`／TASK-297）。「N つの岸を漂って届いた」表示で伝播の体感を単独端末でも再現。本文で「デモ」と明示し、**通常 TTL で自動消滅**するため「記録に残らない」保持挙動も同時に示す。**Release ビルドで動作**（旧デモシード TASK-107 の `#if DEBUG` 限定・審査ビルドで空だった問題を解消）。 |
| レーダー（すれ違い）タブの単独表示 | ✅ 実装済み | 水面スキャン UI と、デモシードで登録した `EncounteredEventModel` を使った**「最後にすれ違ったのは〜」ガイド付き空状態**（`EmptyRadarView`）が表示され、レーダー画面自体は1台で確認できる。ただし**すれ違い相手の一覧はライブ検出（`viewModel.encounteredPeers`）のみ**を出す設計のため、実際の相手行は近接ピアが居ないと現れない。 |
| E2E 暗号 DM の単独到達 | ⚠️ 単独では不可 | DM 画面（`SecretMessageView`）はレーダーの**ライブ検出行のタップからのみ**開くため、近接ピアが居ない単独端末では到達できない。E2E DM の動作は下記デモ動画で示す（判断待ち: 履歴からの DM 導線を設けるかは #205 では扱わず別途）。 |
| デモ動画（2台伝播・E2E DM） | ⬜ あなたの手作業 | 実機2台で投稿伝播・DM を録画し、限定公開 URL を Review Notes に貼る。URL: `（ここに貼る）` |
| Review Notes 追記 | ⬜ 提出時 | 下記文面を §8 の注記に追加。 |

### Review Notes に追記する文面（案）

> 本アプリは WiFi もアカウントも使わず、近接2台の Bluetooth すれ違いでメッセージが伝播する P2P SNS です。周囲に端末がない単独環境でも主要機能をご確認いただけるよう、**初回起動時に説明用のシステム投稿とデモ投稿を自動表示**します。以下の手順で1台のまま各画面をご確認ください。
>
> 1. **タイムライン**: 起動直後に「ようこそ」投稿と、"近くの漂流者" から漂着したデモ投稿（「◯つの岸を漂って届いた」表示）が並びます。右上の作成ボタンから任意の投稿を作成でき、投稿は一定時間で自動消滅します（サーバーレス設計のため記録は端末内のみ）。
> 2. **レーダー（すれ違い）タブ**: 水面スキャン UI と「最後にすれ違った相手」の案内が表示されます。実環境では近くで本アプリを開いた相手が Bluetooth 経由でここに一覧表示され、その相手をタップして E2E 暗号 DM を開始できます。
> 3. **端末間の伝播 と E2E 暗号 DM の往復**: この2つは近接2台でのみ動作するため、添付のデモ動画（実機2台）をご参照ください。単独端末では上記のとおり各画面 UI・投稿作成をご確認いただけます。

### 仕様メモ
- `WelcomePost`（センチネル鍵 `0xD5`×32・ピン留め・非消滅）と `DemoPropagationPost`（`0xD6`×32・通常 TTL）は鍵が異なり、システム2種のシードが混ざらない。いずれも署名は空で、表示名解決のため `EncounteredEventModel` にシステム名（「DriftSonar」/「近くの漂流者」）を登録。本文自体がアプリ説明／デモ明示になっており、本物の受信投稿と混同しない。
- どちらのシードも `UserDefaults` フラグ＋安定 UUID で二重投入を防止し、初回1回だけ実行。デモ伝播投稿は消滅後は再表示されない（フラグ既設のため）。
- **DM は単独端末では到達不可**（レーダーのライブ検出行からのみ開く設計）。審査上は「単独で UI 確認可・伝播/DM は動画」で整合するが、単独でも DM 画面を確認させたい場合は「すれ違い履歴からの DM 導線」等の追加が要る（設計判断が要るため #205 スコープ外・別 Issue 候補）。
- オンボーディング演出のさらなる作り込み（アニメーション強化等）は別 Issue TASK-121（#156, P2）で継続。

---

## 8.3 メディア UGC モデレーション（GL 1.2 / 画像・動画）— TASK-190 ✅

EP-037 で画像・動画の添付に対応したため、UGC の審査面が拡大した。テキスト同様、**メディアも端末側で即時遮断できる**ことを示す。§8.1 の枠組みをメディアへ拡張済み:

| 要件 | 実装 | 即時性 |
|---|---|---|
| メディア投稿の通報 | 投稿コンテキストメニュー「この投稿を通報」が**投稿単位で非表示**にするため、本文だけでなく**添付画像・動画も同時に非表示**になる。通報理由に「不適切・わいせつな内容（画像・動画含む）」を明記。 | 即時 |
| ブロック著者のメディア非表示 | `PostTimelineView.visiblePosts` がブロック著者の投稿を除外＝**その投稿のメディアも自動的に消える**（`@Query` ライブ購読、TASK-033/087）。 | 即時 |
| 容量・枚数・総サイズ上限 | `CreatePostUseCase` が画像≤256KB/4枚・動画≤2MB/1本、**1投稿あたり総メディア≤2MB** を強制。超過は ComposeView でエラー表示。生成時に EXIF/GPS を除去（TASK-186）。 | 投稿作成時 |
| 取得前プレビュー（露出低減） | mesh を流れるのは BlurHash＋ハッシュ参照のみ。**本体は自動取得せず**、閲覧操作で初めて近接ピアから取得（TASK-189）。不快画像を意図せずフル表示しにくい設計。 | 常時 |
| 規約同意 | `EULAGateView` の禁止事項に「画像・動画にも等しく適用」を明記。 | 起動初回 |

### Review Notes に追記する文面（案）

> 画像・動画の投稿に対応していますが、モデレーションはテキストと同じく端末側で完結します。不快なメディアを含む投稿は「通報」で投稿ごと即座に非表示にでき、「ブロック」で当該ユーザーの投稿（メディア含む）が以降すべて遮断されます。メディア本体はサーバーを介さず近接ピアから取得し、未取得時はぼかしプレースホルダのみ表示されるため、不快な画像が意図せずフル表示されることはありません。撮影位置などの EXIF/GPS は投稿前に除去しています。

### 写真ライブラリ権限（`NSPhotoLibraryUsageDescription`）の正当性

- 用途は**投稿への画像・動画添付のみ**。ライブラリ全体の読み取りや書き戻しは行わず、ユーザーが PHPicker で選んだ項目だけを取得する。
- 選択メディアは圧縮・トランスコード・EXIF 除去のうえ、**端末内（Application Support）にのみ保存**。外部送信は近接ピアへのオンデマンド本体転送（コンテンツアドレス指定）に限られ、サーバー送信は一切ない。
- Review Notes に上記の用途限定を明記し、権限文言（Info.plist）と齟齬がないことを確認する。

---

## 8.4 年齢確認ゲートとレーティング（GL 5.1 子どもの安全）— TASK-168 🔄

匿名・無監視の SNS は成人向けコンテンツの温床とみなされ、子どもの安全性で厳しく審査される。中央監視がない代わりに、**初回起動時の年齢確認**でレーティングとの整合を担保する。

| 項目 | 状態 | 内容 |
|---|---|---|
| 初回起動の年齢確認 | ✅ 実装済み | `EULAGateView` に「**18 歳以上です**」トグルを追加。オンにしないと「同意して始める」を押せない（`.disabled(!confirmedAge)`）。最小年齢は `EULAGateView.minimumAge`（現在 18）で一元管理。 |
| App Store Connect レーティング | ⬜ あなたの手作業 | ASC の年齢レーティングを**アプリ内ゲートと同じ 18+ に設定**。無監視 UGC のため最も厳しい区分を選ぶ。 |
| 審査メモへの整合記載 | ⬜ 提出時 | 下記文面を Review Notes に追記。 |
| 画像 NSFW 端末内検出 | ⬜ 別途検討 | 現状は通報・ブロック・BlurHash 遅延取得（§8.3）で露出を低減。自動 NSFW 検出は将来課題（別 Issue 化候補）。 |

> **レーティング数値について**: 旧 Issue（TASK-168）タイトルは「17+」表記だが、これは旧 App Store レーティング体系の名残。現行体系・および 2 回目提出の Review Notes で Apple に伝えた「18+」と揃えるため、アプリ内ゲート・ASC レーティングとも **18+ に統一**する。17+ で運用する場合は `EULAGateView.minimumAge` と ASC 設定・Review Notes を三点セットで 17 に合わせること。

### Review Notes に追記する文面（案）

> 本アプリは 18 歳以上を対象とした P2P SNS です。初回起動時に 18 歳以上であることの確認を必須化し、確認しない限りプロフィール作成・利用を開始できません。App Store Connect の年齢レーティングも 18+ に設定しています。中央監視のない匿名 SNS である点を踏まえ、通報・ブロック・自動フィルタ（§8.1）とメディアのぼかし遅延取得（§8.3）で不適切コンテンツの露出を端末側で低減しています。

---

## 8.5 バックグラウンド BLE の正当性とユーザー制御（GL 2.5.4）— TASK-169 🔄

バックグラウンドでの Bluetooth 常時動作は「バッテリー消費に見合う正当な理由」と「ユーザーが停止できる手段」の両方を審査で要求される（GL 2.5.4）。DriftSonar は Store-and-Forward メッシュが**アプリのコア機能**であり、背景 BLE がその主目的にあたる。

| 項目 | 状態 | 内容 |
|---|---|---|
| ユーザー制御トグル | ✅ 実装済み | 設定に「バックグラウンド通信」オン/オフを追加（`SettingsView.backgroundCommunicationSection` / `@AppStorage("backgroundBLEEnabled")`）。オフ時はバックグラウンド遷移で BLE を完全停止（`AppServices.setBackgroundScanning(enabled:)` → `bleService.stop()`）、フォアグラウンド復帰で再開（`resumeEncounterDiscovery()`）。 |
| バッテリー消費の明示 | ✅ 実装済み | トグルがオンのとき「アプリを閉じている間も…その分バッテリーを消費します」を明示表示。 |
| 省電力制御との整合 | ✅ 実装済み | 低電力モード/低バッテリーでは省電力スキャンcadence（TASK-146）に自動移行。背景オフ時は停止が優先される。 |
| 審査メモへの明記 | ⬜ 提出時 | 下記文面を Review Notes に追記。 |

### Review Notes に追記する文面（案）

> 本アプリはサーバーを持たない Store-and-Forward 型メッシュ SNS です。近接端末とすれ違った際に投稿・メッセージを預かり運ぶことがアプリのコア機能であり、バックグラウンドでの Bluetooth（central/peripheral）動作はこの主目的のために必要です。ユーザーは設定画面の「バックグラウンド通信」トグルでこの動作をいつでも無効化でき、無効時はアプリを閉じている間の Bluetooth 動作を完全に停止します。トグルがオンの間はバッテリー消費が発生する旨を設定画面に明示しています。

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
