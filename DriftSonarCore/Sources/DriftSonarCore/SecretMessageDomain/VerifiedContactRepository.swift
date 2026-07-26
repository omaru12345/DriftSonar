import Foundation

/// 対面で安全番号を突き合わせて検証済みになった相手（TASK-131 / EP-025）。
///
/// 相手の長期公開鍵を主キーとして「いつ・どの安全番号で確認したか」を保持する。
/// 公開鍵が変われば安全番号も変わる（＝別レコード）ので、鍵すり替え時は自然に
/// 未検証へ戻る。識別子ベースの明示的な「鍵が変わった」警告は TASK-132 で追加する。
public struct VerifiedContact: Equatable, Sendable {
    /// 検証済み相手の X25519 長期公開鍵（会話の識別子）。
    public let publicKey: Data
    /// 突合に成功したときの安全番号（60 桁）。後からの再確認・表示に使う。
    public let safetyNumberDigits: String
    /// 検証した日時。
    public let verifiedAt: Date

    public init(publicKey: Data, safetyNumberDigits: String, verifiedAt: Date = Date()) {
        self.publicKey = publicKey
        self.safetyNumberDigits = safetyNumberDigits
        self.verifiedAt = verifiedAt
    }
}

/// 検証済み相手の永続化（TASK-131）。SwiftData 実装とテスト用インメモリ実装を差し替える。
public protocol VerifiedContactRepository {
    /// 検証済みレコードを保存（同じ公開鍵は上書き）。
    func save(_ contact: VerifiedContact) throws
    /// 公開鍵に対応する検証済みレコードを返す（未検証なら `nil`）。
    func find(publicKey: Data) throws -> VerifiedContact?
    /// 検証済み状態を破棄（鍵変更検知時の失効・TASK-132 で利用）。
    func delete(publicKey: Data) throws
}
