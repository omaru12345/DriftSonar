import XCTest
import DriftSonarCore
@testable import DriftSonarApp

/// Unit tests for `TimelineViewModel` — post creation, validation, anonymous flow and refresh (TASK-159).
final class TimelineViewModelTests: XCTestCase {

    private let dummyKey = Data(repeating: 0x01, count: 32)

    // MARK: - createPost 正常系

    func testCreateAnonymousPostSucceedsAndTracksID() {
        let repo = InMemoryPostRepository()
        let vm = TimelineViewModel()
        vm.setup(postRepository: repo)

        let error = vm.createPost(content: "漂流メッセージ", authorPublicKey: dummyKey, isAnonymous: true)

        XCTAssertNil(error, "匿名投稿は成功する")
        XCTAssertEqual(repo.posts.count, 1)
        XCTAssertEqual(repo.posts.first?.content, "漂流メッセージ")
        XCTAssertEqual(vm.anonymousPostIds.count, 1, "匿名投稿IDはセッション内で追跡される")
        XCTAssertTrue(vm.anonymousPostIds.contains(repo.posts[0].id))
    }

    func testCreateAnonymousPostUsesEphemeralKeyNotAuthorKey() {
        let repo = InMemoryPostRepository()
        let vm = TimelineViewModel()
        vm.setup(postRepository: repo)

        let error = vm.createPost(content: "匿名", authorPublicKey: dummyKey, isAnonymous: true)

        // まず生成成功を確定させる（投稿が無いと下の比較が nil で偽陽性になるため）。
        XCTAssertNil(error)
        XCTAssertEqual(repo.posts.count, 1)
        // TASK-110: 匿名投稿は本人鍵と紐づかない使い捨て鍵で署名される。
        XCTAssertNotEqual(repo.posts.first?.authorPublicKey, dummyKey)
    }

    // MARK: - createPost 異常系

    func testCreateEmptyPostReturnsMessageError() {
        let repo = InMemoryPostRepository()
        let vm = TimelineViewModel()
        vm.setup(postRepository: repo)

        let error = vm.createPost(content: "   ", authorPublicKey: dummyKey, isAnonymous: true)

        guard case .message = error else {
            return XCTFail("空投稿は .message エラーを返す（実際: \(String(describing: error)))")
        }
        XCTAssertTrue(repo.posts.isEmpty)
    }

    func testCreateTooLongPostReturnsMessageError() {
        let repo = InMemoryPostRepository()
        let vm = TimelineViewModel()
        vm.setup(postRepository: repo)

        let tooLong = String(repeating: "あ", count: 281)  // maxContentLength(280) 超過
        let error = vm.createPost(content: tooLong, authorPublicKey: dummyKey, isAnonymous: true)

        guard case .message = error else {
            return XCTFail("長すぎる投稿は .message エラーを返す（実際: \(String(describing: error)))")
        }
        XCTAssertTrue(repo.posts.isEmpty)
    }

    func testCreatePostWithoutSetupReturnsPostFailed() {
        let vm = TimelineViewModel()

        let error = vm.createPost(content: "hi", authorPublicKey: dummyKey, isAnonymous: true)

        XCTAssertEqual(error, .postFailed, "setup 前は .postFailed を返す")
    }

    // MARK: - refresh

    func testRefreshLoadsExistingPostsFromRepository() {
        let repo = InMemoryPostRepository()
        // 事前に1件投入（署名は Core の既存パターン同様ダミー鍵で成立）。
        let seed = try! CreatePostUseCase(repository: repo).execute(
            CreatePostRequest(
                content: "既存の漂流物",
                authorPublicKey: Data(repeating: 0x02, count: 32),
                authorPrivateKey: Data(repeating: 0x03, count: 32)
            )
        )

        let vm = TimelineViewModel()
        vm.setup(postRepository: repo)  // refresh() は 0.5 秒デバウンス

        let loaded = expectation(description: "debounced refresh populates posts")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            loaded.fulfill()
        }
        wait(for: [loaded], timeout: 2.0)

        XCTAssertEqual(vm.posts.count, 1)
        XCTAssertEqual(vm.posts.first?.id, seed.id)
        XCTAssertFalse(vm.isLoading)
    }
}
