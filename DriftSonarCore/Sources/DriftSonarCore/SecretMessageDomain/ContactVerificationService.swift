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

/// 会話ごとの検証状態（TASK-132）。バッジ表示と警告の 3 分岐に使う。
///
/// 検証済みレコードは相手の公開鍵をキーに「検証したときの安全番号」を保持している。
/// 安全番号は双方の鍵素材から決まるので、レコードは残っているのに今の安全番号が
/// 保存値と食い違うなら、検証を裏付けた鍵素材が変わった＝検証は無効、という判定になる。
public enum ContactVerificationStatus: Equatable, Sendable {
    /// 検証済みレコードが無い（対面突合をしていない）。
    case unverified
    /// レコードがあり、今の安全番号も保存値と一致する（＝有効な検証済み）。
    case verified(VerifiedContact)
    /// レコードはあるが今の安全番号が保存値と異なる。検証を裏付けた鍵素材が
    /// 変わっているので検証は失効扱い。UI は再確認を促す（TASK-132）。
    case keyChanged(previous: VerifiedContact)
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

    /// この会話の検証状態を 3 値（未検証/検証済み/安全番号変化）で返す（TASK-132）。
    ///
    /// レコードが保持する安全番号と、いまの自分・相手の公開鍵から算出した安全番号を
    /// 突き合わせ、食い違えば `keyChanged`（検証を裏付けた鍵素材が変わった）と判定する。
    ///
    /// `keyChanged` のときにレコードを消さないのは意図的：消すと次回以降は
    /// `unverified` に戻って警告が 1 回きりで消えてしまうため。古いレコードを残すことで、
    /// 相手を再び対面確認して `verify()` が上書き保存するまで、警告を出し続けられる。
    /// 検証済み扱い（バッジ）は `verified` のときだけなので「検証のリセット」は満たす。
    /// - Parameters:
    ///   - myPublicKey: 自分の長期公開鍵（agreement）。
    ///   - otherPublicKey: 相手の長期公開鍵（会話の識別子）。
    public func status(myPublicKey: Data, otherPublicKey: Data) throws -> ContactVerificationStatus {
        guard let record = try repository.find(publicKey: otherPublicKey) else {
            return .unverified
        }
        let current = SafetyNumber.compute(myPublicKey, otherPublicKey).digits
        return current == record.safetyNumberDigits
            ? .verified(record)
            : .keyChanged(previous: record)
    }
}
