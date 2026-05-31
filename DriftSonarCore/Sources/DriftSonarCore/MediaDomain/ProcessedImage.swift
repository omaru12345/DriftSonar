import Foundation

/// 圧縮・メタデータ除去済みの画像処理結果。
public struct ProcessedImage: Equatable, Sendable {
    /// 圧縮後の本体（JPEG）バイト列。EXIF/GPS 等は除去済み。
    public let data: Data

    /// 圧縮後のピクセル幅。
    public let width: Int

    /// 圧縮後のピクセル高さ。
    public let height: Int

    /// 本体の MIME タイプ。
    public let mime: String

    /// 一覧・プレースホルダ表示用のサムネイル（JPEG）。
    public let thumbnailData: Data

    public init(data: Data, width: Int, height: Int, mime: String, thumbnailData: Data) {
        self.data = data
        self.width = width
        self.height = height
        self.mime = mime
        self.thumbnailData = thumbnailData
    }
}
