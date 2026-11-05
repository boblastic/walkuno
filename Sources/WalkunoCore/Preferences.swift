import Foundation

public struct GoalChange: Codable, Equatable, Sendable {
    public var effectiveDate: Date
    public var steps: Int
    public var modifiedAt: Date
    public init(effectiveDate: Date, steps: Int, modifiedAt: Date = .now) {
        self.effectiveDate = effectiveDate
        self.steps = steps
        self.modifiedAt = modifiedAt
    }
}

public struct GoalHistory: Codable, Equatable, Sendable {
    public static let defaultGoal = 8_000
    public private(set) var changes: [GoalChange]
    public init(changes: [GoalChange] = []) { self.changes = changes }

    public func value(on date: Date, calendar: Calendar = .current) -> Int {
        let day = calendar.startOfDay(for: date)
        return changes.filter { calendar.startOfDay(for: $0.effectiveDate) <= day && (500...100_000).contains($0.steps) }
            .max { $0.effectiveDate < $1.effectiveDate }?.steps ?? Self.defaultGoal
    }

    public mutating func set(_ steps: Int, on date: Date = .now, calendar: Calendar = .current, modifiedAt: Date = .now) {
        guard (500...100_000).contains(steps) else { return }
        let day = calendar.startOfDay(for: date)
        if let existing = changes.first(where: { calendar.isDate($0.effectiveDate, inSameDayAs: day) }),
           existing.modifiedAt > modifiedAt { return }
        changes.removeAll { calendar.isDate($0.effectiveDate, inSameDayAs: day) }
        changes.append(GoalChange(effectiveDate: day, steps: steps, modifiedAt: modifiedAt))
        changes.sort { $0.effectiveDate < $1.effectiveDate }
    }

    /// Used for offline Watch changes: latest edit wins for a given calendar day.
    public mutating func merge(_ other: GoalHistory, calendar: Calendar = .current) {
        for change in other.changes {
            set(change.steps, on: change.effectiveDate, calendar: calendar, modifiedAt: change.modifiedAt)
        }
    }
}

public enum WalkunoTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    // Wallkuno keeps the original "mint" identifier in preferences, Watch messages and widget snapshots.
    case mint, coral, glacier, sunshine, lime, rose, violet, indigo, turquoise
    public var id: String { rawValue }
}

public enum DistanceUnit: String, CaseIterable, Codable, Sendable {
    case kilometers, miles
    public var symbol: String { self == .kilometers ? "km" : "mi" }
    public func convert(meters: Double) -> Double { meters / (self == .kilometers ? 1_000 : 1_609.344) }
}

public enum Appearance: String, CaseIterable, Codable, Sendable { case dark, light, system }
public enum CounterStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    // Keep "minimal" on disk so existing choices become the typographic design.
    case ring, horizon, path, milestones, minimal
    public var id: String { rawValue }
    public var requiresPremium: Bool { self != .ring && self != .horizon }
}

public enum CounterEffect: String, CaseIterable, Codable, Identifiable, Sendable {
    case stars, fire, aurora, liquid
    public var id: String { rawValue }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var goals = GoalHistory()
    public var theme: WalkunoTheme = .mint
    public var unit: DistanceUnit = .kilometers
    // Retained for compatibility with saved preferences; the app always uses dark mode.
    public var appearance: Appearance = .dark
    public var counterStyle: CounterStyle = .horizon
    public var counterEffect: CounterEffect = .stars
    public var animatePeriodChanges = false
    public var showEnergy = true
    public var onboardingComplete = false
    public var healthRequested = false
    public var glassTransparency = 0.6
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case goals, theme, unit, appearance, counterStyle, counterEffect, animatePeriodChanges, showEnergy, onboardingComplete, healthRequested, glassTransparency
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        goals = try values.decode(GoalHistory.self, forKey: .goals)
        theme = try values.decode(WalkunoTheme.self, forKey: .theme)
        unit = try values.decode(DistanceUnit.self, forKey: .unit)
        appearance = try values.decode(Appearance.self, forKey: .appearance)
        counterStyle = try values.decode(CounterStyle.self, forKey: .counterStyle)
        counterEffect = (try values.decodeIfPresent(String.self, forKey: .counterEffect)).flatMap(CounterEffect.init(rawValue:)) ?? .stars
        animatePeriodChanges = try values.decodeIfPresent(Bool.self, forKey: .animatePeriodChanges) ?? false
        showEnergy = try values.decode(Bool.self, forKey: .showEnergy)
        onboardingComplete = try values.decode(Bool.self, forKey: .onboardingComplete)
        healthRequested = try values.decode(Bool.self, forKey: .healthRequested)
        // Existing installations keep their goals and preferences when the glass setting is added.
        glassTransparency = min(max(try values.decodeIfPresent(Double.self, forKey: .glassTransparency) ?? 0.6, 0), 1)
    }
}

/// A bounded display cache: recent measurements and precomputed chart summaries.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var updatedAt: Date
    public var timeZoneIdentifier: String
    public var today: ActivityDay
    public var goal: Int
    public var week: [ActivityDay]
    public var theme: WalkunoTheme
    public var unit: DistanceUnit
    public var activity: WidgetActivityDetail?
    public var display: WidgetDisplayPreferences?
    public var history: WidgetHistory?
    public init(updatedAt: Date = .now, timeZoneIdentifier: String = TimeZone.current.identifier,
                today: ActivityDay, goal: Int, week: [ActivityDay], theme: WalkunoTheme, unit: DistanceUnit,
                activity: WidgetActivityDetail? = nil, display: WidgetDisplayPreferences? = nil,
                history: WidgetHistory? = nil) {
        self.updatedAt = updatedAt; self.timeZoneIdentifier = timeZoneIdentifier
        self.today = today; self.goal = goal; self.week = Array(week.sorted { $0.date < $1.date }.suffix(7))
        self.theme = theme; self.unit = unit; self.activity = activity
        self.display = display; self.history = history
    }
    public func isCurrent(now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.isDate(today.date, inSameDayAs: now) && timeZoneIdentifier == calendar.timeZone.identifier
    }

    /// Totals and the partial previous day must come from the same refresh.
    public func change(for metric: ActivityMetric, calendar: Calendar = .current) -> Double? {
        guard timeZoneIdentifier == calendar.timeZone.identifier,
              let activity, activity.sampledAt == updatedAt,
              calendar.isDate(today.date, inSameDayAs: updatedAt),
              let cutoff = WidgetActivityDetail.previousDayCutoff(for: updatedAt, calendar: calendar),
              activity.previousCutoff == cutoff,
              calendar.isDate(activity.yesterdayAtSameTime.date, inSameDayAs: cutoff),
              let current = metric.value(in: today),
              let previous = metric.value(in: activity.yesterdayAtSameTime), previous > 0 else { return nil }
        return (current - previous) / previous
    }

    public func recentWeek(calendar: Calendar = .current) -> [ActivityDay] {
        let end = calendar.startOfDay(for: today.date)
        let start = calendar.date(byAdding: .day, value: -6, to: end)!
        return ActivityMath.days(in: DateInterval(start: start, end: calendar.date(byAdding: .day, value: 1, to: end)!),
                                 available: week + [today], now: end, calendar: calendar)
    }
}
