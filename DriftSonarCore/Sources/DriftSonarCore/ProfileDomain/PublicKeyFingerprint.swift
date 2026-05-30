import CryptoKit
import Foundation

/// Generates a short, human-readable fingerprint from a raw public key.
public enum PublicKeyFingerprint {
    /// SHA-256 の先頭 8 byte を hex 文字列で返す（例: "a1b2c3d4e5f60718"）。
    public static func hex(of keyData: Data) -> String {
        guard !keyData.isEmpty else { return "--------" }
        let digest = SHA256.hash(data: keyData)
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    /// 4文字ずつスペース区切りの読みやすい形式（例: "a1b2 c3d4 e5f6 0718"）。
    public static func formatted(of keyData: Data) -> String {
        let raw = hex(of: keyData)
        return stride(from: 0, to: raw.count, by: 4).map { i in
            let start = raw.index(raw.startIndex, offsetBy: i)
            let end = raw.index(start, offsetBy: min(4, raw.count - i))
            return String(raw[start..<end])
        }.joined(separator: " ")
    }
}
