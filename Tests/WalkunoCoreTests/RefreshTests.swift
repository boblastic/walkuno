import Foundation
import Testing
@testable import WalkunoCore

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct RefreshTests {
    @Test func aMissingQueryCallbackTimesOutAndStopsTheQuery() async {
        let response = QueryResponse<Int>()
        var starts = 0
        var stops = 0
        do {
            _ = try await response.value(timeout: .milliseconds(10), start: { starts += 1 }, stop: { stops += 1 })
            Issue.record("A query without a callback must time out")
        } catch {
            #expect(error is QueryResponseError)
        }
        // HealthKit can deliver a callback after stop(_:). It must not resume the caller again.
        response.finish(.success(999))
        #expect(starts == 1)
        #expect(stops == 1)
    }

    @Test func querySuccessAndDuplicateCallbacksCompleteOnlyOnce() async throws {
        let response = QueryResponse<Int>()
        var stops = 0
        let value = try await response.value(timeout: .seconds(1), start: {
            response.finish(.success(42))
            response.finish(.success(999))
        }, stop: { stops += 1 })
        #expect(value == 42)
        #expect(stops == 1)
    }

    @Test func queryErrorsReleaseTheCallerAndStopTheQuery() async {
        let response = QueryResponse<Int>()
        var stops = 0
        do {
            _ = try await response.value(timeout: .seconds(1), start: {
                response.finish(.failure(CocoaError(.fileReadNoPermission)))
            }, stop: { stops += 1 })
            Issue.record("The query error must reach its caller")
        } catch {
            #expect((error as? CocoaError)?.code == .fileReadNoPermission)
        }
        #expect(stops == 1)
    }

    @Test func cancellationStopsAQueryWithoutWaitingForItsCallback() async {
        let response = QueryResponse<Int>()
        var started = false
        var stops = 0
        let task = Task {
            try await response.value(timeout: .seconds(30), start: { started = true }, stop: { stops += 1 })
        }
        while !started { await Task.yield() }
        task.cancel()
        let result = await task.result
        if case .failure(let error) = result { #expect(error is CancellationError) }
        else { Issue.record("The cancelled query must fail") }
        response.finish(.success(999))
        #expect(stops == 1)
    }

    @Test func anAlreadyCancelledQueryDoesNotStart() async {
        let response = QueryResponse<Int>()
        var starts = 0
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await response.value(timeout: .seconds(30), start: { starts += 1 }, stop: {})
        }
        let result = await task.result
        if case .failure(let error) = result { #expect(error is CancellationError) }
        else { Issue.record("The cancelled query must fail") }
        #expect(starts == 0)
    }

    @Test func notificationBurstsShareTheRefreshAndCatchUpOnlyOnce() async {
        let coordinator = ActivityRefreshCoordinator()
        let probe = RefreshProbe()
        let first = Task { await coordinator.run { await probe.refresh() } }
        await probe.waitForCalls(1)
        var joined = 0
        let callers = (0..<5).map { _ in Task {
            joined += 1
            return await coordinator.run { await probe.refresh() }
        } }
        while joined < callers.count { await Task.yield() }
        #expect(probe.calls == 1)
        probe.complete(succeeded: true)
        await probe.waitForCalls(2)
        var lateJoined = false
        let late = Task {
            lateJoined = true
            return await coordinator.run { await probe.refresh() }
        }
        while !lateJoined { await Task.yield() }
        probe.complete(succeeded: true)
        #expect(await first.value)
        for caller in callers { #expect(await caller.value) }
        #expect(await late.value)
        #expect(probe.calls == 2)
        #expect(probe.maximumConcurrentCalls == 1)
    }

    @Test func failedRefreshDoesNotLoopAndCanBeRetriedManually() async {
        let coordinator = ActivityRefreshCoordinator()
        let probe = RefreshProbe()
        let first = Task { await coordinator.run { await probe.refresh() } }
        await probe.waitForCalls(1)
        var joined = false
        let second = Task {
            joined = true
            return await coordinator.run { await probe.refresh() }
        }
        while !joined { await Task.yield() }
        probe.complete(succeeded: false)
        #expect(await first.value == false)
        #expect(await second.value == false)
        #expect(probe.calls == 1)
        #expect(await coordinator.run { true })
    }

    @Test func cancellingAnOldRefreshDoesNotClearANewRefresh() async {
        let coordinator = ActivityRefreshCoordinator()
        let oldProbe = RefreshProbe()
        let newProbe = RefreshProbe()
        let old = Task { await coordinator.run { await oldProbe.refresh() } }
        await oldProbe.waitForCalls(1)
        coordinator.cancel()
        let current = Task { await coordinator.run { await newProbe.refresh() } }
        await newProbe.waitForCalls(1)
        oldProbe.complete(succeeded: true)
        #expect(await old.value == false)
        var joined = false
        let second = Task {
            joined = true
            return await coordinator.run { await newProbe.refresh() }
        }
        while !joined { await Task.yield() }
        #expect(newProbe.calls == 1)
        newProbe.complete(succeeded: true)
        await newProbe.waitForCalls(2)
        newProbe.complete(succeeded: true)
        #expect(await current.value)
        #expect(await second.value)
        #expect(newProbe.maximumConcurrentCalls == 1)
    }
}

@MainActor
private final class RefreshProbe {
    private(set) var calls = 0
    private(set) var maximumConcurrentCalls = 0
    private var activeCalls = 0
    private var pending: [CheckedContinuation<Bool, Never>] = []

    func refresh() async -> Bool {
        calls += 1
        activeCalls += 1
        maximumConcurrentCalls = max(maximumConcurrentCalls, activeCalls)
        let succeeded = await withCheckedContinuation { pending.append($0) }
        activeCalls -= 1
        return succeeded
    }

    func complete(succeeded: Bool) { pending.removeFirst().resume(returning: succeeded) }

    func waitForCalls(_ count: Int) async {
        while calls < count { await Task.yield() }
    }
}
