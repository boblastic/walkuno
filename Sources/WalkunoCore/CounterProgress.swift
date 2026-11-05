import Foundation

/// Geometry shared by the counter designs. A completed extra lap stays full until
/// the next step, while the first complete objective remains visible underneath.
public struct CounterProgress: Equatable, Sendable {
    public let ratio: Double

    public init(steps: Double, goal: Int) {
        ratio = steps.isFinite && goal > 0 ? max(0, steps) / Double(goal) : 0
    }

    public var fraction: Double { min(ratio, 1) }
    public var overflowLap: Double { max(0, ceil(ratio) - 1) }
    public var overflowFraction: Double { ratio > 1 ? ratio - overflowLap : 0 }
    public var markerFraction: Double { ratio > 1 ? overflowFraction : fraction }

    public func segmentFill(_ index: Int, count: Int = 10, overflow: Bool = false) -> Double {
        guard count > 0, (0..<count).contains(index) else { return 0 }
        return min(1, max(0, (overflow ? overflowFraction : fraction) * Double(count) - Double(index)))
    }

    public func nextMilestone(goal: Int) -> Int? {
        guard goal > 0, ratio < 1 else { return nil }
        return min(goal, Int(ceil((floor(ratio * 10) + 1) * Double(goal) / 10)))
    }
}

/// A finite sweep shared by the counter and the particles emitted along its history.
/// The value settles before the last particles finish fading.
public struct CounterTrailFrame: Equatable, Sendable {
    public static let lifetime = 0.8
    public var elapsed: Double
    public var duration: Double
    public var startRatio: Double
    public var endRatio: Double

    public init(elapsed: Double, duration: Double, startRatio: Double, endRatio: Double) {
        self.elapsed = elapsed.isFinite ? max(0, elapsed) : 0
        self.duration = duration.isFinite ? max(0, duration) : 0
        self.startRatio = startRatio.isFinite ? max(0, startRatio) : 0
        self.endRatio = endRatio.isFinite ? max(0, endRatio) : 0
    }

    public var isActive: Bool {
        duration > 0 && startRatio != endRatio && elapsed < duration + Self.lifetime
    }

    public func ratio(at time: Double) -> Double {
        guard duration > 0 else { return endRatio }
        let fraction = min(1, max(0, time.isFinite ? time / duration : 1))
        let eased = fraction * fraction * (3 - 2 * fraction)
        return startRatio + (endRatio - startRatio) * eased
    }

    public func marker(at time: Double) -> Double {
        CounterProgress(steps: ratio(at: time), goal: 1).markerFraction
    }
}
