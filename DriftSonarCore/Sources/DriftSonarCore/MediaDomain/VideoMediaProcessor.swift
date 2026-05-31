import Foundation

#if canImport(AVFoundation)
import AVFoundation
import CoreGraphics

/// 動画を伝播・保存に適した形へトランスコードするプロセッサ。
///
/// - 解像度・ビットレートを抑えた MP4 へ再エンコード（`AVAssetExportSession`）
/// - 長さ上限（`MediaBudget.videoMaxDuration`）でクリップ
/// - 先頭フレームからサムネイル生成（メタ除去済み JPEG）
///
/// AVFoundation 依存のため、利用できる環境でのみコンパイルする。
public struct VideoMediaProcessor {
    private let budget: MediaBudget

    public init(budget: MediaBudget = .default) {
        self.budget = budget
    }

    /// トランスコード結果。
    public struct ProcessedVideo: Equatable, Sendable {
        public let data: Data
        public let width: Int
        public let height: Int
        public let duration: Double
        public let mime: String
        public let thumbnailData: Data
    }

    /// 動画ファイルをトランスコードする。
    ///
    /// - Parameter sourceURL: 元動画のローカル URL。
    /// - Returns: 軽量化済み MP4 とサムネイル。
    public func process(_ sourceURL: URL) async throws -> ProcessedVideo {
        let asset = AVURLAsset(url: sourceURL)

        // 720p 相当のプリセットで再エンコード。これより小さい元動画はそのまま縮む。
        let preset = AVAssetExportPreset1280x720
        guard let export = AVAssetExportSession(asset: asset, presetName: preset) else {
            throw MediaError.transcodeFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        export.outputURL = outputURL
        export.outputFileType = .mp4
        export.shouldOptimizeForNetworkUse = true

        // 長さ上限でクリップ。
        let duration = try await assetDuration(asset)
        let clipped = min(duration, budget.videoMaxDuration)
        export.timeRange = CMTimeRange(
            start: .zero,
            duration: CMTime(seconds: clipped, preferredTimescale: 600)
        )

        await export.export()
        guard export.status == .completed else {
            throw MediaError.transcodeFailed
        }

        let data = try Data(contentsOf: outputURL)
        try? FileManager.default.removeItem(at: outputURL)
        guard data.count <= budget.videoMaxByteSize else {
            throw MediaError.cannotFitBudget
        }

        let (width, height) = try await videoDimensions(asset)
        let thumbnail = try await makeThumbnailData(asset: asset)

        return ProcessedVideo(
            data: data,
            width: width,
            height: height,
            duration: clipped,
            mime: "video/mp4",
            thumbnailData: thumbnail
        )
    }

    /// 先頭フレームからサムネイル（JPEG・メタ除去済み）を作る。
    public func makeThumbnailData(asset: AVAsset) async throws -> Data {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(
            width: budget.thumbnailMaxLongEdge,
            height: budget.thumbnailMaxLongEdge
        )
        let cgImage = try await firstFrame(generator)
        return try JPEGEncoder.encode(cgImage, quality: 0.7)
    }

    // MARK: - 内部処理

    private func assetDuration(_ asset: AVAsset) async throws -> Double {
        let duration = try await asset.load(.duration)
        return CMTimeGetSeconds(duration)
    }

    private func videoDimensions(_ asset: AVAsset) async throws -> (Int, Int) {
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw MediaError.transcodeFailed
        }
        let size = try await track.load(.naturalSize)
        return (Int(abs(size.width)), Int(abs(size.height)))
    }

    private func firstFrame(_ generator: AVAssetImageGenerator) async throws -> CGImage {
        try await withCheckedThrowingContinuation { continuation in
            generator.generateCGImagesAsynchronously(
                forTimes: [NSValue(time: .zero)]
            ) { _, image, _, _, error in
                if let image {
                    continuation.resume(returning: image)
                } else {
                    continuation.resume(throwing: error ?? MediaError.transcodeFailed)
                }
            }
        }
    }
}
#endif
