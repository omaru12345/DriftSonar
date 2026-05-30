import SwiftUI
import DriftSonarCore
import CryptoKit

@Observable
class TimelineViewModel {
    var posts: [Post] = []
    var isLoading = false
    var errorMessage: String?
    /// Post IDs created anonymously this session — session-only, never persisted (TASK-110).
    var anonymousPostIds: Set<UUID> = []

    private var fetchUseCase: FetchTimelineUseCase?
    private var createUseCase: CreatePostUseCase?
    /// Pending debounce task for refresh (TASK-096).
    private var debounceTask: Task<Void, Never>?

    func setup(postRepository: PostRepository, cacheRepository: MessageCacheRepository? = nil) {
        fetchUseCase = FetchTimelineUseCase(repository: postRepository)
        createUseCase = CreatePostUseCase(repository: postRepository, cacheRepository: cacheRepository)
        refresh()
    }

    /// Debounced refresh — coalesces rapid BLE receive events (TASK-096).
    func refresh() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds
            guard !Task.isCancelled else { return }
            fetchNow()
        }
    }

    private func fetchNow() {
        guard let useCase = fetchUseCase else { return }
        isLoading = true
        errorMessage = nil
        do {
            posts = try useCase.execute(limit: 50)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func createPost(content: String, authorPublicKey: Data, authorPrivateKey: Data, isAnonymous: Bool = false) {
        guard let useCase = createUseCase else { return }
        // TASK-110: When anonymous, substitute ephemeral keys so the post is unlinkable.
        let (pubKey, privKey): (Data, Data)
        if isAnonymous {
            let ephemeral = EphemeralKeyService.generate()
            pubKey = ephemeral.publicKey
            privKey = ephemeral.privateKey
        } else {
            pubKey = authorPublicKey
            privKey = authorPrivateKey
        }
        let request = CreatePostRequest(content: content, authorPublicKey: pubKey, authorPrivateKey: privKey)
        do {
            let post = try useCase.execute(request)
            if isAnonymous { anonymousPostIds.insert(post.id) }
            refresh()
        } catch CreatePostError.emptyContent {
            errorMessage = "投稿内容を入力してください"
        } catch CreatePostError.contentTooLong {
            errorMessage = "\(CreatePostUseCase.maxContentLength)文字以内で入力してください"
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
