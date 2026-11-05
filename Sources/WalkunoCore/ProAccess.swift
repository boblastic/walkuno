import Foundation

/// Mirror of StoreKit-verified rights, shared only inside the app group and with the paired Watch.
/// It never grants an entitlement to PurchaseStore, which always verifies transactions itself.
public struct ProAccess: Codable, Equatable, Sendable {
    public var granted: Bool
    public var expiresAt: Date?
    public var verifiedAt: Date

    public init(granted: Bool = false, expiresAt: Date? = nil, verifiedAt: Date = .distantPast) {
        self.granted = granted; self.expiresAt = expiresAt; self.verifiedAt = verifiedAt
    }

    public func isActive(at date: Date = .now) -> Bool {
        granted && (expiresAt.map { $0 > date } ?? true)
    }
}
