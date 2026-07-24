import CryptoKit
import Foundation

/// 双方の長期公開鍵から、順序非依存（どちらの端末でも同じ）で決定的に導かれる検証コード。
///
/// Signal の Safety Number と同じ発想で、対面や別経路で数列を突き合わせることで
/// 中間者攻撃（相手の公開鍵のすり替え）を検知するために使う。
///
/// 生成手順（TASK-129）:
/// 1. 2つの公開鍵をバイト列でソートして正規順に連結する（順序非依存にするため）。
/// 2. 連結結果を SHA-256 でハッシュする（32 byte）。この生バイトが QR 用のコンパクト表現。
/// 3. ハッシュを 60 桁（5 桁 × 12 ブロック）の数列に変換して人間が読み上げられる形にする。
public struct SafetyNumber: Equatable {
    /// 表示用の 60 桁の数字（区切りなし）。例: "123450678901..."。
    public let digits: String

    /// QR/近距離突合用のコンパクト表現（SHA-256 の生バイト 32 byte）。
    public let compactRepresentation: Data

    /// 2つの公開鍵から Safety Number を生成する。引数の順序に依存しない。
    /// - Parameters:
    ///   - keyA: 一方の長期公開鍵の生バイト（Curve25519 rawRepresentation 等）。
    ///   - keyB: もう一方の長期公開鍵の生バイト。
    public static func compute(_ keyA: Data, _ keyB: Data) -> SafetyNumber {
        // 1. バイト列の辞書順で正規化して連結（keyA/keyB の渡し順に依存しない）。
        let canonical: Data = lexicographicallyLessThan(keyA, keyB)
            ? keyA + keyB
            : keyB + keyA

        // 2. SHA-256（32 byte）。この生バイトを QR 用コンパクト表現として保持。
        let digest = Data(SHA256.hash(data: canonical))

        // 3. 60 桁（5 桁 × 12 ブロック）へ変換。
        let digits = numericString(from: digest)

        return SafetyNumber(digits: digits, compactRepresentation: digest)
    }

    /// 5 桁ごとにスペース区切りにした読み上げ用の表現。例: "12345 06789 01234 ...".
    public var formatted: String {
        stride(from: 0, to: digits.count, by: 5).map { i in
            let start = digits.index(digits.startIndex, offsetBy: i)
            let end = digits.index(start, offsetBy: min(5, digits.count - i))
            return String(digits[start..<end])
        }.joined(separator: " ")
    }

    // MARK: - Helpers

    /// 2つの Data をバイト列として辞書順比較し、lhs が小さいかどうかを返す。
    /// 先頭から等しいバイトが続く場合は短い方を小さいとみなす。
    static func lexicographicallyLessThan(_ lhs: Data, _ rhs: Data) -> Bool {
        for (l, r) in zip(lhs, rhs) where l != r {
            return l < r
        }
        return lhs.count < rhs.count
    }

    /// SHA-256 ダイジェスト（32 byte）を 60 桁（5 桁 × 12 ブロック）の数列に変換する。
    ///
    /// 32 byte のダイジェストをカウンタ付きで 2 回ハッシュして 60 byte の擬似乱数列に伸長し、
    /// 5 byte（40bit）ずつ 12 ブロックに区切って各ブロックを `% 100000` で 5 桁に落とす。
    /// 決定的なので、同じダイジェストからは常に同じ数列が得られる。
    static func numericString(from digest: Data) -> String {
        // 32 byte では 12 ブロック分（60 byte）に足りないため、カウンタ付き SHA-256 で伸長する。
        var stream = Data()
        var counter: UInt8 = 0
        while stream.count < 60 {
            stream += Data(SHA256.hash(data: digest + Data([counter])))
            counter += 1
        }

        var result = ""
        for block in 0..<12 {
            let start = block * 5
            var value: UInt64 = 0
            for offset in 0..<5 {
                value = (value << 8) | UInt64(stream[start + offset])
            }
            result += String(format: "%05u", UInt32(value % 100_000))
        }
        return result
    }
}
