import Foundation

/// Bounded display data: two hourly profiles, a partial-day comparison and one averaged curve.
public struct WidgetActivityDetail: Codable, Equatable, Sendable {
    public var sampledAt: Date
    public var previousCutoff: Date?
    public var todayHours: [HourActivity]
    public var yesterdayHours: [HourActivity]
    public var yesterdayAtSameTime: ActivityDay
    public var usual: WidgetUsualActivity?

    public init(sampledAt: Date, previousCutoff: Date?, todayHours: [HourActivity],
                yesterdayHours: [HourActivity], yesterdayAtSameTime: ActivityDay, usual: WidgetUsualActivity? = nil) {
        self.sampledAt = sampledAt
        self.previousCutoff = previousCutoff
        self.todayHours = Array(todayHours.prefix(25))
        self.yesterdayHours = Array(yesterdayHours.prefix(25))
        self.yesterdayAtSameTime = yesterdayAtSameTime
        self.usual = usual
    }

    /// Use local clock time, not a 24-hour subtraction, including on daylight-saving transitions.
    public static func previousDayCutoff(for date: Date, calendar: Calendar = .current) -> Date? {
        guard let previous = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) else { return nil }
        return clockCutoff(on: previous, matching: date, calendar: calendar)
    }

    public static func clockCutoff(on day: Date, matching date: Date, calendar: Calendar = .current) -> Date? {
        let clock = calendar.dateComponents([.hour, .minute, .second], from: date)
        guard let cutoff = calendar.date(bySettingHour: clock.hour ?? 0, minute: clock.minute ?? 0,
                                         second: clock.second ?? 0, of: day,
                                         matchingPolicy: .nextTime, repeatedTimePolicy: .first),
              calendar.isDate(cutoff, inSameDayAs: day),
              calendar.dateComponents([.hour, .minute, .second], from: cutoff) == clock else { return nil }
        return cutoff
    }

    /// Exactly 24 consecutive clock-hour buckets, including the current partial hour.
    public func last24Hours(calendar: Calendar = .current) -> [WidgetHourBucket] {
        guard let hour = calendar.dateInterval(of: .hour, for: sampledAt)?.start else { return [] }
        let lookup = Dictionary((yesterdayHours + todayHours).map { ($0.date, $0.steps) }, uniquingKeysWith: { _, new in new })
        return (-23...0).compactMap { offset in
            guard let date = calendar.date(byAdding: .hour, value: offset, to: hour) else { return nil }
            return WidgetHourBucket(date: date, steps: lookup[date] ?? nil,
                                    isToday: calendar.isDate(date, inSameDayAs: sampledAt))
        }
    }

    public func cumulative(todaySteps: Int?, calendar: Calendar = .current) -> [DayComparisonPoint] {
        let clock = calendar.dateComponents([.hour, .minute, .second], from: sampledAt)
        let cutoff = Double(clock.hour ?? 0) + Double(clock.minute ?? 0) / 60 + Double(clock.second ?? 0) / 3600
        let current = DayComparison(today: todayHours, history: [], metric: .steps, cutoffHour: cutoff, calendar: calendar)
        let baseline = Dictionary((usual?.points ?? []).map { ($0.hour, $0.usual) }, uniquingKeysWith: { _, new in new })
        return current.points.map { point in
            // The endpoint uses the same reconciled daily total as the counter.
            DayComparisonPoint(hour: point.hour, current: point.hour == cutoff ? todaySteps.map(Double.init) : point.current,
                               usual: baseline[point.hour] ?? nil)
        }
    }

    /// Real measurements stop at the refresh time; only the historical profile extends to midnight.
    public func goalTracking(todaySteps: Int?, calendar: Calendar = .current) -> [DayComparisonPoint] {
        let observed = cumulative(todaySteps: todaySteps, calendar: calendar)
        guard let cutoff = observed.last?.hour else { return observed }
        let remaining = (usual?.dayPoints ?? []).filter { $0.hour > cutoff }
        return observed + remaining.map { .init(hour: $0.hour, current: nil, usual: $0.usual) }
    }
}

public struct WidgetHourBucket: Identifiable, Equatable, Sendable {
    public var date: Date
    public var steps: Int?
    public var isToday: Bool
    public var id: Date { date }
}

public struct WidgetUsualActivity: Codable, Equatable, Sendable {
    public var points: [DayComparisonPoint]
    public var dayPoints: [DayComparisonPoint]?
    public var baselineDays: Int

    public init(comparison: DayComparison) {
        points = Array(comparison.points.prefix(26)).map { .init(hour: $0.hour, current: nil, usual: $0.usual) }
        dayPoints = comparison.usualDayTotal == nil ? nil : Array(comparison.usualDayPoints.prefix(25))
        baselineDays = comparison.baselineDays
    }
}

public enum WidgetNumbers {
    public static func percentageChange(_ change: Double?) -> String {
        guard let change, change.isFinite else { return "—" }
        let percent = (change * 100).rounded()
        guard percent.isFinite, abs(percent) < Double(Int.max) else { return "—" }
        let sign = percent > 0 ? "+" : percent < 0 ? "−" : ""
        let magnitude = steps(Int(abs(percent)), abbreviateFrom: 1000)
        return sign + magnitude + "%"
    }

    /// A stable, narrow label even in locales whose standard compact notation is longer than “K”.
    public static func steps(_ value: Int?, abbreviateFrom threshold: Int = 10_000) -> String {
        guard let value else { return "—" }
        guard value >= threshold else { return value.formatted() }
        let divisor: Double = value >= 1_000_000 ? 1_000_000 : 1_000
        let suffix = value >= 1_000_000 ? "M" : "K"
        let rounded = (Double(value) / divisor * 10).rounded() / 10
        let number = String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        return (number.hasSuffix(".0") ? String(number.dropLast(2)) : number) + suffix
    }
}

/// Only effective, already-authorized display choices are shared with the extension.
public struct WidgetDisplayPreferences: Codable, Equatable, Sendable {
    public var counter: CounterStyle
    public var showEnergy: Bool
    public init(counter: CounterStyle = .ring, showEnergy: Bool = true) {
        self.counter = counter; self.showEnergy = showEnergy
    }
}

/// Calendar slots contain daily totals or monthly aggregates, never the full Health history.
public struct WidgetHistory: Codable, Equatable, Sendable {
    public var periods: [WidgetHistoryPeriod]
    public var monthProgress: [Double?]

    public init(days: [ActivityDay], goals: GoalHistory, includeYear: Bool,
                now: Date = .now, calendar: Calendar = .current) {
        let yearStart = calendar.dateInterval(of: .year, for: now)!.start
        let monthStart = calendar.dateInterval(of: .month, for: now)!.start
        let earliest = includeYear
            ? calendar.date(byAdding: .year, value: -1, to: yearStart)!
            : min(calendar.date(byAdding: .month, value: -1, to: monthStart)!,
                  calendar.date(byAdding: .day, value: -13, to: calendar.startOfDay(for: now))!)
        let available = days.filter { $0.date >= earliest && $0.date <= now }
        periods = ["week", "month", "year"].filter { $0 != "year" || includeYear }.map { period in
            let slots: [TrendChartSlot]
            if period == "week" {
                // Unlike the Statistics comparison, this overview includes today's partial total.
                let start = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now))!
                let previous = calendar.date(byAdding: .day, value: -7, to: start)!
                func day(_ date: Date) -> ActivityBucket {
                    .init(interval: .init(start: date, end: calendar.date(byAdding: .day, value: 1, to: date)!),
                          days: available.filter { calendar.isDate($0.date, inSameDayAs: date) })
                }
                slots = (0..<7).map { index in
                    .init(id: index, previous: day(calendar.date(byAdding: .day, value: index, to: previous)!),
                          current: day(calendar.date(byAdding: .day, value: index, to: start)!))
                }
            } else {
                slots = ActivityStatistics.trendChart(days: available, period: period == "year" ? .year : .month,
                                                     now: now, calendar: calendar)
            }
            let currentDays = slots.flatMap { $0.current?.days ?? [] }
            let previousDays = slots.flatMap { $0.previous?.days ?? [] }
            return WidgetHistoryPeriod(period: period,
                current: slots.compactMap { $0.current.map { Self.aggregate($0.days, at: $0.interval.start) } },
                previous: slots.compactMap { $0.previous.map { Self.aggregate($0.days, at: $0.interval.start) } },
                dailyAverages: slots.compactMap { $0.current.map { Self.aggregate($0.days, at: $0.interval.start, average: true) } },
                previousDailyAverages: slots.compactMap { $0.previous.map { Self.aggregate($0.days, at: $0.interval.start, average: true) } },
                average: Self.aggregate(currentDays, at: now, average: true),
                previousAverage: Self.aggregate(previousDays, at: now, average: true))
        }
        let month = periods.first { $0.period == "month" }?.current ?? []
        monthProgress = month.map { day in
            day.steps.map { ActivityMath.progress(steps: $0, goal: goals.value(on: day.date, calendar: calendar)) }
        }
    }

    private static func aggregate(_ days: [ActivityDay], at date: Date, average: Bool = false) -> ActivityDay {
        func value(_ metric: ActivityMetric) -> Double? {
            let summary = MetricSummary(days: days, metric: metric)
            return average ? summary.average : summary.total
        }
        return .init(date: date, steps: value(.steps).map { Int($0.rounded()) }, meters: value(.distance),
                     kilocalories: value(.energy), exerciseMinutes: value(.exerciseTime), floors: value(.floors))
    }
}

public struct WidgetHistoryPeriod: Codable, Equatable, Sendable {
    public var period: String
    public var current: [ActivityDay]
    public var previous: [ActivityDay]
    public var dailyAverages: [ActivityDay]
    public var previousDailyAverages: [ActivityDay]
    public var average: ActivityDay
    public var previousAverage: ActivityDay
}
