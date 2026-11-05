import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var goal = 8000
    @State private var connecting = false
    private var theme: WalkunoTheme { model.effectiveTheme }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 30) {
                Text("\(step + 1) / 4").font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                ZStack {
                    ProgressRing(progress: step == 0 ? 0.8 : Double(step + 1) / 4,
                                 accent: theme.tint(for: scheme), secondaryAccent: theme.secondaryTint(for: scheme))
                    if step == 0 {
                        BrandMark(size: 96, theme: theme)
                    } else {
                        Image(systemName: ["heart.fill", "scope", "paintpalette.fill"][step - 1])
                            .font(.system(size: 64, weight: .medium))
                            .foregroundStyle(theme.tint(for: scheme))
                    }
                }.frame(width: 200, height: 200).frame(maxWidth: .infinity).padding(.vertical, 24)
                Text(L("onboarding.\(step).title")).font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text(L("onboarding.\(step).body")).font(.body).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if step == 1 {
                    VStack(alignment: .leading, spacing: 16) {
                        Label("onboarding.permission.steps", systemImage: "shoeprints.fill")
                        Label("onboarding.permission.distance", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        Label("onboarding.permission.energy", systemImage: "flame")
                        Text("onboarding.readonly").font(.caption).foregroundStyle(.secondary)
                    }.font(.subheadline)
                }
                if step == 2 {
                    Text(goal.formatted()).font(.system(size: 56, weight: .bold, design: .rounded)).frame(maxWidth: .infinity)
                    Stepper("goal.title", value: $goal, in: 500...100_000, step: 500)
                    Text("goal.note").font(.caption).foregroundStyle(.secondary)
                }
                if step == 3 {
                    HStack(spacing: 14) {
                        ForEach(Appearance.allCases, id: \.self) { appearance in
                            Button {
                                model.preferences.appearance = appearance
                            } label: {
                                VStack(spacing: 10) {
                                    Image(systemName: appearance == .dark ? "moon.fill" : appearance == .light ? "sun.max.fill" : "circle.lefthalf.filled").font(.title2)
                                    Text(L("appearance.\(appearance.rawValue)")).font(.caption)
                                }.frame(maxWidth: .infinity, minHeight: 80).padding(8)
                                    .background(theme.tint(for: scheme).opacity(model.preferences.appearance == appearance ? 0.2 : 0.04), in: RoundedRectangle(cornerRadius: 18))
                            }.buttonStyle(.plain)
                                .accessibilityAddTraits(model.preferences.appearance == appearance ? [.isSelected] : [])
                        }
                    }
                    Text("onboarding.themes.note").font(.caption).foregroundStyle(.secondary)
                }
                if let error = model.errorMessage { Text(error).font(.caption).foregroundStyle(.secondary) }
                Button {
                    if step == 1 {
                        connecting = true
                        Task {
                            await model.connectHealth()
                            connecting = false
                            advance()
                        }
                    } else { advance() }
                } label: {
                    HStack {
                        if connecting { ProgressView() }
                        Text(L(step == 3 ? "onboarding.start" : step == 1 ? "health.connect" : "common.continue"))
                        Image(systemName: "arrow.right")
                    }.font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                }.buttonStyle(.borderedProminent).tint(WalkunoStyle.electric).foregroundStyle(WalkunoStyle.ink).disabled(connecting)
                if step == 1 {
                    Button("onboarding.later") { advance() }.frame(maxWidth: .infinity).font(.subheadline).padding(.vertical, 8)
                }
                Text("onboarding.footer").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }.padding(28)
        }.background(WalkunoStyle.background(scheme))
    }

    private func advance() {
        if step == 3 {
            model.preferences.goals.set(goal)
            model.preferences.onboardingComplete = true
            model.persist()
        } else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { step += 1 }
        }
    }
}
