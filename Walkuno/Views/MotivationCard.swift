import SwiftUI

struct MotivationCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TimelineView(.periodic(from: .now, by: 300)) { context in
            // A Health refresh can finish between two timeline ticks.
            let now = max(context.date, .now)
            MotivationCardContent(snapshot: model.motivationSnapshot(at: now), now: now)
        }
    }
}

private struct MotivationCardContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var generatedText: String?
    @State private var generatedKey: MotivationWordingKey?
    @State private var showExplanation = false
    let snapshot: MotivationSnapshot
    let now: Date

    private var key: MotivationWordingKey { snapshot.wordingKey(locale: AppLocalization.locale.identifier, now: now) }
    private var personalizedText: String? { generatedKey == key ? generatedText : nil }
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private func number(_ value: Int) -> String { value.formatted(.number.locale(AppLocalization.locale)) }
    private func formatted(_ key: String, _ values: CVarArg...) -> String {
        String(format: L(key), locale: AppLocalization.locale, arguments: values)
    }
    private var fact: String {
        guard let remaining = snapshot.remaining else { return L("motivation.fact.noData") }
        if remaining == 0 { return formatted("motivation.fact.achieved %@", number(snapshot.goal)) }
        return formatted("motivation.fact.remaining %@ %@", number(remaining), number(snapshot.goal))
    }

    var body: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("motivation.title", systemImage: "figure.walk")
                    .font(.headline).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 6) {
                    Text(fact).font(.subheadline.weight(.semibold))
                        .accessibilityIdentifier("motivation.fact")
                    Text(personalizedText ?? L("motivation.message.\(snapshot.situation.rawValue)"))
                        .font(.subheadline).foregroundStyle(.secondary)
                        .accessibilityIdentifier("motivation.message")
                }
                if let steps = snapshot.suggestedSteps {
                    Label(formatted("motivation.action %@", number(steps)), systemImage: "shoeprints.fill")
                        .font(.subheadline.weight(.medium)).foregroundStyle(accent)
                        .accessibilityIdentifier("motivation.action")
                }
                DisclosureGroup(isExpanded: $showExplanation) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(formatted("motivation.basis %ld %ld", snapshot.achievedDays, snapshot.recentDays))
                        if let average = snapshot.recentAverage {
                            Text(formatted("motivation.average %@ %ld", number(average), snapshot.recentDays))
                        }
                        if let trend = snapshot.trendPercent, let previous = snapshot.previousAverage {
                            Text(formatted("motivation.trend %@ %@ %ld", trend.formatted(.number.locale(AppLocalization.locale).sign(strategy: .always())),
                                           number(previous), snapshot.previousDays))
                        }
                        if let pace = snapshot.pace, let comparedAt = snapshot.comparedAt, let usual = snapshot.usualSteps {
                            Text(L("motivation.pace.\(pace.rawValue)"))
                            Text(formatted("motivation.sameTime %@ %@ %ld", comparedAt.appFormatted(date: .omitted, time: .shortened),
                                           number(usual), snapshot.baselineDays))
                        }
                        Text("motivation.history.note")
                        if model.usingCache { Text("today.cached") }
                        Text(L(personalizedText == nil ? "motivation.local" : "motivation.apple"))
                            .accessibilityIdentifier("motivation.source")
                        Text("motivation.privacy")
                    }
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("motivation.explanation")
                } label: {
                    Text("motivation.why").font(.caption.weight(.semibold))
                }
                .tint(accent)
                .accessibilityIdentifier("motivation.why")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today.motivation")
        .task(id: Request(key: key, isActive: scenePhase == .active, isDemo: model.isDemo)) {
            generatedText = nil
            generatedKey = nil
            guard scenePhase == .active else { return }
            let requestedKey = key
            let text = await model.motivationWriter.encouragement(for: snapshot, key: requestedKey, isDemo: model.isDemo)
            guard !Task.isCancelled else { return }
            generatedKey = requestedKey
            generatedText = text
        }
    }

    private struct Request: Equatable {
        var key: MotivationWordingKey
        var isActive: Bool
        var isDemo: Bool
    }
}
