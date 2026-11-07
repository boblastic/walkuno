import Foundation
import Testing
@testable import WalkunoCore

struct PreferencesTests {
    @Test func addingActivityGoalsPreservesLegacyPreferencesAndStepHistory() throws {
        var original = Preferences()
        original.goals.set(11_500)
        original.unit = .miles
        original.theme = .violet
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        legacy.removeValue(forKey: "activityGoals")
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(restored == original)
        #expect(restored.goal(for: .steps) == 11_500)
        #expect(restored.goal(for: .distance) == 5_000)
        #expect(restored.goal(for: .energy) == 400)
        #expect(restored.goal(for: .exerciseTime) == 30)
        #expect(restored.goal(for: .floors) == 10)
    }

    @Test func metricGoalsPersistIndependentlyAndDistanceDoesNotChangeWithDisplayUnits() throws {
        var preferences = Preferences()
        preferences.goals.set(12_000)
        for (metric, value): (ActivityMetric, Double) in [(.distance, 3 * 1_609.344), (.energy, 650), (.exerciseTime, 45), (.floors, 15)] {
            preferences.activityGoals.set(value, for: metric)
        }
        preferences.unit = .miles
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
        #expect(restored == preferences)
        #expect(restored.unit.convert(meters: restored.goal(for: .distance)) == 3)
        #expect(restored.goal(for: .steps) == 12_000)
        #expect(restored.goal(for: .energy) == 650)
        #expect(restored.goal(for: .exerciseTime) == 45)
        #expect(restored.goal(for: .floors) == 15)
        let settings = try JSONDecoder().decode(WatchSettings.self, from: JSONEncoder().encode(WatchSettings(preferences: restored)))
        #expect(settings.activityGoals == restored.activityGoals)
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        legacy.removeValue(forKey: "activityGoals")
        let oldWatch = try JSONDecoder().decode(WatchSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(oldWatch.activityGoals == nil)
        #expect(oldWatch.goals == restored.goals)
    }

    @Test func invalidGoalsAreRejectedAndPartialSavedGoalsUseDefaults() throws {
        var goals = ActivityGoals()
        for metric in ActivityMetric.allCases where metric != .steps {
            for invalid in [0, -1, .infinity, .nan, metric.goalRange.upperBound + 1] {
                goals.set(invalid, for: metric)
                #expect(goals.value(for: metric) == metric.defaultGoal)
            }
        }
        goals.set(15.5, for: .exerciseTime)
        #expect(goals.value(for: .exerciseTime) == 30)
        goals.set(5_123.45, for: .distance)
        #expect(goals.value(for: .distance) == 5_123.45)
        let saved = Data(#"{"distance":7000,"energy":0,"floors":2.5}"#.utf8)
        let restored = try JSONDecoder().decode(ActivityGoals.self, from: saved)
        #expect(restored.value(for: .distance) == 7_000)
        #expect(restored.value(for: .energy) == 400)
        #expect(restored.value(for: .exerciseTime) == 30)
        #expect(restored.value(for: .floors) == 10)
    }

    @Test func statisticsWidgetChoicesSurviveSavingIncludingAllHidden() throws {
        for hidden in [Set<StatisticsWidget>([.clock, .history]), Set(StatisticsWidget.allCases)] {
            var original = Preferences()
            original.goals.set(12_000)
            original.statisticsWidgets = .init(order: [.records, .trends, .day, .history, .clock], hidden: hidden)
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(original))
            #expect(restored == original)
            #expect(restored.statisticsWidgets.visible == original.statisticsWidgets.order.filter { !hidden.contains($0) })
        }
    }

    @Test func addingStatisticsLayoutPreservesExistingPreferences() throws {
        var original = Preferences()
        original.goals.set(11_500)
        original.theme = .violet
        original.language = .french
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        legacy.removeValue(forKey: "statisticsWidgets")
        #expect(try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy)) == original)
    }

    @Test func statisticsLayoutRecoversMissingDuplicateAndFutureWidgets() throws {
        var original = Preferences()
        original.unit = .miles
        var saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(original)) as? [String: Any])
        saved["statisticsWidgets"] = ["order": ["records", "future-widget", "records", "day"],
                                      "hidden": ["clock", "future-widget"]]
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: saved))
        #expect(restored.unit == .miles)
        #expect(restored.statisticsWidgets.order == [.dailyGoal, .records, .day, .clock, .trends, .history])
        #expect(restored.statisticsWidgets.hidden == [.clock])
    }

    @Test func dailyGoalIsInsertedFirstInLegacyLayoutsAndCanBeReordered() throws {
        let legacy = Data(#"{"order":["records","day","clock","trends","history"],"hidden":["day","history"]}"#.utf8)
        let restored = try JSONDecoder().decode(StatisticsWidgetLayout.self, from: legacy)
        #expect(restored.order == [.dailyGoal, .records, .day, .clock, .trends, .history])
        #expect(restored.hidden == [.day, .history])
        #expect(restored.visible.first == .dailyGoal)
        let customized = StatisticsWidgetLayout(order: [.clock, .dailyGoal], hidden: [.dailyGoal])
        let saved = try JSONDecoder().decode(StatisticsWidgetLayout.self, from: JSONEncoder().encode(customized))
        #expect(saved == customized)
        #expect(saved.order.prefix(2) == [.clock, .dailyGoal])
        #expect(!saved.visible.contains(.dailyGoal))
    }

    @Test func watchSettingsCarryEveryCounterStyleAndEffect() throws {
        for style in CounterStyle.allCases {
            for effect in CounterEffect.allCases {
                var preferences = Preferences()
                preferences.goals.set(12_000)
                preferences.theme = .violet
                preferences.unit = .miles
                preferences.counterStyle = style
                preferences.counterEffect = effect
                let settings = WatchSettings(preferences: preferences)
                let decoded = try JSONDecoder().decode(WatchSettings.self, from: JSONEncoder().encode(settings))
                #expect(decoded == settings)
                #expect(decoded.counterStyle == style)
                #expect(decoded.counterEffect == effect)
                #expect(decoded.goals.value(on: .now) == 12_000)
                #expect(decoded.theme == .violet)
                #expect(decoded.unit == .miles)
            }
        }
    }

    @Test func legacyWatchSettingsKeepGoalsWithoutRequiringACounterChoice() throws {
        var preferences = Preferences()
        preferences.goals.set(9_500)
        let settings = WatchSettings(preferences: preferences)
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as? [String: Any])
        legacy.removeValue(forKey: "counterStyle")
        legacy.removeValue(forKey: "counterEffect")
        let decoded = try JSONDecoder().decode(WatchSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(decoded.goals == preferences.goals)
        #expect(decoded.theme == preferences.theme)
        #expect(decoded.unit == preferences.unit)
        #expect(decoded.counterStyle == nil)
        #expect(decoded.counterEffect == nil)
    }

    @Test func appLanguageFollowsPreferredLanguagesAndFallsBackToEnglish() {
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: ["fr-FR"]) == "fr")
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: ["pt-BR"]) == "pt")
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: ["nl-NL", "de-DE", "fr-FR"]) == "de")
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: ["zh-Hans", "ko-KR"]) == "en")
        #expect(AppLanguage.system.resolvedCode(preferredLanguages: []) == "en")
        for language in AppLanguage.allCases where language != .system {
            #expect(language.resolvedCode(preferredLanguages: ["fr-FR"]) == language.rawValue)
        }
    }

    @Test func appLanguageChoiceSurvivesSaving() throws {
        for language in AppLanguage.allCases {
            var preferences = Preferences()
            preferences.language = language
            preferences.unit = .miles
            preferences.goals.set(9_500)
            #expect(try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences)) == preferences)
        }
    }

    @Test func legacyAndUnknownLanguagesUseThePhoneWithoutResettingPreferences() throws {
        var preferences = Preferences()
        preferences.theme = .violet
        preferences.goals.set(12_000)
        var legacy = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(preferences)) as? [String: Any])
        legacy.removeValue(forKey: "language")
        #expect(try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy)) == preferences)
        legacy["language"] = "future-language"
        #expect(try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy)) == preferences)
    }

    @Test func counterChoicesPreservePreferencesAcrossSaving() throws {
        for style in CounterStyle.allCases {
            var original = Preferences()
            original.counterStyle = style
            original.theme = .violet
            original.goals.set(11_500)
            original.onboardingComplete = true
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(original))
            #expect(restored == original)
        }
        // "minimal" was saved by the previous two-style selector.
        #expect(try JSONDecoder().decode(CounterStyle.self, from: Data("\"minimal\"".utf8)) == .minimal)
    }

    @Test func effectChoiceSurvivesSavingAndLegacyPreferencesKeepStars() throws {
        for effect in CounterEffect.allCases {
            var original = Preferences()
            original.counterEffect = effect
            original.counterStyle = .path
            original.theme = .violet
            let encoded = try JSONEncoder().encode(original)
            #expect(try JSONDecoder().decode(Preferences.self, from: encoded) == original)
            var legacy = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
            legacy.removeValue(forKey: "counterEffect")
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
            #expect(restored.counterEffect == .stars)
            #expect(restored.counterStyle == .path)
            #expect(restored.theme == .violet)
            legacy["counterEffect"] = "future-effect"
            #expect(try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy)).counterEffect == .stars)
        }
    }

    @Test func retiredPeriodAnimationSettingPreservesExistingPreferences() throws {
        var original = Preferences()
        original.goals.set(12_000)
        original.theme = .coral
        original.unit = .miles
        original.appearance = .light
        original.counterStyle = .minimal
        original.glassTransparency = 0.35
        original.onboardingComplete = true
        original.healthRequested = true
        let encoded = try JSONEncoder().encode(original)
        var legacy = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        for enabled in [false, true] {
            legacy["animatePeriodChanges"] = enabled
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
            #expect(restored == original)
            let saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
            #expect(saved["animatePeriodChanges"] == nil)
        }
    }

    @Test func retiredEnergySettingIsIgnoredWithoutLosingPreferences() throws {
        var original = Preferences()
        original.goals.set(12_000)
        original.theme = .glacier
        original.unit = .miles
        original.onboardingComplete = true
        let encoded = try JSONEncoder().encode(original)
        var legacy = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy["showEnergy"] = false

        let restored = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(restored == original)
        let saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(restored)) as? [String: Any])
        #expect(saved["showEnergy"] == nil)
    }

    @Test func addingGlassPreservesExistingPreferences() throws {
        var original = Preferences()
        original.goals.set(12_000)
        original.theme = .glacier
        original.unit = .miles
        original.appearance = .light
        original.counterStyle = .minimal
        original.onboardingComplete = true
        original.healthRequested = true
        let encoded = try JSONEncoder().encode(original)
        var legacy = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        legacy.removeValue(forKey: "glassTransparency")

        let restored = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(restored == original)
        #expect(restored.glassTransparency == 0.7)
    }

    @Test func transparencySurvivesSavingAndIsBoundedWhenLoaded() throws {
        for level in [0.0, 0.35, 1.0] {
            var preferences = Preferences()
            preferences.glassTransparency = level
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
            #expect(restored.glassTransparency == level)
        }
        for (stored, expected) in [(-0.5, 0.0), (1.5, 1.0)] {
            var preferences = Preferences()
            preferences.glassTransparency = stored
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
            #expect(restored.glassTransparency == expected)
        }
    }
}
