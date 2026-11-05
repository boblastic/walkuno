import Foundation
import Testing
@testable import WalkunoCore

struct StatisticsTests {
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Paris")!
        value.firstWeekday = 2
        value.minimumDaysInFirstWeek = 4
        return value
    }
    func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    func day(_ value: String, steps: Int? = nil, meters: Double? = nil) -> ActivityDay {
        .init(date: calendar.startOfDay(for: date(value + "T12:00:00Z")), steps: steps, meters: meters)
    }

    @Test func metricCoverageIsIndependentAndMissingIsNotZero() {
        let days = [day("2026-10-01", steps: 9000), day("2026-10-02", meters: 1200), day("2026-10-03", meters: 0)]
        let summary = MetricSummary(days: days, metric: .distance)
        #expect(summary.total == 1200)
        #expect(summary.average == 600)
        #expect(summary.observedDays == 2)
        #expect(MetricSummary(days: days, metric: .energy).total == nil)
        #expect(MetricSummary(days: days, metric: .steps).average == 9000)
    }

    @Test func oldCachesDecodeWithoutAdditionalMetrics() throws {
        let data = Data(#"{"date":0,"steps":5000,"meters":3200}"#.utf8)
        let decoded = try JSONDecoder().decode(ActivityDay.self, from: data)
        #expect(decoded.steps == 5000)
        #expect(decoded.exerciseMinutes == nil)
        #expect(decoded.floors == nil)
        let encoded = try JSONEncoder().encode(ActivityDay(date: .now, exerciseMinutes: 32, floors: 8))
        #expect(try JSONDecoder().decode(ActivityDay.self, from: encoded).floors == 8)
    }

    @Test func weekdayProfileUsesObservedCompletedDays() {
        let days = [day("2026-10-26", steps: 1000), day("2026-11-02", steps: 3000),
                    day("2026-10-27"), day("2026-11-03", steps: 0), day("2026-11-04", steps: 100000)]
        let profile = ActivityStatistics.weekdays(days: days, metric: .steps, now: date("2026-11-04T12:00:00Z"), calendar: calendar)
        #expect(profile.map(\.weekday) == [2, 3, 4, 5, 6, 7, 1])
        #expect(profile[0].summary.average == 2000)
        #expect(profile[0].summary.observedDays == 2)
        #expect(profile[1].summary.average == 0)
        #expect(profile[2].summary.average == nil)
    }

    @Test func trendExcludesTodayAndComparesMatchingWeekPortions() {
        let days = [day("2026-10-26", steps: 1000), day("2026-10-27", steps: 3000),
                    day("2026-10-28", steps: 100000), day("2026-11-02", steps: 3000),
                    day("2026-11-03", steps: 5000), day("2026-11-04", steps: 100000)]
        let trend = ActivityStatistics.trend(days: days, metric: .steps, period: .week,
                                             now: date("2026-11-04T12:00:00Z"), calendar: calendar)
        #expect(trend.current.average == 4000)
        #expect(trend.previous.average == 2000)
        #expect(trend.difference == 2000)
        #expect(trend.currentDays.count == 2)
        #expect(trend.previousDays.count == 2)
    }

    @Test func previousMonthDoesNotSpillIntoCurrentMonth() {
        let trend = ActivityStatistics.trend(days: [], metric: .steps, period: .month,
                                             now: date("2026-03-31T12:00:00Z"), calendar: calendar)
        #expect(calendar.dateComponents([.day], from: trend.previousInterval.start, to: trend.previousInterval.end).day == 28)
        #expect(calendar.dateComponents([.day], from: trend.currentInterval.start, to: trend.currentInterval.end).day == 28)
        #expect(calendar.component(.month, from: trend.previousInterval.end) == 3)
        #expect(trend.current.average == nil)
        #expect(trend.difference == nil)
    }

    @Test func rollingDaysRespectDaylightSavingAndRestrictedHistory() {
        let now = date("2026-10-27T12:00:00Z")
        let days = [day("2026-10-26", steps: 8000)] // The preceding period is outside accessible history.
        let trend = ActivityStatistics.trend(days: days, metric: .steps, period: .sevenDays, now: now, calendar: calendar)
        #expect(trend.currentInterval.duration == 169 * 3600)
        #expect(trend.current.average == 8000)
        #expect(trend.previous.average == nil)
        #expect(trend.difference == nil)
        #expect(calendar.dateComponents([.day], from: trend.previousInterval.start, to: trend.previousInterval.end).day == 7)
    }

    @Test func beginningOfWeekHasNoCompletedDaysToCompare() {
        let trend = ActivityStatistics.trend(days: [day("2026-11-02", steps: 7000)], metric: .steps, period: .week,
                                             now: date("2026-11-02T12:00:00Z"), calendar: calendar)
        #expect(trend.currentInterval.duration == 0)
        #expect(trend.previousInterval.duration == 0)
        #expect(trend.current.total == nil)
    }

    @Test func recordsUseSelectedMetricAndIgnoreFutureDays() {
        let days = [day("2024-07-01", steps: 10000, meters: 4000), day("2025-07-01", steps: 5000, meters: 6000),
                    day("2027-07-01", steps: 1000000, meters: 1000000)]
        let now = date("2026-11-04T12:00:00Z")
        let steps = ActivityStatistics.record(days: days, metric: .steps, period: .year, now: now, calendar: calendar)
        let distance = ActivityStatistics.record(days: days, metric: .distance, period: .year, now: now, calendar: calendar)
        #expect(steps.map { calendar.component(.year, from: $0.id) } == 2024)
        #expect(distance.map { calendar.component(.year, from: $0.id) } == 2025)
        #expect(ActivityStatistics.record(days: days, metric: .floors, period: .year, now: now, calendar: calendar) == nil)
    }

    @Test func weeklyBucketsRespectWeekAcrossNewYear() {
        let days = [day("2025-12-31", steps: 1000), day("2026-01-01", steps: 2000)]
        let buckets = ActivityStatistics.buckets(days: days, period: .week, now: date("2026-11-04T12:00:00Z"), calendar: calendar)
        #expect(buckets.count == 1)
        #expect(buckets.first?.summary(for: .steps).total == 3000)
    }

    @Test func dayComparisonKeepsExactPartialHourAndExcludesUnavailableBaselines() {
        let now = date("2026-11-04T09:30:00Z") // 10:30 local.
        let today = [HourActivity(date: date("2026-11-04T08:00:00Z"), steps: 100),
                     HourActivity(date: date("2026-11-04T09:00:00Z"), steps: 25)]
        let previous = [HourActivity(date: date("2026-11-03T08:00:00Z"), steps: 200),
                        HourActivity(date: date("2026-11-03T09:00:00Z"), steps: 50)]
        let missing = [HourActivity(date: now, steps: nil)]
        let comparison = DayComparison(today: today, history: [previous, missing], metric: .steps, cutoffHour: 10.5, calendar: calendar)
        #expect(comparison.current == 125)
        #expect(comparison.usual == 250)
        #expect(comparison.baselineDays == 1)
        #expect(comparison.points.last?.hour == 10.5)
        #expect(comparison.points.first(where: { $0.hour == 10 })?.current == 100)
        let unavailable = DayComparison(today: [], history: [], metric: .steps, cutoffHour: 10.5, calendar: calendar)
        #expect(unavailable.current == nil)
        #expect(unavailable.usual == nil)
    }

    @Test func repeatedHourIsCountedOncePerSampleDuringClockChange() {
        let hours = [HourActivity(date: date("2026-10-25T00:00:00Z"), steps: 100),
                     HourActivity(date: date("2026-10-25T01:00:00Z"), steps: 200)]
        let comparison = DayComparison(today: hours, history: [], metric: .steps, cutoffHour: 4, calendar: calendar)
        #expect(comparison.current == 300)
        #expect(comparison.points.first(where: { $0.hour == 3 })?.current == 300)
    }
}
