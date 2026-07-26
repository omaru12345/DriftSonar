import Foundation

/// 安全番号突合の結果（TASK-131）。
public enum ContactVerificationResult: Equatable {
    /// 突合一致 → 検証済みとして永続化した。
    case verified(VerifiedContact)
    /// スキャン値と自端末計算値が不一致（中間者攻撃の可能性）。永続化しない。
    case mismatch
    /// QR ペイロードがスキーム不一致・桁数不正など解釈不能。永続化しない。
    case invalidPayload
}

/// 相手の安全番号 QR を突合し、一致すれば検証済み状態を永続化するサービス（TASK-131 / EP-025）。
///
/// 安全番号は双方の長期公開鍵から順序非依存に導かれるため、相手の QR に載る 60 桁と
/// 自端末が計算する 60 桁は本来一致する。一致しなければ経路上で公開鍵がすり替えられている。
public final class ContactVerificationService {
    private let repository: VerifiedContactRepository

    public init(repository: VerifiedContactRepository) {
        self.repository = repository
    }

    /// スキャンした QR ペイロードを自端末計算値と突合し、一致時のみ検証済みを保存する。
    /// - Parameters:
    ///   - scannedPayload: 相手の QR から読み取った文字列（`driftsonar://sn/<60桁>`）。
    ///   - myPublicKey: 自分の長期公開鍵（生バイト）。
    ///   - otherPublicKey: 相手の長期公開鍵（生バイト）。
    ///   - now: 検証日時（テスト用に注入可能）。
    @discardableResult
    public func verify(
        scannedPayload: String,
        myPublicKey: Data,
        otherPublicKey: Data,
        now: Date = Date()
    ) throws -> ContactVerificationResult {
        guard let scannedDigits = SafetyNumber.digits(fromQRPayload: scannedPayload) else {
            return .invalidPayload
        }
        let expected = SafetyNumber.compute(myPublicKey, otherPublicKey)
        guard scannedDigits == expected.digits else {
            return .mismatch
        }
        let contact = VerifiedContact(
            publicKey: otherPublicKey,
            safetyNumberDigits: expected.digits,
            verifiedAt: now
        )
        try repository.save(contact)
        return .verified(contact)
    }

    /// この相手を検証済みとして扱ってよいか。
    public func isVerified(otherPublicKey: Data) throws -> Bool {
        try repository.find(publicKey: otherPublicKey) != nil
    }

    /// 検証済みレコード（あれば）。バッジ表示・再確認に使う。
    public func verifiedContact(for otherPublicKey: Data) throws -> VerifiedContact? {
        try repository.find(publicKey: otherPublicKey)
    }
}
