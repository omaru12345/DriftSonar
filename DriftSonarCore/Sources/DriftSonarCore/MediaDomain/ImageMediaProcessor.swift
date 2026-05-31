import Foundation
import ImageIO
import CoreGraphics

/// 画像を伝播・保存に適した形へ加工するプロセッサ。
///
/// 以下を一括で行う:
/// 1. 長辺リサイズ（`MediaBudget.imageMaxLongEdge` 以内）
/// 2. **EXIF/GPS 等メタデータの除去**（プライバシー必須・コンセプト「位置を追跡しない」と整合）
/// 3. 向き（Orientation）の焼き込み（回転メタデータに依存させない）
/// 4. JPEG 品質を段階的に下げて `imageMaxByteSize` 以内へ収める
/// 5. サムネイル生成
///
/// ImageIO ベースのため iOS / macOS 双方で動作し、`swift test` で検証できる。
public struct ImageMediaProcessor {
    private let budget: MediaBudget

    public init(budget: MediaBudget = .default) {
        self.budget = budget
    }

    /// 画像本体を加工する。
    ///
    /// - Parameter source: 元画像バイト列（JPEG/HEIC/PNG 等、ImageIO が読める形式）。
    /// - Returns: 圧縮・メタ除去済みの本体とサムネイル。
    public func process(_ source: Data) throws -> ProcessedImage {
        guard !source.isEmpty else { throw MediaError.emptyInput }
        guard let imageSource = CGImageSourceCreateWithData(source as CFData, nil) else {
            throw MediaError.decodeFailed
        }

        // 長辺を段階的に下げながら、各段で品質を下げて byte 上限に収める。
        // メタデータを持たない再エンコードなので、出力に EXIF/GPS は残らない。
        let edgeSteps = longEdgeSteps(max: budget.imageMaxLongEdge)
        var decodedAny = false
        for maxEdge in edgeSteps {
            guard let cgImage = downscaledImage(from: imageSource, maxPixelSize: maxEdge) else {
                continue
            }
            decodedAny = true
            for quality in qualitySteps() {
                let encoded = try JPEGEncoder.encode(cgImage, quality: quality)
                if encoded.count <= budget.imageMaxByteSize {
                    let thumbnail = try makeThumbnailData(from: imageSource)
                    return ProcessedImage(
                        data: encoded,
                        width: cgImage.width,
                        height: cgImage.height,
                        mime: "image/jpeg",
                        thumbnailData: thumbnail
                    )
                }
            }
        }
        // 一度もデコードできなければ壊れた入力。デコードはできたが上限に収まらない場合のみ予算エラー。
        throw decodedAny ? MediaError.cannotFitBudget : MediaError.decodeFailed
    }

    /// サムネイル（JPEG）のみを生成する。
    public func makeThumbnailData(from imageSource: CGImageSource) throws -> Data {
        guard let thumb = downscaledImage(from: imageSource, maxPixelSize: budget.thumbnailMaxLongEdge) else {
            throw MediaError.decodeFailed
        }
        return try JPEGEncoder.encode(thumb, quality: 0.7)
    }

    // MARK: - 内部処理

    /// 長辺の縮小段階。最初は上限、収まらなければさらに小さく。
    private func longEdgeSteps(max: Int) -> [Int] {
        let candidates = [max, Int(Double(max) * 0.78), Int(Double(max) * 0.625), Int(Double(max) * 0.5)]
        return candidates.filter { $0 > 0 }
    }

    /// JPEG 品質の縮小段階（高→低）。
    private func qualitySteps() -> [CGFloat] {
        [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3]
    }

    /// 指定した長辺に縮小した CGImage を作る。向きは焼き込む（メタ非依存）。
    private func downscaledImage(from source: CGImageSource, maxPixelSize: Int) -> CGImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
