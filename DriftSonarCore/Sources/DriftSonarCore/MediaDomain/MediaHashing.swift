import Foundation
import CryptoKit

/// メディア本体の SHA-256 を計算する。
///
/// メディアID = contentHash（`docs/media-propagation.md`）。本体取得・キャッシュキー・
/// 重複排除・完全性検証にこの 64 hex 文字を流用する。`MediaAttachment.contentHash`
/// と同じ表現に揃える。
public enum MediaHashing {
    /// 本体バイト列の SHA-256（32 バイト）を返す。`MediaAttachment.contentHash` 用。
    public static func sha256(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }

    /// 本体バイト列の SHA-256 を 64 文字の小文字 hex で返す。ファイル名・ログ用。
    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
