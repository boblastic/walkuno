import Foundation

/// Everything an Explorer page renders, calculated before the page enters the viewport.
public struct ExplorerActivity: Identifiable, Sendable {
    public let anchor: Date
    public let interval: DateInterval
    public let summary: ActivitySummary
    public let days: [ActivityDay]
    public let previousTotal: Int?
    public let chartDays: [ActivityDay]
    public let bestMonth: Date?
    public let calendarDays: [ActivityDay]
    public let calendarOffset: Int
    public let calendarMonths: [Month]
    public var id: Date { interval.start }

    public struct Month: Identifiable, Sendable {
        public let date: Date
        public let summary: ActivitySummary
        public let progress: Double?
        public var id: Date { date }
    }

    public func total(for metric: ActivityMetric) -> Double? { MetricSummary(days: days, metric: metric).total }

    public init(period: ActivityPeriod, anchor: Date, available: [ActivityDay], goals: GoalHistory,
                earliest: Date? = nil, now: Date = .now, calendar: Calendar = .current) {
        var calendar = calendar
        if period == .week { calendar.firstWeekday = 2 }
        self.anchor = anchor
        let interval = period.interval(containing: anchor, calendar: calendar)
        self.interval = interval
        let earliest = earliest.map { calendar.startOfDay(for: $0) }
        let days = ActivityMath.days(in: interval, available: available, now: now, calendar: calendar)
            .filter { day in earliest.map { day.date >= $0 } ?? true }
        self.days = days
        summary = ActivitySummary(days: days, goals: goals, calendar: calendar)
        let previousStart = period.interval(containing: period.previous(anchor, calendar: calendar), calendar: calendar).start
        let previousEnd = calendar.date(byAdding: .day, value: days.count, to: previousStart)!
        previousTotal = earliest.map { previousStart < $0 } == true ? nil : ActivitySummary(
            days: available.filter { $0.date >= previousStart && $0.date < previousEnd }, goals: goals, calendar: calendar).total
        let months = Dictionary(grouping: days) { calendar.dateInterval(of: .month, for: $0.date)!.start }
            .map { start, days in ActivityDay(date: start, steps: ActivitySummary(days: days, goals: goals, calendar: calendar).total) }
            .sorted { $0.date < $1.date }
        chartDays = period == .year ? months : days
        bestMonth = months.filter { $0.steps != nil }.max { ($0.steps ?? 0) < ($1.steps ?? 0) }?.date
        let calendarInterval = period == .week ? interval : ActivityPeriod.month.interval(containing: anchor, calendar: calendar)
        // A week always contains Monday through Sunday, including neutral future cells.
        calendarDays = ActivityMath.days(in: calendarInterval, available: available,
                                         now: period == .week ? calendarInterval.end.addingTimeInterval(-1) : now, calendar: calendar)
            .map { $0.date > now ? ActivityDay(date: $0.date) : $0 }
        calendarOffset = period == .week ? 0 : (calendar.component(.weekday, from: calendarInterval.start) - calendar.firstWeekday + 7) % 7
        calendarMonths = period == .year ? (0..<12).map { offset in
            let date = calendar.date(byAdding: .month, value: offset, to: interval.start)!
            let monthDays = days.filter { calendar.isDate($0.date, equalTo: date, toGranularity: .month) }
            let summary = ActivitySummary(days: monthDays, goals: goals, calendar: calendar)
            // Use historical goals only for observed days; unavailable and future days have no score.
            let goal = monthDays.filter { $0.steps != nil }.reduce(0) { $0 + goals.value(on: $1.date, calendar: calendar) }
            return Month(date: date, summary: summary,
                         progress: summary.total.flatMap { goal > 0 ? Double($0) / Double(goal) : nil })
        } : []
    }
}

/// Real local hours, including 23/25-hour days, with unavailable values preserved as nil.
public struct ExplorerHourlyActivity: Sendable {
    public let interval: DateInterval
    public let hours: [HourActivity]

    public init(date: Date, available: [HourActivity], now: Date = .now, calendar: Calendar = .current) {
        let interval = ActivityPeriod.day.interval(containing: date, calendar: calendar)
        self.interval = interval
        let values = Dictionary(available.filter { $0.date >= interval.start && $0.date < interval.end && $0.date <= now }
            .map { (calendar.dateInterval(of: .hour, for: $0.date)!.start, $0.steps) }, uniquingKeysWith: { _, new in new })
        var hours: [HourActivity] = []
        var cursor = interval.start
        while cursor < interval.end {
            hours.append(HourActivity(date: cursor, steps: cursor <= now ? values[cursor] ?? nil : nil))
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        self.hours = hours
    }
}

/// A bounded, reusable window: only the newly exposed neighbor needs calculating after a swipe.
/// Reuse only when measurements, goals, access, the current day and calendar haven't changed.
public struct ExplorerPageWindow: Sendable {
    public let period: ActivityPeriod
    public let previous: ExplorerActivity?
    public let current: ExplorerActivity
    public let next: ExplorerActivity?

    public init(period: ActivityPeriod, anchor: Date, available: [ActivityDay], goals: GoalHistory,
                earliest: Date? = nil, now: Date = .now, calendar: Calendar = .current,
                reusing window: ExplorerPageWindow? = nil) {
        var calendar = calendar
        if period == .week { calendar.firstWeekday = 2 }
        self.period = period
        func page(at date: Date) -> ExplorerActivity {
            let start = period.interval(containing: date, calendar: calendar).start
            if window?.period == period,
               let cached = [window?.previous, window?.current, window?.next].compactMap({ $0 }).first(where: { $0.id == start }) {
                return cached
            }
            return ExplorerActivity(period: period, anchor: date, available: available, goals: goals,
                                    earliest: earliest, now: now, calendar: calendar)
        }
        current = page(at: anchor)
        if let date = ActivityMath.adjacentAnchor(to: anchor, period: period, offset: -1, now: now, calendar: calendar),
           earliest.map({ period.interval(containing: date, calendar: calendar).end > calendar.startOfDay(for: $0) }) ?? true {
            previous = page(at: date)
        } else { previous = nil }
        next = ActivityMath.adjacentAnchor(to: anchor, period: period, offset: 1, now: now, calendar: calendar).map(page)
    }
}
