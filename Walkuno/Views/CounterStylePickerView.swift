import SwiftUI

struct CounterStylePickerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var preview: CounterStyle?
    @State private var showPremium = false
    @State private var previewEffect: CounterEffect?
    @State private var replayCounter = 0

    private var style: CounterStyle { preview ?? model.effectiveCounter }
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private var effect: CounterEffect { previewEffect ?? model.effectiveEffect }
    private var isLocked: Bool { (style.requiresPremium || effect.requiresPremium) && !model.purchases.isPremium }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        HStack {
                            Text("counter.preview").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Spacer()
                            Text(LocalizedStringKey(model.effectiveTheme.titleKey))
                                .font(.caption.weight(.medium)).foregroundStyle(accent)
                                .lineLimit(1).minimumScaleFactor(0.6)
                        }
                        AnimatedStepCounter(steps: 6240, goal: 8000, title: L("tab.today"),
                                            theme: model.effectiveTheme, style: style, effect: effect,
                                            replay: "\(style.rawValue)-\(effect.rawValue)-\(replayCounter)",
                                            animateEntry: true, animateUpdates: true)
                            .id("\(style.rawValue)-\(effect.rawValue)-\(replayCounter)")
                            .frame(height: typeSize.isAccessibilitySize ? 320 : 232)
                            .background {
                                RadialGradient(colors: [accent.opacity(0.10), .clear], center: .center, startRadius: 15, endRadius: 170)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("counter.preview"))
                            .accessibilityValue(Text(LocalizedStringKey(style.titleKey)))
                            .accessibilityIdentifier("counter.preview")
                        Button { replayCounter += 1 } label: {
                            Label("counter.effect.replay", systemImage: "arrow.clockwise")
                                .font(.caption.weight(.semibold)).padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered).tint(accent)
                        .accessibilityIdentifier("counter.effect.replay")
                    }
                    .padding(18)
                    .background(WalkunoStyle.card(scheme), in: RoundedRectangle(cornerRadius: 28))
                    .id("counter.preview.card")

                    VStack(alignment: .leading, spacing: 12) {
                        Text("counter.effect.title").font(.headline)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(CounterEffect.allCases) { candidate in effectOption(candidate) }
                        }
                    }
                    VStack(spacing: 8) {
                        ForEach(CounterStyle.allCases) { candidate in
                            option(candidate)
                        }
                    }
                    if isLocked {
                        Button { showPremium = true } label: {
                            Label("counter.unlock", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 7)
                        }
                        .buttonStyle(.borderedProminent).tint(model.effectiveTheme.accent)
                        .foregroundStyle(WalkunoStyle.ink)
                        .accessibilityIdentifier("counter.unlock")
                    }
                    Text("counter.palette.note").font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center).padding(.horizontal, 8)
                }
                .padding(20)
            }
            .onChange(of: replayCounter) { _, _ in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    reader.scrollTo("counter.preview.card", anchor: .top)
                }
            }
            .onChange(of: preview) { _, _ in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                    reader.scrollTo("counter.preview.card", anchor: .top)
                }
            }
        }
        .background(WalkunoStyle.background(scheme))
        .navigationTitle("settings.counter")
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.selection, trigger: style)
        .sheet(isPresented: $showPremium) { PremiumView() }
        .onChange(of: model.purchases.isPremium) { _, premium in
            if premium {
                select(style)
                model.preferences.counterEffect = effect
                model.persist()
            } else {
                preview = model.effectiveCounter
                previewEffect = model.effectiveEffect
            }
        }
    }

    private func effectOption(_ candidate: CounterEffect) -> some View {
        let selected = candidate == effect
        let locked = candidate.requiresPremium && !model.purchases.isPremium
        return Button {
            previewEffect = candidate
            if !locked {
                model.preferences.counterEffect = candidate
                model.persist()
            }
            replayCounter += 1
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: candidate.symbol)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(candidate.previewGradient)
                    Spacer(minLength: 4)
                    Image(systemName: locked ? "lock.fill" : selected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected ? accent : Color.secondary.opacity(0.4))
                }
                Text(LocalizedStringKey(candidate.titleKey)).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(LocalizedStringKey(candidate.descriptionKey)).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).padding(14)
            .background(selected ? accent.opacity(0.10) : WalkunoStyle.card(scheme), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(selected ? accent.opacity(0.6) : .primary.opacity(0.06)))
            .contentShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(candidate.titleKey)))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("counter.effect.\(candidate.rawValue)")
    }

    private func select(_ candidate: CounterStyle) {
        preview = candidate
        if !candidate.requiresPremium || model.purchases.isPremium {
            model.preferences.counterStyle = candidate
            model.persist()
        }
    }

    private func option(_ candidate: CounterStyle) -> some View {
        let selected = candidate == model.effectiveCounter
        let highlighted = candidate == style
        let locked = candidate.requiresPremium && !model.purchases.isPremium
        return Button { select(candidate) } label: {
            HStack(spacing: 14) {
                Image(systemName: candidate.symbol)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(accent)
                    .frame(width: 42, height: 42)
                    .background(accent.opacity(highlighted ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text(LocalizedStringKey(candidate.titleKey)).font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(LocalizedStringKey(candidate.descriptionKey)).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : locked ? "lock.fill" : "circle")
                    .font(.system(size: selected ? 22 : 17, weight: .medium))
                    .foregroundStyle(selected ? accent : Color.secondary.opacity(0.55))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(highlighted ? accent.opacity(0.07) : WalkunoStyle.card(scheme), in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(highlighted ? accent.opacity(0.45) : .clear, lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(candidate.titleKey)))
        .accessibilityValue(Text(LocalizedStringKey(selected ? "counter.selected" : locked ? "premium.title" : "theme.available")))
        .accessibilityHint(Text(LocalizedStringKey(candidate.descriptionKey)))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("counter.style.\(candidate.rawValue)")
    }
}

extension CounterEffect {
    var titleKey: String { "counter.effect.\(rawValue)" }
    var descriptionKey: String { "counter.effect.\(rawValue).description" }
    var symbol: String {
        switch self {
        case .stars: "sparkles"
        case .fire: "flame.fill"
        case .aurora: "wind"
        case .liquid: "drop.fill"
        }
    }
    var previewGradient: LinearGradient {
        let colors: [Color] = switch self {
        case .stars: [.white, .mint]
        case .fire: [.yellow, .orange, .red]
        case .aurora: [.mint, .cyan, .purple]
        case .liquid: [.white, .cyan, .teal]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
