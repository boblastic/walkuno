import Foundation
import Testing
@testable import WalkunoCore

struct MotivationTests {
    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Europe/Paris")!
        return value
    }
    let now = ISO8601DateFormatter().date(from: "2026-11-05T14:30:00Z")!
    func day(_ offset: Int, _ steps: Int?) -> ActivityDay {
        .init(date: calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now))!, steps: steps)
    }
    func snapshot(_ days: [ActivityDay], goals: GoalHistory = .init(), detail: WidgetActivityDetail? = nil,
                  at: Date? = nil) -> MotivationSnapshot {
        .init(days: days, goals: goals, detail: detail, now: at ?? now, calendar: calendar)
    }
    func detail(reference: Int = 4_000, count: Int = 5, sampledAt: Date? = nil) -> WidgetActivityDetail {
        let sample = sampledAt ?? now
        let hour = calendar.date(byAdding: .hour, value: -1, to: sample)!
        let clock = calendar.dateComponents([.hour, .minute, .second], from: sample)
        let cutoff = Double(clock.hour!) + Double(clock.minute!) / 60 + Double(clock.second!) / 3_600
        let comparison = DayComparison(today: [], history: (0..<count).map { _ in [.init(date: hour, steps: reference)] },
                                       metric: .steps, cutoffHour: cutoff, calendar: calendar)
        return .init(sampledAt: sample, previousCutoff: nil, todayHours: [], yesterdayHours: [],
                     yesterdayAtSameTime: day(-1, nil), usual: .init(comparison: comparison))
    }

    @Test func missingMeasurementsAreNotFailuresAndTodayIsNotACompletedDay() {
        let result = snapshot([day(-15, 99_999), day(-7, 8_000), day(-2, nil), day(-1, 0), day(0, 80_000), day(1, 99_999)])
        #expect(result.recentDays == 2)
        #expect(result.achievedDays == 1)
        #expect(result.recentAverage == 4_000)
        #expect(result.previousAverage == nil)
        #expect(result.trendPercent == nil)
        #expect(result.situation == .farExceeded)
        #expect(result.suggestedSteps == nil)
        let empty = snapshot([day(-1, 9_000)])
        #expect(empty.todaySteps == nil)
        #expect(empty.situation == .noData)
        #expect(empty.remaining == nil)
        #expect(empty.suggestedSteps == nil)
    }

    @Test func historicalGoalsRemainAuthoritative() {
        var goals = GoalHistory()
        goals.set(5_000, on: day(-7, nil).date, calendar: calendar)
        goals.set(10_000, on: day(0, nil).date, calendar: calendar)
        let result = snapshot((-7 ... -1).map { day($0, 6_000) } + [day(0, 6_000)], goals: goals)
        #expect(result.achievedDays == 7)
        #expect(result.goal == 10_000)
        #expect(result.remaining == 4_000)
        #expect(result.suggestedSteps == 1_000)
    }

    @Test func trendsNeedCoverageAndUseTwoCompletedCalendarWeeks() {
        let history = (-14 ... -8).map { day($0, 5_000) } + (-7 ... -1).map { day($0, 6_000) }
        let result = snapshot(history + [day(0, 3_000)])
        #expect(result.trendPercent == 20)
        #expect(result.situation == .progressing)
        let sparse = snapshot([day(-8, 5_000), day(-1, 6_000), day(0, 3_000)])
        #expect(sparse.trendPercent == nil)
        #expect(sparse.situation == .starting)
        let zeroBefore = snapshot((-14 ... -8).map { day($0, 0) } + (-7 ... -1).map { day($0, 6_000) })
        #expect(zeroBefore.trendPercent == nil)
    }

    @Test func reducedActivityGetsABoundedOptionalStepAndNoCatchUp() {
        let result = snapshot((-14 ... -8).map { day($0, 9_000) } + (-7 ... -1).map { day($0, 4_000) } + [day(0, 2_000)])
        #expect(result.situation == .easing)
        #expect(result.suggestedSteps == 500)
        let close = snapshot([day(0, 7_950)])
        #expect(close.situation == .nearGoal)
        #expect(close.suggestedSteps == 50)
        #expect(snapshot([day(0, 0)]).todaySteps == 0)
    }

    @Test func nightDoesNotPromptExtraEffortAndAchievementAlwaysCelebrates() {
        let late = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: now)!
        let result = snapshot([day(0, 7_950)], at: late)
        #expect(result.situation == .evening)
        #expect(result.suggestedSteps == nil)
        #expect(snapshot([day(0, 8_000)], at: late).situation == .achieved)
    }

    @Test(arguments: [8_000, 9_000, 12_501])
    func goalMilestonesHaveDistinctEncouragements(goal: Int) {
        var goals = GoalHistory()
        goals.set(goal, on: now, calendar: calendar)
        let near = Int(ceil(Double(goal) * 0.8))
        let far = Int(ceil(Double(goal) * 1.5))
        #expect(snapshot([day(0, near - 1)], goals: goals).situation == .starting)
        for steps in [near, goal - 1] {
            let result = snapshot([day(0, steps)], goals: goals)
            #expect(result.situation == .nearGoal)
            #expect(result.remaining == goal - steps)
            #expect(result.suggestedSteps == min(1_000, goal - steps))
        }
        let late = calendar.date(bySettingHour: 22, minute: 30, second: 0, of: now)!
        for at in [now, late] {
            for (steps, expected) in [(goal, MotivationSituation.achieved), (goal + 1, .exceeded),
                                      (far - 1, .exceeded), (far, .farExceeded), (goal * 2, .farExceeded)] {
                let result = snapshot([day(0, steps)], goals: goals, at: at)
                #expect(result.situation == expected)
                #expect(result.remaining == 0)
                #expect(result.suggestedSteps == nil)
            }
        }
        // Crossing the goal must invalidate the wording even within one step band.
        let reachedKey = snapshot([day(0, goal)], goals: goals).wordingKey(locale: "fr", now: now, calendar: calendar)
        let exceededKey = snapshot([day(0, goal + 1)], goals: goals).wordingKey(locale: "fr", now: now, calendar: calendar)
        #expect(reachedKey != exceededKey)
    }

    @Test func sameTimePaceRequiresRecentReliableMeasurements() {
        #expect(snapshot([day(0, 5_000)], detail: detail()).pace == .ahead)
        #expect(snapshot([day(0, 3_000)], detail: detail()).pace == .behind)
        #expect(snapshot([day(0, 4_100)], detail: detail()).pace == .similar)
        #expect(snapshot([day(0, 5_000)], detail: detail(count: 2)).pace == nil)
        #expect(snapshot([day(0, 5_000)], detail: detail(sampledAt: now.addingTimeInterval(-7_201))).pace == nil)
        #expect(snapshot([day(0, 5_000)], detail: detail(sampledAt: now.addingTimeInterval(1))).pace == nil)
        #expect(snapshot([], detail: detail()).pace == nil)
        var wrongClockTime = detail()
        wrongClockTime.sampledAt = now.addingTimeInterval(-3_600)
        #expect(snapshot([day(0, 5_000)], detail: wrongClockTime).pace == nil)
    }

    func time(_ hour: Int, minute: Int = 0) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now)!
    }

    @Test func morningCombinesReliablePaceWithGoalProgress() {
        let morning = time(10)
        for (steps, reference, expected) in [
            (6_600, 2_200, MotivationContext.morningFarAheadNearGoal),
            (6_599, 2_200, .morningAheadNearGoal),
            (6_600, 6_500, .morningNearGoal),
            (3_000, 1_000, .morningFarAhead),
            (2_999, 1_000, .morningAhead),
            (1_000, 100, .morningAhead),
            (1_000, 0, .morningAhead)
        ] {
            let result = snapshot([day(0, steps)], detail: detail(reference: reference, sampledAt: morning), at: morning)
            #expect(result.context == expected)
            #expect(result.timeOfDay == .morning)
        }
        for (steps, expected) in [(8_000, MotivationContext.morningAchieved),
                                   (8_001, .morningExceeded), (12_000, .morningFarExceeded)] {
            let result = snapshot([day(0, steps)], at: morning)
            #expect(result.context == expected)
            #expect(result.suggestedSteps == nil)
        }
    }

    @Test func contextCombinesWeeklyProgressConsistencyAndTimeOfDay() {
        let progressing = (-14 ... -8).map { day($0, 5_000) } + (-7 ... -1).map { day($0, 6_000) }
        let consistent = (-7 ... -1).map { day($0, 8_000) }
        let growing = snapshot(progressing + [day(0, 5_000)], detail: detail())
        #expect(growing.context == .progressingAhead)
        #expect(snapshot(progressing + [day(0, 5_000)]).context == nil)
        #expect(snapshot(consistent + [day(0, 6_600)]).context == .consistentNearGoal)
        #expect(snapshot(consistent + [day(0, 8_000)]).context == .consistentAchieved)
        #expect(snapshot([day(-1, 8_000), day(0, 8_000)]).context == nil)
        #expect(snapshot([day(0, 6_600)], detail: detail()).context == .aheadNearGoal)
        #expect(snapshot([day(0, 5_000)], detail: detail()).context == .ahead)
        #expect(snapshot([day(0, 3_000)], detail: detail()).context == .behindGentle)
        let easing = (-14 ... -8).map { day($0, 9_000) } + (-7 ... -1).map { day($0, 4_000) }
        #expect(snapshot(easing + [day(0, 2_000)]).context == nil)
        for (hour, expected) in [(6, MotivationContext.morningStarting), (11, .morningStarting),
                                (12, .afternoonSteady), (17, .afternoonSteady),
                                (18, .eveningSteady), (21, .eveningSteady)] {
            #expect(snapshot([day(0, 2_000)], at: time(hour)).context == expected)
        }
        #expect(snapshot([day(0, 6_600)], at: time(20)).context == .eveningNearGoal)
        for hour in [0, 5, 22, 23] {
            let result = snapshot([day(0, 6_600)], at: time(hour))
            #expect(result.context == nil)
            #expect(result.situation == .evening)
            #expect(result.suggestedSteps == nil)
        }
    }

    @Test func unreliableHourlyDataNeverProducesPaceClaims() {
        let morning = time(10)
        var wrongEndpoint = detail(reference: 2_200, sampledAt: morning)
        wrongEndpoint.sampledAt = morning.addingTimeInterval(-3_600)
        for hourly in [nil, detail(reference: 2_200, count: 2, sampledAt: morning),
                       detail(reference: 2_200, sampledAt: morning.addingTimeInterval(-7_201)),
                       detail(reference: 2_200, sampledAt: morning.addingTimeInterval(1)), wrongEndpoint] {
            let result = snapshot([day(0, 6_600)], detail: hourly, at: morning)
            #expect(result.pace == nil)
            #expect(result.context == .morningNearGoal)
        }
        let empty = snapshot([], detail: detail(reference: 2_200, sampledAt: morning), at: morning)
        #expect(empty.context == nil)
        #expect(empty.messageKey == "motivation.message.noData")
    }

    @Test func contextualWordingInvalidatesAtRatioAndTimeBoundaries() {
        let morning = time(10)
        let hourly = detail(reference: 2_200, sampledAt: morning)
        let before = snapshot([day(0, 6_599)], detail: hourly, at: morning)
        let after = snapshot([day(0, 6_600)], detail: hourly, at: morning)
        #expect(before.wordingKey(locale: "fr", now: morning, calendar: calendar) !=
                after.wordingKey(locale: "fr", now: morning, calendar: calendar))
        #expect(before.situation == after.situation)
        #expect(before.pace == after.pace)
        #expect(before.messageKey != after.messageKey)
        let noon = time(12)
        let atNoon = snapshot([day(0, 6_600)], detail: hourly, at: noon)
        #expect(atNoon.context == .aheadNearGoal)
        let stale = snapshot([day(0, 6_600)], detail: hourly, at: noon.addingTimeInterval(1))
        #expect(stale.context == nil)
        #expect(stale.messageKey == "motivation.message.nearGoal")
    }

    @Test func calendarWindowsSurviveDaylightSavingAndDeduplicateDays() {
        let dstNow = ISO8601DateFormatter().date(from: "2026-10-26T12:00:00Z")!
        let start = calendar.startOfDay(for: dstNow)
        let previous = calendar.date(byAdding: .day, value: -1, to: start)!
        let result = snapshot([.init(date: previous, steps: 8_000), .init(date: previous, steps: 9_000)], at: dstNow)
        #expect(result.recentDays == 1)
        #expect(result.recentAverage == 9_000)
    }

    @Test func wordingCacheChangesForMeaningfulProgressLanguageGoalAndMidnight() {
        func key(_ steps: Int, locale: String = "fr_FR", goals: GoalHistory = .init(), at: Date? = nil) -> MotivationWordingKey {
            snapshot([day(0, steps)], goals: goals, at: at).wordingKey(locale: locale, now: at ?? now, calendar: calendar)
        }
        #expect(key(5_001) == key(5_200))
        #expect(key(5_001) != key(5_500))
        #expect(key(5_001) != key(5_001, locale: "en_US"))
        var goals = GoalHistory()
        goals.set(9_000, on: now, calendar: calendar)
        #expect(key(5_001) != key(5_001, goals: goals))
        #expect(key(5_001) != key(5_001, at: calendar.date(byAdding: .day, value: 1, to: now)!))
    }

    @Test func generatedCopyRejectsDigitsLinksMarkupAndLongContent() {
        #expect(MotivationTextValidation.accepted("Chaque petit pas compte.") != nil)
        for invalid in ["Marche 1000 pas.", "Marche ١٠٠ pas.", "Voir https://example.com", "Voir HTTPS://EXAMPLE.COM", "**Chaque pas compte**",
                        "Première phrase. Deuxième phrase.", "Une phrase\npuis une autre", String(repeating: "a", count: 181)] {
            #expect(MotivationTextValidation.accepted(invalid) == nil)
        }
    }
}
