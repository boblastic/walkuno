import Foundation
import WatchConnectivity

/// Only goals, appearance and verified Pro access cross this bridge. Health measurements stay in each HealthKit store.
@MainActor
final class WatchBridge: NSObject, WCSessionDelegate {
    private var session: WCSession?
    private var pending: Data?
    var onReceive: ((WatchSettings) -> Void)?

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        session.activate()
    }

    func send(_ preferences: Preferences, proAccess: ProAccess? = nil) {
        let payload = WatchSettings(preferences: preferences, proAccess: proAccess)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        pending = data
        flush()
    }

    private func flush() {
        guard let session, session.activationState == .activated, let pending else { return }
        #if os(iOS)
        guard session.isPaired, session.isWatchAppInstalled else { return }
        #endif
        do {
            try session.updateApplicationContext(["settings": pending])
            self.pending = nil
        } catch { /* Retain pending settings until the next activation or app refresh. */ }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            flush()
            receive(session.receivedApplicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in receive(applicationContext) }
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    #endif

    private func receive(_ context: [String: Any]) {
        guard let data = context["settings"] as? Data, data.count <= 100_000,
              let payload = try? JSONDecoder().decode(WatchSettings.self, from: data) else { return }
        onReceive?(payload)
    }
}
