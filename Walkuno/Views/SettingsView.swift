import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var showGoal = false
    @State private var showPremium = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var confirmReset = false
    @State private var showSubscriptions = false
    var body: some View {
        @Bindable var model = model
        Form {
            Section {
                Label("account.local", systemImage: "figure.walk.circle.fill").font(.headline)
                Text("account.local.note").font(.subheadline).foregroundStyle(.secondary)
            }
            Section {
                Button { showPremium = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "sparkles").font(.title2)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L(model.purchases.isPremium ? "premium.active" : "premium.title")).font(.headline)
                            Text("premium.settings.subtitle").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(); Image(systemName: "chevron.right").font(.caption)
                    }.padding(.vertical, 8)
                }
                .accessibilityIdentifier("settings.subscription")
            }
            Section("settings.daily") {
                Button { showGoal = true } label: { LabeledContent("goal.title", value: model.goal.formatted()) }
                Picker("settings.unit", selection: $model.preferences.unit) {
                    Text("unit.kilometers").tag(DistanceUnit.kilometers)
                    Text("unit.miles").tag(DistanceUnit.miles)
                }
                Toggle("settings.energy", isOn: $model.preferences.showEnergy)
            }
            Section {
                Picker("settings.language", selection: $model.preferences.language) {
                    Text("settings.language.system").tag(AppLanguage.system)
                    ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                        Text(verbatim: language.nativeName).tag(language)
                    }
                }
                .accessibilityIdentifier("settings.language")
            } footer: {
                Text("settings.language.note")
            }
            Section("settings.appearance") {
                NavigationLink {
                    ThemePaletteView().appHeader(settingsIsCurrent: true)
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(model.effectiveTheme.accent).frame(width: 22, height: 22)
                            .accessibilityHidden(true)
                        Text("settings.palette")
                        Spacer()
                        Text(LocalizedStringKey(model.effectiveTheme.titleKey)).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settings.palette")
                NavigationLink {
                    CounterStylePickerView().appHeader(settingsIsCurrent: true)
                } label: {
                    LabeledContent("settings.counter", value: L(model.effectiveCounter.titleKey))
                }
                .accessibilityIdentifier("settings.counter")
                Toggle("settings.period.animations", isOn: $model.preferences.animatePeriodChanges)
                    .accessibilityIdentifier("settings.period.animations")
                Text("settings.period.animations.description").font(.caption).foregroundStyle(.secondary)
            }
            GlassSettingsSection()
            Section("settings.data") {
                Button("health.connect") { Task { await model.connectHealth() } }
                Text("health.permissions.path").font(.caption).foregroundStyle(.secondary)
                Button("reset.title", role: .destructive) { confirmReset = true }
            }
            Section("settings.purchases") {
                Button("purchase.restore") { Task { await model.purchases.restore() } }.disabled(model.purchases.isBusy)
                Button("purchase.manage") { showSubscriptions = true }
            }
            Section {
                Text("Walkuno · Orbelio").font(.subheadline.weight(.semibold))
                Text("brand.tagline").font(.caption).foregroundStyle(.secondary)
                Text("settings.version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")").font(.caption2).foregroundStyle(.secondary)
            }
            Section {
                Button("privacy.title") { showPrivacy = true }
                    .accessibilityIdentifier("settings.privacy")
                Button("terms.title") { showTerms = true }
                    .accessibilityIdentifier("settings.terms")
            }
        }
        .scrollContentBackground(.hidden)
        .background(WalkunoStyle.background(scheme))
        .navigationTitle("tab.settings")
        .onChange(of: model.preferences) { oldPreferences, newPreferences in
            // The glass slider previews continuously and saves when the interaction ends.
            var previous = oldPreferences
            previous.glassTransparency = newPreferences.glassTransparency
            if previous != newPreferences {
                if newPreferences.onboardingComplete { model.persist() }
                else if previous.language != newPreferences.language { model.persist(sync: false) }
            }
        }
        .sheet(isPresented: $showGoal) { GoalEditor() }
        .sheet(isPresented: $showPremium) { PremiumView() }
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
        .sheet(isPresented: $showTerms) { TermsView() }
        .manageSubscriptionsSheet(isPresented: $showSubscriptions)
        .confirmationDialog("reset.title", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("reset.confirm", role: .destructive) { Task { await model.resetLocalData() } }
        } message: { Text("reset.body") }
        .alert("purchase.title", isPresented: Binding(get: { model.purchases.message != nil }, set: { if !$0 { model.purchases.message = nil } })) {
            Button("common.done") { model.purchases.message = nil }
        } message: { Text(model.purchases.message ?? "") }
    }
}

private struct ThemePaletteView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showPremium = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("theme.palette.description").font(.subheadline).foregroundStyle(.secondary)
                WalkunoCard {
                    HStack(spacing: 20) {
                        ZStack {
                            ProgressRing(progress: model.progress, accent: model.effectiveTheme.tint(for: scheme),
                                         secondaryAccent: model.effectiveTheme.secondaryTint(for: scheme), lineWidth: 8)
                            BrandMark(size: 28, theme: model.effectiveTheme).foregroundStyle(model.effectiveTheme.tint(for: scheme))
                        }
                        .frame(width: 80, height: 80).padding(4)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(LocalizedStringKey(model.effectiveTheme.titleKey))
                                .font(.system(.title2, design: .rounded, weight: .bold))
                            Text("theme.selected").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 160 : 100), spacing: 12)], spacing: 12) {
                    ForEach(WalkunoTheme.allCases) { theme in
                        paletteButton(theme)
                    }
                }
                if !model.purchases.isPremium {
                    Text("theme.premium.note").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(20)
        }
        .background(WalkunoStyle.background(scheme))
        .navigationTitle("settings.palette")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.palette.picker")
        .sheet(isPresented: $showPremium) { PremiumView() }
    }

    private func paletteButton(_ theme: WalkunoTheme) -> some View {
        let selected = model.effectiveTheme == theme
        let locked = theme != .mint && !model.purchases.isPremium
        return Button {
            if locked { showPremium = true }
            else if model.preferences.theme != theme {
                model.preferences.theme = theme
                model.persist()
            }
        } label: {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    Image(systemName: "circle.dotted.circle.fill").font(.system(size: 28))
                    Spacer(minLength: 4)
                    Image(systemName: selected ? "checkmark.circle.fill" : locked ? "lock.fill" : "circle")
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(LocalizedStringKey(theme.titleKey)).font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 85, alignment: .topLeading).padding(14)
            .foregroundStyle(WalkunoStyle.ink)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(selected ? WalkunoStyle.ink : .clear, lineWidth: 3))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("theme.\(theme.rawValue)")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(theme.titleKey)))
        .accessibilityValue(Text(LocalizedStringKey(selected ? "theme.selected" : locked ? "premium.title" : "theme.available")))
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}

struct GoalEditor: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    private var parsedGoal: Int? {
        let formatter = NumberFormatter(); formatter.numberStyle = .decimal
        guard let number = formatter.number(from: input) else { return nil }
        let value = number.doubleValue
        guard value.rounded() == value, (500...100_000).contains(value) else { return nil }
        return Int(value)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("goal.title", text: $input).keyboardType(.numberPad).font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .accessibilityIdentifier("goal.input")
                        .accessibilityLabel(Text("goal.title"))
                    Text("goal.range").font(.caption).foregroundStyle(.secondary)
                }
                Section("goal.presets") {
                    ForEach([5000, 8000, 10000, 12000], id: \.self) { value in
                        Button { input = value.formatted() } label: {
                            HStack { Text(value.formatted()); Spacer(); if parsedGoal == value { Image(systemName: "checkmark") } }
                        }
                    }
                }
                Section { Text("goal.note").font(.subheadline).foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden)
            .background(WalkunoStyle.background(scheme))
            .navigationTitle("goal.edit").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { if let value = parsedGoal { model.setGoal(value); dismiss() } }.disabled(parsedGoal == nil)
                }
            }
            .onAppear { input = model.goal.formatted() }
            .appHeader()
        }
        .presentationDetents([.medium, .large])
    }
}

struct PrivacyView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "hand.raised.fill").font(.largeTitle).foregroundStyle(.tint)
                    Text("privacy.headline").font(.largeTitle.bold())
                    Text("privacy.body").font(.body).textSelection(.enabled)
                    Text("privacy.permissions").font(.body)
                    Text("privacy.widgets").font(.body)
                    Text("privacy.purchases").font(.body)
                    Text("privacy.reset").font(.body)
                    Text("privacy.sharing").font(.body)
                    Text("privacy.storage").font(.body)
                    Text("privacy.editor").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
                    .textSelection(.enabled)
            }
            .background(WalkunoStyle.background(scheme))
            .navigationTitle("privacy.title").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
            .appHeader()
        }
    }
}

struct TermsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    private let sections = ["use", "health", "purchases", "brand", "sharing", "availability", "rights"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "doc.text").font(.largeTitle).foregroundStyle(.tint)
                        .accessibilityHidden(true)
                    Text("terms.intro").font(.body)
                    ForEach(sections, id: \.self) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("terms.\(section).title")).font(.headline)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("terms.section.\(section)")
                            Text(L("terms.\(section).body")).font(.body)
                        }
                    }
                    Link("terms.apple", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        .accessibilityIdentifier("terms.apple")
                    Text("terms.editor").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading).padding(24)
                .textSelection(.enabled)
            }
            .accessibilityIdentifier("terms.content")
            .background(WalkunoStyle.background(scheme))
            .navigationTitle("terms.title").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
            .appHeader(settingsIsCurrent: true)
        }
    }
}
