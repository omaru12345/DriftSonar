import Foundation

/// メディアの取り込み（加工 → ハッシュ採番 → ローカル保存 → descriptor 生成）を束ねる。
///
/// `CreatePostUseCase` に渡す `MediaAttachment` を、本体保存とセットで一貫生成する
/// 入口。本体は `MediaStore`、descriptor は Post の署名 canonical 範囲に載る。
public struct MediaIngestService {
    private let imageProcessor: ImageMediaProcessor
    private let store: MediaStore
    private let budget: MediaBudget

    public init(
        store: MediaStore,
        budget: MediaBudget = .default,
        imageProcessor: ImageMediaProcessor? = nil
    ) {
        self.store = store
        self.budget = budget
        self.imageProcessor = imageProcessor ?? ImageMediaProcessor(budget: budget)
    }

    /// 取り込み結果。descriptor と保存先の対応。
    public struct IngestResult: Equatable {
        public let attachment: MediaAttachment
        public let bodyURL: URL
        public let thumbnailURL: URL
    }

    /// 画像を取り込む。
    ///
    /// 圧縮・EXIF 除去 → 圧縮後本体の SHA-256 を contentHash として採番 →
    /// 本体とサムネを保存 → `MediaAttachment` を返す。
    public func ingestImage(_ source: Data) throws -> IngestResult {
        let processed = try imageProcessor.process(source)
        guard budget.allowedMimeTypes.contains(processed.mime) else {
            throw MediaError.unsupportedMIME(processed.mime)
        }

        // contentHash は「圧縮後の本体」に対して採番する。
        // 同一入力でも圧縮結果が一致すれば重複排除でき、ハッシュは取得時検証と一致する。
        let contentHash = MediaHashing.sha256Hex(processed.data)
        let bodyURL = try store.store(processed.data, contentHash: contentHash, fileExtension: "jpg")
        let thumbnailURL = try store.store(
            processed.thumbnailData,
            contentHash: contentHash,
            fileExtension: "thumb.jpg"
        )

        let attachment = MediaAttachment(
            kind: .image,
            contentHash: contentHash,
            width: processed.width,
            height: processed.height,
            byteSize: processed.data.count,
            mime: processed.mime,
            blurHash: nil,
            duration: nil
        )
        return IngestResult(attachment: attachment, bodyURL: bodyURL, thumbnailURL: thumbnailURL)
    }
}
