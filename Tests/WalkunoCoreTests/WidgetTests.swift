import Foundation
import Testing
@testable import WalkunoCore

struct WidgetTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendar
    }
    private func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
    private func snapshot(at now: Date, previousSteps: Int? = 4000) -> WidgetSnapshot {
        let cutoff = WidgetActivityDetail.previousDayCutoff(for: now, calendar: calendar)!
        return .init(updatedAt: now, timeZoneIdentifier: calendar.timeZone.identifier,
                     today: .init(date: calendar.startOfDay(for: now), steps: 6000, meters: 4500, floors: 6),
                     goal: 8000, week: [], theme: .mint, unit: .kilometers,
                     activity: .init(sampledAt: now, previousCutoff: cutoff, todayHours: [], yesterdayHours: [],
                                     yesterdayAtSameTime: .init(date: calendar.startOfDay(for: cutoff), steps: previousSteps,
                                                               meters: 3000, floors: 8)))
    }

    @Test func sameTimeComparisonUsesPartialPreviousDayForEachMetric() {
        var snapshot = snapshot(at: date("2026-11-05T13:37:12Z"))
        // Yesterday's full-day total deliberately differs from the exact partial-day total.
        snapshot.week = [.init(date: date("2026-11-04T00:00:00Z"), steps: 12000, meters: 9000)]
        #expect(snapshot.change(for: .steps, calendar: calendar) == 0.5)
        #expect(snapshot.change(for: .distance, calendar: calendar) == 0.5)
        #expect(snapshot.change(for: .floors, calendar: calendar) == -0.25)
        #expect(snapshot.change(for: .energy, calendar: calendar) == nil)
    }

    @Test func absentOrZeroBaselineAndMismatchedRefreshNeverInventPercentages() {
        let now = date("2026-11-05T13:37:12Z")
        for baseline in [nil, 0] as [Int?] {
            #expect(snapshot(at: now, previousSteps: baseline).change(for: .steps, calendar: calendar) == nil)
        }
        var snapshot = snapshot(at: now)
        snapshot.today.steps = nil
        #expect(snapshot.change(for: .steps, calendar: calendar) == nil)
        snapshot.today.steps = 0
        #expect(snapshot.change(for: .steps, calendar: calendar) == -1)
        snapshot.activity?.sampledAt = now.addingTimeInterval(-60)
        #expect(snapshot.change(for: .steps, calendar: calendar) == nil)
        snapshot.activity?.sampledAt = now
        snapshot.activity?.previousCutoff = now.addingTimeInterval(-86460)
        #expect(snapshot.change(for: .steps, calendar: calendar) == nil)
    }

    @Test func sameClockCutoffIncludesMinutesAndSecondsAcrossDaylightSaving() {
        for (now, expected) in [
            ("2026-11-05T13:37:12Z", "2026-11-04T13:37:12Z"),
            ("2026-03-29T10:37:12Z", "2026-03-28T11:37:12Z"),
            ("2026-10-25T11:37:12Z", "2026-10-24T10:37:12Z")
        ] {
            #expect(WidgetActivityDetail.previousDayCutoff(for: date(now), calendar: calendar) == date(expected))
        }
        // Yesterday's 02:37 never existed on the spring clock change.
        #expect(WidgetActivityDetail.previousDayCutoff(for: date("2026-03-30T00:37:12Z"), calendar: calendar) == nil)
        // A repeated clock time selects its first occurrence deterministically.
        #expect(WidgetActivityDetail.previousDayCutoff(for: date("2026-10-26T01:37:12Z"), calendar: calendar)
                == date("2026-10-25T00:37:12Z"))
    }

    @Test func rollingWeekAlwaysContainsSevenCalendarDaysAndCurrentTotal() {
        let now = date("2026-10-27T14:00:00Z")
        var snapshot = snapshot(at: now)
        let start = calendar.startOfDay(for: now)
        snapshot.week = [
            .init(date: calendar.date(byAdding: .day, value: -3, to: start)!, steps: 0),
            .init(date: calendar.date(byAdding: .day, value: -8, to: start)!, steps: 50000),
            .init(date: start, steps: 100)
        ]
        let days = snapshot.recentWeek(calendar: calendar)
        #expect(days.count == 7)
        #expect(days.last?.steps == 6000)
        #expect(days[3].steps == 0)
        #expect(days[0].steps == nil)
        #expect(days.compactMap(\.steps).reduce(0, +) == 6000)
        #expect(calendar.dateComponents([.day], from: days[0].date, to: days[6].date).day == 6)
        #expect(days[6].date.timeIntervalSince(days[0].date) == 145 * 3600)
    }

    @Test func legacyCacheLoadsWithoutHourlyDataAndNewCacheRoundTrips() throws {
        let now = date("2026-11-05T13:37:12Z")
        var original = snapshot(at: now)
        original.activity?.todayHours = [.init(date: now, steps: 120, meters: 85, floors: 2)]
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(WidgetSnapshot.self, from: data) == original)
        var legacy = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "activity")
        let restored = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(restored.activity == nil)
        #expect(restored.today == original.today)
        #expect(restored.change(for: .steps, calendar: calendar) == nil)
        #expect(data.count < 100_000)
    }

    @Test func compactLabelsKeepLargeCountersShort() {
        #expect(WidgetNumbers.steps(nil) == "—")
        #expect(WidgetNumbers.steps(9999) == 9999.formatted())
        #expect(WidgetNumbers.steps(10_000) == "10K")
        #expect(WidgetNumbers.steps(10_050) == "10.1K")
        #expect(WidgetNumbers.steps(12_345) == "12.3K")
        #expect(WidgetNumbers.steps(100_000) == "100K")
        #expect(WidgetNumbers.steps(1_250_000) == "1.3M")
        #expect(WidgetNumbers.steps(5_000, abbreviateFrom: 1000) == "5K")
        #expect(WidgetNumbers.percentageChange(nil) == "—")
        #expect(WidgetNumbers.percentageChange(0) == "0%")
        #expect(WidgetNumbers.percentageChange(0.23) == "+23%")
        #expect(WidgetNumbers.percentageChange(11.25) == "+1.1K%")
        #expect(WidgetNumbers.percentageChange(-1) == "−100%")
    }

    @Test func rollingHoursUseActualConsecutiveHoursAndColorOnlyToday() throws {
        for instant in ["2026-11-05T13:37:12Z", "2026-10-25T11:37:12Z", "2026-03-29T10:37:12Z"] {
            let now = date(instant)
            var snapshot = snapshot(at: now)
            let hour = try #require(calendar.dateInterval(of: .hour, for: now)?.start)
            let previous = calendar.date(byAdding: .hour, value: -23, to: hour)!
            snapshot.activity?.yesterdayHours = [.init(date: previous, steps: 50)]
            snapshot.activity?.todayHours = [.init(date: hour, steps: 0)]
            let buckets = try #require(snapshot.activity?.last24Hours(calendar: calendar))
            #expect(buckets.count == 24)
            #expect(buckets.first?.date == previous)
            #expect(buckets.last?.date == hour)
            #expect(buckets.last?.steps == 0)
            #expect(buckets[1].steps == nil)
            #expect(buckets.first?.steps == 50)
            #expect(buckets.first?.isToday == false)
            #expect(buckets.last?.isToday == true)
            #expect(buckets[23].date.timeIntervalSince(buckets[0].date) == 23 * 3600)
        }
    }

    @Test func cumulativeCurveUsesObservedRecentDaysAtExactCutoff() throws {
        let now = date("2026-11-05T13:37:12Z") // 14:37:12 local time.
        let start = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: start)!
        let older = calendar.date(byAdding: .day, value: -2, to: start)!
        let cutoff = 14.0 + 37.0 / 60 + 12.0 / 3600
        let reference = DayComparison(today: [], history: [
            [.init(date: yesterday.addingTimeInterval(10 * 3600), steps: 2000),
             .init(date: yesterday.addingTimeInterval(14 * 3600), steps: 400)],
            [.init(date: older.addingTimeInterval(10 * 3600), steps: 4000),
             .init(date: older.addingTimeInterval(14 * 3600), steps: 800)],
            [.init(date: older, steps: nil)]
        ], metric: .steps, cutoffHour: cutoff, calendar: calendar)
        var snapshot = snapshot(at: now)
        snapshot.activity?.todayHours = [.init(date: start.addingTimeInterval(10 * 3600), steps: 3000),
                                         .init(date: start.addingTimeInterval(14 * 3600), steps: 500)]
        snapshot.activity?.usual = .init(comparison: reference)
        let points = try #require(snapshot.activity?.cumulative(todaySteps: snapshot.today.steps, calendar: calendar))
        #expect(snapshot.activity?.usual?.baselineDays == 2)
        #expect(points.last?.hour == cutoff)
        #expect(points.last?.usual == 3600)
        #expect(points.last?.current == 6000)
        #expect(points.first?.hour == 0)
        #expect(points.first?.current == 0)
        #expect(points.first?.usual == 0)
        #expect(points.first(where: { $0.hour == 14 })?.usual == 3000)
        #expect(points.allSatisfy { $0.hour <= cutoff })
        let restored = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(snapshot))
        #expect(restored == snapshot)
    }

    @Test func oldHourlyCacheStillLoadsWithoutUsualCurve() throws {
        let original = snapshot(at: date("2026-11-05T13:37:12Z"))
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        var activity = try #require(json["activity"] as? [String: Any])
        activity.removeValue(forKey: "usual")
        json["activity"] = activity
        let restored = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(restored.activity?.usual == nil)
        #expect(restored.change(for: .steps, calendar: calendar) == 0.5)
        #expect(restored.activity?.cumulative(todaySteps: 6000, calendar: calendar).last?.usual == nil)
    }
}
