import Foundation

/// Bridges a one-shot callback query without leaving a suspended caller on timeout or cancellation.
@MainActor
public final class QueryResponse<Value: Sendable> {
    private var continuation: CheckedContinuation<Value, any Error>?
    private var timeoutTask: Task<Void, Never>?
    private var stop: (() -> Void)?

    public init() {}

    public func value(timeout: Duration, start: () -> Void, stop: @escaping () -> Void) async throws -> Value {
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                self.stop = stop
                timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(for: timeout) }
                    catch { return }
                    self?.finish(.failure(QueryResponseError.timedOut))
                }
                start()
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    public func finish(_ result: Result<Value, any Error>) {
        guard let continuation else { return }
        self.continuation = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        let stop = self.stop
        self.stop = nil
        stop?()
        continuation.resume(with: result)
    }
}

public enum QueryResponseError: Error {
    case timedOut
}
