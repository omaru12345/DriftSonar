import Foundation

public class MockEncounterService: EncounterService {
    public var onEncounter: ((EncounteredEvent) -> Void)?
    public var isDiscovering = false
    public var myPublicKey: Data?
    
    public init() {}
    
    public func execute(command: StartDiscoveryCommand) throws {
        isDiscovering = true
        myPublicKey = command.myPublicKey
    }
    
    public func stop() {
        isDiscovering = false
    }

    public func simulateEncounter(peerId: String, peerPublicKey: Data) {
        let event = EncounteredEvent(peerId: peerId, peerPublicKey: peerPublicKey)
        onEncounter?(event)
    }
}
