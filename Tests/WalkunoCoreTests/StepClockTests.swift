import Foundation
import Testing
@testable import WalkunoCore

struct StepClockTests {
    @Test func displayedHabitualTotalMatchesTheDailyCardForEveryMetric() {
        let now = date("2026-11-04T09:30:00Z")
        let morning = HourActivity(date: date("2026-11-03T09:00:00Z"), steps: 200, meters: 150,
                                   kilocalories: 25, exerciseMinutes: 2.5, floors: 1)
        let evening = HourActivity(date: date("2026-11-03T18:00:00Z"), steps: 1_000, meters: 850.5,
                                   kilocalories: 100, exerciseMinutes: 20, floors: 5)
        for metric in ActivityMetric.allCases {
            let comparison = DayComparison(today: [], history: [[morning]], metric: metric,
                cutoffHour: 10.5, calendar: calendar, fullDayHistory: [[morning, evening]])
            let snapshot = ActivityClockSnapshot(metric: metric, sampledAt: now, current: metric.defaultGoal / 2,
                goal: metric.defaultGoal, hours: [], usual: .init(comparison: comparison),
                usualDayTotal: comparison.usualDayTotal, calendar: calendar)
            #expect(snapshot.usualDayTotal == comparison.usualDayTotal)
            #expect(snapshot.usualDayTotal == metric.value(in: morning)! + metric.value(in: evening)!)
            // The live pace still compares matching portions of the day.
            #expect(snapshot.usual == comparison.usual)
            #expect(snapshot.difference == metric.defaultGoal / 2 - metric.value(in: morning)!)
            #expect(snapshot.usualProgress == metric.value(in: morning)! / metric.defaultGoal)
        }
    }

    @Test func dailyReferenceRemainsDistinctFromMissingOrPartialReference() {
        let now = date("2026-11-04T09:30:00Z")
        let partialOnly = ActivityClockSnapshot(metric: .steps, sampledAt: now, current: 1_000, goal: 8_000,
            hours: [], usual: usual(200), calendar: calendar)
        #expect(partialOnly.usual == 200)
        #expect(partialOnly.usualDayTotal == nil)
        let completeOnly = ActivityClockSnapshot(metric: .steps, sampledAt: now, current: 1_000, goal: 8_000,
            hours: [], usual: nil, usualDayTotal: 9_000, calendar: calendar)
        #expect(completeOnly.usualDayTotal == 9_000)
        #expect(completeOnly.change == nil)
        let measuredZero = ActivityClockSnapshot(metric: .steps, sampledAt: now, current: 0, goal: 8_000,
            hours: [], usual: nil, usualDayTotal: 0, calendar: calendar)
        #expect(measuredZero.usualDayTotal == 0)
        for invalid in [-1, Double.infinity, Double.nan] {
            let missing = ActivityClockSnapshot(metric: .steps, sampledAt: now, current: 0, goal: 8_000,
                hours: [], usual: nil, usualDayTotal: invalid, calendar: calendar)
            #expect(missing.usualDayTotal == nil)
        }
    }

    @Test func eachMetricUsesItsOwnDailyValueHourlyRaysBaselineAndGoal() throws {
        let now = date("2026-11-04T09:30:00Z")
        let today = ActivityDay(date: now, steps: 6_432, meters: 4_631.04, kilocalories: 312.5, exerciseMinutes: 18.75, floors: 7.5)
        let sample = HourActivity(date: date("2026-11-04T09:00:00Z"), steps: 100, meters: 72.5,
                                  kilocalories: 12.5, exerciseMinutes: 1.25, floors: 0.5)
        let previous = HourActivity(date: date("2026-11-03T09:00:00Z"), steps: 200, meters: 150,
                                    kilocalories: 25, exerciseMinutes: 2.5, floors: 1)
        for metric in ActivityMetric.allCases {
            let comparison = DayComparison(today: [sample], history: [[previous]], metric: metric, cutoffHour: 10.5, calendar: calendar)
            let snapshot = ActivityClockSnapshot(metric: metric, sampledAt: now, current: metric.value(in: today),
                                                goal: metric.defaultGoal, hours: [sample], usual: .init(comparison: comparison), calendar: calendar)
            #expect(snapshot.current == metric.value(in: today))
            #expect(snapshot.hours[10].value == metric.value(in: sample))
            #expect(snapshot.usual == metric.value(in: previous))
            #expect(snapshot.goal == metric.defaultGoal)
            #expect(snapshot.progress == metric.value(in: today)! / metric.defaultGoal)
            #expect(snapshot.usualProgress == metric.value(in: previous)! / metric.defaultGoal)
            #expect(snapshot.hours[11].value == nil)
            #expect(snapshot.hourlyMaximum >= metric.value(in: sample)!)
        }
    }

    @Test func selectedMetricNeverFallsBackToStepsOrInventsMissingValues() {
        let now = date("2026-11-04T09:30:00Z")
        let sample = HourActivity(date: date("2026-11-04T09:00:00Z"), steps: 8_000)
        let missing = ActivityClockSnapshot(metric: .energy, sampledAt: now, current: nil, goal: 400,
                                            hours: [sample], usual: nil, calendar: calendar)
        #expect(missing.current == nil)
        #expect(missing.progress == nil)
        #expect(missing.hours.allSatisfy { $0.value == nil })
        let measured = ActivityClockSnapshot(metric: .exerciseTime, sampledAt: now, current: 0, goal: 30,
            hours: [.init(date: sample.date, steps: 8_000, exerciseMinutes: 0)], usual: nil, calendar: calendar)
        #expect(measured.current == 0)
        #expect(measured.progress == 0)
        #expect(measured.hours[10].value == 0)
    }

    @Test func fractionalMetricsKeepPreciseProgressAndSharedAnimationGeometry() {
        let snapshot = ActivityClockSnapshot(metric: .exerciseTime, sampledAt: date("2026-11-04T09:30:00Z"),
                                             current: 18.75, goal: 30, hours: [], usual: nil, calendar: calendar)
        #expect(snapshot.progress == 0.625)
        #expect(CounterProgress(value: 18.75, goal: 30).ratio == snapshot.progress)
        #expect(CounterProgress(value: 0.125, goal: 0.5).ratio == 0.25)
        #expect(CounterProgress(value: 1, goal: .infinity).ratio == 0)
    }

    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Paris")!
        return value
    }
    func date(_ string: String) -> Date { ISO8601DateFormatter().date(from: string)! }

    func usual(_ value: Int?, cutoff: Double = 10.5) -> WidgetUsualActivity {
        let hour = HourActivity(date: date("2026-11-03T09:00:00Z"), steps: value)
        return .init(comparison: .init(today: [], history: [[hour]], metric: .steps,
                                      cutoffHour: cutoff, calendar: calendar))
    }

    @Test func dailyCounterAndPartialHourStayIndependentOfHourlyRounding() {
        let snapshot = StepClockSnapshot(sampledAt: date("2026-11-04T09:30:00Z"), todaySteps: 126, goal: 100,
            hours: [.init(date: date("2026-11-04T08:00:00Z"), steps: 100),
                    .init(date: date("2026-11-04T09:00:00Z"), steps: 25)], usual: usual(200), calendar: calendar)
        #expect(snapshot.todaySteps == 126)
        #expect(snapshot.hours[9].steps == 100)
        #expect(snapshot.hours[10].steps == 25)
        #expect(snapshot.hours[10].hasElapsed)
        #expect(snapshot.hours[11].steps == nil)
        #expect(!snapshot.hours[11].hasElapsed)
        #expect(snapshot.progress == 1.26)
        #expect(snapshot.usualProgress == 2)
        #expect(snapshot.difference == -74)
        #expect(snapshot.change == -0.37)
    }

    @Test func unavailableIsDistinctFromMeasuredZeroAndNoPercentIsInvented() {
        let now = date("2026-11-04T09:30:00Z")
        let snapshot = StepClockSnapshot(sampledAt: now, todaySteps: 0, goal: 8000,
            hours: [.init(date: date("2026-11-04T08:00:00Z"), steps: 0)], usual: usual(0), calendar: calendar)
        #expect(snapshot.hours[9].steps == 0)
        #expect(snapshot.hours[8].steps == nil)
        #expect(snapshot.hours[8].hasElapsed)
        #expect(snapshot.usualSteps == 0)
        #expect(snapshot.difference == 0)
        #expect(snapshot.change == nil)
        let missing = StepClockSnapshot(sampledAt: now, todaySteps: nil, goal: 0,
                                        hours: [], usual: usual(nil), calendar: calendar)
        #expect(missing.todaySteps == nil)
        #expect(missing.progress == nil)
        #expect(missing.usualProgress == nil)
        #expect(missing.difference == nil)
        #expect(missing.hours.allSatisfy { $0.steps == nil })
    }

    @Test func referenceFromAnotherClockTimeIsUnavailable() {
        let snapshot = StepClockSnapshot(sampledAt: date("2026-11-04T09:30:00Z"), todaySteps: 1200,
                                        goal: 8000, hours: [], usual: usual(1000, cutoff: 10), calendar: calendar)
        #expect(snapshot.usualSteps == nil)
        #expect(snapshot.baselineDays == 0)
        #expect(snapshot.difference == nil)
    }

    @Test func oldDaysAndFutureReadingsNeverAppearOnTodaysClock() {
        let snapshot = StepClockSnapshot(sampledAt: date("2026-11-04T09:30:00Z"), todaySteps: 123,
            goal: 8000, hours: [.init(date: date("2026-11-03T09:00:00Z"), steps: 3000),
                               .init(date: date("2026-11-04T09:45:00Z"), steps: 3000),
                               .init(date: date("2026-11-04T10:00:00Z"), steps: 3000)], usual: nil, calendar: calendar)
        #expect(snapshot.hours.count == 24)
        #expect(snapshot.hours.allSatisfy { $0.steps == nil })
        #expect(snapshot.hourlyMaximum == 500)
    }

    @Test func repeatedAutumnHourIsFoldedIntoOneRayWithoutLosingSteps() {
        let snapshot = StepClockSnapshot(sampledAt: date("2026-10-25T03:00:00Z"), todaySteps: 7200, goal: 8000,
            hours: [.init(date: date("2026-10-25T00:00:00Z"), steps: 3000),
                    .init(date: date("2026-10-25T01:00:00Z"), steps: 4200)], usual: nil, calendar: calendar)
        #expect(snapshot.hours.count == 24)
        #expect(snapshot.hours[2].steps == 7200)
        #expect(snapshot.hourlyMaximum == 7500)
        #expect(snapshot.hours.compactMap(\.steps).reduce(0, +) == 7200)
    }

    @Test func springClockChangeAndMidnightDoNotFabricateActivity() {
        let spring = StepClockSnapshot(sampledAt: date("2026-03-29T02:00:00Z"), todaySteps: 200, goal: 8000,
            hours: [.init(date: date("2026-03-29T01:00:00Z"), steps: 200)], usual: nil, calendar: calendar)
        #expect(spring.hours[2].steps == nil)
        #expect(spring.hours[3].steps == 200)
        let midnight = StepClockSnapshot(sampledAt: date("2026-11-03T23:00:00Z"), todaySteps: nil, goal: 8000,
            hours: [.init(date: date("2026-11-03T23:00:00Z"), steps: 100)], usual: nil, calendar: calendar)
        #expect(midnight.hours.allSatisfy { !$0.hasElapsed && $0.steps == nil })
    }
}
