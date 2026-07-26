import SwiftUI
import DriftSonarCore
import CryptoKit

@Observable
class TimelineViewModel {
    // The app builds with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which makes this
    // `@Observable` class implicitly `@MainActor` and gives it a *main-actor-isolated*
    // `deinit`. On the iOS 17 back-deploy concurrency runtime that isolated deinit
    // (`swift_task_deinitOnExecutorMainActorBackDeploy`) double-frees its task-local scope
    // and aborts the process whenever the view model is deallocated — which the App-target
    // unit tests do constantly (TASK-159). In the app the shared view model lives for the
    // whole session and is never deallocated, so this never bit production; declaring the
    // deinit `nonisolated` keeps teardown off the executor and sidesteps the runtime bug.
    nonisolated deinit {}

    var posts: [Post] = []
    var isLoading = false
    /// Unified user-facing error surfaced as an alert (TASK-154).
    var error: AppError?
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
        error = nil
        do {
            posts = try useCase.execute(limit: 50)
        } catch {
            self.error = .message(String(localized: "タイムラインの読み込みに失敗しました。"))
        }
        isLoading = false
    }

    /// Creates a post. Returns `nil` on success, or an `AppError` describing the failure
    /// so the caller (ComposeView) can keep its sheet open and present the error there
    /// instead of dismissing into a hidden alert (TASK-142). Post failures are intentionally
    /// not written to `self.error`, which is reserved for timeline-fetch failures.
    @discardableResult
    func createPost(
        content: String,
        authorPublicKey: Data,
        isAnonymous: Bool = false,
        media: [MediaAttachment] = []
    ) -> AppError? {
        guard let useCase = createUseCase else { return .postFailed }
        // TASK-110: When anonymous, substitute ephemeral keys so the post is unlinkable.
        // TASK-153: Load the signing key here and abort+report on failure rather than
        // signing with an empty key (which would produce an invalid signature).
        let (pubKey, privKey): (Data, Data)
        if isAnonymous {
            let ephemeral = EphemeralKeyService.generate()
            pubKey = ephemeral.publicKey
            privKey = ephemeral.privateKey
        } else {
            do {
                privKey = try KeychainService.loadSigningPrivateKey()
            } catch {
                return .keyUnavailable
            }
            pubKey = authorPublicKey
        }
        let request = CreatePostRequest(
            content: content,
            authorPublicKey: pubKey,
            authorPrivateKey: privKey,
            media: media
        )
        do {
            let post = try useCase.execute(request)
            if isAnonymous { anonymousPostIds.insert(post.id) }
            refresh()
            return nil
        } catch CreatePostError.emptyContent {
            return .message(String(localized: "投稿内容を入力してください。"))
        } catch CreatePostError.contentTooLong {
            return .message(String(localized: "\(CreatePostUseCase.maxContentLength)文字以内で入力してください。"))
        } catch CreatePostError.tooManyImages {
            return .message(String(localized: "画像は\(CreatePostUseCase.maxImages)枚までです。"))
        } catch CreatePostError.tooManyVideos {
            return .message(String(localized: "動画は\(CreatePostUseCase.maxVideos)本までです。"))
        } catch CreatePostError.invalidMedia {
            return .message(String(localized: "添付メディアを処理できませんでした。容量や形式をご確認ください。"))
        } catch CreatePostError.mediaTooLarge {
            return .message(String(localized: "添付メディアの合計サイズが大きすぎます。枚数を減らすか、短い動画をお試しください。"))
        } catch {
            return .postFailed
        }
    }
}
