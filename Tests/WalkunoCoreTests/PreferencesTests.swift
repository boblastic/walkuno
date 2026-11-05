import Foundation
import Testing
@testable import WalkunoCore

struct PreferencesTests {
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

    @Test func addingPeriodAnimationsPreservesExistingPreferences() throws {
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
        legacy.removeValue(forKey: "animatePeriodChanges")

        let restored = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        #expect(restored == original)
        #expect(restored.animatePeriodChanges)
    }

    @Test func periodAnimationChoiceSurvivesSaving() throws {
        for enabled in [false, true] {
            var preferences = Preferences()
            preferences.animatePeriodChanges = enabled
            let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
            #expect(restored.animatePeriodChanges == enabled)
        }
    }

    @Test func addingGlassPreservesExistingPreferences() throws {
        var original = Preferences()
        original.goals.set(12_000)
        original.theme = .glacier
        original.unit = .miles
        original.appearance = .light
        original.counterStyle = .minimal
        original.showEnergy = false
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
