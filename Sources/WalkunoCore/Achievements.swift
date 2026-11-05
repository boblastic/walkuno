import Foundation

public struct DailyGoalAchievement: Identifiable, Sendable {
    public let multiplier: Int
    public let count: Int
    public let steps: Int?
    public let target: Int
    public var id: Int { multiplier }
    public var progress: Double { ActivityMath.progress(steps: steps, goal: target) }
}

public struct PerfectPeriodAchievement: Identifiable, Sendable {
    public let period: ActivityPeriod
    public let count: Int
    public let achievedDays: Int
    public let requiredDays: Int
    public let canComplete: Bool
    public let nextStart: Date
    public var id: String { period.rawValue }
    public var progress: Double { Double(achievedDays) / Double(max(1, requiredDays)) }
}

public struct StreakAchievement: Identifiable, Sendable {
    public let target: Int
    public let current: Int
    public let firstReached: Date?
    public var id: Int { target }
    public var progress: Double { firstReached == nil ? min(1, Double(current) / Double(target)) : 1 }
}

/// Recomputed from distinct local days: refreshes never increment a counter twice,
/// and Health corrections and dated goal changes remain authoritative.
public struct AchievementSummary: Sendable {
    public let dailyGoals: [DailyGoalAchievement]
    public let perfectPeriods: [PerfectPeriodAchievement]
    public let streaks: [StreakAchievement]
    public let currentStreak: Int
    public let longestStreak: Int
    public let totalMeters: Double?
    public let totalSteps: Int?
    public let records: [ActivityDay]

    public func record(for metric: ActivityMetric) -> ActivityDay? {
        records.filter { metric.value(in: $0) != nil }.max {
            (metric.value(in: $0) ?? 0) < (metric.value(in: $1) ?? 0)
        }
    }

    public init(days: [ActivityDay], goals: GoalHistory, now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        let lookup = Dictionary(days.filter { $0.date <= now }.map {
            (calendar.startOfDay(for: $0.date), $0)
        }, uniquingKeysWith: { _, latest in latest })
        let ordered = lookup.keys.sorted()
        records = ordered.compactMap { lookup[$0] }
        let summary = ActivitySummary(days: records, goals: goals, calendar: calendar)
        totalMeters = summary.meters
        totalSteps = summary.total
        dailyGoals = [1, 2, 3].map { multiplier in
            .init(multiplier: multiplier, count: ordered.filter { date in
                (lookup[date]?.steps ?? -1) >= goals.value(on: date, calendar: calendar) * multiplier
            }.count, steps: lookup[today]?.steps, target: goals.value(on: today, calendar: calendar) * multiplier)
        }

        func achieved(_ date: Date) -> Bool {
            guard let steps = lookup[date]?.steps else { return false }
            return steps >= goals.value(on: date, calendar: calendar)
        }
        var running = 0, best = 0
        var previous: Date?
        var reached: [Int: Date] = [:]
        for date in ordered {
            let adjacent = previous.flatMap { calendar.date(byAdding: .day, value: 1, to: $0) } == date
            running = achieved(date) ? (adjacent ? running + 1 : 1) : 0
            best = max(best, running)
            for target in [7, 15, 30] where running >= target && reached[target] == nil { reached[target] = date }
            previous = date
        }
        var cursor = achieved(today) ? today : calendar.date(byAdding: .day, value: -1, to: today)!
        var current = 0
        while achieved(cursor) {
            current += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        currentStreak = current
        longestStreak = best
        streaks = [7, 15, 30].map { .init(target: $0, current: current, firstReached: reached[$0]) }

        perfectPeriods = [ActivityPeriod.week, .month, .year].map { period in
            let interval = period.interval(containing: now, calendar: calendar)
            let required = calendar.dateComponents([.day], from: interval.start, to: interval.end).day!
            let currentDays = ordered.filter { $0 >= interval.start && $0 < interval.end && achieved($0) }.count
            let elapsed = calendar.dateComponents([.day], from: interval.start, to: today).day!
            let earlierAchieved = ordered.filter { $0 >= interval.start && $0 < today && achieved($0) }.count
            let groups = Dictionary(grouping: ordered, by: { period.interval(containing: $0, calendar: calendar).start })
            let completed = groups.filter { start, dates in
                let periodInterval = period.interval(containing: start, calendar: calendar)
                let expected = calendar.dateComponents([.day], from: start, to: periodInterval.end).day!
                return dates.count == expected && dates.allSatisfy(achieved)
            }.count
            return .init(period: period, count: completed, achievedDays: currentDays, requiredDays: required,
                         canComplete: earlierAchieved == elapsed, nextStart: interval.end)
        }
    }
}

public struct DistanceTrophy: Identifiable, Sendable {
    public let id: String
    public let meters: Double
    public let symbol: String
    public let landscape: Landscape
    public enum Landscape: Sendable { case city, trail, world, space }
    public var titleKey: String { "journey.\(id)" }

    /// Fixed reference distances keep earned multipliers stable when real routes change.
    /// References and rounding conventions: Documentation/Trophees.md.
    public static let catalog: [DistanceTrophy] = [
        .init(id: "track", meters: 400, symbol: "figure.walk", landscape: .city),
        .init(id: "goldenGate", meters: 2_737, symbol: "water.waves", landscape: .city),
        .init(id: "centralPark", meters: 9_800, symbol: "tree.fill", landscape: .city),
        .init(id: "halfMarathon", meters: 21_097.5, symbol: "flag.checkered", landscape: .city),
        .init(id: "marathon", meters: 42_195, symbol: "flag.2.crossed.fill", landscape: .city),
        .init(id: "hadrian", meters: 135_000, symbol: "building.columns.fill", landscape: .trail),
        .init(id: "montBlanc", meters: 170_000, symbol: "mountain.2.fill", landscape: .trail),
        .init(id: "gr20", meters: 200_000, symbol: "sun.haze.fill", landscape: .trail),
        .init(id: "thames", meters: 298_000, symbol: "water.waves", landscape: .trail),
        .init(id: "loire", meters: 900_000, symbol: "building.2.crop.circle.fill", landscape: .trail),
        .init(id: "francigena", meters: 3_200_000, symbol: "sun.max.fill", landscape: .trail),
        .init(id: "appalachian", meters: 3_540_000, symbol: "leaf.fill", landscape: .trail),
        .init(id: "route66", meters: 3_860_000, symbol: "road.lanes", landscape: .trail),
        .init(id: "pacificCrest", meters: 4_265_000, symbol: "mountain.2.fill", landscape: .trail),
        .init(id: "europe", meters: 12_000_000, symbol: "globe.europe.africa.fill", landscape: .world),
        .init(id: "earth", meters: 40_075_000, symbol: "globe.europe.africa.fill", landscape: .world),
        .init(id: "moon", meters: 384_400_000, symbol: "moon.stars.fill", landscape: .space),
        .init(id: "sun", meters: 149_600_000_000, symbol: "sun.max.fill", landscape: .space)
    ]

    public func progress(totalMeters: Double?) -> DistanceTrophyProgress {
        .init(totalMeters: totalMeters, targetMeters: meters)
    }
}

public struct DistanceTrophyProgress: Sendable {
    public let completed: Int
    public let cycleMeters: Double?
    public let targetMeters: Double
    public var fraction: Double { (cycleMeters ?? 0) / targetMeters }
    public init(totalMeters: Double?, targetMeters: Double) {
        precondition(targetMeters.isFinite && targetMeters > 0)
        self.targetMeters = targetMeters
        guard let totalMeters, totalMeters.isFinite, totalMeters >= 0 else {
            completed = 0; cycleMeters = nil; return
        }
        completed = Int(min(floor(totalMeters / targetMeters), Double(Int.max / 2)))
        cycleMeters = totalMeters.truncatingRemainder(dividingBy: targetMeters)
    }
}
