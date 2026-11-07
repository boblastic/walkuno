import SwiftUI
import WidgetKit

/// Full widget captures, rendered from the same views shipped in the WidgetKit extension.
struct WidgetGalleryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var showPremium = false
    @State private var chart = WidgetGalleryChart.hourly

    @State private var example = WidgetSnapshot.preview(at:
        Calendar.current.date(bySettingHour: 18, minute: 42, second: 0, of: .now) ?? .now)

    private var snapshot: WidgetSnapshot {
        var value = example
        value.theme = model.effectiveTheme
        value.unit = model.preferences.unit
        value.display = .init(counter: model.effectiveCounter)
        value.goal = model.goal
        value.activityGoals = model.preferences.activityGoals
        return value
    }

    private var accent: Color { model.effectiveTheme.tint(for: scheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                Text("widgets.gallery.examples")
                    .font(.caption).foregroundStyle(.secondary)
                feature("widget.name", body: "widgets.gallery.counter.body", symbol: "circle.dotted.circle") {
                    VStack(spacing: 18) {
                        capture(.counter, family: .systemSmall)
                        capture(.counter, family: .systemLarge)
                    }
                }

                feature("widget.charts.name", body: "widgets.gallery.charts.body", symbol: "chart.xyaxis.line") {
                    VStack(alignment: .leading, spacing: 14) {
                        ScrollView(.horizontal) {
                            HStack(spacing: 8) {
                                ForEach(WidgetGalleryChart.allCases) { candidate in
                                    Button { chart = candidate } label: {
                                        Text(LocalizedStringKey(candidate.titleKey))
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 12).padding(.vertical, 9)
                                            .background(chart == candidate ? accent.opacity(0.15) : WalkunoStyle.card(scheme), in: Capsule())
                                            .overlay(Capsule().strokeBorder(chart == candidate ? accent : .primary.opacity(0.08)))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(chart == candidate ? accent : .primary)
                                    .accessibilityAddTraits(chart == candidate ? [.isSelected] : [])
                                    .accessibilityIdentifier("widgets.chart.\(candidate.rawValue)")
                                }
                            }
                        }.scrollIndicators(.hidden)
                        capture(.chart, family: .systemMedium)
                        capture(.chart, family: .systemSmall)
                        capture(.chart, family: .systemLarge)
                    }
                }

                feature("widget.dashboard.name", body: "widgets.gallery.dashboard.body", symbol: "rectangle.grid.1x2") {
                    VStack(spacing: 18) {
                        capture(.dashboard, family: .systemSmall)
                        capture(.dashboard, family: .systemMedium)
                        capture(.dashboard, family: .systemLarge)
                    }
                }

                feature("widget.dailyGoal.name", body: "widgets.gallery.dailyGoal.body", symbol: "target") {
                    VStack(spacing: 18) {
                        capture(.dailyGoal, family: .systemMedium)
                        capture(.dailyGoal, family: .systemLarge)
                    }
                }

                feature("widgets.gallery.everywhere.title", body: "widgets.gallery.everywhere.body", symbol: "applewatch") {
                    VStack(spacing: 20) {
                        HStack(spacing: 24) {
                            capture(.counter, family: .accessoryCircular)
                            capture(.counter, family: .accessoryRectangular)
                        }
                        capture(.counter, family: .accessoryInline)
                        capture(.chart, family: .accessoryRectangular)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .background(WalkunoStyle.ink, in: RoundedRectangle(cornerRadius: 28))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("widgets.gallery.install.title", systemImage: "plus.circle.fill")
                        .font(.headline).foregroundStyle(accent)
                    Text("widgets.gallery.install.body").font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("widgets.install")
            }
            .padding(20)
        }
        .background(WalkunoStyle.background(scheme))
        .navigationTitle("settings.widgets")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom, spacing: 0) { proAction }
        .sheet(isPresented: $showPremium) { PremiumView() }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("widgets.gallery.exclusive", systemImage: "sparkles")
                .font(.caption.weight(.bold)).foregroundStyle(WalkunoStyle.electric)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.white.opacity(0.08), in: Capsule())
            Text("widgets.gallery.headline")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            Text("widgets.gallery.intro")
                .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Image(systemName: "iphone")
                Text("widgets.gallery.surfaces")
            }.font(.caption.weight(.medium)).foregroundStyle(WalkunoStyle.electric)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(26)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 30).fill(
                LinearGradient(colors: [WalkunoStyle.ink, Color(red: 0.06, green: 0.29, blue: 0.29)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
        }
    }

    private func feature<Content: View>(_ title: String, body: String, symbol: String,
                                       @ViewBuilder preview: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(LocalizedStringKey(title), systemImage: symbol)
                .font(.title3.weight(.bold)).foregroundStyle(accent)
                .accessibilityAddTraits(.isHeader)
            Text(LocalizedStringKey(body)).font(.subheadline).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            preview()
        }
    }

    private func capture(_ kind: WidgetGalleryKind, family: WidgetFamily) -> some View {
        WidgetGalleryCapture(kind: kind, family: family, chart: chart.widgetStyle, snapshot: snapshot)
    }

    private var proAction: some View {
        VStack(spacing: 8) {
            if model.purchases.isPremium {
                Label("widgets.gallery.unlocked", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                    .accessibilityIdentifier("widgets.unlocked")
            } else {
                Button { showPremium = true } label: {
                    Label("widgets.gallery.cta", systemImage: "sparkles")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 9)
                }
                .buttonStyle(.borderedProminent).tint(model.effectiveTheme.accent)
                .foregroundStyle(WalkunoStyle.ink)
                .accessibilityIdentifier("widgets.unlock")
                Text("widgets.gallery.pro.note").font(.caption2).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 20).padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

private enum WidgetGalleryChart: String, CaseIterable, Identifiable {
    case hourly, goalTracking, weekly, weeklyLine, dailyRhythm
    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .weekly, .weeklyLine: "widget.style.\(rawValue)"
        default: "widget.chart.\(rawValue)"
        }
    }
}

private enum WidgetGalleryKind: String {
    case counter, chart, dashboard, dailyGoal

    var titleKey: String {
        switch self {
        case .counter: "widget.name"
        case .chart: "widget.charts.name"
        case .dashboard: "widget.dashboard.name"
        case .dailyGoal: "widget.dailyGoal.name"
        }
    }
}

private extension WidgetGalleryChart {
    var widgetStyle: WidgetChartStyle { WidgetChartStyle(rawValue: rawValue) ?? .hourly }
}

/// Capture at the native widget dimensions, then fit the entire image in the available width.
/// No independent approximation of the widget's content is maintained in this gallery.
private struct WidgetGalleryCapture: View {
    var kind: WidgetGalleryKind
    var family: WidgetFamily
    var chart: WidgetChartStyle
    var snapshot: WidgetSnapshot
    @Environment(\.displayScale) private var displayScale
    @Environment(\.locale) private var locale
    @State private var image: UIImage?

    private var familyID: String {
        switch family {
        case .systemSmall: "small"
        case .systemMedium: "medium"
        case .systemLarge: "large"
        case .accessoryCircular: "circular"
        case .accessoryRectangular: "rectangular"
        default: "inline"
        }
    }

    private var size: CGSize {
        switch family {
        case .systemSmall: .init(width: 170, height: 170)
        case .systemMedium: .init(width: 364, height: 170)
        case .systemLarge: .init(width: 364, height: 382)
        case .accessoryCircular: .init(width: 76, height: 76)
        case .accessoryRectangular: .init(width: 172, height: 76)
        default: .init(width: 240, height: 24)
        }
    }

    private var captureID: String {
        "\(kind.rawValue)-\(family.rawValue)-\(chart.rawValue)-\(snapshot.theme.rawValue)-\(snapshot.unit.rawValue)-\(snapshot.display?.counter.rawValue ?? "")-\(ActivityMetric.allCases.map { snapshot.goal(for: $0) })-\(locale.identifier)-\(displayScale)"
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .accessibilityLabel(Text(LocalizedStringKey(kind.titleKey)))
                    .accessibilityIdentifier("widgets.capture.\(kind.rawValue).\(familyID)")
            } else {
                Color.clear.aspectRatio(size, contentMode: .fit)
                    .overlay { ProgressView() }.accessibilityHidden(true)
            }
        }
        .frame(maxWidth: size.width)
        .frame(maxWidth: .infinity)
        .task(id: captureID) { render() }
    }

    @MainActor private func render() {
        let content = widget
            .environment(\.widgetCaptureFamily, family)
            .environment(\.locale, locale)
            .environment(\.colorScheme, .dark)
            .dynamicTypeSize(.medium)
            .frame(width: size.width, height: size.height)
            .clipShape(RoundedRectangle(cornerRadius: family == .systemSmall || family == .systemMedium || family == .systemLarge ? 26 : 0))
        let renderer = ImageRenderer(content: content)
        renderer.scale = displayScale
        image = renderer.uiImage
    }

    @ViewBuilder private var widget: some View {
        switch kind {
        case .counter:
            WalkunoWidgetView(entry: .init(date: snapshot.updatedAt, snapshot: snapshot))
        case .chart:
            WalkunoChartWidgetView(entry: .init(date: snapshot.updatedAt, snapshot: snapshot, style: chart))
        case .dashboard:
            WalkunoDashboardView(entry: .init(date: snapshot.updatedAt, snapshot: snapshot))
        case .dailyGoal:
            WalkunoDailyGoalView(entry: .init(date: snapshot.updatedAt, snapshot: snapshot))
        }
    }
}
