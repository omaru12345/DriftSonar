import Foundation

/// メディアの容量・解像度上限（`docs/media-propagation.md` の数値表に対応）。
///
/// BLE mesh はメディア本体を運べないため、ここで「本体をどこまで軽量化するか」を
/// 一元管理する。圧縮・トランスコード・キャッシュ管理がこの値を共有する。
public struct MediaBudget: Equatable, Sendable {
    /// 画像の長辺リサイズ上限（px）。
    public let imageMaxLongEdge: Int

    /// 画像 1 枚の本体バイト上限。
    public let imageMaxByteSize: Int

    /// サムネイルの長辺（px）。プレースホルダ／一覧表示用。
    public let thumbnailMaxLongEdge: Int

    /// 動画の長辺解像度上限（px）。720p = 1280。
    public let videoMaxLongEdge: Int

    /// 動画の長さ上限（秒）。超過分はトランスコード時にクリップする。
    public let videoMaxDuration: Double

    /// 動画 1 本の本体バイト上限。
    public let videoMaxByteSize: Int

    /// 端末内メディアキャッシュの総量上限。超過時に LRU でエビクションする。
    public let cacheMaxTotalBytes: Int

    /// 受け入れる MIME タイプの許可リスト。許可外は破棄する。
    public let allowedMimeTypes: Set<String>

    public init(
        imageMaxLongEdge: Int,
        imageMaxByteSize: Int,
        thumbnailMaxLongEdge: Int,
        videoMaxLongEdge: Int,
        videoMaxDuration: Double,
        videoMaxByteSize: Int,
        cacheMaxTotalBytes: Int,
        allowedMimeTypes: Set<String>
    ) {
        self.imageMaxLongEdge = imageMaxLongEdge
        self.imageMaxByteSize = imageMaxByteSize
        self.thumbnailMaxLongEdge = thumbnailMaxLongEdge
        self.videoMaxLongEdge = videoMaxLongEdge
        self.videoMaxDuration = videoMaxDuration
        self.videoMaxByteSize = videoMaxByteSize
        self.cacheMaxTotalBytes = cacheMaxTotalBytes
        self.allowedMimeTypes = allowedMimeTypes
    }

    /// `docs/media-propagation.md` の標準値。
    public static let `default` = MediaBudget(
        imageMaxLongEdge: 2048,
        imageMaxByteSize: 500 * 1024,
        thumbnailMaxLongEdge: 320,
        videoMaxLongEdge: 1280,
        videoMaxDuration: 60,
        videoMaxByteSize: 10 * 1024 * 1024,
        cacheMaxTotalBytes: 200 * 1024 * 1024,
        allowedMimeTypes: ["image/jpeg", "video/mp4"]
    )
}
