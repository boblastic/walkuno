import Foundation

/// Nil is an unavailable measurement; it must never become a fabricated zero.
public struct ActivityDay: Codable, Equatable, Identifiable, Sendable {
    public var date: Date
    public var steps: Int?
    public var meters: Double?
    public var kilocalories: Double?
    public var exerciseMinutes: Double?
    public var floors: Double?
    public var id: Date { date }

    public init(date: Date, steps: Int? = nil, meters: Double? = nil, kilocalories: Double? = nil,
                exerciseMinutes: Double? = nil, floors: Double? = nil) {
        self.date = date
        self.steps = steps.map { max(0, $0) }
        self.meters = meters.map { max(0, $0) }
        self.kilocalories = kilocalories.map { max(0, $0) }
        self.exerciseMinutes = exerciseMinutes.map { max(0, $0) }
        self.floors = floors.map { max(0, $0) }
    }
}

public struct HourActivity: Codable, Identifiable, Equatable, Sendable {
    public var date: Date
    public var steps: Int?
    public var meters: Double?
    public var kilocalories: Double?
    public var exerciseMinutes: Double?
    public var floors: Double?
    public var id: Date { date }
    public init(date: Date, steps: Int?, meters: Double? = nil, kilocalories: Double? = nil,
                exerciseMinutes: Double? = nil, floors: Double? = nil) {
        self.date = date; self.steps = steps
        self.meters = meters; self.kilocalories = kilocalories
        self.exerciseMinutes = exerciseMinutes; self.floors = floors
    }
}

public enum ActivityPeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month, year
    public var id: String { rawValue }
    public func interval(containing date: Date, calendar: Calendar = .current) -> DateInterval {
        let component: Calendar.Component
        switch self {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.dateInterval(of: component, for: date)!
    }
    public func previous(_ date: Date, calendar: Calendar = .current) -> Date {
        let component: Calendar.Component
        switch self {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        case .year: component = .year
        }
        return calendar.date(byAdding: component, value: -1, to: date)!
    }
}

public struct ActivitySummary: Equatable, Sendable {
    public let total: Int?
    public let average: Int?
    public let observedDays: Int
    public let achievedDays: Int
    public let best: ActivityDay?
    public let meters: Double?

    public init(days: [ActivityDay], goals: GoalHistory, calendar: Calendar = .current) {
        let observed = days.filter { $0.steps != nil }
        observedDays = observed.count
        total = observed.isEmpty ? nil : observed.compactMap(\.steps).reduce(0, +)
        average = total.map { $0 / max(1, observed.count) }
        achievedDays = observed.filter { ($0.steps ?? 0) >= goals.value(on: $0.date, calendar: calendar) }.count
        best = observed.max { ($0.steps ?? 0) < ($1.steps ?? 0) }
        let distances = days.compactMap(\.meters)
        meters = distances.isEmpty ? nil : distances.reduce(0, +)
    }
}

public enum ActivityMath {
    public static func progress(steps: Int?, goal: Int) -> Double {
        guard let steps, goal > 0 else { return 0 }
        return max(0, Double(steps) / Double(goal))
    }

    /// No comparison is meaningful when the previous period has no data or is zero.
    public static func change(current: Int?, previous: Int?) -> Double? {
        guard let current, let previous, previous > 0 else { return nil }
        return Double(current - previous) / Double(previous)
    }

    public static func longestStreak(days: [ActivityDay], goals: GoalHistory, calendar: Calendar = .current) -> Int {
        var best = 0, running = 0
        var previous: Date?
        for day in days.sorted(by: { $0.date < $1.date }) {
            let adjacent = previous.map { calendar.dateComponents([.day], from: $0, to: day.date).day == 1 } ?? true
            if let steps = day.steps, steps >= goals.value(on: day.date, calendar: calendar) {
                running = adjacent ? running + 1 : 1
                best = max(best, running)
            } else { running = 0 }
            previous = day.date
        }
        return best
    }

    public static func days(in interval: DateInterval, available: [ActivityDay], now: Date = .now,
                            calendar: Calendar = .current) -> [ActivityDay] {
        let lookup = Dictionary(available.map { (calendar.startOfDay(for: $0.date), $0) }, uniquingKeysWith: { _, new in new })
        var result: [ActivityDay] = []
        var cursor = calendar.startOfDay(for: interval.start)
        while cursor < interval.end && cursor <= now {
            result.append(lookup[cursor] ?? ActivityDay(date: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor), next > cursor else { break }
            cursor = next
        }
        return result
    }
}
