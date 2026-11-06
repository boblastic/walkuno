import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var goalMetric: ActivityMetric?
    @State private var showPremium = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showSubscriptions = false
    @State private var isRequestingHealth = false
    @State private var showHealthPermissions = false
    @State private var healthPermissionsMessage = ""
    var body: some View {
        @Bindable var model = model
        Form {
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
            Section("goals.daily") {
                ForEach(ActivityMetric.allCases) { metric in
                    Button { goalMetric = metric } label: {
                        LabeledContent(L(metric.titleKey), value: metric.clockText(model.preferences.goal(for: metric), unit: model.preferences.unit))
                    }
                    .accessibilityIdentifier("settings.goal.\(metric.rawValue)")
                }
            }
            Section("settings.appearance") {
                Picker("settings.unit", selection: $model.preferences.unit) {
                    Text("unit.kilometers").tag(DistanceUnit.kilometers)
                    Text("unit.miles").tag(DistanceUnit.miles)
                }
                Picker("settings.language", selection: $model.preferences.language) {
                    Text("settings.language.system").tag(AppLanguage.system)
                    ForEach(AppLanguage.allCases.filter { $0 != .system }) { language in
                        Text(verbatim: language.nativeName).tag(language)
                    }
                }
                .accessibilityIdentifier("settings.language")
                Text("settings.language.note").font(.caption).foregroundStyle(.secondary)
                NavigationLink {
                    ThemePaletteView().appHeader()
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
                    CounterStylePickerView().appHeader()
                } label: {
                    HStack(spacing: 10) {
                        CounterStyleThumbnail(theme: model.effectiveTheme, style: model.effectiveCounter)
                        Text("settings.counter")
                        Spacer()
                        Text(L(model.effectiveCounter.titleKey)).foregroundStyle(.secondary)
                    }
                }
                .accessibilityIdentifier("settings.counter")
                NavigationLink {
                    WidgetGalleryView().appHeader()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(model.effectiveTheme.tint(for: scheme))
                            .frame(width: 22)
                        Text("settings.widgets")
                        Spacer()
                        Text("Pro").font(.caption.weight(.bold))
                            .foregroundStyle(model.effectiveTheme.tint(for: scheme))
                    }
                }
                .accessibilityIdentifier("settings.widgets")
                GlassSettingsControls()
            }
            Section("settings.data") {
                Button("health.authorize") {
                    isRequestingHealth = true
                    Task {
                        defer { isRequestingHealth = false }
                        let outcome = await model.connectHealth()
                        if outcome == .alreadyRequested {
                            healthPermissionsMessage = L("health.permissions.path")
                            showHealthPermissions = true
                        } else if outcome == nil, !model.isDemo {
                            healthPermissionsMessage = L("health.connection.error")
                            showHealthPermissions = true
                        }
                    }
                }
                .disabled(isRequestingHealth)
                .accessibilityIdentifier("settings.health.authorize")
                Text("health.authorization.note").font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("settings.health.explanation")
            }
            Section("settings.purchases") {
                Button("purchase.restore") { Task { await model.purchases.restore() } }.disabled(model.purchases.isBusy)
                Button("purchase.manage") { showSubscriptions = true }
            }
            Section {
                Label("account.local", systemImage: "figure.walk.circle.fill").font(.headline)
                Text("account.local.note").font(.subheadline).foregroundStyle(.secondary)
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
        .sheet(item: $goalMetric) { GoalEditor(metric: $0) }
        .sheet(isPresented: $showPremium) { PremiumView() }
        .sheet(isPresented: $showPrivacy) { PrivacyView() }
        .sheet(isPresented: $showTerms) { TermsView() }
        .manageSubscriptionsSheet(isPresented: $showSubscriptions)
        .alert("health.authorize", isPresented: $showHealthPermissions) {
            Button("common.done", role: .cancel) { }
        } message: {
            Text(healthPermissionsMessage)
        }
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
    var metric: ActivityMetric = .steps
    @Environment(\.colorScheme) private var scheme
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var input = ""
    private var unit: DistanceUnit { model.preferences.unit }
    private var value: Double { model.preferences.goal(for: metric) }
    private var formatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = AppLocalization.locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = metric == .distance ? 3 : 0
        return formatter
    }
    private func editText(_ value: Double) -> String {
        formatter.string(from: NSNumber(value: metric == .distance ? unit.convert(meters: value) : value)) ?? ""
    }
    private var parsedGoal: Double? {
        // Saving an unchanged distance must not round-trip meters through rounded miles.
        if input == editText(value) { return value }
        let separator = formatter.decimalSeparator ?? "."
        let parts = input.components(separatedBy: separator)
        guard parts.count <= (metric == .distance ? 2 : 1),
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let number = formatter.number(from: input) else { return nil }
        let displayed = number.doubleValue
        let canonical = metric == .distance ? displayed * (unit == .kilometers ? 1_000 : 1_609.344) : displayed
        return metric.acceptsGoal(canonical) ? canonical : nil
    }
    private var presets: [Double] {
        switch metric {
        case .steps: [5_000, 8_000, 10_000, 12_000]
        case .distance: unit == .kilometers ? [3_000, 5_000, 8_000, 10_000] : [2, 3, 5, 6].map { $0 * 1_609.344 }
        case .energy: [200, 400, 600, 800]
        case .exerciseTime: [15, 30, 45, 60]
        case .floors: [5, 10, 15, 20]
        }
    }
    private var rangeText: String {
        func bound(_ value: Double) -> String {
            let displayed = metric == .distance ? unit.convert(meters: value) : value
            return displayed.formatted(.number.locale(AppLocalization.locale).precision(.fractionLength(0...3))) + " " + metric.clockUnit(unit)
        }
        return String(format: L("goals.range %@ %@"), bound(metric.goalRange.lowerBound), bound(metric.goalRange.upperBound))
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField(L(metric.titleKey), text: $input)
                            .keyboardType(metric == .distance ? .decimalPad : .numberPad)
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .accessibilityIdentifier("goal.input")
                            .accessibilityLabel(Text(L(metric.titleKey)))
                        Text(metric.clockUnit(unit)).foregroundStyle(.secondary)
                    }
                    Text(rangeText).font(.caption).foregroundStyle(.secondary)
                }
                Section("goal.presets") {
                    ForEach(presets, id: \.self) { value in
                        Button { input = editText(value) } label: {
                            HStack {
                                Text(metric == .steps ? metric.clockNumber(value, unit: unit) : metric.clockText(value, unit: unit))
                                Spacer()
                                if let parsedGoal, abs(parsedGoal - value) < 0.001 { Image(systemName: "checkmark") }
                            }
                        }
                    }
                }
                if metric == .steps {
                    Section { Text("goal.note").font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WalkunoStyle.background(scheme))
            .navigationTitle(L(metric.shortTitleKey)).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        if let value = parsedGoal { model.setGoal(value, for: metric); dismiss() }
                    }.disabled(parsedGoal == nil)
                    .accessibilityIdentifier("goal.save")
                }
            }
            .onAppear { input = editText(value) }
            .appHeader()
        }
        .presentationDetents([.large])
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
                    Text("privacy.wellbeing").font(.body)
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
            .appHeader()
        }
    }
}
