import Foundation
import Testing
@testable import WalkunoCore

struct ActivityTests {
    var calendar: Calendar {
        var result = Calendar(identifier: .gregorian)
        result.timeZone = TimeZone(identifier: "Europe/Paris")!
        result.firstWeekday = 2
        return result
    }
    func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }

    @Test func unavailableIsNotZero() {
        let summary = ActivitySummary(days: [.init(date: .now)], goals: .init())
        #expect(summary.total == nil)
        #expect(summary.average == nil)
        #expect(summary.observedDays == 0)
        let zero = ActivitySummary(days: [.init(date: .now, steps: 0)], goals: .init())
        #expect(zero.total == 0)
        #expect(ActivityMath.change(current: 300, previous: 0) == nil)
    }

    @Test func missingDaysAreExcludedFromAverage() {
        let summary = ActivitySummary(days: [.init(date: .now, steps: 8000), .init(date: .distantPast)], goals: .init())
        #expect(summary.average == 8000)
        #expect(summary.achievedDays == 1)
    }

    @Test func goalChangesPreserveEarlierDays() {
        var history = GoalHistory()
        history.set(5000, on: date("2026-10-01T12:00:00Z"), calendar: calendar)
        history.set(10000, on: date("2026-11-04T12:00:00Z"), calendar: calendar)
        #expect(history.value(on: date("2026-11-03T12:00:00Z"), calendar: calendar) == 5000)
        #expect(history.value(on: date("2026-11-04T23:00:00Z"), calendar: calendar) == 10000)
        #expect(history.value(on: date("2026-09-01T12:00:00Z"), calendar: calendar) == 8000)
        history.set(-1, calendar: calendar)
        #expect(history.changes.count == 2)
    }

    @Test func watchConflictsKeepLatestEdit() {
        let day = date("2026-11-04T12:00:00Z")
        var phone = GoalHistory()
        phone.set(9000, on: day, calendar: calendar, modifiedAt: day.addingTimeInterval(10))
        var watch = GoalHistory()
        watch.set(6000, on: day, calendar: calendar, modifiedAt: day)
        phone.merge(watch, calendar: calendar)
        #expect(phone.value(on: day, calendar: calendar) == 9000)
        watch.merge(phone, calendar: calendar)
        #expect(watch == phone)
    }

    @Test func streakBreaksOnMissingOrNonAdjacentDays() {
        let day = date("2026-10-01T00:00:00Z")
        let rows = [0, 1, 3, 4, 5, 6].map { offset in
            ActivityDay(date: calendar.date(byAdding: .day, value: offset, to: day)!, steps: offset == 5 ? nil : 9000)
        }
        #expect(ActivityMath.longestStreak(days: rows, goals: .init(), calendar: calendar) == 2)
    }

    @Test func dayBoundariesRespectDaylightSaving() {
        let day = date("2026-10-25T12:00:00Z")
        let interval = ActivityPeriod.day.interval(containing: day, calendar: calendar)
        #expect(interval.duration == 25 * 3600)
        let rows = ActivityMath.days(in: DateInterval(start: interval.start, end: calendar.date(byAdding: .day, value: 3, to: interval.start)!),
                                     available: [], now: date("2026-10-27T12:00:00Z"), calendar: calendar)
        #expect(rows.count == 3)
    }

    @Test func widgetDoesNotReuseYesterdayOrAnotherTimeZone() {
        let now = date("2026-11-04T12:00:00Z")
        let snapshot = WidgetSnapshot(updatedAt: now, timeZoneIdentifier: calendar.timeZone.identifier,
                                      today: .init(date: now, steps: 4000), goal: 8000, week: [], theme: .mint, unit: .kilometers)
        #expect(snapshot.isCurrent(now: now, calendar: calendar))
        #expect(!snapshot.isCurrent(now: now.addingTimeInterval(86400), calendar: calendar))
        var other = calendar; other.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        #expect(!snapshot.isCurrent(now: now, calendar: other))
    }

    @Test func futureDaysAreNotIncluded() {
        let now = date("2026-11-04T12:00:00Z")
        let days = ActivityMath.days(in: ActivityPeriod.month.interval(containing: now, calendar: calendar), available: [], now: now, calendar: calendar)
        #expect(days.count == 4)
        #expect(days.allSatisfy { $0.steps == nil })
    }
}
