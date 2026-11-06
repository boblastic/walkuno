import Foundation
import Testing
@testable import WalkunoCore

struct ProAccessTests {
    @Test func subscriptionStopsAtItsExactExpirationWithoutAnotherStoreRefresh() throws {
        let expiration = Date(timeIntervalSince1970: 1_800_000_000)
        let access = ProAccess(granted: true, expiresAt: expiration, verifiedAt: expiration.addingTimeInterval(-3600))
        let restored = try JSONDecoder().decode(ProAccess.self, from: JSONEncoder().encode(access))
        #expect(restored.isActive(at: expiration.addingTimeInterval(-1)))
        #expect(!restored.isActive(at: expiration))
        #expect(!restored.isActive(at: expiration.addingTimeInterval(86400)))
    }

    @Test func freeAndRevokedRightsNeverUnlockWidgetsEvenWithAFutureExpiration() {
        let now = Date.now
        #expect(!ProAccess().isActive(at: now))
        #expect(!ProAccess(granted: false, expiresAt: now.addingTimeInterval(86400)).isActive(at: now))
        #expect(ProAccess(granted: true).isActive(at: now.addingTimeInterval(86400 * 365)))
    }

    @Test func pairedWatchKeepsTheVerifiedExpirationAndLegacyContextsStayFree() throws {
        let expiration = Date.now.addingTimeInterval(3600)
        let access = ProAccess(granted: true, expiresAt: expiration, verifiedAt: .now)
        let payload = WatchSettings(preferences: .init(), proAccess: access)
        let data = try JSONEncoder().encode(payload)
        let restored = try JSONDecoder().decode(WatchSettings.self, from: data)
        #expect(restored.proAccess == access)
        #expect(restored.proAccess?.isActive(at: expiration) == false)
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "proAccess")
        let decoded = try JSONDecoder().decode(WatchSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.proAccess == nil)
    }

    @Test func onlyHorizonAndStarsAreIncludedInFreeCustomization() {
        #expect(CounterEffect.allCases.filter { !$0.requiresPremium } == [.stars])
        #expect(CounterStyle.allCases.filter { !$0.requiresPremium } == [.horizon])
    }
}
