import Foundation

/// メディア本体・サムネイルをアプリサンドボックスにローカル保存するストア。
///
/// - ファイル名は contentHash（重複排除・完全性検証のキー）。
/// - 総量が `MediaBudget.cacheMaxTotalBytes` を超えたら LRU でエビクションする
///   （アクセス＝ファイル更新日時の最古から削除）。
/// - mesh で受け取ったメディアも、自分で作ったメディアもここに集約する。
public final class MediaStore {
    private let rootDirectory: URL
    private let maxTotalBytes: Int
    private let fileManager: FileManager

    /// - Parameters:
    ///   - rootDirectory: 保存先ディレクトリ（無ければ生成する）。
    ///   - maxTotalBytes: キャッシュ総量上限。
    public init(
        rootDirectory: URL,
        maxTotalBytes: Int = MediaBudget.default.cacheMaxTotalBytes,
        fileManager: FileManager = .default
    ) throws {
        self.rootDirectory = rootDirectory
        self.maxTotalBytes = maxTotalBytes
        self.fileManager = fileManager
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    }

    /// 本体を保存し URL を返す。保存後に総量上限を強制する。
    ///
    /// - Parameters:
    ///   - data: 本体バイト列。
    ///   - contentHash: メディアID（SHA-256 hex）。ファイル名に使う。
    ///   - fileExtension: 拡張子（"jpg" / "mp4" 等）。
    /// - Returns: 保存先 URL。
    @discardableResult
    public func store(_ data: Data, contentHash: String, fileExtension: String) throws -> URL {
        let url = fileURL(contentHash: contentHash, fileExtension: fileExtension)
        do {
            try data.write(to: url, options: .atomic)
            try touch(url)
        } catch {
            throw MediaError.storageFailed
        }
        try enforceCapacity(keeping: url)
        return url
    }

    /// contentHash に対応する本体 URL を返す（存在すればアクセス時刻を更新）。
    public func url(contentHash: String, fileExtension: String) -> URL? {
        let url = fileURL(contentHash: contentHash, fileExtension: fileExtension)
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        try? touch(url)
        return url
    }

    /// contentHash に対応する本体を読み出す（アクセス時刻を更新）。
    public func data(contentHash: String, fileExtension: String) -> Data? {
        guard let url = url(contentHash: contentHash, fileExtension: fileExtension) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// 保存中の総バイト数。
    public func totalBytes() -> Int {
        storedFiles().reduce(0) { $0 + $1.size }
    }

    /// 保存中のメディアを全削除する（アカウント削除＝App Store GL 5.1.1 で使用）。
    /// ルートディレクトリ自体は残し、配下のファイルだけ消す（以後の保存に再利用できる）。
    public func removeAll() {
        for file in storedFiles() {
            try? fileManager.removeItem(at: file.url)
        }
    }

    /// 生存投稿から参照されなくなった孤立メディア（本体・サムネイル）を削除する（TASK-195）。
    ///
    /// 投稿の retention purge 後に呼ぶ。`keep` は生存投稿が参照する contentHash の集合で、
    /// これに含まれない contentHash のファイルをすべて消す。共有 contentHash は「1件でも
    /// 生存投稿が参照していれば keep に入る」ため保持される（参照カウント相当）。本体と
    /// サムネ（`.thumb.jpg`）はどちらも同じ contentHash を接頭辞に持つので、まとめて対象になる。
    ///
    /// LRU の `enforceCapacity` はバイト上限でしか消さず age を見ないため、投稿レコードが
    /// 消えてもファイルがディスクに無期限で残る穴（「記録に残らない」保証の綻び）をこれで塞ぐ。
    /// - Returns: 削除したファイル数。
    @discardableResult
    public func purgeOrphans(keepingContentHashes keep: Set<String>) -> Int {
        var removed = 0
        for file in storedFiles() where !keep.contains(contentHash(of: file.url)) {
            if (try? fileManager.removeItem(at: file.url)) != nil { removed += 1 }
        }
        return removed
    }

    // MARK: - descriptor から URL を引く（TASK-188）

    /// descriptor に対応するサムネ URL を返す（無ければ nil）。
    ///
    /// 受信した投稿は本体・サムネがまだ手元に無い（オンデマンド取得は TASK-189）。
    /// その場合 nil を返し、UI 側はプレースホルダを出す。
    public func thumbnailURL(for attachment: MediaAttachment) -> URL? {
        url(contentHash: attachment.contentHashHex, fileExtension: MediaAttachment.thumbnailFileExtension)
    }

    /// descriptor に対応するフル本体 URL を返す（無ければ nil）。kind で拡張子が決まる。
    public func bodyURL(for attachment: MediaAttachment) -> URL? {
        url(contentHash: attachment.contentHashHex, fileExtension: attachment.bodyFileExtension)
    }

    // MARK: - 内部処理

    private func fileURL(contentHash: String, fileExtension: String) -> URL {
        rootDirectory.appendingPathComponent("\(contentHash).\(fileExtension)")
    }

    /// ファイル名 `{contentHash}.{ext}` から contentHash を取り出す。
    /// サムネは `.thumb.jpg` と多段拡張子なので、拡張子除去ではなく最初のドットまでで判定する
    /// （contentHash は SHA-256 hex なのでドットを含まない）。
    private func contentHash(of url: URL) -> String {
        let name = url.lastPathComponent
        guard let dot = name.firstIndex(of: ".") else { return name }
        return String(name[..<dot])
    }

    /// アクセス時刻（= 更新日時）を現在に更新し LRU の新しさを表す。
    private func touch(_ url: URL) throws {
        try fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
    }

    /// 総量が上限を超えていたら、`keeping` を除いて最古から削除する。
    private func enforceCapacity(keeping survivor: URL) throws {
        let files = storedFiles().sorted { $0.modified < $1.modified }
        var total = files.reduce(0) { $0 + $1.size }
        let survivorPath = survivor.standardizedFileURL.path
        for file in files where total > maxTotalBytes {
            if file.url.standardizedFileURL.path == survivorPath { continue }
            try? fileManager.removeItem(at: file.url)
            total -= file.size
        }
    }

    private struct StoredFile {
        let url: URL
        let size: Int
        let modified: Date
    }

    private func storedFiles() -> [StoredFile] {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let urls = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return urls.compactMap { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  let size = values.fileSize else {
                return nil
            }
            let modified = values.contentModificationDate ?? .distantPast
            return StoredFile(url: url, size: size, modified: modified)
        }
    }
}
