import XCTest
import CryptoKit
@testable import DriftSonarCore

/// TASK-131: 安全番号 QR 突合による検証済み保存のテスト。
final class ContactVerificationTests: XCTestCase {

    private func makeKey() -> Data {
        Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
    }

    // MARK: - QR ペイロード parse（SafetyNumber）

    func testQRPayloadRoundTrips() {
        let sn = SafetyNumber.compute(makeKey(), makeKey())
        XCTAssertEqual(SafetyNumber.digits(fromQRPayload: sn.qrPayload), sn.digits)
        XCTAssertTrue(sn.qrPayload.hasPrefix("driftsonar://sn/"))
    }

    func testQRPayloadRejectsWrongScheme() {
        let sn = SafetyNumber.compute(makeKey(), makeKey())
        XCTAssertNil(SafetyNumber.digits(fromQRPayload: "driftsonar://pk/\(sn.digits)"))
        XCTAssertNil(SafetyNumber.digits(fromQRPayload: sn.digits))  // スキームなし
    }

    func testQRPayloadRejectsMalformedDigits() {
        XCTAssertNil(SafetyNumber.digits(fromQRPayload: "driftsonar://sn/12345"))          // 桁不足
        XCTAssertNil(SafetyNumber.digits(fromQRPayload: "driftsonar://sn/" + String(repeating: "1", count: 61)))  // 桁超過
        XCTAssertNil(SafetyNumber.digits(fromQRPayload: "driftsonar://sn/" + String(repeating: "a", count: 60)))  // 非数字
    }

    // MARK: - 突合と永続化

    /// 相手の QR（＝相手端末が計算した安全番号）を突合すると一致し、検証済みが保存される。
    func testVerifyMatchPersists() throws {
        let mine = makeKey()
        let theirs = makeKey()
        // 相手端末視点の安全番号（順序非依存なので自端末計算値と一致するはず）。
        let peerQR = SafetyNumber.compute(theirs, mine).qrPayload

        let repo = InMemoryVerifiedContactRepository()
        let service = ContactVerificationService(repository: repo)
        let now = Date(timeIntervalSince1970: 1_000)

        let result = try service.verify(
            scannedPayload: peerQR,
            myPublicKey: mine,
            otherPublicKey: theirs,
            now: now
        )

        guard case let .verified(contact) = result else {
            return XCTFail("一致時は .verified を返すべき: \(result)")
        }
        XCTAssertEqual(contact.publicKey, theirs)
        XCTAssertEqual(contact.verifiedAt, now)
        XCTAssertTrue(try service.isVerified(otherPublicKey: theirs))
        XCTAssertEqual(try service.verifiedContact(for: theirs)?.safetyNumberDigits,
                       SafetyNumber.compute(mine, theirs).digits)
    }

    /// 別人（すり替え）の QR は不一致になり、検証済みは保存されない。
    func testVerifyMismatchDoesNotPersist() throws {
        let mine = makeKey()
        let theirs = makeKey()
        let attacker = makeKey()
        // 攻撃者が自分の鍵で作った安全番号を相手のものと偽って提示。
        let attackerQR = SafetyNumber.compute(attacker, mine).qrPayload

        let repo = InMemoryVerifiedContactRepository()
        let service = ContactVerificationService(repository: repo)

        let result = try service.verify(
            scannedPayload: attackerQR,
            myPublicKey: mine,
            otherPublicKey: theirs
        )

        XCTAssertEqual(result, .mismatch)
        XCTAssertFalse(try service.isVerified(otherPublicKey: theirs))
    }

    /// 壊れた QR は invalidPayload として弾き、永続化しない。
    func testVerifyInvalidPayload() throws {
        let mine = makeKey()
        let theirs = makeKey()
        let repo = InMemoryVerifiedContactRepository()
        let service = ContactVerificationService(repository: repo)

        let result = try service.verify(
            scannedPayload: "not-a-driftsonar-uri",
            myPublicKey: mine,
            otherPublicKey: theirs
        )

        XCTAssertEqual(result, .invalidPayload)
        XCTAssertFalse(try service.isVerified(otherPublicKey: theirs))
    }

    /// 未検証の相手は isVerified=false。
    func testUnknownContactIsUnverified() throws {
        let service = ContactVerificationService(repository: InMemoryVerifiedContactRepository())
        XCTAssertFalse(try service.isVerified(otherPublicKey: makeKey()))
    }

    // MARK: - 検証状態の 3 値判定と失効（TASK-132）

    /// レコードが無ければ status は unverified。
    func testStatusUnverifiedWhenNoRecord() throws {
        let service = ContactVerificationService(repository: InMemoryVerifiedContactRepository())
        XCTAssertEqual(try service.status(myPublicKey: makeKey(), otherPublicKey: makeKey()), .unverified)
    }

    /// 検証時と同じ鍵素材なら status は verified。
    func testStatusVerifiedWhenSafetyNumberMatches() throws {
        let mine = makeKey()
        let theirs = makeKey()
        let peerQR = SafetyNumber.compute(theirs, mine).qrPayload
        let service = ContactVerificationService(repository: InMemoryVerifiedContactRepository())
        _ = try service.verify(scannedPayload: peerQR, myPublicKey: mine, otherPublicKey: theirs)

        guard case let .verified(contact) = try service.status(myPublicKey: mine, otherPublicKey: theirs) else {
            return XCTFail("鍵素材が変わっていなければ verified を返すべき")
        }
        XCTAssertEqual(contact.publicKey, theirs)
    }

    /// 検証済みレコードは残るが自分の鍵が変わると安全番号が食い違い、keyChanged になる。
    func testStatusKeyChangedWhenSafetyNumberDiffers() throws {
        let mine = makeKey()
        let theirs = makeKey()
        let peerQR = SafetyNumber.compute(theirs, mine).qrPayload
        let service = ContactVerificationService(repository: InMemoryVerifiedContactRepository())
        _ = try service.verify(scannedPayload: peerQR, myPublicKey: mine, otherPublicKey: theirs)

        // 自分の鍵が変わった（再インストール・鍵ローテーション相当）。相手キーは同じ。
        let myNewKey = makeKey()
        guard case let .keyChanged(previous) = try service.status(myPublicKey: myNewKey, otherPublicKey: theirs) else {
            return XCTFail("鍵素材が変わったら keyChanged を返すべき")
        }
        XCTAssertEqual(previous.safetyNumberDigits, SafetyNumber.compute(mine, theirs).digits)
    }

    /// keyChanged でもレコードは残り、警告が 1 回で消えない（status は毎回 keyChanged を返す）。
    /// 再検証すると save が上書きし、status は verified へ戻る。
    func testStatusKeyChangedPersistsUntilReVerify() throws {
        let mine = makeKey()
        let theirs = makeKey()
        let peerQR = SafetyNumber.compute(theirs, mine).qrPayload
        let service = ContactVerificationService(repository: InMemoryVerifiedContactRepository())
        _ = try service.verify(scannedPayload: peerQR, myPublicKey: mine, otherPublicKey: theirs)

        // 自分の鍵が変わった状態では、何度呼んでも keyChanged のまま（警告は消えない）。
        let myNewKey = makeKey()
        guard case .keyChanged = try service.status(myPublicKey: myNewKey, otherPublicKey: theirs) else {
            return XCTFail("keyChanged を返すべき")
        }
        guard case .keyChanged = try service.status(myPublicKey: myNewKey, otherPublicKey: theirs) else {
            return XCTFail("再取得しても keyChanged のままであるべき")
        }

        // 新しい鍵素材で対面再確認すると上書きされ、status は verified へ回復する。
        let newPeerQR = SafetyNumber.compute(theirs, myNewKey).qrPayload
        _ = try service.verify(scannedPayload: newPeerQR, myPublicKey: myNewKey, otherPublicKey: theirs)
        guard case .verified = try service.status(myPublicKey: myNewKey, otherPublicKey: theirs) else {
            return XCTFail("再検証後は verified に戻るべき")
        }
    }

    /// 再検証すると verifiedAt が更新される（上書き）。
    func testReVerifyUpdatesTimestamp() throws {
        let mine = makeKey()
        let theirs = makeKey()
        let peerQR = SafetyNumber.compute(theirs, mine).qrPayload
        let service = ContactVerificationService(repository: InMemoryVerifiedContactRepository())

        _ = try service.verify(scannedPayload: peerQR, myPublicKey: mine, otherPublicKey: theirs,
                               now: Date(timeIntervalSince1970: 1))
        _ = try service.verify(scannedPayload: peerQR, myPublicKey: mine, otherPublicKey: theirs,
                               now: Date(timeIntervalSince1970: 999))

        XCTAssertEqual(try service.verifiedContact(for: theirs)?.verifiedAt,
                       Date(timeIntervalSince1970: 999))
    }
}
