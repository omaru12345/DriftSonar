import SwiftUI
import PhotosUI
import CoreTransferable
import UniformTypeIdentifiers
import DriftSonarCore

struct ComposeView: View {
    let authorPublicKey: Data
    /// Ingests picked photos/videos into the local store and returns signed descriptors
    /// (TASK-187). `nil` hides the attach button when the media store is unavailable.
    let mediaIngestService: MediaIngestService?
    /// Called with (content, isAnonymous, media) when the user taps "流す" (TASK-109/110/187/199).
    /// Returns `nil` on success, or an `AppError` to keep the sheet open and report (TASK-142).
    let onSubmit: (String, Bool, [MediaAttachment]) async -> AppError?

    @State private var content = ""
    @State private var isAnonymous = false
    @State private var isPosting = false
    /// Photos picked in the sheet, kept in sync with `mediaPreviews` (TASK-187).
    @State private var selection: [PhotosPickerItem] = []
    /// Ingested attachments + their thumbnails, shown in the horizontal strip (TASK-187).
    @State private var mediaPreviews: [MediaPreview] = []
    /// True while a pick is being compressed/transcoded (TASK-142 spinner consistency).
    @State private var isProcessingMedia = false
    /// Post/media failure surfaced in-sheet so it isn't hidden behind the dismissed sheet.
    @State private var activeError: AppError?
    /// TASK-199: Drives the letter card's brief "set adrift" motion after a
    /// successful post, just before the sheet dismisses.
    @State private var isDriftingAway = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    private let maxLength = CreatePostUseCase.maxContentLength

    private var remaining: Int { maxLength - content.count }
    private var isOverLimit: Bool { remaining < 0 }
    /// Text *or* media is enough to post; block while a pick is still processing.
    private var canPost: Bool {
        let hasText = !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !mediaPreviews.isEmpty) && !isOverLimit && !isProcessingMedia
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                // TASK-199: The letter — a foam card the message is written onto,
                // mirroring the timeline's washed-ashore cards (TASK-197).
                letterCard
                    .padding(.horizontal, DSLayout.Spacing.md)
                    .padding(.top, DSLayout.Spacing.md)
                    // Set adrift on success: the letter slips away toward the sea.
                    .offset(x: isDriftingAway ? 80 : 0)
                    .opacity(isDriftingAway ? 0 : 1)

                // TASK-199: Over-limit spoken in the world's voice — no blame,
                // always a next step.
                if isOverLimit {
                    Text("ボトルに入りきらないようです。あと\(-remaining)文字だけ短くしてみましょう。")
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsWarnText)
                        .padding(.horizontal, DSLayout.Spacing.lg)
                        .padding(.top, DSLayout.Spacing.sm)
                }

                HStack(spacing: DSLayout.Spacing.md) {
                    // Character count in the mono data role (TASK-196).
                    Text("\(remaining)")
                        .font(.dsMono(.caption))
                        .fontWeight(isOverLimit ? .bold : .regular)
                        .foregroundStyle(remaining < 20 ? Color.dsWarnText : Color.dsTextSecondary)
                        .padding(.leading, DSLayout.Spacing.lg)
                        // TASK-143: The low/over-limit warning is colour-only; spell it out.
                        .accessibilityLabel(
                            isOverLimit
                                ? "文字数が\(-remaining)文字超過しています"
                                : "残り\(remaining)文字"
                        )

                    if mediaIngestService != nil {
                        // TASK-187: up to 4 images OR 1 video; the combination is validated
                        // after selection in `syncSelection()`.
                        PhotosPicker(
                            selection: $selection,
                            maxSelectionCount: CreatePostUseCase.maxImages,
                            matching: .any(of: [.images, .videos])
                        ) {
                            Image(systemName: "photo.on.rectangle.angled")
                        }
                        .disabled(isPosting || isProcessingMedia)
                        .accessibilityLabel("写真・動画を追加")
                    }

                    Spacer()
                    // TASK-109/199: Anonymous toggle — "流す" vocabulary, tinted
                    // deep tide while on so the state is unmistakable.
                    Toggle(isOn: $isAnonymous) {
                        Label("匿名で流す", systemImage: "person.fill.questionmark")
                            .font(.dsCaption)
                    }
                    .toggleStyle(.button)
                    // Same near-tint rule as TASK-197: deep tide on foam, sea
                    // glass on the abyss (deepTide is 2.3:1 against dark).
                    .tint(isAnonymous ? (colorScheme == .dark ? .seaGlass : .deepTide) : .secondary)
                    .padding(.trailing, DSLayout.Spacing.lg)
                }
                .padding(.vertical, DSLayout.Spacing.sm)

                // TASK-199: Say what anonymity means the moment it is switched on.
                if isAnonymous {
                    Text("名前を伏せて流します。誰の手紙かは、届いた先でも分かりません。")
                        .font(.dsCaption)
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(.horizontal, DSLayout.Spacing.lg)
                        .transition(.opacity)
                }

                Spacer()
            }
            // Gate the layout animations on Reduce Motion like the drift-out.
            .animation(reduceMotion ? nil : .default, value: isAnonymous)
            .animation(reduceMotion ? nil : .default, value: isOverLimit)
            // TASK-199: freeze the letter while it is being posted / drifting away
            // (the toolbar's cancel button handles its own disabled state).
            .disabled(isPosting || isDriftingAway)
            .background(Color.dsBackground)
            .navigationTitle("手紙を流す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isPosting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    // TASK-089/142: Show the spinner for the duration of the post and only
                    // dismiss on success. Swapping the button for the spinner also blocks
                    // double submission.
                    if isPosting {
                        ProgressView()
                    } else {
                        // TASK-199: Publishing is "流す" — consistent with the
                        // anonymous toggle and the bottle-letter framing.
                        Button("流す") { submit() }
                            .bold()
                            .disabled(!canPost)
                    }
                }
            }
            // TASK-187: Ingest picks (compress/transcode) whenever the selection changes.
            .onChange(of: selection) {
                Task { await syncSelection() }
            }
            // TASK-142/154/187: Report a post/media failure in-sheet.
            .errorAlert($activeError)
        }
    }

    // MARK: - Letter card (TASK-199)

    /// The message being written, on the same foam surface + driftwood hairline as
    /// the timeline's washed-ashore cards, with an in-world placeholder.
    private var letterCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                if content.isEmpty {
                    // Aligned to the editor's caret: same outer padding as the
                    // TextEditor plus its default text-container insets
                    // (~5pt leading, ~8pt top), so typed text replaces the
                    // placeholder in place.
                    Text("いま、波間に流したいことは？")
                        .font(.dsBody)
                        // dsTextSecondary unfaded keeps AA on the foam surface;
                        // the primary-ink body text still reads darker.
                        .foregroundStyle(Color.dsTextSecondary)
                        .padding(.leading, DSLayout.Spacing.md + 5)
                        .padding(.trailing, DSLayout.Spacing.md + 5)
                        .padding(.top, DSLayout.Spacing.sm + 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                TextEditor(text: $content)
                    .font(.dsBody)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(.horizontal, DSLayout.Spacing.md)
                    .padding(.top, DSLayout.Spacing.sm)
            }

            if !mediaPreviews.isEmpty || isProcessingMedia {
                mediaStrip
            }
        }
        .background(Color.dsSurface, in: RoundedRectangle(cornerRadius: DSLayout.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: DSLayout.Radius.lg)
                .stroke(Color.driftwood.opacity(0.18), lineWidth: 0.5)
        )
    }

    // MARK: - Media preview strip (TASK-187)

    private var mediaStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(mediaPreviews) { preview in
                    mediaThumbnail(preview)
                }
                if isProcessingMedia {
                    ProgressView()
                        .frame(width: 80, height: 80)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private func mediaThumbnail(_ preview: MediaPreview) -> some View {
        Image(uiImage: preview.image)
            .resizable()
            .scaledToFill()
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: DSLayout.Radius.md))
            // TASK-199: same driftwood hairline as the letter card.
            .overlay(
                RoundedRectangle(cornerRadius: DSLayout.Radius.md)
                    .stroke(Color.driftwood.opacity(0.18), lineWidth: 0.5)
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    remove(preview)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.55))
                }
                .padding(4)
                .accessibilityLabel("メディアを削除")
            }
            .overlay(alignment: .bottomLeading) {
                if preview.attachment.kind == .video {
                    Image(systemName: "play.circle.fill")
                        .foregroundStyle(.white)
                        .padding(4)
                }
            }
            .accessibilityLabel(preview.attachment.kind == .video ? "添付動画" : "添付画像")
    }

    // MARK: - Selection → ingest (TASK-187)

    /// Brings `mediaPreviews` in line with `selection`: drops deselected items and
    /// ingests newly added ones, validating the image/video combination first.
    private func syncSelection() async {
        guard let service = mediaIngestService else { return }

        // Drop previews whose source item was deselected.
        mediaPreviews.removeAll { preview in !selection.contains(preview.item) }
        let existing = mediaPreviews.map(\.item)
        let newItems = selection.filter { !existing.contains($0) }
        guard !newItems.isEmpty else { return }

        // Validate the resulting combination before any expensive ingest work.
        // TASK-199: Validation speaks in the world's voice — no blame, and always
        // a next step.
        let videoTotal = selection.filter { isVideo($0) }.count
        let imageTotal = selection.count - videoTotal
        if videoTotal > CreatePostUseCase.maxVideos {
            revertSelection("ボトルに入る動画は\(CreatePostUseCase.maxVideos)本まで。1本だけ選び直してみましょう。")
            return
        }
        if videoTotal >= 1 && imageTotal >= 1 {
            revertSelection("画像と動画は同じボトルに入りません。どちらかだけにしてみましょう。")
            return
        }
        if imageTotal > CreatePostUseCase.maxImages {
            revertSelection("ボトルに入る画像は\(CreatePostUseCase.maxImages)枚まで。少し減らしてみましょう。")
            return
        }

        isProcessingMedia = true
        defer { isProcessingMedia = false }
        for item in newItems {
            do {
                let preview = try await ingest(item, using: service)
                mediaPreviews.append(preview)
            } catch {
                // Drop only the failed item and report; keep any that succeeded.
                selection.removeAll { $0 == item }
                activeError = Self.mediaError(from: error)
            }
        }
    }

    /// Resets the picker to the items we already have previews for and reports why.
    private func revertSelection(_ message: String) {
        selection = mediaPreviews.map(\.item)
        activeError = .message(message)
    }

    private func remove(_ preview: MediaPreview) {
        mediaPreviews.removeAll { $0.id == preview.id }
        selection.removeAll { $0 == preview.item }
    }

    private func ingest(_ item: PhotosPickerItem, using service: MediaIngestService) async throws -> MediaPreview {
        if isVideo(item) {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                throw MediaError.decodeFailed
            }
            defer { try? FileManager.default.removeItem(at: movie.url) }
            let result = try await service.ingestVideo(movie.url)
            return MediaPreview(item: item, attachment: result.attachment, image: Self.thumbnail(at: result.thumbnailURL))
        } else {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw MediaError.decodeFailed
            }
            let result = try service.ingestImage(data)
            return MediaPreview(item: item, attachment: result.attachment, image: Self.thumbnail(at: result.thumbnailURL))
        }
    }

    private func isVideo(_ item: PhotosPickerItem) -> Bool {
        item.supportedContentTypes.contains { $0.conforms(to: .movie) }
    }

    private static func thumbnail(at url: URL) -> UIImage {
        UIImage(contentsOfFile: url.path) ?? UIImage(systemName: "photo") ?? UIImage()
    }

    /// Maps a `MediaError` to safe, user-facing copy (TASK-154 pattern).
    /// TASK-199: worded gently, with a next step.
    private static func mediaError(from error: Error) -> AppError {
        guard let media = error as? MediaError else {
            return .message("メディアをうまく載せられませんでした。もう一度お試しください。")
        }
        switch media {
        case .cannotFitBudget:
            return .message("このボトルには収まりきらないようです。短い動画や小さめの画像でもう一度お試しください。")
        case .unsupportedMIME:
            return .message("この形式のメディアはまだ流せません。別のファイルをお試しください。")
        case .emptyInput, .decodeFailed:
            return .message("メディアを読み込めませんでした。別のファイルをお試しください。")
        default:
            return .message("メディアをうまく載せられませんでした。もう一度お試しください。")
        }
    }

    /// Runs the post asynchronously, keeping the spinner visible until it completes,
    /// dismissing only on success and surfacing the error otherwise (TASK-142).
    /// TASK-199: on success the letter briefly drifts away before the sheet closes
    /// (skipped under Reduce Motion).
    private func submit() {
        Task {
            isPosting = true
            let result = await onSubmit(content, isAnonymous, mediaPreviews.map(\.attachment))
            if let result {
                isPosting = false
                activeError = result
            } else {
                // Keep `isPosting` true through the drift-out so the 流す button
                // cannot re-enable and double-submit during the 250ms window.
                if !reduceMotion {
                    withAnimation(.easeIn(duration: 0.25)) { isDriftingAway = true }
                    try? await Task.sleep(for: .milliseconds(250))
                }
                dismiss()
            }
        }
    }
}

// MARK: - Supporting types (TASK-187)

/// One attached media item: its signed descriptor plus a thumbnail for the strip.
private struct MediaPreview: Identifiable {
    let id = UUID()
    let item: PhotosPickerItem
    let attachment: MediaAttachment
    let image: UIImage
}

/// Copies a picked video out of the Photos sandbox into a temp file we can transcode.
private struct PickedMovie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("pick-\(UUID().uuidString).mov")
            try? FileManager.default.removeItem(at: copy)
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedMovie(url: copy)
        }
    }
}
