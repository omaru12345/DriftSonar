import AVKit
import SwiftUI
import DriftSonarCore

/// Full-screen, swipeable media viewer (TASK-188).
///
/// Presented over the Timeline. Images support pinch-to-zoom and double-tap zoom;
/// videos play inline via `AVPlayer`. Multiple attachments page horizontally. The
/// full body is loaded on demand from `MediaStore`; until it is available (received
/// posts before TASK-189 propagation) the thumbnail or a placeholder stands in.
struct MediaViewerView: View {
    let media: [MediaAttachment]
    let store: MediaStore?

    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(media: [MediaAttachment], startIndex: Int, store: MediaStore?) {
        self.media = media
        self.store = store
        _index = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(media.enumerated()), id: \.offset) { offset, attachment in
                    page(for: attachment)
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: media.count > 1 ? .automatic : .never))

            closeButton
        }
        .statusBarHidden()
    }

    @ViewBuilder
    private func page(for attachment: MediaAttachment) -> some View {
        if attachment.kind == .video {
            VideoPage(attachment: attachment, store: store)
        } else {
            ZoomableImagePage(attachment: attachment, store: store)
        }
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.5), in: Circle())
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .accessibilityLabel("閉じる")
    }
}

// MARK: - Zoomable image page

/// One image page: loads the full body (fallback: thumbnail) and supports
/// pinch / double-tap zoom with panning while zoomed.
private struct ZoomableImagePage: View {
    let attachment: MediaAttachment
    let store: MediaStore?

    @State private var image: UIImage?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private let maxScale: CGFloat = 4

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnification)
                        .simultaneousGesture(scale > 1 ? panGesture : nil)
                        .onTapGesture(count: 2) { toggleZoom() }
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .task(id: attachment.contentHashHex) { await load() }
    }

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { resetPan() }
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in lastOffset = offset }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3)) {
            if scale > 1 {
                scale = 1
                lastScale = 1
                resetPan()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func resetPan() {
        offset = .zero
        lastOffset = .zero
    }

    private func load() async {
        // Prefer the full body; fall back to the thumbnail so something always shows.
        let url = store?.bodyURL(for: attachment) ?? store?.thumbnailURL(for: attachment)
        guard let url else { return }
        image = await MediaImageCache.image(at: url)
    }
}

// MARK: - Video page

/// One video page: plays the full body inline once it is available locally.
private struct VideoPage: View {
    let attachment: MediaAttachment
    let store: MediaStore?

    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.largeTitle)
                    Text("動画はまだ取得されていません")
                        .font(.subheadline)
                }
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { preparePlayer() }
        .onDisappear { player?.pause() }
    }

    private func preparePlayer() {
        guard player == nil, let url = store?.bodyURL(for: attachment) else { return }
        player = AVPlayer(url: url)
        player?.play()
    }
}
