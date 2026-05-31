import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// CGImage を JPEG にエンコードする共通ヘルパー。
///
/// メタデータ（EXIF/GPS/TIFF）を一切付与しないことでプライバシー除去を保証する。
/// 画像本体・サムネ・動画サムネで共有する。
enum JPEGEncoder {
    /// CGImage を JPEG データへエンコードする。EXIF/GPS は付与しない。
    static func encode(_ image: CGImage, quality: CGFloat) throws -> Data {
        let mutableData = NSMutableData()
        let type = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else {
            throw MediaError.encodeFailed
        }
        // 向きは呼び出し側で焼き込み済みのため Orientation=1 固定。
        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality,
            kCGImagePropertyOrientation: 1
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw MediaError.encodeFailed
        }
        return mutableData as Data
    }
}
