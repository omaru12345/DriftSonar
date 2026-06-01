import SwiftData
import SwiftUI
import DriftSonarCore

struct PostTimelineView: View {
    let myProfile: UserProfileModel
    let appServices: AppServices
    @State private var showingCompose = false
    /// TASK-167: Locally reported (hidden) post IDs, loaded from `ReportStore`.
    @State private var reportedPostIds: Set<UUID> = ReportStore.reportedIDs()
    /// TASK-167: Post currently targeted by the report confirmation dialog.
    @State private var reportTarget: Post?
    @Environment(\.modelContext) private var modelContext

    /// TASK-167: Shared content filter for masking the copy action.
    private static let contentFilter = ContentFilter()

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
        viewModel.posts.filter {
            // TASK-033: hide blocked authors. TASK-167: hide reported posts.
            !blockedKeys.contains($0.authorPublicKey) && !reportedPostIds.contains($0.id)
        }
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
                ComposeView(
                    authorPublicKey: myProfile.signingPublicKey,
                    mediaIngestService: appServices.mediaIngestService
                ) { content, isAnonymous, media in
                    // TASK-142: createPost returns nil on success or an AppError on failure,
                    // letting ComposeView keep the sheet open and report the problem.
                    // TASK-187: media descriptors travel through to the use case.
                    viewModel.createPost(
                        content: content,
                        authorPublicKey: myProfile.signingPublicKey,
                        isAnonymous: isAnonymous,
                        media: media
                    )
                }
            }
            // TASK-154: Unified error alert.
            .errorAlert(Binding(
                get: { viewModel.error },
                set: { viewModel.error = $0 }
            ))
            // TASK-167: Report reasons. Reporting hides the post locally at once;
            // there is no server, so the report is purely an on-device action.
            .confirmationDialog(
                "この投稿を通報",
                isPresented: Binding(
                    get: { reportTarget != nil },
                    set: { if !$0 { reportTarget = nil } }
                ),
                titleVisibility: .visible,
                presenting: reportTarget
            ) { post in
                ForEach(ReportStore.Reason.allCases) { reason in
                    Button(reason.rawValue, role: .destructive) {
                        report(post: post, reason: reason)
                    }
                }
                Button("キャンセル", role: .cancel) { reportTarget = nil }
            } message: { _ in
                Text("通報した投稿はこの端末で即座に非表示になります。投稿者をまとめて非表示にするにはブロックをご利用ください。")
            }
        }
    }

    /// Builds the row view for a single post, resolving nickname and anonymous state (TASK-111).
    @ViewBuilder
    private func postRow(for post: Post) -> some View {
        let isAnonymous = viewModel.anonymousPostIds.contains(post.id)
        let isMine = post.authorPublicKey == myProfile.signingPublicKey
        let displayName = resolveDisplayName(post: post, isMine: isMine, isAnonymous: isAnonymous)
        PostRowView(
            post: post,
            displayName: displayName,
            isAnonymous: isAnonymous,
            mediaStore: appServices.mediaStore
        )
            .contextMenu {
                Button {
                    // TASK-167: Copy the masked text so prohibited words stay filtered.
                    UIPasteboard.general.string = Self.contentFilter.mask(post.content)
                } label: {
                    Label("テキストをコピー", systemImage: "doc.on.doc")
                }
                if !isMine {
                    // TASK-167: Report this post — hides it immediately on this device.
                    Button(role: .destructive) {
                        reportTarget = post
                    } label: {
                        Label("この投稿を通報", systemImage: "flag.fill")
                    }
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

    // TASK-167: Report a post — record it and hide it from this device immediately.
    private func report(post: Post, reason: ReportStore.Reason) {
        reportedPostIds = ReportStore.report(postID: post.id, reason: reason)
        reportTarget = nil
    }
}

// MARK: - PostRowView

struct PostRowView: View {
    let post: Post
    /// Resolved display name — nickname if available, otherwise short fingerprint (TASK-078).
    let displayName: String
    /// True when this post was created anonymously this session (TASK-111).
    var isAnonymous: Bool = false
    /// TASK-188: Media store used to resolve attachment thumbnails/bodies. `nil` hides media.
    var mediaStore: MediaStore?

    /// TASK-188: Attachment index the full-screen viewer should open at, `nil` = closed.
    @State private var viewerSelection: MediaViewerSelection?

    /// TASK-167: Shared content filter that masks prohibited words on display.
    private static let contentFilter = ContentFilter()

    /// TASK-167: Post body with any prohibited words replaced by mask characters.
    private var displayedContent: String {
        Self.contentFilter.mask(post.content)
    }

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

            if !displayedContent.isEmpty {
                Text(displayedContent)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // TASK-188: Media mosaic; tapping a tile opens the full-screen viewer.
            // Hidden when the post carries no media or the store is unavailable.
            if !post.media.isEmpty, mediaStore != nil {
                PostMediaGridView(media: post.media, store: mediaStore) { index in
                    viewerSelection = MediaViewerSelection(index: index)
                }
                .padding(.top, 2)
            }

            HStack(spacing: 12) {
                hopBadge
                Label("TTL \(post.ttl)", systemImage: "timer")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        // TASK-188: Full-screen viewer, opened at the tapped attachment.
        .fullScreenCover(item: $viewerSelection) { selection in
            MediaViewerView(media: post.media, startIndex: selection.index, store: mediaStore)
        }
    }

    private var hopBadge: some View {
        let color: Color = post.hopCount == 0 ? .accentColor
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

/// TASK-188: Identifiable wrapper so `fullScreenCover(item:)` can open the viewer
/// at a specific attachment index.
private struct MediaViewerSelection: Identifiable {
    let id = UUID()
    let index: Int
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
