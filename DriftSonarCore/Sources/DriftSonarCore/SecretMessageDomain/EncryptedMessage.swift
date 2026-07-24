import Foundation

/// 暗号化済みメッセージのワイヤーフォーマット（TASK-125）。
///
/// 先頭 1 バイトに version を持たせ、将来の方式追加（前方秘匿性など）に備える。
/// - v1（静的鍵）: `version(1) + ciphertext`
/// - v2（エフェメラル鍵）: `version(1) + ephemeralPublicKey(32) + ciphertext`
///
/// `ciphertext` は AES-GCM の combined box（nonce + ct + tag）。
public struct EncryptedMessage: Equatable {
    /// ワイヤーフォーマットのバージョン識別子。
    public enum Version: UInt8 {
        /// 旧来の静的鍵方式。エフェメラル公開鍵を持たない。
        case v1Static = 1
        /// 前方秘匿性のためのエフェメラル鍵方式。送信側の使い捨て公開鍵を同梱する。
        case v2Ephemeral = 2
    }

    /// エフェメラル公開鍵の生バイト長（Curve25519 rawRepresentation）。
    public static let ephemeralPublicKeyLength = 32

    public let version: Version
    /// v2 のときのみ存在する送信側エフェメラル公開鍵（32 byte）。
    public let ephemeralPublicKey: Data?
    /// 暗号文本体（AES-GCM combined box）。
    public let data: Data

    /// 既存の呼び出し互換: version 未指定は v1（静的鍵）とみなす。
    public init(data: Data) {
        self.version = .v1Static
        self.ephemeralPublicKey = nil
        self.data = data
    }

    /// version を明示して構築する。v2 では `ephemeralPublicKey` を渡す。
    public init(version: Version, ephemeralPublicKey: Data?, data: Data) {
        self.version = version
        self.ephemeralPublicKey = ephemeralPublicKey
        self.data = data
    }

    /// ワイヤーフォーマットへエンコードする。
    /// - Throws: v2 でエフェメラル公開鍵が無い/長さ不正なら `DecryptionError.invalidData`。
    public func encoded() throws -> Data {
        var out = Data([version.rawValue])
        switch version {
        case .v1Static:
            out.append(data)
        case .v2Ephemeral:
            guard let epk = ephemeralPublicKey,
                  epk.count == EncryptedMessage.ephemeralPublicKeyLength else {
                throw DecryptionError.invalidData
            }
            out.append(epk)
            out.append(data)
        }
        return out
    }

    /// ワイヤーフォーマットからデコードする。不正バイト列は棄却する。
    /// - Throws: 空・未知 version・v2 の長さ不足・暗号文欠落で `DecryptionError.invalidData`。
    public static func decode(_ wire: Data) throws -> EncryptedMessage {
        guard let first = wire.first, let version = Version(rawValue: first) else {
            throw DecryptionError.invalidData
        }
        // dropFirst で得た slice は count ベースの prefix/dropFirst のみ使い、Data() で 0 起点に正規化する。
        let body = wire.dropFirst()

        switch version {
        case .v1Static:
            // version の後ろに暗号文が最低 1 byte 必要。
            guard !body.isEmpty else { throw DecryptionError.invalidData }
            return EncryptedMessage(version: .v1Static, ephemeralPublicKey: nil, data: Data(body))
        case .v2Ephemeral:
            // epk(32) + 暗号文最低 1 byte が必要。
            guard body.count > ephemeralPublicKeyLength else { throw DecryptionError.invalidData }
            let epk = Data(body.prefix(ephemeralPublicKeyLength))
            let ciphertext = Data(body.dropFirst(ephemeralPublicKeyLength))
            return EncryptedMessage(version: .v2Ephemeral, ephemeralPublicKey: epk, data: ciphertext)
        }
    }
}
