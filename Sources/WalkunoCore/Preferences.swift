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
    public static let defaultGoal = 6_000
    public private(set) var changes: [GoalChange]
    public private(set) var initialGoal: Int
    public init(changes: [GoalChange] = [], initialGoal: Int = Self.defaultGoal) {
        self.changes = changes
        self.initialGoal = (500...100_000).contains(initialGoal) ? initialGoal : Self.defaultGoal
    }

    private enum CodingKeys: String, CodingKey { case changes, initialGoal }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Older installations used 8,000 before their first dated change.
        self.init(changes: try values.decode([GoalChange].self, forKey: .changes),
                  initialGoal: try values.decodeIfPresent(Int.self, forKey: .initialGoal) ?? 8_000)
    }

    public func value(on date: Date, calendar: Calendar = .current) -> Int {
        let day = calendar.startOfDay(for: date)
        return changes.filter { calendar.startOfDay(for: $0.effectiveDate) <= day && (500...100_000).contains($0.steps) }
            .max { $0.effectiveDate < $1.effectiveDate }?.steps ?? initialGoal
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
    // Walkuno keeps the original "mint" identifier in preferences, Watch messages and widget snapshots.
    case mint, coral, glacier, sunshine, lime, rose, violet, indigo, turquoise
    public var id: String { rawValue }
}

public enum DistanceUnit: String, CaseIterable, Codable, Sendable {
    case kilometers, miles
    public var symbol: String { self == .kilometers ? "km" : "mi" }
    public func convert(meters: Double) -> Double { meters / (self == .kilometers ? 1_000 : 1_609.344) }
}

public enum Appearance: String, CaseIterable, Codable, Sendable { case dark, light, system }

public enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system, english = "en", french = "fr", german = "de", spanish = "es", italian = "it", portuguese = "pt", japanese = "ja"
    public var id: String { rawValue }

    public var nativeName: String {
        switch self {
        case .system: ""
        case .english: "English"
        case .french: "Français"
        case .german: "Deutsch"
        case .spanish: "Español"
        case .italian: "Italiano"
        case .portuguese: "Português"
        case .japanese: "日本語"
        }
    }

    public func resolvedCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        guard self == .system else { return rawValue }
        for identifier in preferredLanguages {
            let code = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
            if let language = Self(rawValue: code), language != .system { return code }
        }
        return Self.english.rawValue
    }
}

public enum CounterStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    // Keep "minimal" on disk so existing choices become the typographic design.
    case horizon, ring, path, milestones, minimal
    public var id: String { rawValue }
    public var requiresPremium: Bool { self != .horizon }
}

public enum CounterEffect: String, CaseIterable, Codable, Identifiable, Sendable {
    case stars, fire, aurora, liquid
    public var id: String { rawValue }
    public var requiresPremium: Bool { self != .stars }
}

public enum StatisticsWidget: String, CaseIterable, Codable, Identifiable, Sendable {
    case dailyGoal, clock, day, trends, history, records
    public var id: String { rawValue }
}

public struct StatisticsWidgetLayout: Codable, Equatable, Sendable {
    public var order: [StatisticsWidget]
    public var hidden: Set<StatisticsWidget>
    public var visible: [StatisticsWidget] { order.filter { !hidden.contains($0) } }

    public init(order: [StatisticsWidget] = StatisticsWidget.allCases, hidden: Set<StatisticsWidget> = [.clock]) {
        var seen = Set<StatisticsWidget>()
        // Introduce the daily overview first for saved layouts, preserving existing choices.
        let suppliedOrder = order.contains(.dailyGoal) ? order : [.dailyGoal] + order
        self.order = (suppliedOrder + StatisticsWidget.allCases).filter { seen.insert($0).inserted }
        self.hidden = hidden
    }

    private enum CodingKeys: String, CodingKey { case order, hidden }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        // Ignore future identifiers without losing the other preferences after a downgrade.
        let order = try values.decodeIfPresent([String].self, forKey: .order) ?? []
        let hidden = try values.decodeIfPresent([String].self, forKey: .hidden) ?? []
        self.init(order: order.compactMap(StatisticsWidget.init(rawValue:)),
                  hidden: Set(hidden.compactMap(StatisticsWidget.init(rawValue:))))
    }
}

extension ActivityMetric {
    /// Product defaults, expressed in HealthKit's canonical units (meters, kcal, minutes).
    public var defaultGoal: Double {
        switch self {
        case .steps: Double(GoalHistory.defaultGoal)
        case .distance: 5_000
        case .energy: 500
        case .exerciseTime: 30
        case .floors: 5
        }
    }

    public var goalRange: ClosedRange<Double> {
        switch self {
        case .steps: 500...100_000
        case .distance: 100...200_000
        case .energy: 10...10_000
        case .exerciseTime: 1...1_440
        case .floors: 1...1_000
        }
    }

    public var goalIncrement: Double {
        switch self {
        case .steps, .distance: 500
        case .energy: 50
        case .exerciseTime: 5
        case .floors: 1
        }
    }

    public func acceptsGoal(_ value: Double) -> Bool {
        value.isFinite && goalRange.contains(value) && (self == .distance || value.rounded() == value)
    }
}

/// Phone-owned objectives. Steps retain their existing dated history for streaks and records.
public struct ActivityGoals: Codable, Equatable, Sendable {
    public private(set) var distance = ActivityMetric.distance.defaultGoal
    public private(set) var energy = ActivityMetric.energy.defaultGoal
    public private(set) var exerciseTime = ActivityMetric.exerciseTime.defaultGoal
    public private(set) var floors = ActivityMetric.floors.defaultGoal
    public init() {}

    public func value(for metric: ActivityMetric) -> Double {
        switch metric {
        case .steps: metric.defaultGoal
        case .distance: distance
        case .energy: energy
        case .exerciseTime: exerciseTime
        case .floors: floors
        }
    }

    public mutating func set(_ value: Double, for metric: ActivityMetric) {
        guard metric.acceptsGoal(value) else { return }
        switch metric {
        case .steps: break
        case .distance: distance = value
        case .energy: energy = value
        case .exerciseTime: exerciseTime = value
        case .floors: floors = value
        }
    }

    private enum CodingKeys: String, CodingKey { case distance, energy, exerciseTime, floors }
    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        for (key, metric): (CodingKeys, ActivityMetric) in [(.distance, .distance), (.energy, .energy),
                                                          (.exerciseTime, .exerciseTime), (.floors, .floors)] {
            if let value = try values.decodeIfPresent(Double.self, forKey: key) { set(value, for: metric) }
        }
    }
}

public struct Preferences: Codable, Equatable, Sendable {
    public var goals = GoalHistory()
    public var activityGoals = ActivityGoals()
    public var theme: WalkunoTheme = .mint
    public var unit: DistanceUnit = .kilometers
    public var language: AppLanguage = .system
    // Retained for compatibility with saved preferences; the app always uses dark mode.
    public var appearance: Appearance = .dark
    public var counterStyle: CounterStyle = .horizon
    public var counterEffect: CounterEffect = .stars
    public var onboardingComplete = false
    public var healthRequested = false
    public var glassTransparency = 0.7
    public var statisticsWidgets = StatisticsWidgetLayout()
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case goals, activityGoals, theme, unit, language, appearance, counterStyle, counterEffect, onboardingComplete, healthRequested, glassTransparency, statisticsWidgets
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        goals = try values.decode(GoalHistory.self, forKey: .goals)
        activityGoals = try values.decodeIfPresent(ActivityGoals.self, forKey: .activityGoals) ?? .init()
        theme = try values.decode(WalkunoTheme.self, forKey: .theme)
        unit = try values.decode(DistanceUnit.self, forKey: .unit)
        language = (try values.decodeIfPresent(String.self, forKey: .language)).flatMap(AppLanguage.init(rawValue:)) ?? .system
        appearance = try values.decode(Appearance.self, forKey: .appearance)
        counterStyle = try values.decode(CounterStyle.self, forKey: .counterStyle)
        counterEffect = (try values.decodeIfPresent(String.self, forKey: .counterEffect)).flatMap(CounterEffect.init(rawValue:)) ?? .stars
        onboardingComplete = try values.decode(Bool.self, forKey: .onboardingComplete)
        healthRequested = try values.decode(Bool.self, forKey: .healthRequested)
        // Existing installations keep their goals and preferences when the glass setting is added.
        glassTransparency = min(max(try values.decodeIfPresent(Double.self, forKey: .glassTransparency) ?? 0.7, 0), 1)
        statisticsWidgets = try values.decodeIfPresent(StatisticsWidgetLayout.self, forKey: .statisticsWidgets) ?? .init()
    }

    public func goal(for metric: ActivityMetric, on date: Date = .now, calendar: Calendar = .current) -> Double {
        metric == .steps ? Double(goals.value(on: date, calendar: calendar)) : activityGoals.value(for: metric)
    }
}

/// Phone-owned display settings; optional fields preserve compatibility with older companions.
public struct WatchSettings: Codable, Equatable, Sendable {
    public var goals: GoalHistory
    public var activityGoals: ActivityGoals?
    public var theme: WalkunoTheme
    public var unit: DistanceUnit
    public var counterStyle: CounterStyle?
    public var counterEffect: CounterEffect?
    public var proAccess: ProAccess?

    public init(preferences: Preferences, proAccess: ProAccess? = nil) {
        goals = preferences.goals; theme = preferences.theme; unit = preferences.unit
        activityGoals = preferences.activityGoals
        counterStyle = preferences.counterStyle; counterEffect = preferences.counterEffect
        self.proAccess = proAccess
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
    public var activityGoals: ActivityGoals?
    public init(updatedAt: Date = .now, timeZoneIdentifier: String = TimeZone.current.identifier,
                today: ActivityDay, goal: Int, week: [ActivityDay], theme: WalkunoTheme, unit: DistanceUnit,
                activity: WidgetActivityDetail? = nil, display: WidgetDisplayPreferences? = nil,
                history: WidgetHistory? = nil, activityGoals: ActivityGoals? = nil) {
        self.updatedAt = updatedAt; self.timeZoneIdentifier = timeZoneIdentifier
        self.today = today; self.goal = goal; self.week = Array(week.sorted { $0.date < $1.date }.suffix(7))
        self.theme = theme; self.unit = unit; self.activity = activity
        self.display = display; self.history = history; self.activityGoals = activityGoals
    }
    public func goal(for metric: ActivityMetric) -> Double {
        metric == .steps ? Double(goal) : (activityGoals ?? .init()).value(for: metric)
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
