import SwiftUI

enum ShareScope: String, CaseIterable, Identifiable {
    case day, week, month, year, record, badge
    var id: String { rawValue }
}

struct ShareCardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var anchor: Date
    @State private var includeDistance = true
    @State private var image: Image?
    @State private var scope: ShareScope

    init(anchor: Date = .now, initialScope: ShareScope = .day) {
        self.anchor = anchor
        _scope = State(initialValue: initialScope)
    }

    private var day: ActivityDay? {
        guard earliest.map({ anchor >= $0 }) ?? true else { return nil }
        return model.days.first { Calendar.current.isDate($0.date, inSameDayAs: anchor) }
    }
    private var earliest: Date? {
        model.purchases.isPremium ? nil : Calendar.current.date(byAdding: .day, value: -30, to: Calendar.current.startOfDay(for: .now))
    }
    private var periodActivity: DashboardActivity {
        .init(period: scope == .year ? .year : scope == .month ? .month : .week, anchor: anchor, available: model.days,
              goals: model.preferences.goals, earliest: earliest)
    }
    private var summary: ActivitySummary { .init(days: model.days, goals: model.preferences.goals) }
    private var sharedSteps: Int? {
        switch scope {
        case .day: day?.steps
        case .week, .month, .year: periodActivity.summary.total
        case .record, .badge: summary.best?.steps
        }
    }
    private var sharedGoal: Int {
        if scope == .week || scope == .month || scope == .year { return periodActivity.goal }
        let date = scope == .record || scope == .badge ? summary.best?.date ?? anchor : anchor
        return model.preferences.goals.value(on: date)
    }
    private var distance: String? {
        guard includeDistance else { return nil }
        let meters: Double?
        switch scope {
        case .day: meters = day?.meters
        case .week, .month, .year: meters = periodActivity.summary.meters
        case .record, .badge: meters = summary.best?.meters
        }
        return distanceText(meters, unit: model.preferences.unit)
    }
    private var artwork: some View {
        ActivityShareArtwork(steps: sharedSteps, goal: sharedGoal, distance: distance,
                             theme: model.effectiveTheme, title: L("share.scope.\(scope.rawValue)"),
                             date: scope == .record || scope == .badge ? summary.best?.date ?? anchor : anchor,
                             badge: scope == .badge, yearOnly: scope == .year)
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("share.scope", selection: $scope) {
                        ForEach(ShareScope.allCases.filter { $0 != .year || model.purchases.isPremium }) { scope in
                            Text(L("share.scope.\(scope.rawValue)")).tag(scope)
                        }
                    }.pickerStyle(.menu)
                    artwork.frame(maxWidth: 360)
                    Toggle("share.distance", isOn: $includeDistance).padding(.horizontal)
                    Text("share.privacy").font(.caption).foregroundStyle(.secondary)
                    if let image {
                        ShareLink(item: image, preview: SharePreview(Text("share.preview"), image: image)) {
                            Label("share.title", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(8)
                        }.buttonStyle(.borderedProminent).tint(model.effectiveTheme.accent).foregroundStyle(WalkunoStyle.ink)
                    }
                }.padding(24)
            }
            .navigationTitle("share.title").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
            .task(id: "\(includeDistance)-\(scope.rawValue)-\(model.effectiveTheme.rawValue)-\(model.preferences.language.rawValue)") { render() }
            .appHeader()
        }
        .onChange(of: model.purchases.isPremium) { _, premium in
            if !premium && scope == .year { scope = .day }
        }
    }

    @MainActor private func render() {
        let renderer = ImageRenderer(content: artwork.frame(width: 360).environment(\.colorScheme, .dark).environment(\.locale, AppLocalization.locale))
        renderer.scale = 3
        if let result = renderer.uiImage { image = Image(uiImage: result) }
    }
}

struct ActivityShareArtwork: View {
    var steps: Int?
    var goal: Int
    var distance: String?
    var theme: WalkunoTheme
    var title: String
    var date: Date
    var badge: Bool
    var yearOnly = false
    var body: some View {
        VStack(spacing: 24) {
            HStack { BrandMark(theme: theme); Text("Walkuno").font(.title2.bold()) }.foregroundStyle(theme.accent)
            Text(title).font(.headline)
            ZStack {
                ProgressRing(progress: ActivityMath.progress(steps: steps, goal: goal), accent: theme.accent,
                             secondaryAccent: theme.secondaryAccent, lineWidth: 14)
                VStack(spacing: 10) {
                    if badge { Image(systemName: "rosette").font(.largeTitle).foregroundStyle(theme.accent) }
                    Text(stepsText(steps)).font(.system(size: 58, weight: .bold, design: .rounded)).minimumScaleFactor(0.5).lineLimit(1)
                        .accessibilityIdentifier("share.steps")
                    Text("today.steps").font(.subheadline).foregroundStyle(.secondary)
                }.padding(24)
            }.frame(height: 238).padding(.horizontal, 14)
            Text(yearOnly ? date.formatted(.dateTime.locale(AppLocalization.locale).year()) : date.appFormatted(date: .long, time: .omitted)).font(.subheadline)
                .accessibilityIdentifier("share.date")
            if let distance { Text(distance).font(.headline).foregroundStyle(theme.accent) }
            Text("brand.tagline").font(.caption).foregroundStyle(.secondary)
        }
        .padding(28).frame(maxWidth: .infinity)
        .foregroundStyle(.white).background(WalkunoStyle.ink, in: RoundedRectangle(cornerRadius: 28))
        .environment(\.colorScheme, .dark)
    }
}
