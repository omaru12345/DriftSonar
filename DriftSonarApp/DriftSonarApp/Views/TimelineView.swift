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
                    // TASK-143: Icon-only button needs an explicit VoiceOver label.
                    .accessibilityLabel("新規投稿")
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
            // TASK-138: Card list — clear row chrome so the row's own card shows through.
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
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
        VStack(alignment: .leading, spacing: 8) {
            // TASK-138: Identity row — avatar + name with the propagation badge as a
            // subtitle, and the relative time trailing.
            HStack(alignment: .center, spacing: 10) {
                avatar
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isAnonymous ? .secondary : .primary)
                    hopBadge
                }
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

            #if DEBUG
            // TASK-138: "TTL" is a developer-facing propagation counter. It is hidden
            // from end users (jargon) and shown only in debug builds for diagnostics.
            Label("TTL \(post.ttl)", systemImage: "timer")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityLabel("残り伝播回数 \(post.ttl)")
            #endif
        }
        .padding(14)
        // TASK-138: Light flat card to lift the row off the background and improve
        // readability while staying in line with the white/flat concept.
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator).opacity(0.5), lineWidth: 0.5)
        )
        // TASK-188: Full-screen viewer, opened at the tapped attachment.
        .fullScreenCover(item: $viewerSelection) { selection in
            MediaViewerView(media: post.media, startIndex: selection.index, store: mediaStore)
        }
    }

    // TASK-138: Deterministic public-key avatar (identicon). Anonymous posts keep the
    // ghost glyph so they stay visually unlinkable to a stable identity.
    @ViewBuilder
    private var avatar: some View {
        if isAnonymous {
            Image(systemName: "person.fill.questionmark")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 36)
                .background(Color(.systemGray5), in: Circle())
                .accessibilityHidden(true)
        } else {
            IdenticonView(publicKey: post.authorPublicKey, initial: avatarInitial, size: 36)
                .accessibilityHidden(true)
        }
    }

    private var avatarInitial: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(1)).uppercased()
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
        // TASK-143: hopCount is also colour-coded; give VoiceOver a full sentence
        // so the meaning does not rely on colour alone.
        .accessibilityLabel(
            post.hopCount == 0 ? "あなたに直接届いた投稿" : "\(post.hopCount)人を経由して届いた投稿"
        )
    }
}

/// TASK-188: Identifiable wrapper so `fullScreenCover(item:)` can open the viewer
/// at a specific attachment index.
private struct MediaViewerSelection: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - IdenticonView (TASK-138)

/// Deterministic avatar derived from a public key: a hue-stable gradient disc with
/// the author's initial. Gives each author a recognisable identity without a server
/// or uploaded image. The hue is derived from the key's SHA-256 fingerprint so the
/// same author always renders the same colour across devices.
struct IdenticonView: View {
    let publicKey: Data
    let initial: String
    var size: CGFloat = 36

    var body: some View {
        let base = Self.hue(for: publicKey)
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(hue: base, saturation: 0.55, brightness: 0.9),
                        Color(hue: (base + 0.08).truncatingRemainder(dividingBy: 1),
                              saturation: 0.7, brightness: 0.7),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
    }

    /// Stable 0..<1 hue from the key's fingerprint (SHA-256 based, deterministic).
    private static func hue(for key: Data) -> Double {
        let hex = PublicKeyFingerprint.hex(of: key)
        var hash = 5381
        for byte in hex.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        return Double(((hash % 360) + 360) % 360) / 360.0
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
                .accessibilityHidden(true) // TASK-143: decorative mascot
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
