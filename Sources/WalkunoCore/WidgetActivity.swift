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
}

public struct WidgetHourBucket: Identifiable, Equatable, Sendable {
    public var date: Date
    public var steps: Int?
    public var isToday: Bool
    public var id: Date { date }
}

public struct WidgetUsualActivity: Codable, Equatable, Sendable {
    public var points: [DayComparisonPoint]
    public var baselineDays: Int

    public init(comparison: DayComparison) {
        points = Array(comparison.points.prefix(26)).map { .init(hour: $0.hour, current: nil, usual: $0.usual) }
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
