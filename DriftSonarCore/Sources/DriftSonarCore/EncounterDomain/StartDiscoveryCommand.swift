import Foundation

public struct StartDiscoveryCommand {
    public let myPublicKey: Data
    
    public init(myPublicKey: Data) {
        self.myPublicKey = myPublicKey
    }
}
