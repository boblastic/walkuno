import Foundation

/// Align both days by local clock hour, preserving unavailable and future measurements.
public struct DailyRhythmActivity: Sendable {
    public struct Hour: Identifiable, Sendable {
        public let hour: Int
        public let steps: Int?
        public let previousSteps: Int?
        public var id: Int { hour }
    }

    public let hours: [Hour]
    public let currentHour: Double?

    public init(date: Date, hours: [HourActivity], previousHours: [HourActivity],
                now: Date = .now, calendar: Calendar = .current) {
        func values(_ measurements: [HourActivity], on day: Date) -> [Int: Int] {
            Dictionary(measurements.compactMap { measurement in
                guard calendar.isDate(measurement.date, inSameDayAs: day), measurement.date <= now,
                      let steps = measurement.steps else { return nil }
                return (calendar.component(.hour, from: measurement.date), steps)
            }, uniquingKeysWith: +)
        }
        let current = values(hours, on: date)
        let previous = calendar.date(byAdding: .day, value: -1, to: date).map { values(previousHours, on: $0) } ?? [:]
        self.hours = (0..<24).map { .init(hour: $0, steps: current[$0], previousSteps: previous[$0]) }
        if calendar.isDate(date, inSameDayAs: now) {
            let clock = calendar.dateComponents([.hour, .minute, .second], from: now)
            currentHour = Double(clock.hour ?? 0) + Double(clock.minute ?? 0) / 60 + Double(clock.second ?? 0) / 3600
        } else { currentHour = nil }
    }
}

/// A calendar period clipped to elapsed, accessible days. Missing measurements remain nil.
public struct DashboardActivity: Sendable {
    public let interval: DateInterval
    public let days: [ActivityDay]
    public let summary: ActivitySummary
    public let goal: Int

    public var progress: Double { ActivityMath.progress(steps: summary.total, goal: goal) }
    public func total(for metric: ActivityMetric) -> Double? { MetricSummary(days: days, metric: metric).total }

    public init(period: ActivityPeriod, anchor: Date, available: [ActivityDay], goals: GoalHistory,
                earliest: Date? = nil, now: Date = .now, calendar: Calendar = .current) {
        var calendar = calendar
        calendar.firstWeekday = 2
        interval = period.interval(containing: anchor, calendar: calendar)
        days = ActivityMath.days(in: interval, available: available, now: now, calendar: calendar)
            .filter { day in earliest.map { day.date >= calendar.startOfDay(for: $0) } ?? true }
        summary = ActivitySummary(days: days, goals: goals, calendar: calendar)
        goal = days.reduce(0) { $0 + goals.value(on: $1.date, calendar: calendar) }
    }
}

/// Keep adjacent counters ready in memory before a horizontal gesture starts.
public struct DashboardPageWindow: Sendable {
    public struct Page: Identifiable, Sendable {
        public let anchor: Date
        public let activity: DashboardActivity
        public var id: Date { activity.interval.start }
    }

    public let period: ActivityPeriod
    public let previous: Page?
    public let current: Page
    public let next: Page?

    public init(period: ActivityPeriod, anchor: Date, available: [ActivityDay], goals: GoalHistory,
                earliest: Date? = nil, now: Date = .now, calendar: Calendar = .current) {
        var calendar = calendar
        calendar.firstWeekday = 2
        self.period = period
        func page(at date: Date) -> Page {
            Page(anchor: date, activity: DashboardActivity(period: period, anchor: date, available: available,
                                                         goals: goals, earliest: earliest, now: now, calendar: calendar))
        }
        current = page(at: anchor)
        if let date = ActivityMath.adjacentAnchor(to: anchor, period: period, offset: -1, now: now, calendar: calendar),
           earliest.map({ period.interval(containing: date, calendar: calendar).end > calendar.startOfDay(for: $0) }) ?? true {
            previous = page(at: date)
        } else { previous = nil }
        next = ActivityMath.adjacentAnchor(to: anchor, period: period, offset: 1, now: now, calendar: calendar).map(page)
    }

    public func page(containing date: Date, period: ActivityPeriod) -> Page? {
        guard self.period == period else { return nil }
        // DateInterval.contains includes its end; adjacent calendar pages must not overlap.
        return [previous, current, next].compactMap { $0 }.first {
            date >= $0.activity.interval.start && date < $0.activity.interval.end
        }
    }
}

/// Full calendar bounds for the home chart, with measurements limited to accessible, elapsed days.
public struct DashboardTrendActivity: Sendable {
    public struct Point: Identifiable, Sendable {
        public let date: Date
        public let steps: Double?
        public let segment: Int
        public var id: Date { date }
    }

    public let days: [ActivityDay]
    public let summary: ActivitySummary
    public let domain: ClosedRange<Date>
    public let tickDates: [Date]
    public let points: [Point]

    public init(period: ActivityPeriod, anchor: Date, available: [ActivityDay],
                earliest: Date? = nil, now: Date = .now, calendar: Calendar = .current) {
        var calendar = calendar
        calendar.firstWeekday = 2
        let interval: DateInterval
        if period == .day {
            let last = calendar.startOfDay(for: anchor)
            interval = DateInterval(start: calendar.date(byAdding: .day, value: -6, to: last)!,
                                    end: calendar.date(byAdding: .day, value: 1, to: last)!)
        } else {
            interval = period.interval(containing: anchor, calendar: calendar)
        }
        let days = ActivityMath.days(in: interval, available: available, now: now, calendar: calendar)
            .filter { day in earliest.map { day.date >= calendar.startOfDay(for: $0) } ?? true }
            .map { day in
                var day = day
                day.date = calendar.startOfDay(for: day.date)
                return day
            }
        self.days = days
        summary = ActivitySummary(days: days, goals: .init(), calendar: calendar)

        let dates: [Date]
        if period == .year {
            dates = (0..<12).map { calendar.date(byAdding: .month, value: $0, to: interval.start)! }
            tickDates = dates
        } else {
            let count = calendar.dateComponents([.day], from: interval.start, to: interval.end).day!
            dates = (0..<count).map { calendar.date(byAdding: .day, value: $0, to: interval.start)! }
            tickDates = period == .month
                ? dates.enumerated().filter { [0, 4, 9, 14, 19, 24, count - 1].contains($0.offset) }.map(\.element)
                : dates
        }
        domain = dates.first!...dates.last!

        let lookup = Dictionary(days.map { ($0.date, $0) }, uniquingKeysWith: { _, new in new })
        let months = Dictionary(grouping: days) { calendar.dateInterval(of: .month, for: $0.date)!.start }
        var segment = 0
        points = dates.map { date in
            // Monthly daily averages keep the annual curve comparable to the daily goal and mean.
            let steps = period == .year
                ? MetricSummary(days: months[date] ?? [], metric: .steps).average
                : lookup[date]?.steps.map(Double.init)
            if steps == nil { segment += 1 }
            return Point(date: date, steps: steps, segment: segment)
        }
    }
}

extension ActivityMath {
    /// Today's unfinished goal keeps yesterday's streak alive. A missing day breaks the chain.
    public static func currentStreak(days: [ActivityDay], goals: GoalHistory, endingOn date: Date,
                                     now: Date = .now, calendar: Calendar = .current) -> Int? {
        let lookup = Dictionary(days.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { _, new in new })
        var cursor = calendar.startOfDay(for: date)
        guard let steps = lookup[cursor]?.steps else { return nil }
        if steps < goals.value(on: cursor, calendar: calendar) {
            guard calendar.isDate(cursor, inSameDayAs: now),
                  let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = previous
        }
        var count = 0
        while let steps = lookup[cursor]?.steps, steps >= goals.value(on: cursor, calendar: calendar) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    /// Navigate from period boundaries so Jan 31 → February → March never skips a period.
    public static func adjacentAnchor(to anchor: Date, period: ActivityPeriod, offset: Int,
                                      now: Date = .now, calendar: Calendar = .current) -> Date? {
        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        let start = period.interval(containing: anchor, calendar: calendar).start
        guard let result = calendar.date(byAdding: component, value: offset, to: start), result <= now else { return nil }
        return result
    }
}
