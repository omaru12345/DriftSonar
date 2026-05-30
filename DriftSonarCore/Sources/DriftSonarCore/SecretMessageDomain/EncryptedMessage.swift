import Foundation

public struct EncryptedMessage {
    public let data: Data
    
    public init(data: Data) {
        self.data = data
    }
}
