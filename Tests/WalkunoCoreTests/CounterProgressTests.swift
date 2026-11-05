import Foundation
import Testing
@testable import WalkunoCore

struct CounterProgressTests {
    @Test func emptyAndInvalidValuesNeverFillTheCounter() {
        for steps in [0, -1, Double.nan, .infinity] {
            let progress = CounterProgress(steps: steps, goal: 8000)
            #expect(progress.fraction == 0)
            #expect(progress.markerFraction == 0)
            #expect(progress.nextMilestone(goal: 8000) == 800)
        }
        #expect(CounterProgress(steps: 500, goal: 0).ratio == 0)
    }

    @Test func completedGoalsAndExtraLapsRemainVisible() {
        for (steps, lap, fraction) in [(8000.0, 0.0, 1.0), (10000, 1, 0.25), (16000, 1, 1), (18000, 2, 0.25), (24000, 2, 1)] {
            let progress = CounterProgress(steps: steps, goal: 8000)
            #expect(progress.fraction == 1)
            #expect(progress.overflowLap == lap)
            #expect(progress.markerFraction == fraction)
            #expect(progress.nextMilestone(goal: 8000) == nil)
        }
    }

    @Test func milestonesUseTheActualGoalAndPreservePartialSteps() {
        let progress = CounterProgress(steps: 6240, goal: 8000)
        #expect(progress.segmentFill(6) == 1)
        #expect(abs(progress.segmentFill(7) - 0.8) < 0.0001)
        #expect(progress.segmentFill(8) == 0)
        #expect(progress.nextMilestone(goal: 8000) == 6400)
        #expect(CounterProgress(steps: 6400, goal: 8000).nextMilestone(goal: 8000) == 7200)
        #expect(CounterProgress(steps: 801, goal: 8001).nextMilestone(goal: 8001) == 1601)
        let extra = CounterProgress(steps: 10000, goal: 8000)
        #expect(extra.segmentFill(2, overflow: true) == 0.5)
        #expect(extra.segmentFill(2) == 1)
    }

    @Test func trailStartsAtItsInitialValueAndReachesTheTargetWithoutReversing() {
        let frame = CounterTrailFrame(elapsed: 0, duration: 2, startRatio: 0, endRatio: 0.78)
        #expect(frame.ratio(at: -1) == 0)
        #expect(frame.ratio(at: 0) == 0)
        #expect(frame.isActive)

        let samples = (0...120).map { frame.ratio(at: Double($0) / 60) }
        for (previous, current) in zip(samples, samples.dropFirst()) {
            #expect(current >= previous)
            #expect(current >= 0 && current <= 0.78)
        }
        #expect(abs(frame.ratio(at: 1) - 0.39) < 0.000_001)
        #expect(frame.ratio(at: 2) == 0.78)
        #expect(frame.ratio(at: 10) == 0.78)
    }

    @Test func valueSettlesWhileTheLastStarsFadeThenTheTrailStops() {
        let duration = 1.2
        let finish = duration + CounterTrailFrame.lifetime
        for elapsed in [duration, duration + 0.4, finish - 0.001] {
            let frame = CounterTrailFrame(elapsed: elapsed, duration: duration, startRatio: 0.3, endRatio: 0.8)
            #expect(frame.isActive)
            #expect(abs(frame.ratio(at: elapsed) - 0.8) < 0.000_001)
        }
        for elapsed in [finish, finish + 0.001, 30] {
            let frame = CounterTrailFrame(elapsed: elapsed, duration: duration, startRatio: 0.3, endRatio: 0.8)
            #expect(!frame.isActive)
            #expect(abs(frame.ratio(at: elapsed) - 0.8) < 0.000_001)
        }
        #expect(!CounterTrailFrame(elapsed: 0, duration: 2, startRatio: 0.8, endRatio: 0.8).isActive)
    }

    @Test func extraLapParticlesKeepTheirBirthPositionAndCompletedEndpoint() {
        var twoLaps = CounterTrailFrame(elapsed: 1.1, duration: 2, startRatio: 0, endRatio: 2)
        #expect(twoLaps.marker(at: 1) == 1)
        #expect(twoLaps.marker(at: 0.999) > 0.99)
        #expect(twoLaps.marker(at: 1.001) < 0.01)
        #expect(twoLaps.marker(at: 2) == 1)
        let birthPosition = twoLaps.marker(at: 1.5)
        #expect(birthPosition > 0 && birthPosition < 1)
        twoLaps.elapsed = 2.4
        #expect(twoLaps.marker(at: 1.5) == birthPosition)
        #expect(twoLaps.marker(at: 2.4) == 1)

        let partialExtraLap = CounterTrailFrame(elapsed: 2, duration: 2, startRatio: 0, endRatio: 1.25)
        #expect(partialExtraLap.marker(at: 1) == 0.625)
        #expect(partialExtraLap.marker(at: 2) == 0.25)
        #expect(partialExtraLap.marker(at: 2.7) == 0.25)
    }

    @Test func liveUpdatesContinueFromTheirCurrentValueIncludingCorrections() {
        for (start, end) in [(0.65, 0.8), (1.1, 1.25), (0.8, 0.65)] {
            let frame = CounterTrailFrame(elapsed: 0, duration: 1.2, startRatio: start, endRatio: end)
            #expect(frame.ratio(at: 0) == start)
            #expect(abs(frame.ratio(at: 1.2) - end) < 0.000_001)
            let samples = (0...60).map { frame.ratio(at: Double($0) / 50) }
            for (previous, current) in zip(samples, samples.dropFirst()) {
                #expect(start < end ? current >= previous : current <= previous)
                #expect(current >= min(start, end) && current <= max(start, end))
            }
        }
    }

    @Test func invalidTrailInputsStayFiniteAndCannotLeaveAnEndlessAnimation() {
        for invalid in [-1.0, Double.nan, Double.infinity, -Double.infinity] {
            let frame = CounterTrailFrame(elapsed: invalid, duration: invalid, startRatio: invalid, endRatio: 0.75)
            #expect(frame.elapsed == 0)
            #expect(frame.duration == 0)
            #expect(frame.startRatio == 0)
            #expect(!frame.isActive)
            #expect(frame.ratio(at: invalid) == 0.75)
            #expect(frame.marker(at: invalid) == 0.75)

            let invalidTarget = CounterTrailFrame(elapsed: 0, duration: 1, startRatio: 0.5, endRatio: invalid)
            #expect(invalidTarget.endRatio == 0)
            #expect(invalidTarget.ratio(at: 1) == 0)
        }
        let valid = CounterTrailFrame(elapsed: 0, duration: 1, startRatio: 0, endRatio: 1.25)
        for invalidTime in [Double.nan, Double.infinity, -Double.infinity] {
            #expect(valid.ratio(at: invalidTime).isFinite)
            #expect((0...1).contains(valid.marker(at: invalidTime)))
        }
    }
}
