import Foundation

public enum ActivityMetric: String, CaseIterable, Identifiable, Sendable {
    case steps, distance, energy, exerciseTime, floors
    public var id: String { rawValue }

    public func value(in day: ActivityDay) -> Double? {
        switch self {
        case .steps: day.steps.map(Double.init)
        case .distance: day.meters
        case .energy: day.kilocalories
        case .exerciseTime: day.exerciseMinutes
        case .floors: day.floors
        }
    }

    public func value(in hour: HourActivity) -> Double? {
        switch self {
        case .steps: hour.steps.map(Double.init)
        case .distance: hour.meters
        case .energy: hour.kilocalories
        case .exerciseTime: hour.exerciseMinutes
        case .floors: hour.floors
        }
    }
}

public struct MetricSummary: Equatable, Sendable {
    public let total: Double?
    public let average: Double?
    public let observedDays: Int

    public init(days: [ActivityDay], metric: ActivityMetric) {
        let values = days.compactMap { metric.value(in: $0) }
        observedDays = values.count
        total = values.isEmpty ? nil : values.reduce(0, +)
        average = total.map { $0 / Double(values.count) }
    }
}

public struct ActivityBucket: Identifiable, Sendable {
    public let interval: DateInterval
    public let days: [ActivityDay]
    public var id: Date { interval.start }
    public func summary(for metric: ActivityMetric) -> MetricSummary { .init(days: days, metric: metric) }
}

public enum TrendPeriod: String, CaseIterable, Identifiable, Sendable {
    case sevenDays, week, month, year
    public var id: String { rawValue }
}

public struct ActivityTrend: Sendable {
    public let currentInterval: DateInterval
    public let previousInterval: DateInterval
    public let currentDays: [ActivityDay]
    public let previousDays: [ActivityDay]
    public let current: MetricSummary
    public let previous: MetricSummary
    public var difference: Double? {
        guard let current = current.average, let previous = previous.average else { return nil }
        return current - previous
    }
}

public struct WeekdayAverage: Identifiable, Sendable {
    public let weekday: Int
    public let summary: MetricSummary
    public var id: Int { weekday }
}

/// Matching calendar positions, including empty slots for dates still to come.
public struct TrendChartSlot: Identifiable, Sendable {
    public let id: Int
    public let previous: ActivityBucket?
    public let current: ActivityBucket?
}

public enum ActivityStatistics {
    /// The chart shows full calendar periods; the summary compares completed, matching spans.
    public static func trendChart(days: [ActivityDay], period: TrendPeriod,
                                  now: Date = .now, calendar: Calendar = .current) -> [TrendChartSlot] {
        let currentInterval: DateInterval
        let previousInterval: DateInterval
        if period == .sevenDays {
            let today = calendar.startOfDay(for: now)
            let start = calendar.date(byAdding: .day, value: -7, to: today)!
            currentInterval = DateInterval(start: start, end: today)
            previousInterval = DateInterval(start: calendar.date(byAdding: .day, value: -7, to: start)!, end: start)
        } else {
            let unit: ActivityPeriod = period == .year ? .year : period == .month ? .month : .week
            currentInterval = unit.interval(containing: now, calendar: calendar)
            previousInterval = unit.interval(containing: unit.previous(now, calendar: calendar), calendar: calendar)
        }
        let component: Calendar.Component = period == .year ? .month : .day
        let available = days.filter { $0.date <= now }
        func slots(in interval: DateInterval) -> [ActivityBucket] {
            var result: [ActivityBucket] = []
            var start = interval.start
            while start < interval.end {
                let end = min(calendar.date(byAdding: component, value: 1, to: start)!, interval.end)
                result.append(ActivityBucket(interval: DateInterval(start: start, end: end),
                                             days: available.filter { $0.date >= start && $0.date < end }))
                start = end
            }
            return result
        }
        let previous = slots(in: previousInterval)
        let current = slots(in: currentInterval)
        return (0..<max(previous.count, current.count)).map { index in
            TrendChartSlot(id: index, previous: index < previous.count ? previous[index] : nil,
                           current: index < current.count ? current[index] : nil)
        }
    }

    /// Only completed days are compared, with equal calendar spans. Missing days remain absent.
    public static func trend(days: [ActivityDay], metric: ActivityMetric, period: TrendPeriod,
                             now: Date = .now, calendar: Calendar = .current) -> ActivityTrend {
        let today = calendar.startOfDay(for: now)
        let currentStart: Date
        let previousStart: Date
        let previousEnd: Date
        if period == .sevenDays {
            currentStart = calendar.date(byAdding: .day, value: -7, to: today)!
            previousStart = calendar.date(byAdding: .day, value: -7, to: currentStart)!
            previousEnd = currentStart
        } else {
            let activityPeriod: ActivityPeriod = period == .week ? .week : period == .month ? .month : .year
            currentStart = activityPeriod.interval(containing: now, calendar: calendar).start
            previousStart = activityPeriod.interval(containing: activityPeriod.previous(now, calendar: calendar), calendar: calendar).start
            let elapsed = calendar.dateComponents([.day], from: currentStart, to: today).day!
            previousEnd = min(currentStart, calendar.date(byAdding: .day, value: elapsed, to: previousStart)!)
        }
        // A shorter previous month cannot be extended into the following month.
        let comparableDays = calendar.dateComponents([.day], from: previousStart, to: previousEnd).day!
        let currentEnd = min(today, calendar.date(byAdding: .day, value: comparableDays, to: currentStart)!)
        let currentInterval = DateInterval(start: currentStart, end: currentEnd)
        let previousInterval = DateInterval(start: previousStart, end: previousEnd)
        let current = days.filter { $0.date >= currentStart && $0.date < currentEnd }
        let previous = days.filter { $0.date >= previousStart && $0.date < previousEnd }
        return ActivityTrend(currentInterval: currentInterval, previousInterval: previousInterval,
                             currentDays: current, previousDays: previous,
                             current: .init(days: current, metric: metric), previous: .init(days: previous, metric: metric))
    }

    public static func buckets(days: [ActivityDay], period: ActivityPeriod, now: Date = .now,
                               calendar: Calendar = .current) -> [ActivityBucket] {
        Dictionary(grouping: days.filter { $0.date <= now }, by: { period.interval(containing: $0.date, calendar: calendar).start })
            .map { start, days in ActivityBucket(interval: period.interval(containing: start, calendar: calendar),
                                                days: days.sorted { $0.date < $1.date }) }
            .sorted { $0.id < $1.id }
    }

    public static func record(days: [ActivityDay], metric: ActivityMetric, period: ActivityPeriod,
                              now: Date = .now, calendar: Calendar = .current) -> ActivityBucket? {
        buckets(days: days, period: period, now: now, calendar: calendar)
            .filter { $0.summary(for: metric).total != nil }
            .max { ($0.summary(for: metric).total ?? 0) < ($1.summary(for: metric).total ?? 0) }
    }

    public static func weekdays(days: [ActivityDay], metric: ActivityMetric, now: Date = .now,
                                calendar: Calendar = .current) -> [WeekdayAverage] {
        let groups = Dictionary(grouping: days.filter { $0.date < calendar.startOfDay(for: now) },
                                by: { calendar.component(.weekday, from: $0.date) })
        return (0..<7).map { offset in
            let weekday = (calendar.firstWeekday - 1 + offset) % 7 + 1
            return WeekdayAverage(weekday: weekday, summary: .init(days: groups[weekday] ?? [], metric: metric))
        }
    }
}

public struct DayComparisonPoint: Codable, Equatable, Identifiable, Sendable {
    public let hour: Double
    public let current: Double?
    public let usual: Double?
    public var id: Double { hour }
}

/// Each history query ends at the same local clock time as today's query, including the partial hour.
public struct DayComparison: Sendable {
    public let points: [DayComparisonPoint]
    /// Complete historical days for the chart; same-time totals still come from `points`.
    public let usualDayPoints: [DayComparisonPoint]
    public let baselineDays: Int
    public var current: Double? { points.last?.current }
    public var usual: Double? { points.last?.usual }
    /// Average total at the end of a complete historical day.
    public var usualDayTotal: Double? { usualDayPoints.last?.usual }

    public init(today: [HourActivity], history: [[HourActivity]], metric: ActivityMetric,
                cutoffHour: Double, calendar: Calendar = .current, fullDayHistory: [[HourActivity]] = []) {
        let cutoff = min(24, max(0, cutoffHour))
        func values(_ hours: [HourActivity], through limit: Double) -> [Int: Double]? {
            let observed = hours.compactMap { hour -> (Int, Double)? in
                let clockHour = calendar.component(.hour, from: hour.date)
                guard Double(clockHour) < limit, let value = metric.value(in: hour) else { return nil }
                return (clockHour, value)
            }
            guard !observed.isEmpty else { return nil }
            return Dictionary(observed, uniquingKeysWith: +)
        }
        let currentValues = values(today, through: cutoff)
        let baseline = history.compactMap { values($0, through: cutoff) }
        baselineDays = baseline.count
        var hours = (0...Int(cutoff)).map(Double.init)
        if cutoff > (hours.last ?? 0) { hours.append(cutoff) }
        func cumulative(_ values: [Int: Double], at hour: Double) -> Double {
            values.filter { Double($0.key) < hour }.values.reduce(0, +)
        }
        points = hours.map { hour in
            DayComparisonPoint(hour: hour, current: currentValues.map { cumulative($0, at: hour) },
                               usual: baseline.isEmpty ? nil : baseline.map { cumulative($0, at: hour) }.reduce(0, +) / Double(baseline.count))
        }
        let fullBaseline = fullDayHistory.compactMap { values($0, through: 24) }
        usualDayPoints = (0...24).map { hour in
            DayComparisonPoint(hour: Double(hour), current: nil,
                               usual: fullBaseline.isEmpty ? nil : fullBaseline.map { cumulative($0, at: Double(hour)) }.reduce(0, +) / Double(fullBaseline.count))
        }
    }
}
