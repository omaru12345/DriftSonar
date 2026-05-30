import CryptoKit
import Foundation

/// Startup integrity check between the persisted profile (SwiftData) and the
/// private keys held in the Keychain (TASK-155).
///
/// A profile can become inconsistent with its keys — e.g. the SwiftData store
/// survives an app reinstall while `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// Keychain items are wiped, or a restore mixes data from two devices. In that
/// state every signature/decryption silently breaks (the failure mode TASK-153
/// already stopped masking). This type detects it up-front so the app can guide
/// the user instead of running half-broken.
public enum ProfileIntegrity {

    /// Result of verifying a profile against its Keychain key material.
    public enum Status: Equatable {
        /// Keys are present and derive to the stored public keys.
        case ok
        /// The profile exists but one or both private keys are absent from the Keychain.
        case keysMissing
        /// Private keys are present but do not derive to the stored public keys
        /// (corruption, or keys belonging to a different profile).
        case keyMismatch
    }

    /// Verifies that the Keychain holds private keys matching the profile's public keys.
    ///
    /// - Parameters:
    ///   - publicKey: stored X25519 (agreement) public key — `UserProfileModel.publicKey`.
    ///   - signingPublicKey: stored Ed25519 (signing) public key — `UserProfileModel.signingPublicKey`.
    /// - Returns: `.ok`, `.keysMissing`, or `.keyMismatch`.
    public static func verify(publicKey: Data, signingPublicKey: Data) -> Status {
        guard
            let agreementPrivate = try? KeychainService.loadAgreementPrivateKey(),
            let signingPrivate = try? KeychainService.loadSigningPrivateKey()
        else {
            return .keysMissing
        }

        // X25519: derive the agreement public key and compare.
        guard
            let derivedAgreementPublic = try? Curve25519.KeyAgreement
                .PrivateKey(rawRepresentation: agreementPrivate)
                .publicKey.rawRepresentation,
            derivedAgreementPublic == publicKey
        else {
            return .keyMismatch
        }

        // Ed25519: derive the signing public key and compare.
        guard
            let derivedSigningPublic = try? Curve25519.Signing
                .PrivateKey(rawRepresentation: signingPrivate)
                .publicKey.rawRepresentation,
            derivedSigningPublic == signingPublicKey
        else {
            return .keyMismatch
        }

        return .ok
    }
}
