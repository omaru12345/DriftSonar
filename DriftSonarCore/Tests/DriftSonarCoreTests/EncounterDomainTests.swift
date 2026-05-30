import XCTest
@testable import DriftSonarCore

final class EncounterDomainTests: XCTestCase {
    
    func testStartDiscoveryFiresEncounteredEvent() async throws {
        // Arrange
        let mockService = MockEncounterService()
        let myPublicKey = Data([0x01, 0x02, 0x03])
        let command = StartDiscoveryCommand(myPublicKey: myPublicKey)
        
        var encounteredEvents: [EncounteredEvent] = []
        let expectation = XCTestExpectation(description: "Encountered event received")
        
        mockService.onEncounter = { event in
            encounteredEvents.append(event)
            expectation.fulfill()
        }
        
        // Act
        try mockService.execute(command: command)
        
        // Simulate an encounter in the mock
        mockService.simulateEncounter(peerId: "PeerB", peerPublicKey: Data([0x04, 0x05]))
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Assert
        XCTAssertEqual(encounteredEvents.count, 1)
        XCTAssertEqual(encounteredEvents.first?.peerId, "PeerB")
        XCTAssertEqual(encounteredEvents.first?.peerPublicKey, Data([0x04, 0x05]))
    }
}
