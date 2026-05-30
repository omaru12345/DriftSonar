import Foundation

public enum DecryptionError: Error, Equatable {
    case authenticationFailed
    case invalidKey
    case invalidData
}
