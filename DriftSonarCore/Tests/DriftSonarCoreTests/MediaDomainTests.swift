import XCTest
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers
import AVFoundation
@testable import DriftSonarCore

final class MediaDomainTests: XCTestCase {

    // MARK: - テスト用画像生成

    /// 非圧縮で潰れない（ノイズ入り）JPEG を生成する。任意で GPS メタデータを埋め込む。
    private func makeJPEG(width: Int, height: Int, withGPS: Bool) -> Data {
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * height)
        for index in pixels.indices {
            pixels[index] = UInt8.random(in: 0...255)
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = pixels.withUnsafeMutableBytes { raw -> CGContext? in
            CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        }
        guard let cgImage = context?.makeImage() else {
            XCTFail("テスト画像の生成に失敗")
            return Data()
        }

        let mutableData = NSMutableData()
        let type = UTType.jpeg.identifier as CFString
        guard let destination = CGImageDestinationCreateWithData(mutableData, type, 1, nil) else {
            XCTFail("テスト画像のエンコードに失敗")
            return Data()
        }
        var properties: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 1.0]
        if withGPS {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 35.6586,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 139.7454,
                kCGImagePropertyGPSLongitudeRef: "E"
            ]
            properties[kCGImagePropertyExifDictionary] = [
                kCGImagePropertyExifUserComment: "secret location"
            ]
        }
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        CGImageDestinationFinalize(destination)
        return mutableData as Data
    }

    private func properties(of data: Data) -> [CFString: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return [:]
        }
        return props
    }

    private func dimensions(of data: Data) -> (Int, Int) {
        let props = properties(of: data)
        let width = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        return (width, height)
    }

    private func hex(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }

    // MARK: - ImageMediaProcessor

    func test_process_resizesWithinLongEdge() throws {
        let source = makeJPEG(width: 4000, height: 3000, withGPS: false)
        let processor = ImageMediaProcessor(budget: .default)
        let result = try processor.process(source)
        XCTAssertLessThanOrEqual(max(result.width, result.height), MediaBudget.default.imageMaxLongEdge)
        XCTAssertEqual(result.mime, "image/jpeg")
    }

    func test_process_stripsGPSAndEXIF() throws {
        let source = makeJPEG(width: 1200, height: 900, withGPS: true)
        // 入力には GPS が乗っていることを確認。
        XCTAssertNotNil(properties(of: source)[kCGImagePropertyGPSDictionary])

        let processor = ImageMediaProcessor(budget: .default)
        let result = try processor.process(source)

        // プライバシー上重要な位置情報・ユーザー埋め込みメタデータが消えていること。
        // ImageIO は再エンコード時に ColorSpace / 画素寸法のみの最小 EXIF を付与するため、
        // EXIF 辞書そのものの不在ではなく「機微フィールドが残っていないこと」を検証する。
        let outProps = properties(of: result.data)
        XCTAssertNil(outProps[kCGImagePropertyGPSDictionary], "GPS が除去されていない")
        let exif = outProps[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifUserComment], "EXIF のユーザーコメントが残存")
        XCTAssertNil(outProps[kCGImagePropertyExifAuxDictionary], "EXIF Aux が残存")
    }

    func test_process_withinByteBudget() throws {
        // 小さめ予算 + ノイズ画像で品質ステップ縮小を強制。
        let budget = MediaBudget(
            imageMaxLongEdge: 1024,
            imageMaxByteSize: 80 * 1024,
            thumbnailMaxLongEdge: 320,
            videoMaxLongEdge: 1280,
            videoMaxDuration: 15,
            videoMaxByteSize: 2 * 1024 * 1024,
            cacheMaxTotalBytes: 200 * 1024 * 1024,
            allowedMimeTypes: ["image/jpeg"]
        )
        let source = makeJPEG(width: 3000, height: 3000, withGPS: false)
        let processor = ImageMediaProcessor(budget: budget)
        let result = try processor.process(source)
        XCTAssertLessThanOrEqual(result.data.count, budget.imageMaxByteSize)
    }

    func test_process_generatesThumbnail() throws {
        let source = makeJPEG(width: 2000, height: 1000, withGPS: false)
        let processor = ImageMediaProcessor(budget: .default)
        let result = try processor.process(source)
        XCTAssertFalse(result.thumbnailData.isEmpty)
        let (tw, th) = dimensions(of: result.thumbnailData)
        XCTAssertLessThanOrEqual(max(tw, th), MediaBudget.default.thumbnailMaxLongEdge)
    }

    func test_process_emptyInput_throws() {
        let processor = ImageMediaProcessor(budget: .default)
        XCTAssertThrowsError(try processor.process(Data())) { error in
            XCTAssertEqual(error as? MediaError, .emptyInput)
        }
    }

    func test_process_garbageInput_throwsDecode() {
        let processor = ImageMediaProcessor(budget: .default)
        let garbage = Data([0x00, 0x01, 0x02, 0x03, 0x04])
        XCTAssertThrowsError(try processor.process(garbage)) { error in
            XCTAssertEqual(error as? MediaError, .decodeFailed)
        }
    }

    // MARK: - MediaHashing

    func test_hash_isStableForSameBytes() {
        let data = Data("driftsonar".utf8)
        XCTAssertEqual(MediaHashing.sha256(data), MediaHashing.sha256(data))
        XCTAssertEqual(MediaHashing.sha256(data).count, MediaAttachment.contentHashByteCount)
        XCTAssertEqual(MediaHashing.sha256Hex(data).count, 64)
        XCTAssertNotEqual(MediaHashing.sha256(data), MediaHashing.sha256(Data("other".utf8)))
    }

    // MARK: - MediaStore

    private func makeTempStore(maxTotalBytes: Int) throws -> (MediaStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("media-test-\(UUID().uuidString)")
        let store = try MediaStore(rootDirectory: dir, maxTotalBytes: maxTotalBytes)
        return (store, dir)
    }

    func test_store_roundTrip() throws {
        let (store, dir) = try makeTempStore(maxTotalBytes: 10 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: dir) }

        let body = Data((0..<1000).map { _ in UInt8.random(in: 0...255) })
        let hash = MediaHashing.sha256Hex(body)
        try store.store(body, contentHash: hash, fileExtension: "jpg")

        let loaded = store.data(contentHash: hash, fileExtension: "jpg")
        XCTAssertEqual(loaded, body)
        XCTAssertNil(store.data(contentHash: hash, fileExtension: "mp4"))
    }

    func test_store_evictsOldestBeyondCap() throws {
        // 1KB ファイル 3 つ。上限 2.5KB → 最古 1 つが消える。
        let (store, dir) = try makeTempStore(maxTotalBytes: 2500)
        defer { try? FileManager.default.removeItem(at: dir) }

        func blob() -> Data { Data((0..<1000).map { _ in UInt8.random(in: 0...255) }) }
        let h1 = "1" + String(repeating: "a", count: 63)
        let h2 = "2" + String(repeating: "a", count: 63)
        let h3 = "3" + String(repeating: "a", count: 63)

        try store.store(blob(), contentHash: h1, fileExtension: "jpg")
        try store.store(blob(), contentHash: h2, fileExtension: "jpg")
        try store.store(blob(), contentHash: h3, fileExtension: "jpg")

        // 直近保存の h3 は必ず残る。総量は上限以下。
        XCTAssertNotNil(store.data(contentHash: h3, fileExtension: "jpg"))
        XCTAssertLessThanOrEqual(store.totalBytes(), 2500)
        // 最古の h1 がエビクションされている。
        XCTAssertNil(store.data(contentHash: h1, fileExtension: "jpg"))
    }

    // MARK: - MediaIngestService

    func test_ingestImage_producesAttachmentAndStores() throws {
        let (store, dir) = try makeTempStore(maxTotalBytes: 10 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = MediaIngestService(store: store)
        let source = makeJPEG(width: 1600, height: 1200, withGPS: true)
        let result = try service.ingestImage(source)
        let key = hex(result.attachment.contentHash)

        XCTAssertEqual(result.attachment.kind, .image)
        XCTAssertEqual(result.attachment.contentHash.count, MediaAttachment.contentHashByteCount)
        XCTAssertEqual(result.attachment.mimeType, "image/jpeg")
        XCTAssertNil(result.attachment.durationMs)
        // 本体とサムネが保存されている。
        XCTAssertEqual(result.attachment.byteSize, store.data(contentHash: key, fileExtension: "jpg")?.count)
        XCTAssertNotNil(store.url(contentHash: key, fileExtension: "jpg"))
        XCTAssertNotNil(store.url(contentHash: key, fileExtension: "thumb.jpg"))

        // contentHash は保存本体の SHA-256 と一致する（完全性検証の前提）。
        let stored = try XCTUnwrap(store.data(contentHash: key, fileExtension: "jpg"))
        XCTAssertEqual(MediaHashing.sha256(stored), result.attachment.contentHash)
        XCTAssertLessThanOrEqual(result.attachment.byteSize, CreatePostUseCase.maxImageBytes)
    }

    // TASK-188: descriptor から保存済みサムネ/本体 URL を引けること（Timeline 表示の前提）。
    func test_descriptorURLs_resolveStoredFiles() throws {
        let (store, dir) = try makeTempStore(maxTotalBytes: 10 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = MediaIngestService(store: store)
        let result = try service.ingestImage(makeJPEG(width: 800, height: 600, withGPS: false))
        let attachment = result.attachment

        // hex は contentHash と一致し、ファイル名キーとして使える。
        XCTAssertEqual(attachment.contentHashHex, hex(attachment.contentHash))
        XCTAssertEqual(attachment.bodyFileExtension, "jpg")
        // 保存済みファイルが descriptor から解決できる。
        XCTAssertEqual(store.bodyURL(for: attachment), result.bodyURL)
        XCTAssertEqual(store.thumbnailURL(for: attachment), result.thumbnailURL)
    }

    // TASK-188: 手元に無いメディア（受信投稿）は nil を返し、UI 側がプレースホルダを出す。
    func test_descriptorURLs_returnNilWhenAbsent() throws {
        let (store, dir) = try makeTempStore(maxTotalBytes: 10 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: dir) }

        let absent = MediaAttachment(
            kind: .video,
            contentHash: Data(repeating: 0xAB, count: MediaAttachment.contentHashByteCount),
            width: 1280,
            height: 720,
            byteSize: 1024,
            mimeType: "video/mp4",
            durationMs: 3000
        )
        XCTAssertEqual(absent.bodyFileExtension, "mp4")
        XCTAssertNil(store.bodyURL(for: absent))
        XCTAssertNil(store.thumbnailURL(for: absent))
    }

    func test_ingestImage_canFeedCreatePostUseCase() throws {
        let (store, dir) = try makeTempStore(maxTotalBytes: 10 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: dir) }

        let service = MediaIngestService(store: store)
        let source = makeJPEG(width: 800, height: 600, withGPS: false)
        let result = try service.ingestImage(source)

        let repo = InMemoryPostRepo()
        let useCase = CreatePostUseCase(repository: repo)
        let request = CreatePostRequest(
            content: "写真付き",
            authorPublicKey: Data(repeating: 0x01, count: 32),
            authorPrivateKey: Data(repeating: 0x02, count: 32),
            media: [result.attachment]
        )
        let post = try useCase.execute(request)
        XCTAssertEqual(post.media.count, 1)
        XCTAssertEqual(post.media.first?.contentHash, result.attachment.contentHash)
    }

    func test_ingestVideo_producesAttachmentAndStores() async throws {
        let (store, dir) = try makeTempStore(maxTotalBytes: 10 * 1024 * 1024)
        defer { try? FileManager.default.removeItem(at: dir) }

        let sourceURL = try await makeMP4(seconds: 1.0, width: 320, height: 240)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let service = MediaIngestService(store: store)
        let result = try await service.ingestVideo(sourceURL)
        let key = hex(result.attachment.contentHash)

        XCTAssertEqual(result.attachment.kind, .video)
        XCTAssertEqual(result.attachment.mimeType, "video/mp4")
        // 動画は再生時間を持つ（画像との差分）。
        XCTAssertNotNil(result.attachment.durationMs)
        XCTAssertGreaterThan(result.attachment.durationMs ?? 0, 0)
        XCTAssertNil(result.attachment.blurHash)

        // 本体（mp4）とサムネ（jpg）が保存され、サイズ上限に収まる。
        XCTAssertEqual(result.attachment.byteSize, store.data(contentHash: key, fileExtension: "mp4")?.count)
        XCTAssertNotNil(store.url(contentHash: key, fileExtension: "mp4"))
        XCTAssertNotNil(store.url(contentHash: key, fileExtension: "thumb.jpg"))
        XCTAssertLessThanOrEqual(result.attachment.byteSize, CreatePostUseCase.maxVideoBytes)

        // contentHash は保存本体の SHA-256 と一致する（取得時の完全性検証の前提）。
        let stored = try XCTUnwrap(store.data(contentHash: key, fileExtension: "mp4"))
        XCTAssertEqual(MediaHashing.sha256(stored), result.attachment.contentHash)
    }

    // MARK: - テスト用動画生成

    /// ノイズフレームを書き込んだ短い MP4 を生成する（トランスコード経路の入力用）。
    private func makeMP4(seconds: Double, width: Int, height: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("src-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )
        writer.add(input)
        guard writer.startWriting() else { throw MediaError.transcodeFailed }
        writer.startSession(atSourceTime: .zero)

        let fps: Int32 = 24
        let frameCount = max(1, Int(seconds * Double(fps)))
        for frame in 0..<frameCount {
            while !input.isReadyForMoreMediaData { await Task.yield() }
            let buffer = try makeNoisePixelBuffer(width: width, height: height)
            let time = CMTime(value: CMTimeValue(frame), timescale: fps)
            adaptor.append(buffer, withPresentationTime: time)
        }
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw MediaError.transcodeFailed }
        return url
    }

    /// ノイズで埋めた ARGB ピクセルバッファ（圧縮で消えないよう乱数を入れる）。
    private func makeNoisePixelBuffer(width: Int, height: Int) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard let buffer = pixelBuffer else { throw MediaError.transcodeFailed }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { throw MediaError.transcodeFailed }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        for index in 0..<(bytesPerRow * height) {
            ptr[index] = UInt8.random(in: 0...255)
        }
        return buffer
    }
}
