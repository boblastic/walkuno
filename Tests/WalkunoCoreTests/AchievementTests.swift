import Foundation
import Testing
@testable import WalkunoCore

struct AchievementTests {
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text + "T12:00:00Z")! }
    func days(from start: String, count: Int, steps: Int = 8_000) -> [ActivityDay] {
        (0..<count).map { offset in
            .init(date: calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: date(start))!), steps: steps)
        }
    }
    func summary(_ days: [ActivityDay], now: String, goals: GoalHistory = .init(initialGoal: 8_000)) -> AchievementSummary {
        .init(days: days, goals: goals, now: date(now), calendar: calendar)
    }

    @Test func dailyCountersUseHistoricalGoalsAndDoNotCountRefreshesTwice() {
        var goals = GoalHistory()
        goals.set(5_000, on: date("2026-11-02"), calendar: calendar)
        let rows = [ActivityDay(date: date("2026-11-01"), steps: 16_000),
                    ActivityDay(date: date("2026-11-02"), steps: 15_000),
                    ActivityDay(date: date("2026-11-02"), steps: 15_500),
                    ActivityDay(date: date("2026-11-03"), steps: 100_000)]
        let result = summary(rows, now: "2026-11-02", goals: goals)
        #expect(result.dailyGoals.map(\.count) == [2, 2, 1])
        #expect(result.dailyGoals.map(\.target) == [5_000, 10_000, 15_000])
        #expect(result.dailyGoals[2].steps == 15_500)
        #expect(result.record(for: .steps)?.steps == 16_000)
    }

    @Test func exactDailyThresholdCountsImmediatelyAndRefreshIsIdempotent() {
        let rows = days(from: "2026-11-02", count: 1)
        let first = summary(rows, now: "2026-11-02")
        let refreshed = summary(rows, now: "2026-11-02")
        #expect(first.dailyGoals.map(\.count) == [1, 0, 0])
        #expect(first.dailyGoals.map(\.count) == refreshed.dailyGoals.map(\.count))
        #expect(first.dailyGoals[0].progress == 1)
        #expect(first.dailyGoals[1].progress == 0.5)
    }

    @Test func missingMeasurementsRemainUnavailableAndRecordsAreIndependent() {
        let rows = [ActivityDay(date: date("2026-11-01"), steps: 10_000, kilocalories: 600),
                    ActivityDay(date: date("2026-11-02"), meters: 12_345, exerciseMinutes: 90, floors: 42)]
        let result = summary(rows, now: "2026-11-02")
        #expect(result.dailyGoals[0].steps == nil)
        #expect(result.record(for: .steps)?.steps == 10_000)
        #expect(result.record(for: .energy)?.kilocalories == 600)
        #expect(result.record(for: .distance)?.meters == 12_345)
        #expect(result.record(for: .exerciseTime)?.exerciseMinutes == 90)
        #expect(result.record(for: .floors)?.floors == 42)
        #expect(result.totalMeters == 12_345)
        let empty = summary([], now: "2026-11-02")
        #expect(empty.totalMeters == nil)
        #expect(empty.record(for: .floors) == nil)
    }

    @Test func perfectWeekRequiresEveryCalendarDayAndCountsAcrossYears() {
        let rows = days(from: "2026-12-28", count: 7)
        let completed = summary(rows, now: "2027-01-03").perfectPeriods[0]
        #expect(completed.count == 1)
        #expect(completed.progress == 1)
        #expect(completed.requiredDays == 7)
        let missing = summary(Array(rows.dropFirst()), now: "2027-01-03").perfectPeriods[0]
        #expect(missing.count == 0)
        #expect(!missing.canComplete)
        let inflated = rows.enumerated().map { offset, row in
            ActivityDay(date: row.date, steps: offset == 0 ? 0 : 24_000)
        }
        #expect(summary(inflated, now: "2027-01-03").perfectPeriods[0].count == 0)
    }

    @Test func cumulativeDistanceIncludesOlderDistanceOnlyDaysWithoutACap() {
        let rows = [ActivityDay(date: date("2014-01-01"), meters: 24_000_000),
                    ActivityDay(date: date("2026-11-01"), steps: 8_000, meters: 12_345),
                    ActivityDay(date: date("2026-11-02"), steps: 16_000),
                    ActivityDay(date: date("2026-11-03"), meters: 50_000)]
        let result = summary(rows, now: "2026-11-02")
        #expect(result.totalMeters == 24_012_345)
        #expect(result.totalSteps == 24_000)
        #expect(DistanceTrophy.catalog.first { $0.id == "europe" }?.progress(totalMeters: result.totalMeters).completed == 2)
    }

    @Test func partialPeriodAndTodayCannotBeAwardedPrematurely() {
        let rows = days(from: "2026-11-02", count: 6)
        let result = summary(rows, now: "2026-11-08").perfectPeriods[0]
        #expect(result.count == 0)
        #expect(result.achievedDays == 6)
        #expect(result.canComplete)
        let nextWeek = summary(rows, now: "2026-11-09").perfectPeriods[0]
        #expect(nextWeek.achievedDays == 0)
        #expect(nextWeek.canComplete)
    }

    @Test func perfectLeapMonthYearAndDaylightSavingUseCalendarDays() {
        let february = summary(days(from: "2024-02-01", count: 29), now: "2024-02-29").perfectPeriods[1]
        #expect(february.requiredDays == 29)
        #expect(february.count == 1)
        let leapYear = summary(days(from: "2024-01-01", count: 366), now: "2024-12-31").perfectPeriods[2]
        #expect(leapYear.requiredDays == 366)
        #expect(leapYear.count == 1)
        let dstWeek = summary(days(from: "2026-10-19", count: 7), now: "2026-10-25").perfectPeriods[0]
        #expect(dstWeek.count == 1)
        #expect(dstWeek.requiredDays == 7)
    }

    @Test func multiplePerfectPeriodsCountOnceEach() {
        let rows = days(from: "2026-10-01", count: 61)
        let result = summary(rows, now: "2026-11-30")
        #expect(result.perfectPeriods[1].count == 2)
        #expect(result.perfectPeriods[2].count == 0)
    }

    @Test func streaksAwardOnFirstThresholdDateAndSurviveLaterBreaks() {
        var rows = days(from: "2026-09-01", count: 30)
        rows += days(from: "2026-10-02", count: 3)
        let result = summary(rows, now: "2026-10-04")
        #expect(result.streaks.map(\.target) == [7, 15, 30])
        #expect(result.longestStreak == 30)
        #expect(result.currentStreak == 3)
        #expect(result.streaks[0].firstReached == calendar.startOfDay(for: date("2026-09-07")))
        #expect(result.streaks[1].firstReached == calendar.startOfDay(for: date("2026-09-15")))
        #expect(result.streaks[2].firstReached == calendar.startOfDay(for: date("2026-09-30")))
        #expect(result.streaks.allSatisfy { $0.progress == 1 })
    }

    @Test func unfinishedTodayPreservesYesterdayButMissingYesterdayBreaksStreak() {
        let rows = days(from: "2026-11-01", count: 6)
        #expect(summary(rows, now: "2026-11-07").currentStreak == 6)
        #expect(summary(rows + [.init(date: date("2026-11-07"), steps: 300)], now: "2026-11-07").currentStreak == 6)
        #expect(summary(rows, now: "2026-11-08").currentStreak == 0)
        #expect(summary(Array(rows.dropFirst()), now: "2026-11-07").streaks[0].firstReached == nil)
    }

    @Test func distancesRepeatAndNextCycleStartsAtExactBoundary() {
        let trophy = DistanceTrophy.catalog.first { $0.id == "goldenGate" }!
        let progress = trophy.progress(totalMeters: 6_842.5)
        #expect(progress.completed == 2)
        #expect(progress.cycleMeters == 1_368.5)
        #expect(progress.fraction == 0.5)
        let exact = trophy.progress(totalMeters: 8_211)
        #expect(exact.completed == 3)
        #expect(exact.cycleMeters == 0)
        #expect(exact.fraction == 0)
        #expect(trophy.progress(totalMeters: nil).cycleMeters == nil)
        #expect(trophy.progress(totalMeters: .infinity).cycleMeters == nil)
        #expect(trophy.progress(totalMeters: .nan).cycleMeters == nil)
    }

    @Test func catalogIsOrderedAndSupportsLongTermTotals() {
        let catalog = DistanceTrophy.catalog
        #expect(catalog.count == 22)
        #expect(Set(catalog.map(\.id)).count == catalog.count)
        #expect(catalog.map(\.meters) == catalog.map(\.meters).sorted())
        let earth = catalog.first { $0.id == "earth" }!
        #expect(earth.progress(totalMeters: earth.meters * 1_000 + 500).completed == 1_000)
        #expect(earth.progress(totalMeters: earth.meters * 1_000 + 500).cycleMeters == 500)
    }
}
