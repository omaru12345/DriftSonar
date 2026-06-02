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
    /// Called with (content, isAnonymous, media) when the user taps "投稿" (TASK-109/110/187).
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
    @Environment(\.dismiss) private var dismiss

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
                TextEditor(text: $content)
                    .frame(minHeight: 140)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                if !mediaPreviews.isEmpty || isProcessingMedia {
                    mediaStrip
                }

                Divider()

                HStack(spacing: 12) {
                    Text("\(remaining)")
                        .font(.caption)
                        .foregroundStyle(remaining < 20 ? (isOverLimit ? .red : .orange) : .secondary)
                        .padding(.leading, 16)
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
                    // TASK-109: Anonymous posting toggle.
                    Toggle(isOn: $isAnonymous) {
                        Label("匿名で投稿", systemImage: "person.fill.questionmark")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .tint(.secondary)
                    .padding(.trailing, 16)
                }
                .padding(.vertical, 8)

                Spacer()
            }
            .navigationTitle("新しい投稿")
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
                        Button("投稿") { submit() }
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
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
        let videoTotal = selection.filter { isVideo($0) }.count
        let imageTotal = selection.count - videoTotal
        if videoTotal > CreatePostUseCase.maxVideos {
            revertSelection("動画は\(CreatePostUseCase.maxVideos)本までです。")
            return
        }
        if videoTotal >= 1 && imageTotal >= 1 {
            revertSelection("画像と動画は同時に添付できません。")
            return
        }
        if imageTotal > CreatePostUseCase.maxImages {
            revertSelection("画像は\(CreatePostUseCase.maxImages)枚までです。")
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
    private static func mediaError(from error: Error) -> AppError {
        guard let media = error as? MediaError else {
            return .message("メディアを処理できませんでした。もう一度お試しください。")
        }
        switch media {
        case .cannotFitBudget:
            return .message("メディアの容量が大きすぎます。短い動画や小さい画像をお試しください。")
        case .unsupportedMIME:
            return .message("対応していない形式のメディアです。")
        case .emptyInput, .decodeFailed:
            return .message("メディアを読み込めませんでした。別のファイルをお試しください。")
        default:
            return .message("メディアを処理できませんでした。もう一度お試しください。")
        }
    }

    /// Runs the post asynchronously, keeping the spinner visible until it completes,
    /// dismissing only on success and surfacing the error otherwise (TASK-142).
    private func submit() {
        Task {
            isPosting = true
            let result = await onSubmit(content, isAnonymous, mediaPreviews.map(\.attachment))
            isPosting = false
            if let result {
                activeError = result
            } else {
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
