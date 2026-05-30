import XCTest
import CryptoKit
@testable import DriftSonarCore

/// TASK-155: startup integrity check between the profile and its Keychain keys.
final class ProfileIntegrityTests: XCTestCase {

    override func tearDown() {
        try? KeychainService.delete(account: KeychainService.agreementPrivateKeyAccount)
        try? KeychainService.delete(account: KeychainService.signingPrivateKeyAccount)
        super.tearDown()
    }

    func testReturnsOkWhenKeysMatchStoredPublicKeys() throws {
        let agreement = Curve25519.KeyAgreement.PrivateKey()
        let signing = Curve25519.Signing.PrivateKey()
        try KeychainService.save(agreement.rawRepresentation, account: KeychainService.agreementPrivateKeyAccount)
        try KeychainService.save(signing.rawRepresentation, account: KeychainService.signingPrivateKeyAccount)

        let status = ProfileIntegrity.verify(
            publicKey: agreement.publicKey.rawRepresentation,
            signingPublicKey: signing.publicKey.rawRepresentation
        )

        XCTAssertEqual(status, .ok)
    }

    func testReturnsKeysMissingWhenKeychainEmpty() {
        try? KeychainService.delete(account: KeychainService.agreementPrivateKeyAccount)
        try? KeychainService.delete(account: KeychainService.signingPrivateKeyAccount)

        let status = ProfileIntegrity.verify(
            publicKey: Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation,
            signingPublicKey: Curve25519.Signing.PrivateKey().publicKey.rawRepresentation
        )

        XCTAssertEqual(status, .keysMissing)
    }

    func testReturnsKeyMismatchWhenStoredKeysBelongToDifferentProfile() throws {
        // Keychain holds one profile's keys, but we verify against another's public keys.
        let storedAgreement = Curve25519.KeyAgreement.PrivateKey()
        let storedSigning = Curve25519.Signing.PrivateKey()
        try KeychainService.save(storedAgreement.rawRepresentation, account: KeychainService.agreementPrivateKeyAccount)
        try KeychainService.save(storedSigning.rawRepresentation, account: KeychainService.signingPrivateKeyAccount)

        let otherAgreementPublic = Curve25519.KeyAgreement.PrivateKey().publicKey.rawRepresentation
        let otherSigningPublic = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation

        let status = ProfileIntegrity.verify(
            publicKey: otherAgreementPublic,
            signingPublicKey: otherSigningPublic
        )

        XCTAssertEqual(status, .keyMismatch)
    }
}
