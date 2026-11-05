import Foundation

public enum MotivationSituation: String, Sendable {
    case noData, starting, steady, progressing, easing, nearGoal, achieved, evening
}

public enum MotivationPace: String, Sendable { case ahead, similar, behind }

/// Facts and suggested effort are computed locally. Generated text cannot change either.
public struct MotivationSnapshot: Equatable, Sendable {
    public let day: Date
    public let todaySteps: Int?
    public let goal: Int
    public let recentDays: Int
    public let achievedDays: Int
    public let recentAverage: Int?
    public let previousDays: Int
    public let previousAverage: Int?
    public let trendPercent: Int?
    public let pace: MotivationPace?
    public let usualSteps: Int?
    public let baselineDays: Int
    public let comparedAt: Date?
    public let situation: MotivationSituation
    /// A small optional increment, never a new daily goal or a catch-up prescription.
    public let suggestedSteps: Int?
    public var remaining: Int? { todaySteps.map { max(0, goal - $0) } }

    public init(days: [ActivityDay], goals: GoalHistory, detail: WidgetActivityDetail? = nil,
                now: Date = .now, calendar: Calendar = .current) {
        let today = calendar.startOfDay(for: now)
        day = today
        let recentStart = calendar.date(byAdding: .day, value: -7, to: today)!
        let previousStart = calendar.date(byAdding: .day, value: -7, to: recentStart)!
        // One measurement per local day. Nil is not zero; future samples are excluded.
        let records = Dictionary(days.filter { $0.date <= now }.map {
            (calendar.startOfDay(for: $0.date), $0)
        }, uniquingKeysWith: { _, latest in latest }).values
        todaySteps = records.first { calendar.isDate($0.date, inSameDayAs: now) }?.steps
        goal = goals.value(on: now, calendar: calendar)
        let recent = ActivitySummary(days: records.filter { $0.date >= recentStart && $0.date < today }, goals: goals, calendar: calendar)
        let previous = ActivitySummary(days: records.filter { $0.date >= previousStart && $0.date < recentStart }, goals: goals, calendar: calendar)
        recentDays = recent.observedDays
        achievedDays = recent.achievedDays
        recentAverage = recent.average
        previousDays = previous.observedDays
        previousAverage = previous.average
        // Sparse history is insufficient to claim a change of habit.
        if recentDays >= 4, previousDays >= 4, let current = recent.average,
           let before = previous.average, before > 0 {
            trendPercent = Int(((Double(current) / Double(before) - 1) * 100).rounded())
        } else { trendPercent = nil }

        let clock = detail.map { calendar.dateComponents([.hour, .minute, .second], from: $0.sampledAt) }
        let cutoffHour = Double(clock?.hour ?? 0) + Double(clock?.minute ?? 0) / 60 + Double(clock?.second ?? 0) / 3600
        if let detail, let steps = todaySteps, calendar.isDate(detail.sampledAt, inSameDayAs: now),
           (0...7_200).contains(now.timeIntervalSince(detail.sampledAt)),
           let usual = detail.usual, usual.baselineDays >= 3,
           let endpoint = usual.points.last, abs(endpoint.hour - cutoffHour) < 1.0 / 3600,
           let reference = endpoint.usual, reference.isFinite, reference >= 0,
           reference < Double(Int.max) {
            usualSteps = Int(reference.rounded())
            baselineDays = usual.baselineDays
            comparedAt = detail.sampledAt
            let difference = Double(steps) - reference
            let tolerance = max(300, reference * 0.15)
            pace = abs(difference) <= tolerance ? .similar : difference > 0 ? .ahead : .behind
        } else {
            usualSteps = nil; baselineDays = 0; comparedAt = nil; pace = nil
        }

        let hour = calendar.component(.hour, from: now)
        if let steps = todaySteps {
            if steps >= goal { situation = .achieved }
            else if hour >= 22 || hour < 6 { situation = .evening }
            else if Double(steps) / Double(goal) >= 0.8 { situation = .nearGoal }
            else if recentDays < 3 { situation = .starting }
            else if (trendPercent ?? 0) <= -15 { situation = .easing }
            else if (trendPercent ?? 0) >= 10 { situation = .progressing }
            else if recentDays >= 4 && achievedDays <= 1 { situation = .easing }
            else { situation = .steady }
        } else { situation = .noData }

        if let steps = todaySteps, steps < goal, situation != .evening {
            suggestedSteps = min(goal - steps, situation == .easing ? 500 : 1_000)
        } else { suggestedSteps = nil }
    }

    /// Cache only the wording: facts remain live even within the same step band.
    public func wordingKey(locale: String, now: Date, calendar: Calendar = .current) -> MotivationWordingKey {
        .init(day: day, timeZone: calendar.timeZone.identifier, locale: locale,
              timeSlot: calendar.component(.hour, from: now) / 6,
              situation: situation, pace: pace, goal: goal, stepBand: (todaySteps ?? 0) / 500,
              recentDays: recentDays, achievedDays: achievedDays, trendPercent: trendPercent)
    }
}

public struct MotivationWordingKey: Equatable, Sendable {
    public let day: Date
    public let timeZone: String
    public let locale: String
    public let timeSlot: Int
    public let situation: MotivationSituation
    public let pace: MotivationPace?
    public let goal: Int
    public let stepBand: Int
    public let recentDays: Int
    public let achievedDays: Int
    public let trendPercent: Int?
}

public enum MotivationTextValidation {
    /// Plain, short encouragement only. Measurements and actions are rendered separately.
    public static func accepted(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = text.lowercased()
        guard (12...180).contains(text.count),
              !text.contains(where: { $0.wholeNumberValue != nil }),
              text.rangeOfCharacter(from: .controlCharacters) == nil,
              !lower.contains("http"), !lower.contains("www."),
              !text.contains(where: { "*#[]<>@:".contains($0) }) else { return nil }
        let endings = text.filter { ".!?。！？".contains($0) }.count
        return endings <= 1 ? text : nil
    }
}
