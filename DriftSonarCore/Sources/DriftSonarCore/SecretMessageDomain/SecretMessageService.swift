import CryptoKit
import Foundation

public struct SecretMessageService {
    /// Protocol-specific HKDF salt — prevents cross-protocol key reuse (TASK-054).
    static let hkdfSalt = Data("DriftSonar-SecretMessage-v1".utf8)

    public init() {}

    /// 平文を暗号化する。
    ///
    /// - v1（既定 / TASK-054）: 送信者の長期秘密鍵と受信者の長期公開鍵で共有秘密を作る静的方式。
    /// - v2（前方秘匿性 / TASK-126）: 送信ごとに使い捨ての X25519 鍵ペアを生成し、その秘密鍵と
    ///   受信者の長期公開鍵で共有秘密を作る。送信者の長期秘密鍵が漏れても過去 DM の鍵は再現できない。
    ///   エフェメラル秘密鍵は本メソッドを抜けた時点で破棄され、どこにも保持しない。`senderPrivateKey`
    ///   は v2 では用いない（署名互換のためシグネチャは共通のまま受け取る）。
    ///
    /// - Important: v2 は前方秘匿性と秘匿性のみを提供し、**送信者認証を持たない**。v1 は
    ///   static-static ECDH のため「送信者の長期鍵を持つ者だけが復号可能な暗号文を作れる」＝暗黙の
    ///   送信者認証があったが、v2 では受信者の公開鍵を知る第三者が任意の送信者になりすませる。
    ///   認証モデル（署名付きエフェメラル / ダブル DH / 意図的な否認可能・匿名のいずれか）は脅威モデル
    ///   （EP-035）で決めるべき別スコープであり、**アプリ層が v2 を既定採用する前に決着が必要**。
    /// - Parameter version: 暗号化方式。既定は既存挙動を保つ `.v1Static`。
    public func encrypt(
        plainText: String,
        senderPrivateKey: Data,
        receiverPublicKey: Data,
        version: EncryptedMessage.Version = .v1Static
    ) throws -> EncryptedMessage {
        guard let plainData = plainText.data(using: .utf8) else {
            throw DecryptionError.invalidData
        }
        let receiverKey: Curve25519.KeyAgreement.PublicKey
        do {
            receiverKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: receiverPublicKey)
        } catch {
            throw DecryptionError.invalidKey
        }

        switch version {
        case .v1Static:
            let senderKey: Curve25519.KeyAgreement.PrivateKey
            do {
                senderKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: senderPrivateKey)
            } catch {
                throw DecryptionError.invalidKey
            }
            let sharedSecret = try senderKey.sharedSecretFromKeyAgreement(with: receiverKey)
            let symmetricKey = Self.deriveKey(from: sharedSecret, version: .v1Static)
            return EncryptedMessage(data: try Self.seal(plainData, using: symmetricKey))
        case .v2Ephemeral:
            // Fresh ephemeral keypair per message — the root of forward secrecy (TASK-126).
            let ephemeralPrivateKey = Curve25519.KeyAgreement.PrivateKey()
            let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: receiverKey)
            let symmetricKey = Self.deriveKey(from: sharedSecret, version: .v2Ephemeral)
            let ciphertext = try Self.seal(plainData, using: symmetricKey)
            // `ephemeralPrivateKey` leaves scope here and is never persisted or returned.
            return EncryptedMessage(
                version: .v2Ephemeral,
                ephemeralPublicKey: ephemeralPrivateKey.publicKey.rawRepresentation,
                data: ciphertext
            )
        }
    }

    /// 暗号文を復号する。`encryptedMessage.version` を見て方式を分岐する（TASK-127）。
    ///
    /// - v1: 従来通り送信者の長期公開鍵（`senderPublicKey`）と共有秘密を再計算する。
    /// - v2: メッセージ同梱のエフェメラル公開鍵と自分の長期秘密鍵で共有秘密を再計算する
    ///   （`senderPublicKey` は参照しない）。既存の v1 暗号文はそのまま復号でき、破壊的変更を避ける。
    public func decrypt(
        encryptedMessage: EncryptedMessage, receiverPrivateKey: Data, senderPublicKey: Data
    ) throws -> String {
        let receiverKey: Curve25519.KeyAgreement.PrivateKey
        do {
            receiverKey = try Curve25519.KeyAgreement.PrivateKey(rawRepresentation: receiverPrivateKey)
        } catch {
            throw DecryptionError.invalidKey
        }

        // The peer half of the agreement depends on the version: v1 uses the sender's
        // long-term key, v2 uses the ephemeral key carried in the message.
        let peerPublicKeyData: Data
        switch encryptedMessage.version {
        case .v1Static:
            peerPublicKeyData = senderPublicKey
        case .v2Ephemeral:
            guard let ephemeralPublicKey = encryptedMessage.ephemeralPublicKey else {
                throw DecryptionError.invalidData
            }
            peerPublicKeyData = ephemeralPublicKey
        }

        let peerKey: Curve25519.KeyAgreement.PublicKey
        do {
            peerKey = try Curve25519.KeyAgreement.PublicKey(rawRepresentation: peerPublicKeyData)
        } catch {
            throw DecryptionError.invalidKey
        }

        let sharedSecret = try receiverKey.sharedSecretFromKeyAgreement(with: peerKey)
        let symmetricKey = Self.deriveKey(from: sharedSecret, version: encryptedMessage.version)

        let sealedBox: AES.GCM.SealedBox
        do {
            sealedBox = try AES.GCM.SealedBox(combined: encryptedMessage.data)
        } catch {
            throw DecryptionError.invalidData
        }

        let decryptedData: Data
        do {
            decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw DecryptionError.authenticationFailed
        }

        guard let text = String(data: decryptedData, encoding: .utf8) else {
            throw DecryptionError.invalidData
        }

        return text
    }

    // MARK: - Key derivation / sealing (shared by v1 & v2)

    /// 共有秘密から AES-GCM 用の対称鍵を導出する。salt はプロトコル定数を継続し、`sharedInfo` に
    /// version を織り込むことで v1/v2 の鍵導出を分離する（v1 は互換のため空 `sharedInfo` を維持）。
    private static func deriveKey(
        from sharedSecret: SharedSecret, version: EncryptedMessage.Version
    ) -> SymmetricKey {
        let sharedInfo: Data
        switch version {
        case .v1Static:
            sharedInfo = Data()
        case .v2Ephemeral:
            sharedInfo = Data([EncryptedMessage.Version.v2Ephemeral.rawValue])
        }
        return sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: hkdfSalt,
            sharedInfo: sharedInfo,
            outputByteCount: 32
        )
    }

    private static func seal(_ plainData: Data, using symmetricKey: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(plainData, using: symmetricKey)
        guard let combinedData = sealedBox.combined else {
            throw DecryptionError.invalidData
        }
        return combinedData
    }
}
