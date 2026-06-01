import SwiftUI
import DriftSonarCore

/// Small in-memory cache + off-main decode for media files on disk (TASK-188).
///
/// Thumbnails are read repeatedly while scrolling the Timeline, so we keep decoded
/// `UIImage`s in an `NSCache` keyed by file path and decode off the main thread to
/// avoid scroll hitches. The cache is bounded by `NSCache`'s own memory pressure
/// eviction — the on-disk LRU cap lives in `MediaStore`.
enum MediaImageCache {
    private static let cache = NSCache<NSString, UIImage>()

    /// Returns the decoded image for `url`, using the cache when warm and decoding
    /// off-main otherwise. Returns `nil` if the file is missing or undecodable.
    static func image(at url: URL) async -> UIImage? {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let decoded = await Task.detached(priority: .userInitiated) {
            UIImage(contentsOfFile: url.path)
        }.value
        if let decoded { cache.setObject(decoded, forKey: key) }
        return decoded
    }
}

/// Renders one media attachment's thumbnail, filling its container.
///
/// While the thumbnail is loading — or when the body has not been fetched yet
/// (received posts before TASK-189 propagation) — a neutral placeholder is shown.
/// Videos get a play-icon overlay so a still frame reads as playable.
struct MediaThumbnailView: View {
    let attachment: MediaAttachment
    let store: MediaStore?

    @State private var image: UIImage?
    @State private var didLoad = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .overlay(alignment: .center) {
            if attachment.kind == .video, image != nil {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(radius: 3)
            }
        }
        .task(id: attachment.contentHashHex) { await load() }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(.quaternary)
            .overlay {
                Image(systemName: attachment.kind == .video ? "video.slash" : "photo")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            // While the first decode is in flight, show a subtle redaction shimmer.
            .redacted(reason: didLoad ? [] : .placeholder)
    }

    private func load() async {
        defer { didLoad = true }
        guard let store, let url = store.thumbnailURL(for: attachment) else {
            image = nil
            return
        }
        image = await MediaImageCache.image(at: url)
    }
}
