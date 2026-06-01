import SwiftUI
import DriftSonarCore

/// Twitter-style media mosaic shown under a post's text (TASK-188).
///
/// Layout follows the familiar one/two/three/four arrangement; 5+ attachments are
/// never produced by Compose (max 4 images OR 1 video, TASK-187) but a "+N" badge
/// keeps the grid safe if more ever arrive over the mesh. Tapping a tile reports its
/// index so the parent can open the full-screen viewer at that item.
struct PostMediaGridView: View {
    let media: [MediaAttachment]
    let store: MediaStore?
    /// Called with the tapped attachment's index to open the viewer.
    let onTap: (Int) -> Void

    private let spacing: CGFloat = 3
    private let corner: CGFloat = 14

    var body: some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch media.count {
        case 0:
            EmptyView()
        case 1:
            tile(0)
                .aspectRatio(singleAspectRatio, contentMode: .fit)
                .frame(maxHeight: 360)
        case 2:
            HStack(spacing: spacing) {
                tile(0)
                tile(1)
            }
            .frame(height: 200)
        case 3:
            HStack(spacing: spacing) {
                tile(0)
                VStack(spacing: spacing) {
                    tile(1)
                    tile(2)
                }
            }
            .frame(height: 240)
        default:
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    tile(0)
                    tile(1)
                }
                HStack(spacing: spacing) {
                    tile(2)
                    tile(3)
                }
            }
            .frame(height: 240)
        }
    }

    /// Clamped aspect ratio for a lone attachment so very tall/wide media stays
    /// within a sensible Timeline footprint.
    private var singleAspectRatio: CGFloat {
        let a = media[0]
        guard a.width > 0, a.height > 0 else { return 1 }
        return min(max(CGFloat(a.width) / CGFloat(a.height), 0.75), 1.78)
    }

    private func tile(_ index: Int) -> some View {
        Button {
            onTap(index)
        } label: {
            MediaThumbnailView(attachment: media[index], store: store)
                // The last visible tile shows how many more are hidden (5+ case).
                .overlay {
                    if index == 3, media.count > 4 {
                        ZStack {
                            Color.black.opacity(0.45)
                            Text("+\(media.count - 4)")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(media[index].kind == .video ? "添付動画" : "添付画像")
        .accessibilityHint("タップで全画面表示")
    }
}
