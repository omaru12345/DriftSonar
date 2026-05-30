import SwiftData
import SwiftUI
import DriftSonarCore

struct PostTimelineView: View {
    let myProfile: UserProfileModel
    let appServices: AppServices
    @State private var showingCompose = false
    @Environment(\.modelContext) private var modelContext

    private var viewModel: TimelineViewModel { appServices.timelineViewModel }
    /// TASK-033: Live query of blocked keys — filters posts from blocked authors.
    @Query private var blockedKeyModels: [BlockedKeyModel]
    /// TASK-078: Live query of encountered peers for nickname resolution.
    @Query private var encounteredPeers: [EncounteredEventModel]

    private var blockedKeys: Set<Data> {
        Set(blockedKeyModels.map(\.publicKey))
    }

    /// Maps peerPublicKey → nickname for encountered peers (TASK-078).
    private var nicknameMap: [Data: String] {
        Dictionary(
            encounteredPeers.compactMap { model -> (Data, String)? in
                guard let nickname = model.nickname, !nickname.isEmpty else { return nil }
                return (model.peerPublicKey, nickname)
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var visiblePosts: [Post] {
        viewModel.posts.filter { !blockedKeys.contains($0.authorPublicKey) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.posts.isEmpty {
                    SkeletonTimelineView()
                } else if visiblePosts.isEmpty {
                    EmptyTimelineView()
                } else {
                    ScrollViewReader { proxy in
                    List(visiblePosts, id: \.id) { post in
                        postRow(for: post)
                    }
                    .listStyle(.plain)
                    .refreshable { viewModel.refresh() }
                    // TASK-090: Auto-scroll to top when new posts arrive.
                    .onChange(of: visiblePosts.count) { oldCount, newCount in
                        if newCount > oldCount, let first = visiblePosts.first {
                            withAnimation { proxy.scrollTo(first.id, anchor: .top) }
                        }
                    }
                    } // end ScrollViewReader
                }
            }
            .navigationTitle("Timeline")
            // TASK-084: Reset unread badge when user opens the Timeline.
            .onAppear { appServices.unreadPostCount = 0 }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCompose = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingCompose) {
                // TASK-109/110: Pass isAnonymous flag from ComposeView to ViewModel.
                // TASK-153: The signing key is loaded inside the ViewModel; the View no
                // longer touches the Keychain, and key-load failures surface as an alert.
                ComposeView(authorPublicKey: myProfile.signingPublicKey) { content, isAnonymous in
                    viewModel.createPost(
                        content: content,
                        authorPublicKey: myProfile.signingPublicKey,
                        isAnonymous: isAnonymous
                    )
                }
            }
            .alert("エラー", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    /// Builds the row view for a single post, resolving nickname and anonymous state (TASK-111).
    @ViewBuilder
    private func postRow(for post: Post) -> some View {
        let isAnonymous = viewModel.anonymousPostIds.contains(post.id)
        let isMine = post.authorPublicKey == myProfile.signingPublicKey
        let displayName = resolveDisplayName(post: post, isMine: isMine, isAnonymous: isAnonymous)
        PostRowView(post: post, displayName: displayName, isAnonymous: isAnonymous)
            .contextMenu {
                Button {
                    UIPasteboard.general.string = post.content
                } label: {
                    Label("テキストをコピー", systemImage: "doc.on.doc")
                }
                if !isMine {
                    Button(role: .destructive) {
                        blockAuthor(publicKey: post.authorPublicKey)
                    } label: {
                        Label("このユーザーをブロック", systemImage: "hand.raised.fill")
                    }
                }
            }
    }

    private func resolveDisplayName(post: Post, isMine: Bool, isAnonymous: Bool) -> String {
        if isAnonymous { return "匿名" }
        if isMine { return myProfile.nickname }
        return nicknameMap[post.authorPublicKey]
            ?? String(PublicKeyFingerprint.hex(of: post.authorPublicKey).prefix(8)) + "…"
    }

    // TASK-087: Block a post author directly from the Timeline.
    private func blockAuthor(publicKey: Data) {
        let model = BlockedKeyModel(publicKey: publicKey)
        modelContext.insert(model)
        try? modelContext.save()
    }
}

// MARK: - PostRowView

struct PostRowView: View {
    let post: Post
    /// Resolved display name — nickname if available, otherwise short fingerprint (TASK-078).
    let displayName: String
    /// True when this post was created anonymously this session (TASK-111).
    var isAnonymous: Bool = false

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: post.timestamp, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                // TASK-111: Use ghost icon and muted style for anonymous posts.
                Label(displayName, systemImage: isAnonymous ? "person.fill.questionmark" : "person.circle")
                    .font(.caption)
                    .foregroundStyle(isAnonymous ? .tertiary : .secondary)
                Spacer()
                Text(relativeTime)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Text(post.content)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                hopBadge
                Label("TTL \(post.ttl)", systemImage: "timer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var hopBadge: some View {
        let color: Color = post.hopCount == 0 ? .blue
            : post.hopCount <= 2 ? .green
            : post.hopCount <= 5 ? .orange
            : .red
        return Label(
            post.hopCount == 0 ? "直接" : "\(post.hopCount)人経由",
            systemImage: "point.3.connected.trianglepath.dotted"
        )
        .font(.caption2)
        .foregroundStyle(color)
    }
}

// MARK: - SkeletonTimelineView

private struct SkeletonTimelineView: View {
    var body: some View {
        List(0..<6, id: \.self) { _ in
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 120, height: 12)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 200, height: 16)
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
        .redacted(reason: .placeholder)
    }
}

// MARK: - EmptyTimelineView

// TASK-115: Dolphin mascot illustration in empty state.
private struct EmptyTimelineView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image("DriftSonarLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .opacity(0.7)
            Text("まだ投稿がありません")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("BLE 圏内に誰かがいると\nメッセージが流れてきます")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
