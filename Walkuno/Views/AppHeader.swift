import SwiftUI

/// The same fixed header sits above every app screen, including presented details.
private struct AppHeaderModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Reserve the header's height during layout and let content scroll behind its glass.
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader()
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .background(WalkunoStyle.background(scheme).ignoresSafeArea())
    }
}

extension View {
    /// Apply to screen content inside a NavigationStack, below its system navigation controls.
    func appHeader() -> some View {
        modifier(AppHeaderModifier())
    }
}

private struct AppHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var showsStreak = false

    private var ink: Color { model.effectiveTheme.tint(for: scheme) }
    private var streak: Int? {
        ActivityMath.currentStreak(days: model.days, goals: model.preferences.goals, endingOn: model.today.date)
    }
    private var streakSymbol: String { model.effectiveEffect == .fire ? "flame.fill" : "star.fill" }

    var body: some View {
        HStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                identity(showName: true)
                identity(showName: false)
            }
            Spacer(minLength: 0)
            streakBadge
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background { WalkunoGlassSurface() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app.header")
    }

    private var streakBadge: some View {
        Button {
            showsStreak = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: streakSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(model.effectiveTheme.accent.gradient)
                    .accessibilityHidden(true)
                Text(stepsText(streak))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ink)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(ink.opacity(0.08), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("today.streak"))
        .accessibilityValue(Text(stepsText(streak)))
        .accessibilityHint(Text("streak.hint"))
        .accessibilityIdentifier("app.streak")
        .popover(isPresented: $showsStreak, arrowEdge: .top) {
            StreakPopover(streak: streak, symbol: streakSymbol)
                .presentationCompactAdaptation(.popover)
        }
    }

    private func identity(showName: Bool) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                BrandMark(size: 22, theme: model.effectiveTheme)
                if showName {
                    Text("Walkuno").font(.system(.title3, design: .rounded, weight: .bold)).tracking(-0.5)
                }
            }
            .foregroundStyle(ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Walkuno")
            .accessibilityIdentifier("app.brand")

            Text(L(model.purchases.isPremium ? "subscription.pro" : "subscription.free"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(model.purchases.isPremium ? ink : Color.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .overlay {
                    Capsule().strokeBorder(model.purchases.isPremium ? ink.opacity(0.45) : Color.primary.opacity(0.2), lineWidth: 1)
                }
                .accessibilityIdentifier("app.subscription")
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

private struct StreakPopover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let streak: Int?
    let symbol: String

    private var ink: Color { model.effectiveTheme.tint(for: scheme) }
    private var encouragement: String {
        guard let streak else { return "streak.encouragement.unavailable" }
        switch streak {
        case 0: return "streak.encouragement.zero"
        case 1: return "streak.encouragement.one"
        case 2..<7: return "streak.encouragement.few"
        default: return "streak.encouragement.many"
        }
    }

    private var detail: String {
        guard let streak else { return L("streak.detail.unavailable") }
        switch streak {
        case 0: return L("streak.detail.zero")
        case 1: return L("streak.detail.one")
        default: return String(format: L("streak.detail.many"), stepsText(streak))
        }
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
                .scrollBounceBehavior(.basedOnSize)
        }
        .frame(width: 300)
        .background(WalkunoStyle.card(scheme))
        .accessibilityIdentifier("streak.popover")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .top, spacing: 8) {
                    Text("streak.title")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityAddTraits(.isHeader)
                        .padding(.top, 8)
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(.caption, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(.primary.opacity(0.06), in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("streak.close"))
                    .accessibilityIdentifier("streak.close")
                }
                Text("streak.intro")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(model.effectiveTheme.accent.gradient)
                    .frame(width: 64, height: 64)
                    .background(ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 0) {
                    Text(stepsText(streak))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                        .accessibilityIdentifier("streak.count")
                    Text(streak == 1 || streak == 0 ? "streak.unit.one" : "streak.unit.many")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            Text(detail)
                .font(.subheadline)
                .accessibilityIdentifier("streak.detail")

            if let streak, streak > 0 {
                let goalReached = (model.today.steps ?? 0) >= model.preferences.goals.value(on: model.today.date)
                Text(goalReached ? "streak.today.complete" : "streak.today.continue")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles").accessibilityHidden(true)
                Text(LocalizedStringKey(encouragement))
                    .accessibilityIdentifier("streak.encouragement")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(ink)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
        }
        .padding(20)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Shared glass for fixed controls, with the app's transparency and iOS accessibility settings.
struct WalkunoGlassSurface: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    private let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
    private var transparency: Double {
        reduceTransparency || contrast == .increased ? 0 : min(max(model.preferences.glassTransparency, 0), 1)
    }

    var body: some View {
        Group {
            if transparency == 0 {
                shape.fill(WalkunoStyle.card(scheme))
            } else if #available(iOS 26.0, *) {
                // The backing veil changes opacity without fading the text or hit targets.
                Color.clear
                    .glassEffect(.regular, in: shape)
                    .overlay { shape.fill(WalkunoStyle.card(scheme).opacity(1 - transparency)) }
            } else {
                shape.fill(.ultraThinMaterial)
                    .overlay { shape.fill(WalkunoStyle.card(scheme).opacity(1 - transparency)) }
            }
        }
        .overlay {
            shape.strokeBorder(.linearGradient(colors: [.white.opacity(scheme == .dark ? 0.24 : 0.8),
                                                       .primary.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .shadow(color: .black.opacity(scheme == .dark ? 0.16 : 0.06), radius: 16, y: 6)
        .allowsHitTesting(false)
    }
}

struct GlassSettingsControls: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isAdjustingTransparency = false
    private var systemOverridesTransparency: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        Group {
            VStack(alignment: .leading, spacing: 12) {
                Text("Liquid Glass").font(.headline)
                LabeledContent("settings.glass.transparency", value: model.preferences.glassTransparency.formatted(.percent.precision(.fractionLength(0))))
                Slider(value: Binding(get: { model.preferences.glassTransparency }, set: {
                    model.preferences.glassTransparency = $0
                    // Accessibility adjustments can change the value without a drag session.
                    if !isAdjustingTransparency { model.persist(sync: false) }
                }), in: 0...1) {
                    Text("settings.glass.transparency")
                } onEditingChanged: { isEditing in
                    isAdjustingTransparency = isEditing
                    if !isEditing { model.persist(sync: false) }
                }
                .sensoryFeedback(.selection, trigger: isAdjustingTransparency) { wasEditing, isEditing in
                    wasEditing && !isEditing
                }
                .accessibilityValue(Text(model.preferences.glassTransparency.formatted(.percent.precision(.fractionLength(0)))))
                .accessibilityIdentifier("settings.glass.transparency")
                .disabled(systemOverridesTransparency)
                HStack {
                    Text("settings.glass.opaque")
                    Spacer()
                    Text("settings.glass.transparent")
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(.vertical, 4)
            if systemOverridesTransparency {
                Text("settings.glass.accessibility")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
