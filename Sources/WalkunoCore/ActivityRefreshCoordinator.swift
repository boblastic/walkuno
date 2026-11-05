import Foundation

/// Joins concurrent refresh callers and allows one recent-data catch-up for a burst of notifications.
/// A failed pass is never retried automatically, and a burst cannot keep the caller loading forever.
@MainActor
public final class ActivityRefreshCoordinator {
    private var task: Task<Bool, Never>?
    private var activeID: UUID?
    private var needsCatchUp = false

    public init() {}

    @discardableResult
    public func run(_ operation: @escaping @MainActor () async -> Bool) async -> Bool {
        if let task {
            needsCatchUp = true
            return await task.value
        }
        let id = UUID()
        activeID = id
        needsCatchUp = false
        let task = Task {
            defer {
                if activeID == id {
                    self.task = nil
                    activeID = nil
                    needsCatchUp = false
                }
            }
            guard !Task.isCancelled, await operation(), !Task.isCancelled else { return false }
            if needsCatchUp {
                needsCatchUp = false
                return await operation() && !Task.isCancelled
            }
            return true
        }
        self.task = task
        return await task.value
    }

    public func cancel() {
        task?.cancel()
        task = nil
        activeID = nil
        needsCatchUp = false
    }
}
