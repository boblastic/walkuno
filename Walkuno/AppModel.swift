import SwiftUI
import Observation
import WidgetKit

struct DailyActivitySnapshot {
    let metric: ActivityMetric
    let sampledAt: Date
    let today: ActivityDay
    let hours: [HourActivity]
    let comparison: DayComparison
}

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
    @ObservationIgnored let motivationWriter = MotivationWriter()

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
        purchases.onAccessChange = { [weak self] access in
            guard let self, !self.isDemo else { return }
            do { try LocalStore.save(access) }
            catch { self.errorMessage = L("cache.error") }
            self.writeSnapshot()
            self.sendSettings()
            WidgetCenter.shared.reloadAllTimelines()
        }
        bridge.onReceive = { [weak self] settings in
            guard let self, self.preferences.onboardingComplete else { return }
            self.preferences.goals.merge(settings.goals)
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

    var todayChange: Double? {
        guard let lastUpdated, Calendar.current.isDateInToday(lastUpdated) else { return nil }
        guard !usingCache || loadedSnapshot?.isCurrent() == true else { return nil }
        // Reuse the exact same-time baseline and refresh validation as the widgets.
        let snapshot = WidgetSnapshot(updatedAt: lastUpdated, today: today, goal: goal,
                                      week: [], theme: effectiveTheme, unit: preferences.unit,
                                      activity: widgetActivity)
        return snapshot.change(for: .steps)
    }

    func activityClock(metric: ActivityMetric, data: DailyActivitySnapshot?) -> ActivityClockSnapshot {
        let calendar = Calendar.current
        let sampledAt = data?.sampledAt ?? lastUpdated.flatMap { calendar.isDateInToday($0) ? $0 : nil } ?? .now
        let cached = widgetActivity.flatMap {
            $0.sampledAt == sampledAt && calendar.isDateInToday($0.sampledAt) ? $0 : nil
        }
        // Keep the measured rays visible while the shared comparison loads. The cached
        // habitual profile is steps-only and must never be reused for another metric.
        let reference = data.map { WidgetUsualActivity(comparison: $0.comparison) } ?? (metric == .steps ? cached?.usual : nil)
        return .init(metric: metric, sampledAt: sampledAt, current: metric.value(in: data?.today ?? today),
                     goal: preferences.goal(for: metric), hours: data?.hours ?? cached?.todayHours ?? (isDemo ? hours : []),
                     usual: reference, calendar: calendar)
    }

    func motivationSnapshot(at now: Date) -> MotivationSnapshot {
        // A new daily read must not be compared with an older hourly query.
        let detail = !usingCache && widgetActivity?.sampledAt == lastUpdated ? widgetActivity : nil
        return .init(days: days, goals: preferences.goals, detail: detail, now: now)
    }
    var effectiveTheme: WalkunoTheme { purchases.isPremium ? preferences.theme : .mint }
    var effectiveCounter: CounterStyle {
        preferences.counterStyle.requiresPremium && !purchases.isPremium ? .horizon : preferences.counterStyle
    }

    var effectiveEffect: CounterEffect {
        preferences.counterEffect.requiresPremium && !purchases.isPremium ? .stars : preferences.counterEffect
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

    @discardableResult
    func connectHealth() async -> HealthAuthorizationRequestOutcome? {
        guard !isDemo else { return nil }
        do {
            let outcome = try await health.authorize()
            preferences.healthRequested = true
            persist()
            observe()
            await refresh()
            return outcome
        } catch { errorMessage = L("health.connection.error") }
        return nil
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
            // Keep the current chart visible until the replacement hourly detail arrives.
            if let detail = widgetActivity, !calendar.isDate(detail.sampledAt, inSameDayAs: refreshTime) {
                widgetActivity = nil; hours = []
            }
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
                widgetActivity = nil; hours = []
                errorMessage = L("health.refresh.error")
                writeSnapshot()
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

    func dailyActivity(metric: ActivityMetric, earliest: Date?) async throws -> DailyActivitySnapshot {
        let total = today
        let calendar = Calendar.current
        let cutoff = lastUpdated.flatMap { calendar.isDateInToday($0) ? $0 : nil } ?? .now
        let clock = calendar.dateComponents([.hour, .minute, .second], from: cutoff)
        let cutoffHour = Double(clock.hour ?? 0) + Double(clock.minute ?? 0) / 60 + Double(clock.second ?? 0) / 3600
        guard isDemo || preferences.healthRequested else {
            return .init(metric: metric, sampledAt: cutoff, today: total, hours: [],
                         comparison: .init(today: [], history: [], metric: metric, cutoffHour: cutoffHour))
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
            guard let end = WidgetActivityDetail.clockCutoff(on: day.date, matching: cutoff, calendar: calendar) else { continue }
            if isDemo {
                history.append(demoHours(on: day.date, through: end))
                fullDayHistory.append(demoHours(on: day.date))
            } else {
                async let partial = health.hours(on: day.date, metric: metric, through: end, now: cutoff, calendar: calendar, strictEnd: true)
                async let complete = health.hours(on: day.date, metric: metric)
                let (partialHours, completeHours) = try await (partial, complete)
                history.append(partialHours)
                fullDayHistory.append(completeHours)
            }
        }
        try Task.checkCancellation()
        return .init(metric: metric, sampledAt: cutoff, today: total, hours: current,
                     comparison: .init(today: current, history: history, metric: metric, cutoffHour: cutoffHour,
                                       calendar: calendar, fullDayHistory: fullDayHistory))
    }

    func setGoal(_ value: Int) {
        preferences.goals.set(value)
        persist()
    }

    func setGoal(_ value: Double, for metric: ActivityMetric) {
        guard metric.acceptsGoal(value) else { return }
        if metric == .steps { preferences.goals.set(Int(value)) }
        else { preferences.activityGoals.set(value, for: metric) }
        persist()
    }

    func setGoals(_ values: [ActivityMetric: Double]) {
        guard values.allSatisfy({ $0.key.acceptsGoal($0.value) }) else { return }
        var updated = preferences
        for (metric, value) in values where preferences.goal(for: metric) != value {
            if metric == .steps { updated.goals.set(Int(value)) }
            else { updated.activityGoals.set(value, for: metric) }
        }
        preferences = updated
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
        settings.counterStyle = effectiveCounter
        settings.counterEffect = effectiveEffect
        guard purchases.hasLoadedEntitlements else { return }
        bridge.send(settings, proAccess: purchases.access)
    }

    private func writeSnapshot() {
        guard !isDemo, preferences.healthRequested else { return }
        let history = WidgetHistory(
            days: days.filter { purchases.isPremium || $0.date >= Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: .now))! },
            goals: preferences.goals, includeYear: purchases.isPremium && hasLoadedWidgetHistory, now: lastUpdated ?? .now)
        let snapshot = WidgetSnapshot(updatedAt: lastUpdated ?? .now, today: today, goal: goal,
                                      week: days, theme: effectiveTheme, unit: preferences.unit, activity: widgetActivity,
                                      display: .init(counter: effectiveCounter), history: history,
                                      activityGoals: preferences.activityGoals)
        do {
            try LocalStore.save(snapshot)
            loadedSnapshot = snapshot
            WidgetCenter.shared.reloadAllTimelines()
        } catch { errorMessage = L("cache.error") }
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
        let sampledAt = Date.now
        lastUpdated = sampledAt
        if let cutoff = WidgetActivityDetail.previousDayCutoff(for: sampledAt, calendar: calendar) {
            let partial = demoHours(on: cutoff, through: cutoff).compactMap(\.steps)
            widgetActivity = .init(sampledAt: sampledAt, previousCutoff: cutoff, todayHours: hours,
                                   yesterdayHours: demoHours(on: cutoff),
                                   yesterdayAtSameTime: .init(date: calendar.startOfDay(for: cutoff),
                                                             steps: partial.isEmpty ? nil : partial.reduce(0, +)))
        } else { widgetActivity = nil }
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
