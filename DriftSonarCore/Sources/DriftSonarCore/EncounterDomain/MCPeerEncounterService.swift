import Foundation
import MultipeerConnectivity

// A factory protocol so we can inject mocks for testing
public protocol MCNearbyServiceFactory {
    func createAdvertiser(
        peer: MCPeerID, discoveryInfo: [String: String]?, serviceType: String
    ) -> MCNearbyServiceAdvertiser
    func createBrowser(peer: MCPeerID, serviceType: String) -> MCNearbyServiceBrowser
}

// Default factory that creates real objects
public struct DefaultMCNearbyServiceFactory: MCNearbyServiceFactory {
    public init() {}
    
    public func createAdvertiser(
        peer: MCPeerID, discoveryInfo: [String: String]?, serviceType: String
    ) -> MCNearbyServiceAdvertiser {
        return MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: discoveryInfo, serviceType: serviceType)
    }
    
    public func createBrowser(peer: MCPeerID, serviceType: String) -> MCNearbyServiceBrowser {
        return MCNearbyServiceBrowser(peer: peer, serviceType: serviceType)
    }
}

public class MCPeerEncounterService: NSObject, EncounterService {
    public var onEncounter: ((EncounteredEvent) -> Void)?
    
    private let peerID: MCPeerID
    private let serviceType: String
    private let factory: MCNearbyServiceFactory
    
    public private(set) var advertiser: MCNearbyServiceAdvertiser?
    public private(set) var browser: MCNearbyServiceBrowser?
    
    public init(
        peerID: MCPeerID, serviceType: String, factory: MCNearbyServiceFactory = DefaultMCNearbyServiceFactory()
    ) {
        self.peerID = peerID
        self.serviceType = serviceType
        self.factory = factory
        super.init()
    }
    
    public func execute(command: StartDiscoveryCommand) throws {
        // Stop existing discovery if any
        advertiser?.delegate = nil
        browser?.delegate = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        
        let discoveryInfo = ["pk": command.myPublicKey.base64EncodedString()]
        
        self.advertiser = factory.createAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        self.browser = factory.createBrowser(peer: peerID, serviceType: serviceType)
        
        self.advertiser?.delegate = self
        self.browser?.delegate = self
        
        self.advertiser?.startAdvertisingPeer()
        self.browser?.startBrowsingForPeers()
    }

    public func stop() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser?.delegate = nil
        browser?.delegate = nil
    }
}

extension MCPeerEncounterService: MCNearbyServiceAdvertiserDelegate {
    public func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(false, nil)
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to start advertising: \(error)")
    }
}

extension MCPeerEncounterService: MCNearbyServiceBrowserDelegate {
    public func browser(
        _ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?
    ) {
        guard let info = info,
              let pkBase64 = info["pk"],
              let publicKeyData = Data(base64Encoded: pkBase64) else {
            return
        }
        
        let event = EncounteredEvent(peerId: peerID.displayName, peerPublicKey: publicKeyData)
        onEncounter?(event)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to start browsing: \(error)")
    }
}
