import XCTest
import MultipeerConnectivity
@testable import DriftSonarCore

// MARK: - Mocks for Apple's Framework classes
class MockMCNearbyServiceAdvertiser: MCNearbyServiceAdvertiser {
    var isAdvertisingStarted = false
    var customDiscoveryInfo: [String: String]?
    
    override init(peer myPeerID: MCPeerID, discoveryInfo info: [String : String]?, serviceType: String) {
        self.customDiscoveryInfo = info
        super.init(peer: myPeerID, discoveryInfo: info, serviceType: serviceType)
    }
    
    override func startAdvertisingPeer() {
        isAdvertisingStarted = true
    }
    
    override func stopAdvertisingPeer() {
        isAdvertisingStarted = false
    }
}

class MockMCNearbyServiceBrowser: MCNearbyServiceBrowser {
    var isBrowsingStarted = false
    
    override func startBrowsingForPeers() {
        isBrowsingStarted = true
    }
    
    override func stopBrowsingForPeers() {
        isBrowsingStarted = false
    }
}

class MockMCNearbyServiceFactory: MCNearbyServiceFactory {
    var createdAdvertiser: MockMCNearbyServiceAdvertiser?
    var createdBrowser: MockMCNearbyServiceBrowser?
    
    func createAdvertiser(peer: MCPeerID, discoveryInfo: [String : String]?, serviceType: String) -> MCNearbyServiceAdvertiser {
        let mock = MockMCNearbyServiceAdvertiser(peer: peer, discoveryInfo: discoveryInfo, serviceType: serviceType)
        createdAdvertiser = mock
        return mock
    }
    
    func createBrowser(peer: MCPeerID, serviceType: String) -> MCNearbyServiceBrowser {
        let mock = MockMCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
        createdBrowser = mock
        return mock
    }
}

// MARK: - Tests

final class MCPeerEncounterServiceTests: XCTestCase {
    
    func testStartDiscoveryStartsAdvertisingAndBrowsing() throws {
        // Arrange
        let serviceType = "driftsonar"
        let myPublicKey = Data([0xAA, 0xBB, 0xCC])
        let peerID = MCPeerID(displayName: "TestDevice")
        
        let mockFactory = MockMCNearbyServiceFactory()
        let service = MCPeerEncounterService(peerID: peerID, serviceType: serviceType, factory: mockFactory)
        
        let command = StartDiscoveryCommand(myPublicKey: myPublicKey)
        
        // Act
        try service.execute(command: command)
        
        // Assert
        XCTAssertNotNil(mockFactory.createdAdvertiser)
        XCTAssertNotNil(mockFactory.createdBrowser)
        
        XCTAssertTrue(mockFactory.createdAdvertiser!.isAdvertisingStarted, "Advertiser should be started")
        XCTAssertTrue(mockFactory.createdBrowser!.isBrowsingStarted, "Browser should be started")
        
        // The discovery Info should contain the base64 string of our public key
        let expectedInfo = ["pk": myPublicKey.base64EncodedString()]
        XCTAssertEqual(mockFactory.createdAdvertiser!.customDiscoveryInfo, expectedInfo)
    }
    
    func testBrowserFoundPeerFiresEncounterEvent() async throws {
        // Arrange
        let serviceType = "driftsonar"
        let peerID = MCPeerID(displayName: "TestDevice")
        let otherPeerID = MCPeerID(displayName: "OtherDevice")
        let otherPublicKey = Data([0x11, 0x22, 0x33])
        
        let mockFactory = MockMCNearbyServiceFactory()
        let service = MCPeerEncounterService(peerID: peerID, serviceType: serviceType, factory: mockFactory)
        
        let expectation = XCTestExpectation(description: "Encounter received")
        var receivedEvent: EncounteredEvent?
        
        service.onEncounter = { event in
            receivedEvent = event
            expectation.fulfill()
        }
        
        let command = StartDiscoveryCommand(myPublicKey: Data())
        try service.execute(command: command)
        
        guard let browserMock = mockFactory.createdBrowser else {
            XCTFail("Browser should have been created")
            return
        }
        
        // Act - Simulate the Multipeer framework calling our delegate when a peer is found
        let discoveryInfo = ["pk": otherPublicKey.base64EncodedString()]
        service.browser(browserMock, foundPeer: otherPeerID, withDiscoveryInfo: discoveryInfo)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Assert
        XCTAssertNotNil(receivedEvent)
        XCTAssertEqual(receivedEvent?.peerId, otherPeerID.displayName)
        XCTAssertEqual(receivedEvent?.peerPublicKey, otherPublicKey)
    }
}
