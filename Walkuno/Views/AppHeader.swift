import SwiftUI

/// The same fixed header sits above every app screen, including presented details.
private struct AppHeaderModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var subscriptionLinkEnabled: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Reserve the header's height during layout and let content scroll behind its glass.
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(subscriptionLinkEnabled: subscriptionLinkEnabled)
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .background(WalkunoStyle.background(scheme).ignoresSafeArea())
    }
}

extension View {
    /// Apply to screen content inside a NavigationStack, below its system navigation controls.
    func appHeader(subscriptionLinkEnabled: Bool = true) -> some View {
        modifier(AppHeaderModifier(subscriptionLinkEnabled: subscriptionLinkEnabled))
    }
}

private struct AppHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var showsStreak = false
    @State private var showsPremium = false
    var subscriptionLinkEnabled: Bool

    private var ink: Color { model.effectiveTheme.tint(for: scheme) }
    private var streak: Int? {
        ActivityMath.currentStreak(days: model.days, goals: model.preferences.goals, endingOn: model.today.date)
    }

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
        .sheet(isPresented: $showsPremium) { PremiumView() }
    }

    private var streakBadge: some View {
        Button {
            showsStreak = true
        } label: {
            HStack(spacing: 5) {
                StreakStar(active: (streak ?? 0) > 0, theme: model.effectiveTheme, size: 15)
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
            StreakPopover(streak: streak)
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

            Button { showsPremium = true } label: {
                Text(L(model.purchases.isPremium ? "subscription.pro" : "subscription.free"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.purchases.isPremium ? ink : Color.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .overlay {
                        Capsule().strokeBorder(model.purchases.isPremium ? ink.opacity(0.45) : Color.primary.opacity(0.2), lineWidth: 1)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!subscriptionLinkEnabled)
            .accessibilityIdentifier("app.subscription")
        }
        .fixedSize(horizontal: true, vertical: false)
    }
}

/// A slow pearlescent glow marks an active streak, independently of the counter effect.
private struct StreakStar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    let active: Bool
    let theme: WalkunoTheme
    let size: CGFloat

    var body: some View {
        Group {
            if active {
                if !reduceMotion, scenePhase == .active {
                    PhaseAnimator([0.0, 1.0]) { phase in
                        glowingStar(phase: phase)
                    } animation: { _ in
                        .easeInOut(duration: 3.2)
                    }
                } else {
                    glowingStar(phase: 0.5)
                }
            } else {
                Image(systemName: "star")
                    .font(.system(size: size, weight: .medium))
                    .foregroundStyle(theme.accent.opacity(0.65))
            }
        }
        .frame(width: size + 4, height: size + 4)
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(true)
    }

    private var silhouette: some View {
        Image(systemName: "star.fill")
            .font(.system(size: size, weight: .medium))
            .frame(width: size + 4, height: size + 4)
    }

    private func glowingStar(phase: Double) -> some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [theme.accent.opacity(0.32), theme.secondaryAccent.opacity(0.12), .clear],
                                     center: .center, startRadius: 0, endRadius: size))
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(0.85 + phase * 0.15)
                .opacity(0.65 + phase * 0.35)

            silhouette
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.95), theme.accent, theme.secondaryAccent],
                                                startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    LinearGradient(stops: [.init(color: .clear, location: 0.2),
                                           .init(color: .white.opacity(0.7), location: 0.48),
                                           .init(color: .clear, location: 0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .offset(x: size * (phase - 0.5), y: size * (phase - 0.5) * 0.4)
                        .mask(silhouette)
                        .blendMode(.screen)
                }
                .shadow(color: theme.accent.opacity(0.35 + phase * 0.2), radius: 2 + phase * 2)
                .rotationEffect(.degrees((phase - 0.5) * 5))
                .scaleEffect(0.98 + phase * 0.04)
                .offset(y: (0.5 - phase) * 0.6)
        }
        .frame(width: size + 4, height: size + 4)
    }
}

private struct StreakPopover: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    let streak: Int?

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
        .accessibilityElement(children: .contain)
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
                StreakStar(active: (streak ?? 0) > 0, theme: model.effectiveTheme, size: 30)
                    .frame(width: 64, height: 64)
                    .background(ink.opacity(0.10), in: RoundedRectangle(cornerRadius: 22))
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
                HStack {
                    Text("Liquid Glass").font(.headline)
                    Spacer()
                    Text(model.preferences.glassTransparency.formatted(.percent.precision(.fractionLength(0))))
                        .monospacedDigit().foregroundStyle(.secondary)
                }
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
