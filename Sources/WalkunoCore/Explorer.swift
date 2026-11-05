import Foundation

/// Everything an Explorer page renders, calculated before the page enters the viewport.
public struct ExplorerActivity: Identifiable, Sendable {
    public let anchor: Date
    public let interval: DateInterval
    public let summary: ActivitySummary
    public let previousTotal: Int?
    public let chartDays: [ActivityDay]
    public let bestMonth: Date?
    public let calendarDays: [ActivityDay]
    public let calendarOffset: Int
    public var id: Date { interval.start }

    public init(period: ActivityPeriod, anchor: Date, available: [ActivityDay], goals: GoalHistory,
                earliest: Date? = nil, now: Date = .now, calendar: Calendar = .current) {
        self.anchor = anchor
        interval = period.interval(containing: anchor, calendar: calendar)
        let earliest = earliest.map { calendar.startOfDay(for: $0) }
        let days = ActivityMath.days(in: interval, available: available, now: now, calendar: calendar)
            .filter { day in earliest.map { day.date >= $0 } ?? true }
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
        let month = ActivityPeriod.month.interval(containing: anchor, calendar: calendar)
        calendarDays = ActivityMath.days(in: month, available: available, now: now, calendar: calendar)
        calendarOffset = (calendar.component(.weekday, from: month.start) - calendar.firstWeekday + 7) % 7
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
