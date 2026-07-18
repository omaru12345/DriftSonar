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
            .navigationTitle("タイムライン")
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

    /// TASK-197: One-shot "washed ashore" drift-in for the row. Reduced-motion → instant.
    @State private var landed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// TASK-197: Tide-mark tints adapt so both modes stay legible (driftwood brown is
    /// too dark on the abyss surface).
    @Environment(\.colorScheme) private var colorScheme

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
        .padding(DSLayout.Spacing.lg)
        // TASK-197: The foam surface the post has washed up onto, with a soft tide
        // line at its base — the waterline it drifted in to.
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSLayout.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.Radius.lg)
                .stroke(Color.driftwood.opacity(0.18), lineWidth: 0.5)
        )
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [.clear, .seaGlass.opacity(0.4), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 1.5)
            .padding(.horizontal, DSLayout.Spacing.lg)
            .accessibilityHidden(true)
        }
        // TASK-197: Drift-in — the row eases in from the trailing edge and fades up,
        // as if drifting ashore. Honours Reduce Motion by landing instantly.
        .opacity(landed ? 1 : 0)
        .offset(x: landed ? 0 : 10)
        .onAppear {
            if reduceMotion {
                landed = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) { landed = true }
            }
        }
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
                .background(Color.dsTextSecondary.opacity(0.18), in: Circle())
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

    // TASK-197: Tide mark — the hop count as "N の岸を漂って届いた", weathering from
    // fresh deep-tide (arrived directly) to driftwood brown (drifted far). No red/green
    // status colours; distance reads through the drift palette and the wording.
    private var hopBadge: some View {
        Label {
            Text(hopLabel).font(.dsCaption)
        } icon: {
            Image(systemName: post.hopCount == 0 ? "drop.fill" : "water.waves")
                .font(.caption2)
        }
        .foregroundStyle(weatheredTint)
        // TASK-143: distance also reads through colour; give VoiceOver the full sentence.
        .accessibilityLabel(
            post.hopCount == 0 ? "あなたにまっすぐ届いた投稿" : "\(post.hopCount) 個の岸を漂って届いた投稿"
        )
    }

    /// Non-jargon distance label — "岸" (shores) instead of hops/relays.
    private var hopLabel: String {
        post.hopCount == 0 ? "まっすぐ届いた" : "\(post.hopCount) の岸を漂って"
    }

    /// Weathered tint: crisp sea up close, driftwood brown far away. Lightened in dark
    /// mode so the weathered tones keep AA contrast on the abyss surface.
    private var weatheredTint: Color {
        let dark = colorScheme == .dark
        let near: Color = dark ? .seaGlass : .deepTide
        let weathered = dark ? Color(hue: 0.09, saturation: 0.20, brightness: 0.70) : .driftwood
        switch post.hopCount {
        case 0: return near
        case 1...4: return weathered
        default: return weathered.opacity(0.82)
        }
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

    // TASK-197: Deterministic avatar drawn from the drift palette instead of the full
    // hue wheel, so every author reads as part of the same sea. A faint ripple motif
    // behind the initial evokes a drifting piece of flotsam. Same key → same disc.
    private static let gradients: [(Color, Color)] = [
        (.seaGlass, .deepTide),
        (Color(hue: 0.50, saturation: 0.42, brightness: 0.72), .deepTide),
        (Color(hue: 0.55, saturation: 0.48, brightness: 0.58), Color(hue: 0.57, saturation: 0.55, brightness: 0.40)),
        (.driftwood, Color(hue: 0.08, saturation: 0.38, brightness: 0.30)),
        (.buoy, .driftwood),
        (Color(hue: 0.11, saturation: 0.30, brightness: 0.66), .deepTide),
    ]

    var body: some View {
        let (top, bottom) = Self.gradient(for: publicKey)
        Circle()
            .fill(
                LinearGradient(
                    colors: [top, bottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            // Concentric ripple rings — the disc as a spot on the water.
            .overlay {
                ZStack {
                    Circle().stroke(.white.opacity(0.14), lineWidth: 1).scaleEffect(0.72)
                    Circle().stroke(.white.opacity(0.10), lineWidth: 1).scaleEffect(0.46)
                }
            }
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
            }
    }

    /// Stable drift-palette gradient from the key's fingerprint (deterministic).
    private static func gradient(for key: Data) -> (Color, Color) {
        let hex = PublicKeyFingerprint.hex(of: key)
        var hash = 5381
        for byte in hex.utf8 { hash = ((hash << 5) &+ hash) &+ Int(byte) }
        let index = ((hash % gradients.count) + gradients.count) % gradients.count
        return gradients[index]
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
            Text("まだ何も流れ着いていません")
                .font(.dsTitle)
                .foregroundStyle(.secondary)
            Text("近くで誰かが DriftSonar を開くと\nその投稿が波に乗って流れ着きます")
                .font(.dsBody)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
