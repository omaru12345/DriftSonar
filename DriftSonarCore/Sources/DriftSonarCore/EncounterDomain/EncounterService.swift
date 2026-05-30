import Foundation

public protocol EncounterService {
    var onEncounter: ((EncounteredEvent) -> Void)? { get set }
    func execute(command: StartDiscoveryCommand) throws
    func stop()
}
