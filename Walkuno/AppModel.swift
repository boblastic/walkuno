import SwiftUI
import Observation
import WidgetKit

@MainActor @Observable
final class AppModel {
    static let shared = AppModel()
    var preferences = LocalStore.preferences() {
        didSet {
            if preferences.language != oldValue.language { AppLocalization.configure(preferences.language) }
        }
    }
    private(set) var days: [ActivityDay] = []
    private(set) var hours: [HourActivity] = []
    private(set) var isLoading = false
    private(set) var lastUpdated: Date?
    private(set) var usingCache = false
    private(set) var isDemo = false
    var errorMessage: String?
    var celebration = false
    let purchases = PurchaseStore()
    @ObservationIgnored private let health = HealthService()
    @ObservationIgnored private let bridge = WatchBridge()
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let refreshCoordinator = ActivityRefreshCoordinator()
    @ObservationIgnored private var historyTask: Task<Void, Never>?
    @ObservationIgnored private var loadedSnapshot: WidgetSnapshot?
    private var widgetActivity: WidgetActivityDetail?
    @ObservationIgnored private var hasLoadedWidgetHistory = false
    @ObservationIgnored private var recentRefreshStart: Date?

    init() {
        AppLocalization.configure(preferences.language)
        if let snapshot = LocalStore.snapshot(), snapshot.isCurrent() {
            // Restore only the bounded daily cache, so a settings edit before Health
            // responds cannot replace an existing month with just seven days.
            let month = snapshot.history?.periods.first { $0.period == "month" }
            let cached = (month?.previous ?? []) + (month?.current ?? []) + snapshot.week + [snapshot.today]
            days = Dictionary(cached.filter { $0.date <= Date.now }.map { ($0.date, $0) }, uniquingKeysWith: { _, latest in latest })
                .values.sorted { $0.date < $1.date }
            lastUpdated = snapshot.updatedAt
            usingCache = true
            loadedSnapshot = snapshot
            widgetActivity = snapshot.activity
            hours = snapshot.activity?.todayHours ?? []
        }
        bridge.onReceive = { [weak self] goals, _, _ in
            guard let self, self.preferences.onboardingComplete else { return }
            self.preferences.goals.merge(goals)
            self.persist(sync: false)
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            isDemo = true
            preferences.onboardingComplete = true
            loadDemo()
        }
        #endif
    }

    var goal: Int { preferences.goals.value(on: .now) }
    var today: ActivityDay { days.first { Calendar.current.isDateInToday($0.date) } ?? .init(date: Calendar.current.startOfDay(for: .now)) }
    var yesterday: ActivityDay? { days.first { Calendar.current.isDateInYesterday($0.date) } }
    var yesterdayHours: [HourActivity] {
        let calendar = Calendar.current
        if isDemo, let yesterday = calendar.date(byAdding: .day, value: -1, to: .now) {
            return demoHours(on: yesterday)
        }
        guard let detail = widgetActivity, calendar.isDateInToday(detail.sampledAt) else { return [] }
        return detail.yesterdayHours
    }
    var progress: Double { ActivityMath.progress(steps: today.steps, goal: goal) }
    var effectiveTheme: WalkunoTheme { purchases.isPremium ? preferences.theme : .mint }
    var effectiveCounter: CounterStyle {
        preferences.counterStyle.requiresPremium && !purchases.isPremium ? .horizon : preferences.counterStyle
    }

    func start() async {
        prepareForHealthDelivery()
        if !isDemo, preferences.onboardingComplete, preferences.healthRequested {
            await refresh()
            sendSettings()
        }
        await purchases.load()
        if !isDemo, preferences.healthRequested { writeSnapshot(); sendSettings() }
    }

    /// Register before any asynchronous App Store work, including a background launch.
    func prepareForHealthDelivery() {
        guard !isDemo, preferences.onboardingComplete, preferences.healthRequested else { return }
        observe()
    }

    func connectHealth() async {
        guard !isDemo else { return }
        do {
            try await health.authorize()
            preferences.healthRequested = true
            persist()
            observe()
            await refresh()
        } catch { errorMessage = L("health.connection.error") }
    }

    private func observe() {
        health.observe { [weak self] in await self?.refresh(recentOnly: true) }
    }

    func refresh(recentOnly: Bool = false) async {
        guard !isDemo, preferences.healthRequested else { return }
        let refreshed = await refreshCoordinator.run { [weak self] in
            await self?.refreshRecentActivity() ?? false
        }
        if refreshed, !recentOnly, preferences.healthRequested {
            refreshOlderHistory()
        }
    }

    private func refreshRecentActivity() async -> Bool {
        guard preferences.healthRequested, !Task.isCancelled else { return false }
        isLoading = true
        let token = generation
        defer { if token == generation { isLoading = false } }
        if today.steps == nil { celebration = false }
        do {
            let refreshTime = Date.now
            let calendar = Calendar.current
            // Keep widget calendars current during background deliveries, with a bounded query.
            let from = purchases.isPremium
                ? calendar.date(byAdding: .year, value: -1, to: calendar.dateInterval(of: .year, for: refreshTime)!.start)!
                : calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: refreshTime))!
            async let widgetQuery = health.widgetActivity(at: refreshTime)
            let newDays = try await health.history(from: from, now: refreshTime)
            try Task.checkCancellation()
            guard token == generation, calendar.timeZone == Calendar.current.timeZone else { return false }
            days = days.filter { $0.date < from } + newDays
            recentRefreshStart = from
            if purchases.isPremium { hasLoadedWidgetHistory = true }
            usingCache = false; lastUpdated = refreshTime
            errorMessage = nil
            celebration = progress >= 1
            widgetActivity = nil; hours = []
            writeSnapshot()
            // Hourly detail must not discard successfully refreshed daily measurements.
            do {
                let detail = try await widgetQuery
                try Task.checkCancellation()
                guard token == generation else { return false }
                hours = detail.todayHours
                widgetActivity = detail
                writeSnapshot()
            }
            catch is CancellationError { return false }
            catch {
                guard token == generation else { return false }
                hours = []; errorMessage = L("health.refresh.error")
            }
            return true
        } catch is CancellationError {
            return false
        } catch {
            guard token == generation else { return false }
            // Never show yesterday's cached counter as today's measurement.
            if let snapshot = loadedSnapshot, !snapshot.isCurrent() { days = []; hours = []; usingCache = false }
            errorMessage = L("health.refresh.error")
            return false
        }
    }

    private func refreshOlderHistory() {
        guard historyTask == nil else { return }
        let token = generation
        let calendar = Calendar.current
        let from = recentRefreshStart ?? calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: .now))!
        historyTask = Task { [weak self] in
            guard let self else { return }
            defer { if token == generation { historyTask = nil } }
            do {
                // Exclude the recent window: a slow history read cannot overwrite newer measurements.
                let olderDays = try await health.history(now: from, calendar: calendar)
                try Task.checkCancellation()
                guard token == generation, calendar.timeZone == Calendar.current.timeZone else { return }
                days = olderDays.filter { $0.date < from } + days.filter { $0.date >= from }
                hasLoadedWidgetHistory = true
                writeSnapshot()
            } catch is CancellationError { }
            catch { if token == generation { errorMessage = L("health.history.error") } }
        }
    }

    func hourly(on date: Date, metric: ActivityMetric = .steps) async throws -> [HourActivity] {
        if metric == .steps, Calendar.current.isDateInToday(date) { return hours }
        if isDemo { return demoHours(on: date) }
        if metric == .steps, Calendar.current.isDateInYesterday(date), !yesterdayHours.isEmpty {
            return yesterdayHours
        }
        return try await health.hours(on: date, metric: metric)
    }

    func dayComparison(metric: ActivityMetric, earliest: Date?) async throws -> DayComparison {
        let calendar = Calendar.current
        let cutoff = lastUpdated.flatMap { calendar.isDateInToday($0) ? $0 : nil } ?? .now
        let clock = calendar.dateComponents([.hour, .minute, .second], from: cutoff)
        let cutoffHour = Double(clock.hour ?? 0) + Double(clock.minute ?? 0) / 60 + Double(clock.second ?? 0) / 3600
        guard isDemo || preferences.healthRequested else {
            return .init(today: [], history: [], metric: metric, cutoffHour: cutoffHour)
        }
        let current: [HourActivity]
        if isDemo { current = demoHours(on: cutoff, through: cutoff) }
        else { current = try await health.hours(on: cutoff, metric: metric, through: cutoff, now: cutoff) }
        let recentStart = calendar.date(byAdding: .day, value: -28, to: calendar.startOfDay(for: cutoff))!
        let candidates = days.filter {
            $0.date >= max(earliest ?? recentStart, recentStart) && $0.date < calendar.startOfDay(for: cutoff) && metric.value(in: $0) != nil
        }.sorted { $0.date > $1.date }.prefix(7)
        var history: [[HourActivity]] = []
        var fullDayHistory: [[HourActivity]] = []
        for day in candidates {
            try Task.checkCancellation()
            guard let end = calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0,
                                          second: clock.second ?? 0, of: day.date) else { continue }
            if isDemo {
                history.append(demoHours(on: day.date, through: end))
                fullDayHistory.append(demoHours(on: day.date))
            } else {
                async let partial = health.hours(on: day.date, metric: metric, through: end)
                async let complete = health.hours(on: day.date, metric: metric)
                let (partialHours, completeHours) = try await (partial, complete)
                history.append(partialHours)
                fullDayHistory.append(completeHours)
            }
        }
        try Task.checkCancellation()
        return .init(today: current, history: history, metric: metric, cutoffHour: cutoffHour, calendar: calendar,
                     fullDayHistory: fullDayHistory)
    }

    func setGoal(_ value: Int) {
        preferences.goals.set(value)
        persist()
    }

    func persist(sync: Bool = true) {
        guard !isDemo else { return }
        LocalStore.save(preferences)
        writeSnapshot()
        if sync { sendSettings() }
    }

    private func sendSettings() {
        var settings = preferences
        settings.theme = effectiveTheme
        bridge.send(settings)
    }

    private func writeSnapshot() {
        guard !isDemo, preferences.healthRequested else { return }
        let history = WidgetHistory(
            days: days.filter { purchases.isPremium || $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: .now))! },
            goals: preferences.goals, includeYear: purchases.isPremium && hasLoadedWidgetHistory, now: lastUpdated ?? .now)
        let snapshot = WidgetSnapshot(updatedAt: lastUpdated ?? .now, today: today, goal: goal,
                                      week: days, theme: effectiveTheme, unit: preferences.unit, activity: widgetActivity,
                                      display: .init(counter: effectiveCounter, showEnergy: preferences.showEnergy), history: history)
        do {
            try LocalStore.save(snapshot)
            loadedSnapshot = snapshot
            WidgetCenter.shared.reloadAllTimelines()
        } catch { errorMessage = L("cache.error") }
    }

    func resetLocalData() async {
        generation += 1
        // Refuse observer callbacks already queued while HealthKit finishes stopping delivery.
        preferences.healthRequested = false
        refreshCoordinator.cancel()
        historyTask?.cancel()
        historyTask = nil
        isLoading = false
        await health.stop()
        do {
            try LocalStore.clear()
            days = []; hours = []; lastUpdated = nil; usingCache = false; loadedSnapshot = nil; widgetActivity = nil
            hasLoadedWidgetHistory = false
            recentRefreshStart = nil
            preferences = .init()
            celebration = false
            WidgetCenter.shared.reloadAllTimelines()
        } catch { errorMessage = L("reset.error") }
    }

    #if DEBUG
    private func loadDemo() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        days = (0..<1096).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: today)!
            let steps = offset == 0 ? 6432 : 3200 + ((offset * 2767 + 3171) % 10200)
            return ActivityDay(date: date, steps: steps, meters: Double(steps) * 0.72, kilocalories: Double(steps) * 0.035,
                               exerciseMinutes: Double(steps) / 180, floors: Double(steps / 650))
        }
        hours = demoHours(on: .now)
        lastUpdated = .now
    }
    #endif

    private func demoHours(on date: Date, through: Date? = nil) -> [HourActivity] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = min(through ?? ActivityPeriod.day.interval(containing: date).end, .now)
        let weights = [0, 0, 0, 0, 0, 1, 4, 9, 12, 5, 2, 6, 13, 7, 4, 5, 8, 9, 8, 5, 4, 3, 1, 0]
        guard let total = days.first(where: { calendar.isDate($0.date, inSameDayAs: date) })?.steps else { return [] }
        let dayEnd = calendar.isDateInToday(date) ? Date.now : ActivityPeriod.day.interval(containing: date).end
        let eligibleWeights = weights.enumerated().filter { offset, _ in
            calendar.date(byAdding: .hour, value: offset, to: start)! < dayEnd
        }.map(\.element).reduce(0, +)
        var result: [HourActivity] = []
        var cursor = start
        var assigned = 0
        while cursor < end {
            let next = calendar.date(byAdding: .hour, value: 1, to: cursor)!
            let hour = calendar.component(.hour, from: cursor)
            let fraction = min(1, end.timeIntervalSince(cursor) / next.timeIntervalSince(cursor))
            var steps = Int(Double(total * weights[hour]) / Double(max(1, eligibleWeights)) * fraction)
            if calendar.isDateInToday(date), next >= end { steps = max(0, total - assigned) }
            assigned += steps
            result.append(.init(date: cursor, steps: steps, meters: Double(steps) * 0.72,
                                kilocalories: Double(steps) * 0.035, exerciseMinutes: Double(steps) / 180,
                                floors: Double(steps) / 650))
            cursor = next
        }
        return result
    }
}
