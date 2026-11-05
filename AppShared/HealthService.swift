import Foundation
import HealthKit

/// Read-only HealthKit adapter. Statistics queries let HealthKit reconcile overlapping sources.
/// Read permission cannot be inferred from authorizationStatus(for:), which describes writing.
@MainActor
final class HealthService {
    private let store = HKHealthStore()
    private var observers: [HKObserverQuery] = []
    private var activeQueries: [UUID: () -> Void] = [:]
    private let queryTimeout: Duration = .seconds(15)
    private let identifiers: [HKQuantityTypeIdentifier] = [.stepCount, .distanceWalkingRunning, .activeEnergyBurned, .appleExerciseTime, .flightsClimbed]
    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func authorize() async throws {
        guard isAvailable else { throw HealthFailure.unavailable }
        let types = Set(identifiers.map { HKQuantityType($0) })
        try await store.requestAuthorization(toShare: [], read: types)
    }

    func observe(onChange: @escaping @MainActor @Sendable () async -> Void) {
        guard isAvailable, observers.isEmpty else { return }
        for identifier in identifiers {
            let type = HKQuantityType(identifier)
            let query = HKObserverQuery(sampleType: type, predicate: nil) { _, completion, error in
                guard error == nil else { completion(); return }
                Task { @MainActor in
                    await onChange()
                    completion()
                }
            }
            observers.append(query)
            store.execute(query)
            store.enableBackgroundDelivery(for: type, frequency: .hourly) { _, _ in }
        }
    }

    func stop() async {
        observers.forEach { store.stop($0) }
        observers.removeAll()
        let cancellations = Array(activeQueries.values)
        cancellations.forEach { $0() }
        try? await store.disableAllBackgroundDelivery()
    }

    func history(from requestedStart: Date? = nil, now: Date = .now, calendar: Calendar = .current) async throws -> [ActivityDay] {
        guard isAvailable else { throw HealthFailure.unavailable }
        let first: Date
        if let requestedStart { first = requestedStart }
        else { first = try await firstActivityDate() ?? now }
        let start = calendar.startOfDay(for: min(first, now))
        async let stepQuery = quantities(.stepCount, unit: .count(), from: start, to: now, hourly: false, calendar: calendar)
        async let distanceQuery = quantities(.distanceWalkingRunning, unit: .meter(), from: start, to: now, hourly: false, calendar: calendar)
        async let energyQuery = quantities(.activeEnergyBurned, unit: .kilocalorie(), from: start, to: now, hourly: false, calendar: calendar)
        async let exerciseQuery = quantities(.appleExerciseTime, unit: .minute(), from: start, to: now, hourly: false, calendar: calendar)
        async let floorQuery = quantities(.flightsClimbed, unit: .count(), from: start, to: now, hourly: false, calendar: calendar)
        let (steps, distances, energy, exercise, floors) = try await (stepQuery, distanceQuery, energyQuery, exerciseQuery, floorQuery)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        return ActivityMath.days(in: DateInterval(start: start, end: end), available: [], now: now, calendar: calendar).map {
            ActivityDay(date: $0.date, steps: steps[$0.date].map { Int($0.rounded()) },
                        meters: distances[$0.date], kilocalories: energy[$0.date],
                        exerciseMinutes: exercise[$0.date], floors: floors[$0.date])
        }
    }

    func hours(on date: Date, metric: ActivityMetric = .steps, through: Date? = nil,
               now: Date = .now, calendar: Calendar = .current, strictEnd: Bool = false) async throws -> [HourActivity] {
        let interval = ActivityPeriod.day.interval(containing: date, calendar: calendar)
        let end = min(interval.end, through ?? now, now)
        guard interval.start < end else { return [] }
        let identifier: HKQuantityTypeIdentifier
        let unit: HKUnit
        switch metric {
        case .steps: identifier = .stepCount; unit = .count()
        case .distance: identifier = .distanceWalkingRunning; unit = .meter()
        case .energy: identifier = .activeEnergyBurned; unit = .kilocalorie()
        case .exerciseTime: identifier = .appleExerciseTime; unit = .minute()
        case .floors: identifier = .flightsClimbed; unit = .count()
        }
        let values = try await quantities(identifier, unit: unit, from: interval.start, to: end, hourly: true,
                                          calendar: calendar, strictEnd: strictEnd)
        var hours: [HourActivity] = []
        var cursor = interval.start
        while cursor < end {
            let value = values[cursor]
            hours.append(.init(date: cursor, steps: metric == .steps ? value.map { Int($0.rounded()) } : nil,
                               meters: metric == .distance ? value : nil, kilocalories: metric == .energy ? value : nil,
                               exerciseMinutes: metric == .exerciseTime ? value : nil, floors: metric == .floors ? value : nil))
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return hours
    }

    func widgetActivity(at now: Date, calendar: Calendar = .current) async throws -> WidgetActivityDetail {
        guard isAvailable else { throw HealthFailure.unavailable }
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let cutoff = WidgetActivityDetail.previousDayCutoff(for: now, calendar: calendar)
        async let usual = widgetUsualActivity(at: now, calendar: calendar)
        // The percentage has its own exact cutoff query. Never prorate a complete hourly bin.
        async let steps = widgetQuantities(.stepCount, unit: .count(), from: yesterday, to: now, cutoff: cutoff, calendar: calendar)
        async let distance = widgetQuantities(.distanceWalkingRunning, unit: .meter(), from: yesterday, to: now, cutoff: cutoff, calendar: calendar)
        let (stepValues, distanceValues) = try await (steps, distance)
        var currentHours: [HourActivity] = [], previousHours: [HourActivity] = []
        var cursor = yesterday
        while cursor < now {
            let hour = HourActivity(date: cursor, steps: stepValues.hours[cursor].map { Int($0.rounded()) },
                                    meters: distanceValues.hours[cursor])
            if cursor < today { previousHours.append(hour) } else { currentHours.append(hour) }
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        // A missing usual reference must not discard the real hourly measurements.
        let reference = await usual
        return .init(sampledAt: now, previousCutoff: cutoff, todayHours: currentHours, yesterdayHours: previousHours,
                     yesterdayAtSameTime: .init(date: yesterday, steps: stepValues.previous.map { Int($0.rounded()) },
                                               meters: distanceValues.previous), usual: reference)
    }

    private func widgetUsualActivity(at now: Date, calendar: Calendar) async -> WidgetUsualActivity? {
        do {
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -28, to: today)!
            let days = try await quantities(.stepCount, unit: .count(), from: start, to: today,
                                            hourly: false, calendar: calendar)
            let candidates = days.keys.filter { $0 < today }.sorted(by: >).prefix(7)
            let history = try await withThrowingTaskGroup(of: (partial: [HourActivity], full: [HourActivity]).self) { group in
                for day in candidates {
                    guard let cutoff = WidgetActivityDetail.clockCutoff(on: day, matching: now, calendar: calendar) else { continue }
                    group.addTask { @MainActor in
                        async let partial = self.hours(on: day, through: cutoff, now: now, calendar: calendar, strictEnd: true)
                        async let full = self.hours(on: day, now: now, calendar: calendar)
                        return try await (partial, full)
                    }
                }
                var result: [(partial: [HourActivity], full: [HourActivity])] = []
                for try await hours in group { result.append(hours) }
                return result
            }
            try Task.checkCancellation()
            let clock = calendar.dateComponents([.hour, .minute, .second], from: now)
            let cutoff = Double(clock.hour ?? 0) + Double(clock.minute ?? 0) / 60 + Double(clock.second ?? 0) / 3600
            return .init(comparison: .init(today: [], history: history.map(\.partial), metric: .steps,
                                          cutoffHour: cutoff, calendar: calendar, fullDayHistory: history.map(\.full)))
        } catch { return nil }
    }

    private func widgetQuantities(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date,
                                  cutoff: Date?, calendar: Calendar) async throws -> (hours: [Date: Double], previous: Double?) {
        async let hours = quantities(identifier, unit: unit, from: start, to: end, hourly: true, calendar: calendar)
        // A skipped local clock time has no same-time baseline; the hourly profiles remain useful.
        guard let cutoff, cutoff > start else { return try await (hours, nil) }
        async let previous = quantities(identifier, unit: unit, from: start, to: cutoff, hourly: false,
                                         calendar: calendar, strictEnd: true)
        return try await (hours, previous[start])
    }

    private func firstActivityDate() async throws -> Date? {
        // Distance and other measurements may predate steps or have separate read permissions.
        try await withThrowingTaskGroup(of: Date?.self) { group in
            for identifier in identifiers {
                group.addTask { @MainActor in try await self.firstSampleDate(for: identifier) }
            }
            var earliest: Date?
            for try await date in group {
                if let date { earliest = min(earliest ?? date, date) }
            }
            return earliest
        }
    }

    private func firstSampleDate(for identifier: HKQuantityTypeIdentifier) async throws -> Date? {
        try await performQuery { complete in
            let query = HKSampleQuery(sampleType: HKQuantityType(identifier), predicate: nil, limit: 1,
                                      sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, error in
                if let error { complete(.failure(error)) }
                else { complete(.success(samples?.first?.startDate)) }
            }
            return query
        }
    }

    private func quantities(_ identifier: HKQuantityTypeIdentifier, unit: HKUnit, from start: Date, to end: Date,
                            hourly: Bool, calendar: Calendar, strictEnd: Bool = false) async throws -> [Date: Double] {
        try await performQuery { complete in
            let options: HKQueryOptions = strictEnd ? [.strictStartDate, .strictEndDate] : .strictStartDate
            let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: options)
            let interval = hourly ? DateComponents(hour: 1) : DateComponents(day: 1)
            let query = HKStatisticsCollectionQuery(quantityType: HKQuantityType(identifier), quantitySamplePredicate: predicate,
                                                    options: .cumulativeSum, anchorDate: calendar.startOfDay(for: start), intervalComponents: interval)
            query.initialResultsHandler = { _, collection, error in
                if let error { complete(.failure(error)); return }
                var values: [Date: Double] = [:]
                collection?.enumerateStatistics(from: start, to: end) { statistic, _ in
                    // Absence of sumQuantity is intentionally left nil.
                    if let quantity = statistic.sumQuantity() {
                        values[statistic.startDate] = max(0, quantity.doubleValue(for: unit))
                    }
                }
                complete(.success(values))
            }
            return query
        }
    }

    private func performQuery<Value: Sendable>(_ makeQuery: (@escaping @Sendable (Result<Value, any Error>) -> Void) -> HKQuery) async throws -> Value {
        let response = QueryResponse<Value>()
        let query = makeQuery { result in
            Task { @MainActor in response.finish(result) }
        }
        let id = UUID()
        activeQueries[id] = { response.finish(.failure(CancellationError())) }
        defer { activeQueries[id] = nil }
        return try await response.value(timeout: queryTimeout, start: { store.execute(query) }, stop: { self.store.stop(query) })
    }
}

enum HealthFailure: LocalizedError {
    case unavailable
    var errorDescription: String? { String(localized: "health.unavailable") }
}
