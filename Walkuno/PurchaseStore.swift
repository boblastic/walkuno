import Foundation
import StoreKit
import Observation

@MainActor @Observable
final class PurchaseStore {
    static let productIDs = ["fr.orbelio.walkuno.premium.annual", "fr.orbelio.walkuno.premium.lifetime"]
    private(set) var products: [Product] = []
    private var hasPremiumEntitlement = false
    private(set) var hasLoadedEntitlements = false
    #if DEBUG
    var isDevelopmentProEnabled = UserDefaults.standard.bool(forKey: "development.proEnabled") {
        didSet { UserDefaults.standard.set(isDevelopmentProEnabled, forKey: "development.proEnabled") }
    }
    #endif
    var isPremium: Bool {
        #if DEBUG
        hasPremiumEntitlement || isDevelopmentProEnabled
        #else
        hasPremiumEntitlement
        #endif
    }
    private(set) var isBusy = false
    var message: String?
    @ObservationIgnored private var listener: Task<Void, Never>?

    init() {
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { break }
                guard case .verified(let transaction) = result,
                      Self.productIDs.contains(transaction.productID) else { continue }
                await self?.refreshEntitlements()
                await transaction.finish()
            }
        }
    }

    deinit { listener?.cancel() }

    func load() async {
        await refreshEntitlements()
        do {
            products = try await Product.products(for: Self.productIDs).sorted { $0.price < $1.price }
        } catch { message = L("purchase.unavailable") }
    }

    func refreshEntitlements() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  Self.productIDs.contains(transaction.productID),
                  transaction.revocationDate == nil, !transaction.isUpgraded,
                  transaction.expirationDate.map({ $0 > .now }) ?? true else { continue }
            active = true
        }
        hasPremiumEntitlement = active
        hasLoadedEntitlements = true
    }

    func buy(_ product: Product) async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    message = L("purchase.unverified"); return
                }
                await refreshEntitlements()
                await transaction.finish()
            case .pending: message = L("purchase.pending")
            case .userCancelled: break
            @unknown default: break
            }
        } catch { message = L("purchase.failed") }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = L(hasPremiumEntitlement ? "purchase.restored" : "purchase.nothing")
        } catch { message = L("purchase.failed") }
    }
}
