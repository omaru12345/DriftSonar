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
    /// TASK-197: Posts that already played their drift-in this session. Row `@State` is
    /// discarded when a List row scrolls far off screen, so without this a post would
    /// wash ashore again every time it scrolls back into view.
    private static var driftedInIds = Set<UUID>()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// True when the row should be visible immediately instead of drifting in.
    private var skipsDriftIn: Bool {
        reduceMotion || Self.driftedInIds.contains(post.id)
    }
    /// TASK-205: Drift in from the trailing edge — mirror the offset under RTL.
    @Environment(\.layoutDirection) private var layoutDirection
    private var driftInOffset: CGFloat {
        layoutDirection == .rightToLeft ? -10 : 10
    }
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

    /// TASK-149: "あと N 時間で消えます" — surfaces the retention window so the
    /// "記録に残らない" behaviour is felt, not hidden. `nil` (hidden) for the pinned
    /// welcome post (never purged) and for anything already past its window.
    private var lifetimeText: String? {
        guard post.authorPublicKey != WelcomePost.authorKey else { return nil }
        let remaining = RetentionPolicy.remainingLifetime(forTimestamp: post.timestamp)
        guard remaining > 0 else { return nil }
        let hours = Int(remaining / 3_600)
        if hours >= 1 { return "あと約\(hours)時間で消えます" }
        let minutes = Int(remaining / 60)
        if minutes >= 1 { return "あと約\(minutes)分で消えます" }
        return "まもなく消えます"
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
                // TASK-204: time is data — mono role (TASK-196).
                Text(relativeTime)
                    .font(.dsMono(.caption2))
                    .foregroundStyle(.tertiary)
            }

            if !displayedContent.isEmpty {
                Text(displayedContent)
                    .font(.dsBody)
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

            // TASK-149: Remaining lifetime before the post is purged ("記録に残らない").
            if let lifetimeText {
                Label(lifetimeText, systemImage: "hourglass")
                    .font(.dsMono(.caption2))
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(lifetimeText)
            }

            #if DEBUG
            // TASK-138: "TTL" is a developer-facing propagation counter. It is hidden
            // from end users (jargon) and shown only in debug builds for diagnostics.
            Label("TTL \(post.ttl)", systemImage: "timer")
                .font(.dsMono(.caption2))
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
        // as if drifting ashore. `skipsDriftIn` keeps the row visible from its very
        // first frame under Reduce Motion and when the row re-enters after scrolling
        // (List recreates row state, so `landed` alone cannot make this one-shot).
        .opacity(landed || skipsDriftIn ? 1 : 0)
        .offset(x: landed || skipsDriftIn ? 0 : driftInOffset)
        .animation(.easeOut(duration: 0.45), value: landed)
        .onAppear {
            if !skipsDriftIn { Self.driftedInIds.insert(post.id) }
            landed = true
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

    // TASK-197: Tide mark — the hop count as "Nつの岸を漂って届いた", weathering from
    // fresh deep-tide (arrived directly) to driftwood brown (drifted far). No red/green
    // status colours; distance reads through the drift palette and the wording.
    private var hopBadge: some View {
        Label {
            Text(hopLabel).font(.dsCaption)
        } icon: {
            // TASK-204: same text style as the label so sizes/baselines align.
            Image(systemName: post.hopCount == 0 ? "drop.fill" : "water.waves")
                .font(.caption)
        }
        .foregroundStyle(weatheredTint)
        // TASK-143: distance also reads through colour; give VoiceOver the full sentence.
        .accessibilityLabel(
            post.hopCount == 0 ? "あなたにまっすぐ届いた投稿" : "\(post.hopCount)つの岸を漂って届いた投稿"
        )
    }

    /// Non-jargon distance label — "岸" (shores) instead of hops/relays.
    private var hopLabel: String {
        post.hopCount == 0 ? "まっすぐ届いた" : "\(post.hopCount)つの岸を漂って"
    }

    /// Weathered tint: crisp sea up close, weathered ink far away (TASK-206 token —
    /// Light/Dark handled inside `dsWeatheredInk`). No further opacity fade with
    /// distance — a dimmed tier drops below AA on the foam surface, so past the
    /// first hop the extra distance reads through the wording alone.
    private var weatheredTint: Color {
        let near: Color = colorScheme == .dark ? .seaGlass : .deepTide
        return post.hopCount == 0 ? near : .dsWeatheredInk
    }
}

/// TASK-188: Identifiable wrapper so `fullScreenCover(item:)` can open the viewer
/// at a specific attachment index.
private struct MediaViewerSelection: Identifiable {
    let id = UUID()
    let index: Int
}

// MARK: - IdenticonView (TASK-138 / TASK-197 / TASK-203)

/// Deterministic avatar derived from a public key: a drift-palette gradient disc
/// with a ripple motif and the author's initial. Gives each author a recognisable
/// identity without a server or uploaded image. Three visual axes — gradient
/// (`DSIdenticonPalette`, 8), ripple motif (4) and gradient direction (2) — are
/// each derived from separate bytes of the key's SHA-256 fingerprint, giving 64
/// distinct discs while staying within the drift palette. Same key → same disc
/// on every device.
struct IdenticonView: View {
    let publicKey: Data
    let initial: String
    var size: CGFloat = 36

    var body: some View {
        let traits = Self.traits(for: publicKey)
        Circle()
            .fill(
                LinearGradient(
                    colors: [traits.gradient.top, traits.gradient.bottom],
                    startPoint: traits.flipped ? .bottomLeading : .topLeading,
                    endPoint: traits.flipped ? .topTrailing : .bottomTrailing
                )
            )
            .frame(width: size, height: size)
            // Concentric ripple rings — the disc as a spot on the water. The
            // ring pattern is one of the identity axes (TASK-203).
            .overlay { rippleMotif(traits.motif) }
            .overlay {
                Text(initial)
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
            }
    }

    @ViewBuilder
    private func rippleMotif(_ motif: Int) -> some View {
        switch motif {
        case 0:
            ZStack {
                Circle().stroke(.white.opacity(0.14), lineWidth: 1).scaleEffect(0.72)
                Circle().stroke(.white.opacity(0.10), lineWidth: 1).scaleEffect(0.46)
            }
        case 1:
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 1).scaleEffect(0.84)
                Circle().stroke(.white.opacity(0.10), lineWidth: 1).scaleEffect(0.60)
                Circle().stroke(.white.opacity(0.08), lineWidth: 1).scaleEffect(0.36)
            }
        case 2:
            Circle().stroke(.white.opacity(0.16), lineWidth: 1.5).scaleEffect(0.62)
        default:
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 1).scaleEffect(0.90)
                Circle().stroke(.white.opacity(0.12), lineWidth: 1).scaleEffect(0.52)
            }
        }
    }

    /// Stable visual traits from the key's fingerprint (deterministic). Each axis
    /// reads a different fingerprint byte so the axes vary independently.
    private static func traits(
        for key: Data
    ) -> (gradient: (top: Color, bottom: Color), motif: Int, flipped: Bool) {
        let hex = PublicKeyFingerprint.hex(of: key)
        let bytes = Self.bytes(fromHex: hex, count: 3)
        let gradients = DSIdenticonPalette.gradients
        return (
            gradient: gradients[bytes[0] % gradients.count],
            motif: bytes[1] % 4,
            flipped: bytes[2] % 2 == 1
        )
    }

    /// Parses the first `count` bytes out of a hex fingerprint string. Falls back
    /// to 0 for malformed input (fingerprint hex is always well-formed in practice).
    private static func bytes(fromHex hex: String, count: Int) -> [Int] {
        var result: [Int] = []
        var index = hex.startIndex
        for _ in 0..<count {
            // UInt8 (not Int) so a stray sign character can never yield a
            // negative index downstream.
            guard let next = hex.index(index, offsetBy: 2, limitedBy: hex.endIndex),
                  let value = UInt8(hex[index..<next], radix: 16).map(Int.init) else {
                // Defensive: stop re-evaluating the same position on malformed input.
                result.append(0)
                index = hex.endIndex
                continue
            }
            result.append(value)
            index = next
        }
        return result
    }
}

// MARK: - SkeletonTimelineView

// TASK-204: Skeleton rows mirror the washed-ashore card shape (TASK-197) so the
// loading state doesn't flash a different layout than the loaded one.
private struct SkeletonTimelineView: View {
    var body: some View {
        List(0..<6, id: \.self) { _ in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 36, height: 36)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 120, height: 12)
                }
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(maxWidth: .infinity)
                    .frame(height: 16)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 200, height: 16)
            }
            .padding(DSLayout.Spacing.lg)
            .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSLayout.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.Radius.lg)
                    .stroke(Color.driftwood.opacity(0.18), lineWidth: 0.5)
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
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
