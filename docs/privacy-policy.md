# DriftSonar プライバシーポリシー / Privacy Policy

**最終更新日 / Last updated: 2026-05-30**

DriftSonar（以下「本アプリ」）は、Bluetooth Low Energy（BLE）メッシュを用いて、インターネット接続なしで近くのデバイス間にメッセージを伝播するオフグリッド型 SNS アプリです。本ポリシーは、本アプリがどのように情報を扱うかを説明します。

DriftSonar ("the App") is an off-grid social app that propagates messages between nearby devices over a Bluetooth Low Energy (BLE) mesh, without any internet connection. This policy explains how the App handles information.

---

## 日本語

### 1. 収集する情報はありません（サーバーは存在しません）

本アプリにはバックエンドサーバーがありません。開発者はあなたのデータを受信・収集・保存しません。アカウント登録、メールアドレス、電話番号は一切不要です。アクセス解析・トラッキング・広告 SDK・サードパーティ SDK を一切使用していません。

### 2. デバイス内に保存される情報

以下の情報はすべて **あなたのデバイス内にのみ** 保存され、開発者を含む第三者のサーバーには送信されません。

- **投稿・受信メッセージ**: SwiftData ローカルストア（ファイル保護レベル: complete）に保存されます。
- **暗号鍵**: 署名・鍵共有用の秘密鍵は iOS の Keychain に保存されます。
- **ニックネーム**: あなたが設定した表示名。
- **重複排除用メッセージ ID**: 同じメッセージの再受信を防ぐため、メッセージ ID のリストを UserDefaults にローカル保存します（メッセージ本文は含みません）。

### 3. BLE による近接デバイスとのデータ共有（本アプリの中核機能）

本アプリは設計上、以下を BLE 経由で近くのデバイスと直接やり取りします。

- **公開鍵・ニックネーム**: 近くのデバイスにあなたを識別させるため、BLE で公開（アドバタイズ／読み取り）されます。
- **投稿（Post）**: あなたの投稿は、Store-and-Forward メッシュにより近くのデバイスへ中継・伝播されます。**投稿は物理的に近くにいる人やメッシュ上の参加者に届く前提のものです。秘密にしたい内容は投稿しないでください。**
- **ダイレクトメッセージ（DM）**: DM は Curve25519 鍵共有 + AES-GCM によりエンドツーエンドで暗号化され、宛先デバイスのみが復号できます。中継デバイスは暗号文しか扱えません。

すべての通信は端末間の P2P であり、インターネットや開発者のサーバーを経由しません。

### 4. 匿名投稿

本アプリには使い捨て鍵ペアによる匿名投稿機能があります。匿名投稿に使われる鍵は永続化されず、通常のプロフィールとは紐づきません。

### 5. 端末の権限

- **Bluetooth**: 近くのユーザーの検出とメッセージ伝播に使用します。位置情報の取得には使用しません。
- **通知**: 新しい投稿・DM の受信をローカル通知でお知らせするために使用します。通知はすべて端末内で生成され、リモートプッシュサーバーは使用しません。

### 6. データの保持と削除

データはあなたのデバイス内にのみ存在します。本アプリを削除（アンインストール）すると、ローカルに保存された投稿・メッセージ・鍵・設定はすべて削除されます。一度メッシュに伝播した投稿は、それを受信した他のデバイス上に残る場合があります（本アプリからは制御できません）。

### 7. 子どものプライバシー

本アプリは特定の個人情報を収集しません。

### 8. 本ポリシーの変更

本ポリシーを更新する場合は、本ページの「最終更新日」を改定します。

### 9. お問い合わせ

ご質問は次の連絡先までお願いします: **bleachonn77@gmail.com**

---

## English

### 1. We collect nothing (there is no server)

The App has no backend server. The developer does not receive, collect, or store any of your data. No account, email address, or phone number is required. The App uses no analytics, tracking, advertising SDKs, or any third-party SDKs.

### 2. Information stored on your device

All of the following is stored **only on your device** and is never transmitted to any server, including the developer's:

- **Posts and received messages**: stored in a local SwiftData store (file protection level: complete).
- **Cryptographic keys**: private keys for signing and key agreement are stored in the iOS Keychain.
- **Nickname**: your chosen display name.
- **Seen message IDs**: a list of message IDs is stored locally in UserDefaults to avoid re-receiving the same message (message contents are not included).

### 3. Data shared with nearby devices over BLE (the App's core function)

By design, the App exchanges the following directly with nearby devices over BLE:

- **Public key and nickname**: broadcast/readable over BLE so nearby devices can identify you.
- **Posts**: your posts are relayed and propagated to nearby devices via a store-and-forward mesh. **Posts are intended to reach people physically near you and participants on the mesh. Do not post anything you wish to keep private.**
- **Direct messages (DMs)**: DMs are end-to-end encrypted using Curve25519 key agreement + AES-GCM, and can be decrypted only by the intended recipient device. Relaying devices handle ciphertext only.

All communication is peer-to-peer between devices and never goes through the internet or the developer's servers.

### 4. Anonymous posting

The App offers anonymous posting using ephemeral key pairs. Keys used for anonymous posts are not persisted and are not linked to your regular profile.

### 5. Device permissions

- **Bluetooth**: used to discover nearby users and propagate messages. It is not used to determine your location.
- **Notifications**: used to alert you to incoming posts/DMs via local notifications. All notifications are generated on-device; no remote push server is used.

### 6. Data retention and deletion

Your data exists only on your device. Deleting (uninstalling) the App removes all locally stored posts, messages, keys, and settings. Posts that have already propagated through the mesh may remain on other devices that received them (this is outside the App's control).

### 7. Children's privacy

The App does not collect any specific personal information.

### 8. Changes to this policy

If we update this policy, we will revise the "Last updated" date on this page.

### 9. Contact

For questions, contact: **bleachonn77@gmail.com**
