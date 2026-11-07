import Foundation
import Testing
@testable import WalkunoCore

struct DailyRhythmTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    @Test func fullDayKeepsFutureAndMissingHoursUnavailable() {
        let now = date("2026-11-05T12:30:00Z")
        let rhythm = DailyRhythmActivity(date: now, hours: [
            .init(date: date("2026-11-05T07:00:00Z"), steps: 0),
            .init(date: date("2026-11-05T12:00:00Z"), steps: 120),
            .init(date: date("2026-11-05T13:00:00Z"), steps: 999)
        ], previousHours: [
            .init(date: date("2026-11-04T12:00:00Z"), steps: 240),
            .init(date: date("2026-11-04T22:00:00Z"), steps: 80)
        ], now: now, calendar: calendar)
        #expect(rhythm.hours.map(\.hour) == Array(0..<24))
        #expect(rhythm.hours[8].steps == 0)
        #expect(rhythm.hours[9].steps == nil)
        #expect(rhythm.hours[13].steps == 120)
        #expect(rhythm.hours[13].previousSteps == 240)
        #expect(rhythm.hours[14].steps == nil)
        #expect(rhythm.hours[23].previousSteps == 80)
        #expect(rhythm.currentHour == 13.5)
    }

    @Test func historicalSelectionUsesItsOwnPreviousDayAndHasNoNowMarker() {
        let selected = date("2026-11-03T12:00:00Z")
        let rhythm = DailyRhythmActivity(date: selected, hours: [], previousHours: [
            .init(date: date("2026-11-02T09:00:00Z"), steps: 400),
            .init(date: date("2026-11-04T09:00:00Z"), steps: 999)
        ], now: date("2026-11-05T12:00:00Z"), calendar: calendar)
        #expect(rhythm.hours[10].previousSteps == 400)
        #expect(rhythm.hours.allSatisfy { $0.steps == nil })
        #expect(rhythm.currentHour == nil)
    }

    @Test func repeatedClockHourCombinesMeasurementsAcrossAutumnTimeChange() {
        let now = date("2026-10-26T12:00:00Z")
        let rhythm = DailyRhythmActivity(date: now, hours: [], previousHours: [
            .init(date: date("2026-10-25T00:00:00Z"), steps: 120),
            .init(date: date("2026-10-25T01:00:00Z"), steps: 180)
        ], now: now, calendar: calendar)
        #expect(rhythm.hours.count == 24)
        #expect(rhythm.hours[2].previousSteps == 300)
        #expect(rhythm.hours[3].previousSteps == nil)
    }

    @Test func skippedClockHourRemainsUnavailableAcrossSpringTimeChange() {
        let now = date("2026-03-30T12:00:00Z")
        let rhythm = DailyRhythmActivity(date: now, hours: [], previousHours: [
            .init(date: date("2026-03-29T00:00:00Z"), steps: 100),
            .init(date: date("2026-03-29T01:00:00Z"), steps: 200)
        ], now: now, calendar: calendar)
        #expect(rhythm.hours[1].previousSteps == 100)
        #expect(rhythm.hours[2].previousSteps == nil)
        #expect(rhythm.hours[3].previousSteps == 200)
    }
}

struct DashboardTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.firstWeekday = 2
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    @Test func adjacentCountersArePreparedForEveryPeriod() throws {
        let now = date("2026-11-05T12:00:00Z")
        let anchor = date("2025-09-15T12:00:00Z")
        let days: [ActivityDay] = (0..<800).map { offset in
            .init(date: calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!,
                  steps: offset % 9 == 0 ? nil : offset * 30, meters: Double(offset * 20))
        }
        var goals = GoalHistory()
        goals.set(6_000, on: date("2025-09-01T12:00:00Z"), calendar: calendar)
        for period in ActivityPeriod.allCases {
            let window = DashboardPageWindow(period: period, anchor: anchor, available: days, goals: goals, now: now, calendar: calendar)
            let previous = try #require(window.previous)
            let next = try #require(window.next)
            #expect(previous.activity.interval.end == window.current.activity.interval.start)
            #expect(window.current.activity.interval.end == next.activity.interval.start)
            for page in [previous, window.current, next] {
                let expected = DashboardActivity(period: period, anchor: page.anchor, available: days, goals: goals, now: now, calendar: calendar)
                #expect(page.activity.days == expected.days)
                #expect(page.activity.summary.total == expected.summary.total)
                #expect(page.activity.goal == expected.goal)
                #expect(window.page(containing: page.activity.interval.start, period: period)?.id == page.id)
            }
        }
    }

    @Test func preparedCountersRespectFreeHistoryAndBlockFuture() throws {
        let now = date("2026-11-05T12:00:00Z")
        let earliest = calendar.startOfDay(for: date("2026-10-06T12:00:00Z"))
        let boundary = DashboardPageWindow(period: .day, anchor: earliest, available: [], goals: .init(), earliest: earliest, now: now, calendar: calendar)
        #expect(boundary.previous == nil)
        #expect(boundary.current.activity.summary.total == nil)
        #expect(boundary.next != nil)
        for period in ActivityPeriod.allCases {
            let window = DashboardPageWindow(period: period, anchor: now, available: [], goals: .init(), earliest: earliest, now: now, calendar: calendar)
            #expect(window.next == nil)
            #expect(window.current.activity.days.allSatisfy { $0.date >= earliest && $0.date <= now })
        }
        let premium = DashboardPageWindow(period: .day, anchor: earliest, available: [], goals: .init(), now: now, calendar: calendar)
        #expect(premium.previous != nil)
    }

    @Test func preparingAgainUsesCorrectedMeasurementsAndGoals() throws {
        let now = date("2026-11-05T12:00:00Z")
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let old = DashboardPageWindow(period: .day, anchor: now, available: [], goals: .init(), now: now, calendar: calendar)
        var goals = GoalHistory()
        goals.set(5_000, on: yesterday, calendar: calendar)
        let updated = DashboardPageWindow(period: .day, anchor: now, available: [.init(date: yesterday, steps: 0)], goals: goals, now: now, calendar: calendar)
        #expect(old.previous?.activity.summary.total == nil)
        #expect(updated.previous?.activity.summary.total == 0)
        #expect(updated.previous?.activity.goal == 5_000)
    }

    @Test func preparedDayHandlesDaylightSaving() throws {
        let now = date("2026-10-26T12:00:00Z")
        let window = DashboardPageWindow(period: .day, anchor: now, available: [], goals: .init(), now: now, calendar: calendar)
        let previous = try #require(window.previous)
        #expect(previous.activity.interval.duration == 25 * 3_600)
        #expect(previous.activity.interval.end == window.current.activity.interval.start)
    }

    @Test func weeklyTotalsUseElapsedDaysAndHistoricalGoals() {
        let monday = date("2026-11-02T12:00:00Z")
        let tuesday = date("2026-11-03T12:00:00Z")
        let now = date("2026-11-04T12:00:00Z")
        var goals = GoalHistory()
        goals.set(5_000, on: monday, calendar: calendar)
        goals.set(10_000, on: now, calendar: calendar)
        let activity = DashboardActivity(period: .week, anchor: now, available: [
            .init(date: monday, steps: 6_000, meters: 4_000, kilocalories: 200, exerciseMinutes: 30, floors: 4),
            .init(date: tuesday, steps: 0, meters: 0, kilocalories: 0, exerciseMinutes: 0, floors: 0),
            .init(date: now, steps: 4_000, meters: 3_000, kilocalories: 150, exerciseMinutes: 20, floors: 2)
        ], goals: goals, now: now, calendar: calendar)
        #expect(activity.days.count == 3)
        #expect(activity.goal == 20_000)
        #expect(activity.summary.total == 10_000)
        #expect(activity.summary.achievedDays == 1)
        #expect(activity.total(for: .distance) == 7_000)
        #expect(activity.total(for: .energy) == 350)
        #expect(activity.total(for: .exerciseTime) == 50)
        #expect(activity.total(for: .floors) == 6)
        #expect(activity.progress == 0.5)
    }

    @Test func missingMetricsStayUnavailableAndZeroStaysMeasured() {
        let now = date("2026-11-04T12:00:00Z")
        let empty = DashboardActivity(period: .day, anchor: now, available: [], goals: .init(), now: now, calendar: calendar)
        #expect(empty.summary.total == nil)
        #expect(empty.total(for: .exerciseTime) == nil)
        #expect(empty.total(for: .floors) == nil)
        let zero = DashboardActivity(period: .day, anchor: now, available: [.init(date: now, steps: 0, floors: 0)],
                                     goals: .init(), now: now, calendar: calendar)
        #expect(zero.summary.total == 0)
        #expect(zero.total(for: .floors) == 0)
        #expect(zero.total(for: .exerciseTime) == nil)
    }

    @Test func monthlyTotalsRespectAccessBoundary() {
        let now = date("2026-11-04T12:00:00Z")
        let first = date("2026-10-01T12:00:00Z")
        let earliest = date("2026-10-05T12:00:00Z")
        let activity = DashboardActivity(period: .month, anchor: first, available: [
            .init(date: first, steps: 100_000), .init(date: earliest, steps: 4_000)
        ], goals: .init(), earliest: earliest, now: now, calendar: calendar)
        #expect(activity.days.count == 27)
        #expect(activity.summary.total == 4_000)
        #expect(activity.goal == 27 * 8_000)
    }

    @Test func navigationHandlesMonthEndsAndBlocksFuturePeriods() {
        let now = date("2026-03-31T12:00:00Z")
        let february = ActivityMath.adjacentAnchor(to: now, period: .month, offset: -1, now: now, calendar: calendar)!
        #expect(calendar.component(.month, from: february) == 2)
        let march = ActivityMath.adjacentAnchor(to: february, period: .month, offset: 1, now: now, calendar: calendar)!
        #expect(calendar.component(.month, from: march) == 3)
        #expect(ActivityMath.adjacentAnchor(to: now, period: .day, offset: 1, now: now, calendar: calendar) == nil)
        #expect(ActivityMath.adjacentAnchor(to: now, period: .month, offset: 1, now: now, calendar: calendar) == nil)
    }

    @Test func dailyNavigationUsesCalendarAcrossDaylightSaving() {
        let now = date("2026-10-26T12:00:00Z")
        let previous = ActivityMath.adjacentAnchor(to: now, period: .day, offset: -1, now: now, calendar: calendar)!
        #expect(calendar.component(.day, from: previous) == 25)
        #expect(calendar.startOfDay(for: now).timeIntervalSince(previous) == 25 * 3_600)
    }

    @Test func streakKeepsTodayOpenButStopsAtMissingDays() {
        let now = date("2026-11-04T12:00:00Z")
        let yesterday = date("2026-11-03T12:00:00Z")
        let before = date("2026-11-02T12:00:00Z")
        let rows: [ActivityDay] = [.init(date: before, steps: 9_000), .init(date: yesterday, steps: 9_000), .init(date: now, steps: 3_000)]
        #expect(ActivityMath.currentStreak(days: rows, goals: .init(), endingOn: now, now: now, calendar: calendar) == 2)
        #expect(ActivityMath.currentStreak(days: rows, goals: .init(), endingOn: before, now: now, calendar: calendar) == 1)
        #expect(ActivityMath.currentStreak(days: [rows[1], rows[2]], goals: .init(), endingOn: now, now: now, calendar: calendar) == 1)
        #expect(ActivityMath.currentStreak(days: [], goals: .init(), endingOn: now, now: now, calendar: calendar) == nil)
        #expect(ActivityMath.currentStreak(days: [.init(date: yesterday, steps: 0)], goals: .init(), endingOn: yesterday, now: now, calendar: calendar) == 0)
    }

    @Test func currentStreakPreservesYesterdayUntilTodaysGoalIsReached() {
        let yesterday = date("2026-11-03T12:00:00Z")
        let today = date("2026-11-04T12:00:00Z")
        let tomorrow = date("2026-11-05T12:00:00Z")
        let history: [ActivityDay] = [.init(date: yesterday, steps: 8_000)]
        var goals = GoalHistory()
        goals.set(10_000, on: today, calendar: calendar)

        // Before the first measurement, yesterday's successful day still counts.
        #expect(ActivityMath.currentStreak(days: history, goals: goals, endingOn: today, now: today, calendar: calendar) == 1)
        for steps: Int? in [nil, 0, 9_999, 10_000, 12_000] {
            let rows = history + [ActivityDay(date: today, steps: steps)]
            let expected = (steps ?? 0) >= 10_000 ? 2 : 1
            #expect(ActivityMath.currentStreak(days: rows, goals: goals, endingOn: today, now: today, calendar: calendar) == expected)
            // Once this day has ended, only a completed goal can preserve the series.
            let nextDay = rows + [ActivityDay(date: tomorrow, steps: 0)]
            #expect(ActivityMath.currentStreak(days: nextDay, goals: goals, endingOn: tomorrow, now: tomorrow, calendar: calendar) == (expected == 2 ? 2 : 0))
        }
    }
}

struct DashboardTrendTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        // The home chart must still use Monday when the locale starts weeks on Sunday.
        calendar.firstWeekday = 1
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }
    private func start(_ value: String) -> Date { calendar.startOfDay(for: date(value)) }

    @Test func sevenDaysEndExactlyOnAnchorAcrossTimeChange() {
        let anchor = date("2026-10-27T12:00:00Z")
        let trend = DashboardTrendActivity(period: .day, anchor: anchor, available: [
            .init(date: date("2026-10-20T12:00:00Z"), steps: 90_000),
            .init(date: date("2026-10-21T12:00:00Z"), steps: 2_000),
            .init(date: anchor, steps: 4_000),
            .init(date: date("2026-10-28T12:00:00Z"), steps: 90_000)
        ], now: date("2026-11-05T12:00:00Z"), calendar: calendar)
        #expect(trend.domain == start("2026-10-21T12:00:00Z")...start("2026-10-27T12:00:00Z"))
        #expect(trend.points.count == 7)
        #expect(trend.tickDates == trend.points.map(\.date))
        #expect(trend.points.first?.steps == 2_000)
        #expect(trend.points.last?.steps == 4_000)
        #expect(trend.summary.average == 3_000)
        #expect(trend.domain.upperBound.timeIntervalSince(trend.domain.lowerBound) == 6 * 86_400 + 3_600)
    }

    @Test func currentWeekShowsMondayToSundayButOnlyCountsThroughToday() {
        let now = date("2026-11-05T12:00:00Z")
        let values = (2...8).map { day in
            ActivityDay(date: date(String(format: "2026-11-%02dT08:00:00Z", day)), steps: day <= 5 ? 4_000 : 90_000)
        }
        let trend = DashboardTrendActivity(period: .week, anchor: now, available: values, now: now, calendar: calendar)
        let dashboard = DashboardActivity(period: .week, anchor: now, available: values, goals: .init(), now: now, calendar: calendar)
        #expect(trend.domain == start("2026-11-02T12:00:00Z")...start("2026-11-08T12:00:00Z"))
        #expect(dashboard.interval.start == trend.domain.lowerBound)
        #expect(dashboard.summary.total == trend.summary.total)
        #expect(dashboard.summary.average == trend.summary.average)
        #expect(trend.tickDates.count == 7)
        #expect(trend.days.count == 4)
        #expect(trend.summary.average == 4_000)
        #expect(trend.summary.observedDays == 4)
        #expect(trend.points.suffix(3).allSatisfy { $0.steps == nil })
    }

    @Test func currentMonthShowsEveryDayWithoutDilutingAverageWithFutureDays() {
        let now = date("2026-11-05T12:00:00Z")
        let trend = DashboardTrendActivity(period: .month, anchor: now, available: [
            .init(date: date("2026-11-01T12:00:00Z"), steps: 0),
            .init(date: now, steps: 6_000),
            .init(date: date("2026-11-06T12:00:00Z"), steps: 99_000)
        ], now: now, calendar: calendar)
        #expect(trend.domain == start("2026-11-01T12:00:00Z")...start("2026-11-30T12:00:00Z"))
        #expect(trend.points.count == 30)
        #expect(trend.tickDates.first == trend.domain.lowerBound)
        #expect(trend.tickDates.last == trend.domain.upperBound)
        #expect(trend.days.count == 5)
        #expect(trend.summary.observedDays == 2)
        #expect(trend.summary.average == 3_000)
        #expect(trend.points.dropFirst(5).allSatisfy { $0.steps == nil })
    }

    @Test func historicalLeapMonthKeepsFullBoundsWithRestrictedHistory() {
        let anchor = date("2024-02-15T12:00:00Z")
        let earliest = date("2024-02-20T12:00:00Z")
        let trend = DashboardTrendActivity(period: .month, anchor: anchor, available: [
            .init(date: anchor, steps: 99_000), .init(date: earliest, steps: 5_000)
        ], earliest: earliest, now: date("2024-03-02T12:00:00Z"), calendar: calendar)
        #expect(trend.domain == start("2024-02-01T12:00:00Z")...start("2024-02-29T12:00:00Z"))
        #expect(trend.points.count == 29)
        #expect(trend.days.count == 10)
        #expect(trend.points.prefix(19).allSatisfy { $0.steps == nil })
        #expect(trend.points[19].steps == 5_000)
        #expect(trend.summary.average == 5_000)
    }

    @Test func yearUsesMonthlyDailyAveragesThroughCurrentDayAndWeightsOverallMeanByDays() {
        let now = date("2026-03-02T12:00:00Z")
        let trend = DashboardTrendActivity(period: .year, anchor: now, available: [
            .init(date: date("2026-01-01T12:00:00Z"), steps: 2_000),
            .init(date: date("2026-01-02T12:00:00Z"), steps: 4_000),
            .init(date: date("2026-02-01T12:00:00Z"), steps: 9_000),
            .init(date: date("2026-03-01T12:00:00Z"), steps: 0),
            .init(date: now, steps: 5_000),
            .init(date: date("2026-03-03T12:00:00Z"), steps: 99_000),
            .init(date: date("2026-04-01T12:00:00Z"), steps: 99_000)
        ], now: now, calendar: calendar)
        #expect(trend.domain == start("2026-01-01T12:00:00Z")...start("2026-12-01T12:00:00Z"))
        #expect(trend.tickDates.count == 12)
        #expect(trend.points.map(\.steps) == [3_000, 9_000, 2_500] + Array(repeating: nil, count: 9))
        #expect(trend.summary.observedDays == 5)
        #expect(trend.summary.total == 20_000)
        #expect(trend.summary.average == 4_000)
    }

    @Test func historicalYearIncludesDecemberAndKeepsMissingMonthsAsGaps() {
        let anchor = date("2025-06-02T12:00:00Z")
        let trend = DashboardTrendActivity(period: .year, anchor: anchor, available: [
            .init(date: date("2025-01-01T12:00:00Z"), steps: 0),
            .init(date: date("2025-03-01T12:00:00Z"), steps: 7_000),
            .init(date: date("2025-12-31T12:00:00Z"), steps: 8_000)
        ], now: date("2026-01-01T12:00:00Z"), calendar: calendar)
        #expect(trend.points.count == 12)
        #expect(trend.points[0].steps == 0)
        #expect(trend.points[1].steps == nil)
        #expect(trend.points[2].segment != trend.points[0].segment)
        #expect(trend.points[11].steps == 8_000)
        #expect(trend.summary.average == 5_000)
    }

    @Test func emptyDataHasFullBoundsAndNoInventedZeroes() {
        let now = date("2026-01-01T12:00:00Z")
        for period in ActivityPeriod.allCases {
            let trend = DashboardTrendActivity(period: period, anchor: now, available: [], now: now, calendar: calendar)
            #expect(trend.domain.lowerBound < trend.domain.upperBound)
            #expect(trend.summary.average == nil)
            #expect(trend.summary.total == nil)
            #expect(trend.points.allSatisfy { $0.steps == nil })
        }
    }
}
