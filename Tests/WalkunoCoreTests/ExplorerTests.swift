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
}
