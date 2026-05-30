import Foundation
import SwiftData

@available(macOS 14, iOS 17, *)
public class SwiftDataUserRepository: UserRepository {
    private let context: ModelContext

    @MainActor
    public init(container: ModelContainer) {
        self.context = container.mainContext
    }

    public func saveUser(_ user: UserProfile) throws {
        // Persist private keys to Keychain (TASK-035)
        try KeychainService.save(user.privateKey, account: KeychainService.agreementPrivateKeyAccount)
        try KeychainService.save(user.signingPrivateKey, account: KeychainService.signingPrivateKeyAccount)

        // Persist non-secret fields to SwiftData
        let model = UserProfileModel(
            id: user.id,
            nickname: user.nickname,
            bio: user.bio,
            publicKey: user.publicKey,
            signingPublicKey: user.signingPublicKey
        )
        context.insert(model)
        try context.save()
    }

    public func getUser() throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfileModel>()
        guard let model = try context.fetch(descriptor).first else { return nil }

        // Load private keys from Keychain. A profile without its matching keys is
        // an integrity violation (TASK-153) — fail loudly instead of returning empty
        // Data, which would silently break signing/decryption downstream.
        let privateKey = try KeychainService.loadAgreementPrivateKey()
        let signingPrivateKey = try KeychainService.loadSigningPrivateKey()

        return UserProfile(
            id: model.id,
            nickname: model.nickname,
            bio: model.bio,
            publicKey: model.publicKey,
            privateKey: privateKey,
            signingPublicKey: model.signingPublicKey,
            signingPrivateKey: signingPrivateKey
        )
    }
}
