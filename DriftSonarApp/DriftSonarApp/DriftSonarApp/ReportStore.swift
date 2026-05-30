import Foundation

/// Local store of reported post IDs (TASK-167).
///
/// DriftSonar has no server, so "reporting" a post is an immediate, on-device
/// action: the reported post is hidden from this user's timeline at once. IDs are
/// persisted in `UserDefaults` so the post stays hidden across launches. The
/// reason is kept only as a lightweight tally for the user's own reference — it is
/// never transmitted (there is nowhere to send it).
enum ReportStore {
    private static let idsKey = "reportedPostIDs"

    /// Reasons a user can pick when reporting a post. Offline-only; not transmitted.
    enum Reason: String, CaseIterable, Identifiable {
        case spam = "スパム・宣伝"
        case harassment = "嫌がらせ・いじめ"
        case inappropriate = "不適切・わいせつな内容"
        case violenceOrIllegal = "暴力的・違法な内容"
        case other = "その他"

        var id: String { rawValue }
    }

    /// All currently reported (hidden) post IDs.
    static func reportedIDs() -> Set<UUID> {
        let raw = UserDefaults.standard.stringArray(forKey: idsKey) ?? []
        return Set(raw.compactMap(UUID.init(uuidString:)))
    }

    /// Records a report and returns the updated set so the caller can refresh state.
    @discardableResult
    static func report(postID: UUID, reason: Reason) -> Set<UUID> {
        var ids = reportedIDs()
        ids.insert(postID)
        UserDefaults.standard.set(ids.map(\.uuidString), forKey: idsKey)
        return ids
    }
}
