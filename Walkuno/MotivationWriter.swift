import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One bounded memory-only cache. No transcript, Health samples, disk writes or network tools.
@MainActor
final class MotivationWriter {
    private var cachedKey: MotivationWordingKey?
    private var cachedText: String?
    private var revision = 0

    func clear() {
        revision += 1
        cachedKey = nil
        cachedText = nil
    }

    func encouragement(for snapshot: MotivationSnapshot, key: MotivationWordingKey, isDemo: Bool) async -> String? {
        guard !isDemo, snapshot.todaySteps != nil else { return nil }
        if cachedKey == key { return cachedText }
        let token = revision
        var result: String?
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            if model.availability == .available, model.supportsLocale(Locale(identifier: key.locale)) {
                do {
                    try Task.checkCancellation()
                    let session = LanguageModelSession(model: model, instructions: """
                    Write one short, kind encouragement for a walking app, in locale \(key.locale).
                    In French, always use polite "vous" forms (vouvoiement), never "tu" forms.
                    Keep the tone warm and encouraging, without pressure.
                    Maximum 160 characters, one sentence, plain text, no heading or quotation marks.
                    Rephrase the supplied encouragement without adding facts, numbers (including spelled-out
                    quantities), targets, durations, health claims, comparisons, instructions or promises.
                    Preserve the supplied time-of-day, goal status and habitual-pace context when present.
                    Do not turn a past weekly trend into a claim about today's pace, or ask for more effort after success.
                    Never pressure, shame, diagnose, suggest catching up or increasing a goal.
                    The app displays all measurements and its optional action separately.
                    """)
                    // Only trusted, localized copy and categorical context enter the model.
                    // Raw Health history and personal identifiers never enter its transcript.
                    let prompt = """
                    Encouragement to rephrase: \(L(snapshot.messageKey))
                    Situation: \(snapshot.situation.rawValue)
                    Context: \(snapshot.context?.rawValue ?? "general")
                    Time of day: \(snapshot.timeOfDay.rawValue)
                    Recent trend: \(snapshot.trendPercent.map { $0 > 0 ? "increasing" : $0 < 0 ? "decreasing" : "stable" } ?? "insufficient history")
                    Same-time pace: \(snapshot.pace?.rawValue ?? "unavailable")
                    Preserve the meaning of the encouragement. Respond only in \(key.locale).
                    """
                    let response = try await session.respond(to: prompt, generating: WalkingEncouragement.self,
                                                             options: GenerationOptions(temperature: 0.4, maximumResponseTokens: 100))
                    try Task.checkCancellation()
                    result = MotivationTextValidation.accepted(response.content.encouragement)
                } catch {
                    // Unsupported language, refusal, model busy or any generation error uses local copy.
                }
            }
        }
        #endif
        guard !Task.isCancelled, revision == token else { return nil }
        cachedKey = key
        cachedText = result
        return result
    }
}

#if canImport(FoundationModels)
@available(iOS 26.0, *)
@Generable
private struct WalkingEncouragement {
    @Guide(description: "One brief, kind sentence preserving the supplied context, without numbers, new factual claims or extra suggested effort.")
    var encouragement: String
}
#endif
