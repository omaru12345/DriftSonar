import Foundation
import SwiftData

/// 検証済み相手の SwiftData 永続モデル（TASK-131 / EP-025）。
///
/// 追加専用の新規モデルなので既存ストアには影響せず、SwiftData の軽量マイグレーションで
/// そのまま追加される。公開鍵を一意キーにして相手 1 人につき 1 レコードに保つ。
@available(macOS 14, iOS 17, *)
@Model
public class VerifiedContactModel {
    @Attribute(.unique) public var publicKey: Data
    public var safetyNumberDigits: String
    public var verifiedAt: Date

    public init(publicKey: Data, safetyNumberDigits: String, verifiedAt: Date = Date()) {
        self.publicKey = publicKey
        self.safetyNumberDigits = safetyNumberDigits
        self.verifiedAt = verifiedAt
    }
}
