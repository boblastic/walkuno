import Foundation
import Testing
@testable import WalkunoCore

struct ExplorerTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        calendar.firstWeekday = 2
        return calendar
    }
    private func date(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    @Test func allPageWidgetsArePreparedForEachNeighbor() throws {
        let now = date("2026-11-05T12:00:00Z")
        let anchor = date("2025-10-15T12:00:00Z")
        let days = (0..<800).map { offset in
            ActivityDay(date: calendar.date(byAdding: .day, value: -offset, to: calendar.startOfDay(for: now))!,
                        steps: offset % 5 == 0 ? nil : 8_000 + offset, meters: Double(offset))
        }
        for period in ActivityPeriod.allCases {
            let window = ExplorerPageWindow(period: period, anchor: anchor, available: days, goals: .init(), now: now, calendar: calendar)
            let previous = try #require(window.previous)
            let next = try #require(window.next)
            #expect(previous.interval.end == window.current.interval.start)
            #expect(window.current.interval.end == next.interval.start)
            for page in [previous, window.current, next] {
                let rows = ActivityMath.days(in: page.interval, available: days, now: now, calendar: calendar)
                #expect(page.summary == ActivitySummary(days: rows, goals: .init(), calendar: calendar))
                #expect(!page.calendarDays.isEmpty)
                #expect((0..<7).contains(page.calendarOffset))
                let monthCount = Set(rows.map { calendar.dateInterval(of: .month, for: $0.date)!.start }).count
                #expect(page.chartDays.count == (period == .year ? monthCount : rows.count))
                if period == .year { #expect(page.bestMonth != nil) }
            }
            let moved = ExplorerPageWindow(period: period, anchor: previous.anchor, available: days, goals: .init(), now: now,
                                           calendar: calendar, reusing: window)
            #expect(moved.current.chartDays == previous.chartDays)
            #expect(moved.current.summary == previous.summary)
            #expect(moved.next?.id == window.current.id)
        }
    }

    @Test func freeBoundaryAndCurrentPeriodHaveNoInaccessibleNeighbor() throws {
        let now = date("2026-11-05T12:00:00Z")
        let earliest = calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: now))!
        for period in ActivityPeriod.allCases {
            let current = ExplorerPageWindow(period: period, anchor: now, available: [], goals: .init(), earliest: earliest, now: now, calendar: calendar)
            #expect(current.next == nil)
            #expect(current.current.summary.total == nil)
            let chartStart = period == .year ? calendar.dateInterval(of: .month, for: earliest)!.start : earliest
            #expect(current.current.chartDays.allSatisfy { $0.date >= chartStart && $0.date <= now })
            let boundary = ExplorerPageWindow(period: period, anchor: earliest, available: [], goals: .init(), earliest: earliest, now: now, calendar: calendar)
            #expect(boundary.previous == nil)
            #expect(boundary.current.previousTotal == nil)
            let premium = ExplorerPageWindow(period: period, anchor: earliest, available: [], goals: .init(), now: now, calendar: calendar)
            #expect(premium.previous != nil)
        }
    }

    @Test func changingMeasurementsAndGoalsRebuildsPreparedSummaries() throws {
        let now = date("2026-11-05T12:00:00Z")
        let day = calendar.startOfDay(for: now)
        let empty = ExplorerPageWindow(period: .month, anchor: now, available: [], goals: .init(), now: now, calendar: calendar)
        var goals = GoalHistory()
        goals.set(5_000, on: day, calendar: calendar)
        let updated = ExplorerPageWindow(period: .month, anchor: now, available: [.init(date: day, steps: 6_000)], goals: goals, now: now, calendar: calendar)
        #expect(empty.current.summary.total == nil)
        #expect(updated.current.summary.total == 6_000)
        #expect(updated.current.summary.achievedDays == 1)
        #expect(updated.current.calendarDays.last?.steps == 6_000)
    }

    @Test func neighborsRemainContiguousAcrossDSTAndLeapMonth() throws {
        for anchor in [date("2026-03-29T12:00:00Z"), date("2026-10-25T12:00:00Z"), date("2024-02-29T12:00:00Z")] {
            for period in ActivityPeriod.allCases {
                let window = ExplorerPageWindow(period: period, anchor: anchor, available: [], goals: .init(), now: date("2027-12-31T12:00:00Z"), calendar: calendar)
                #expect(try #require(window.previous).interval.end == window.current.interval.start)
                #expect(try #require(window.next).interval.start == window.current.interval.end)
            }
        }
    }

    @Test func weeklyCalendarUsesMondayThroughSundayAcrossMonthAndDST() {
        var sundayCalendar = calendar
        sundayCalendar.firstWeekday = 1
        let now = date("2026-03-29T12:00:00Z")
        let page = ExplorerActivity(period: .week, anchor: now, available: [], goals: .init(), now: now, calendar: sundayCalendar)
        #expect(page.calendarDays.count == 7)
        #expect(page.calendarOffset == 0)
        #expect(calendar.component(.weekday, from: page.calendarDays.first!.date) == 2)
        #expect(calendar.component(.weekday, from: page.calendarDays.last!.date) == 1)
        #expect(page.interval.duration == 167 * 3600)
        let current = ExplorerActivity(period: .week, anchor: date("2026-11-05T12:00:00Z"), available: [], goals: .init(),
                                       now: date("2026-11-05T12:00:00Z"), calendar: calendar)
        #expect(current.calendarDays.count == 7)
        #expect(current.calendarDays.suffix(3).allSatisfy { $0.steps == nil })
    }

    @Test func periodTotalsUseIndependentMeasurementsAndAccessibleElapsedDays() {
        let now = date("2026-11-05T12:00:00Z")
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let days: [ActivityDay] = [
            .init(date: yesterday, steps: 1_000, meters: 700, kilocalories: 50, exerciseMinutes: 20, floors: 3),
            .init(date: today, meters: 500, exerciseMinutes: 10, floors: 0),
            .init(date: tomorrow, steps: 99_000, kilocalories: 999, exerciseMinutes: 999, floors: 999)
        ]
        for period in [ActivityPeriod.week, .month, .year] {
            let page = ExplorerActivity(period: period, anchor: now, available: days, goals: .init(), now: now, calendar: calendar)
            #expect(page.total(for: .distance) == 1_200)
            #expect(page.total(for: .energy) == 50)
            #expect(page.total(for: .exerciseTime) == 30)
            #expect(page.total(for: .floors) == 3)
            let restricted = ExplorerActivity(period: period, anchor: now, available: days, goals: .init(), earliest: today, now: now, calendar: calendar)
            #expect(restricted.total(for: .energy) == nil)
            #expect(restricted.total(for: .floors) == 0)
        }
    }

    @Test func annualCalendarScoresTwelveMonthsUsingHistoricalGoals() throws {
        let now = date("2026-03-05T12:00:00Z")
        let jan = calendar.startOfDay(for: date("2026-01-10T12:00:00Z"))
        let feb = calendar.startOfDay(for: date("2026-02-10T12:00:00Z"))
        let march = calendar.startOfDay(for: now)
        var goals = GoalHistory(initialGoal: 8_000)
        goals.set(4_000, on: jan, calendar: calendar)
        goals.set(10_000, on: feb, calendar: calendar)
        let page = ExplorerActivity(period: .year, anchor: now, available: [
            .init(date: jan, steps: 2_000), .init(date: feb, steps: 10_000), .init(date: march, steps: 0),
            .init(date: date("2026-04-01T00:00:00Z"), steps: 99_000)
        ], goals: goals, now: now, calendar: calendar)
        #expect(page.calendarMonths.count == 12)
        #expect(page.calendarMonths[0].progress == 2_000.0 / 160_000)
        #expect(page.calendarMonths[1].progress == 10_000.0 / 226_000)
        #expect(page.calendarMonths[2].progress == 0)
        #expect(page.calendarMonths.dropFirst(3).allSatisfy { $0.progress == nil && $0.summary.total == nil })
    }

    @Test func monthlyCalendarCountersMatchHomeGlobalGoalsAndPreserveOverflow() throws {
        let now = date("2026-03-05T12:00:00Z")
        let january = calendar.startOfDay(for: date("2026-01-01T12:00:00Z"))
        let february = calendar.startOfDay(for: date("2026-02-01T12:00:00Z"))
        let march = calendar.startOfDay(for: date("2026-03-01T12:00:00Z"))
        var goals = GoalHistory(initialGoal: 8_000)
        goals.set(10_000, on: february, calendar: calendar)
        let days: [ActivityDay] = [
            .init(date: january, steps: 248_000), // One day can compensate for the rest of the month.
            .init(date: february, steps: 420_000),
            .init(date: march, steps: 0),
            .init(date: date("2026-03-06T12:00:00Z"), steps: 999_000)
        ]
        for earliest in [nil, february] as [Date?] {
            let page = ExplorerActivity(period: .year, anchor: now, available: days, goals: goals,
                                        earliest: earliest, now: now, calendar: calendar)
            for month in page.calendarMonths where month.summary.total != nil {
                let home = DashboardActivity(period: .month, anchor: month.date, available: days, goals: goals,
                                             earliest: earliest, now: now, calendar: calendar)
                #expect(month.progress == home.progress)
            }
            #expect(page.calendarMonths[0].progress == (earliest == nil ? 1 : nil))
            #expect(page.calendarMonths[1].progress == 1.5)
            #expect(page.calendarMonths[2].progress == 0)
            #expect(page.calendarMonths.dropFirst(3).allSatisfy { $0.progress == nil })
        }
    }

    @Test func hourlySlotsPreserveMissingZeroAndFutureValuesAcrossDST() {
        for (day, count) in [("2026-03-29T12:00:00Z", 23), ("2026-10-25T12:00:00Z", 25)] {
            let date = date(day)
            let start = calendar.startOfDay(for: date)
            let next = calendar.date(byAdding: .hour, value: 1, to: start)!
            let activity = ExplorerHourlyActivity(date: date, available: [.init(date: start, steps: 0), .init(date: next, steps: 2_000)],
                                                   now: self.date("2027-01-01T00:00:00Z"), calendar: calendar)
            #expect(activity.hours.count == count)
            #expect(activity.hours[0].steps == 0)
            #expect(activity.hours[1].steps == 2_000)
            #expect(activity.hours.dropFirst(2).allSatisfy { $0.steps == nil })
            let current = ExplorerHourlyActivity(date: date, available: [.init(date: next, steps: 2_000)], now: start, calendar: calendar)
            #expect(current.hours.allSatisfy { $0.steps == nil })
        }
    }
}
