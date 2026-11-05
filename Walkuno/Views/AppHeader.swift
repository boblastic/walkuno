import SwiftUI

/// The same fixed header sits above every app screen, including presented details.
private struct AppHeaderModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var accountIsCurrent: Bool
    @State private var showAccount = false

    func body(content: Content) -> some View {
        ZStack {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Reserve the header's height during layout and let content scroll behind its glass.
        .safeAreaInset(edge: .top, spacing: 0) {
            AppHeader(accountIsCurrent: accountIsCurrent) { showAccount = true }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 10)
        }
        .background(WalkunoStyle.background(scheme).ignoresSafeArea())
        .sheet(isPresented: $showAccount) { AccountView() }
    }
}

extension View {
    /// Apply to screen content inside a NavigationStack, below its system navigation controls.
    func appHeader(accountIsCurrent: Bool = false) -> some View {
        modifier(AppHeaderModifier(accountIsCurrent: accountIsCurrent))
    }
}

private struct AppHeader: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    var accountIsCurrent: Bool
    var onAccount: () -> Void

    private var ink: Color { model.effectiveTheme.tint(for: scheme) }

    var body: some View {
        HStack(spacing: 10) {
            ViewThatFits(in: .horizontal) {
                identity(showName: true)
                identity(showName: false)
            }
            Spacer(minLength: 0)
            Button(action: onAccount) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 25, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(ink.opacity(0.08), in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(ink)
            .accessibilityLabel(Text("account.title"))
            .accessibilityIdentifier("app.account")
            .disabled(accountIsCurrent)
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background { WalkunoGlassSurface() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app.header")
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

struct GlassSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var isAdjustingTransparency = false
    private var systemOverridesTransparency: Bool { reduceTransparency || contrast == .increased }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
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
        } header: {
            Text("Liquid Glass")
        } footer: {
            Text(systemOverridesTransparency ? "settings.glass.accessibility" : "settings.glass.note")
        }
    }
}
