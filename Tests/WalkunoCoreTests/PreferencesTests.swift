import Foundation
import Testing
@testable import WalkunoCore

struct PreferencesTests {
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
        #expect(!restored.animatePeriodChanges)
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
        #expect(restored.glassTransparency == 0.6)
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
