import Foundation

public struct ActivityClockHour: Identifiable, Equatable, Sendable {
    public let hour: Int
    public let value: Double?
    public let hasElapsed: Bool
    public var id: Int { hour }
}

/// All values, including hourly rays and the same-time baseline, use the selected metric's units.
public struct ActivityClockSnapshot: Sendable {
    public let metric: ActivityMetric
    public let sampledAt: Date
    public let current: Double?
    public let goal: Double
    public let hours: [ActivityClockHour]
    /// Same-time reference for the live pace and its comparison percentage.
    public let usual: Double?
    /// Complete-day reference shown in both statistics card headers.
    public let usualDayTotal: Double?
    public let baselineDays: Int

    public var progress: Double? { current.flatMap { goal.isFinite && goal > 0 ? $0 / goal : nil } }
    public var usualProgress: Double? { usual.flatMap { goal.isFinite && goal > 0 ? $0 / goal : nil } }
    public var difference: Double? { current.flatMap { value in usual.map { value - $0 } } }
    public var change: Double? { difference.flatMap { value in usual.flatMap { $0 > 0 ? value / $0 : nil } } }
    public var hourlyMaximum: Double {
        let step: Double = switch metric {
        case .steps, .distance: 500
        case .energy: 25
        case .exerciseTime: 5
        case .floors: 1
        }
        return max(step, ceil((hours.compactMap(\.value).max() ?? 0) / step) * step)
    }

    public init(metric: ActivityMetric, sampledAt: Date, current: Double?, goal: Double,
                hours: [HourActivity], usual: WidgetUsualActivity?, usualDayTotal: Double? = nil,
                calendar: Calendar = .current) {
        self.metric = metric; self.sampledAt = sampledAt; self.goal = goal
        self.current = current.flatMap { $0.isFinite ? max(0, $0) : nil }
        self.usualDayTotal = usualDayTotal.flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        let clock = calendar.dateComponents([.hour, .minute, .second], from: sampledAt)
        let cutoff = Double(clock.hour ?? 0) + Double(clock.minute ?? 0) / 60 + Double(clock.second ?? 0) / 3600
        var totals: [Int: Double] = [:]
        for sample in hours where sample.date <= sampledAt && calendar.isDate(sample.date, inSameDayAs: sampledAt) {
            let hour = calendar.component(.hour, from: sample.date)
            guard Double(hour) < cutoff, let value = metric.value(in: sample), value.isFinite else { continue }
            totals[hour, default: 0] += max(0, value)
        }
        self.hours = (0..<24).map { .init(hour: $0, value: totals[$0], hasElapsed: Double($0) < cutoff) }
        if let usual, usual.baselineDays > 0, let last = usual.points.last,
           abs(last.hour - cutoff) < 1.0 / 3600, let value = last.usual, value.isFinite, value >= 0 {
            self.usual = value; baselineDays = usual.baselineDays
        } else {
            self.usual = nil; baselineDays = 0
        }
    }
}

/// A clock face folds repeated local hours together while keeping absent and future readings nil.
public struct StepClockHour: Identifiable, Equatable, Sendable {
    public let hour: Int
    public let steps: Int?
    public let hasElapsed: Bool
    public var id: Int { hour }
}

public struct StepClockSnapshot: Sendable {
    public let sampledAt: Date
    public let todaySteps: Int?
    public let goal: Int
    public let hours: [StepClockHour]
    public let usualSteps: Double?
    public let baselineDays: Int

    public var progress: Double? {
        guard let todaySteps, goal > 0 else { return nil }
        return Double(todaySteps) / Double(goal)
    }

    public var usualProgress: Double? {
        guard let usualSteps, goal > 0 else { return nil }
        return usualSteps / Double(goal)
    }

    public var difference: Double? {
        guard let todaySteps, let usualSteps else { return nil }
        return Double(todaySteps) - usualSteps
    }

    public var change: Double? {
        guard let difference, let usualSteps, usualSteps > 0 else { return nil }
        return difference / usualSteps
    }

    public var hourlyMaximum: Double {
        max(500, ceil(Double(hours.compactMap(\.steps).max() ?? 0) / 500) * 500)
    }

    public init(sampledAt: Date, todaySteps: Int?, goal: Int, hours: [HourActivity],
                usual: WidgetUsualActivity?, calendar: Calendar = .current) {
        let activity = ActivityClockSnapshot(metric: .steps, sampledAt: sampledAt, current: todaySteps.map(Double.init),
                                            goal: Double(goal), hours: hours, usual: usual, calendar: calendar)
        self.sampledAt = sampledAt; self.todaySteps = todaySteps.map { max(0, $0) }; self.goal = goal
        self.hours = activity.hours.map { .init(hour: $0.hour, steps: $0.value.map(Int.init), hasElapsed: $0.hasElapsed) }
        usualSteps = activity.usual; baselineDays = activity.baselineDays
    }
}
