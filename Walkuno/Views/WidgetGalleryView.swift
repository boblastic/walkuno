import SwiftUI
import Charts

/// Illustrative previews of the three shipped WidgetKit families and their accessories.
struct WidgetGalleryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var showPremium = false
    @State private var chart = WidgetGalleryChart.hourly

    private var accent: Color { model.effectiveTheme.tint(for: scheme) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                hero
                Text("widgets.gallery.examples")
                    .font(.caption).foregroundStyle(.secondary)
                feature("widget.name", body: "widgets.gallery.counter.body", symbol: "circle.dotted.circle") {
                    HStack(spacing: 18) {
                        StepCounterFace(displayedSteps: 6240, hasSteps: true, goal: 8000,
                                        title: L("today.steps"), theme: model.effectiveTheme,
                                        style: model.effectiveCounter)
                            .frame(width: 220, height: 220)
                            .scaleEffect(0.65)
                            .frame(width: 143, height: 143)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("78 %").font(.system(.title, design: .rounded, weight: .bold))
                            Text("widget.goal").font(.caption).foregroundStyle(.secondary)
                            Text("8 000").font(.headline.monospacedDigit())
                        }
                        Spacer(minLength: 0)
                    }
                    .previewSurface()
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
                        VStack(alignment: .leading, spacing: 12) {
                            previewHeading(chart.titleKey)
                            WidgetGalleryPlot(style: chart, accent: accent).frame(height: 120)
                        }.previewSurface()
                    }
                }

                feature("widget.dashboard.name", body: "widgets.gallery.dashboard.body", symbol: "rectangle.grid.1x2") {
                    dashboard.previewSurface()
                }

                feature("widgets.gallery.everywhere.title", body: "widgets.gallery.everywhere.body", symbol: "applewatch") {
                    HStack(spacing: 20) {
                        HStack(spacing: 10) {
                            ProgressRing(progress: 0.78, accent: accent, lineWidth: 5)
                                .frame(width: 42, height: 42)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("6 240").font(.system(.title3, design: .rounded, weight: .bold))
                                Text("today.steps").font(.caption2)
                            }
                        }
                        .padding(16)
                        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 22))
                        Spacer(minLength: 0)
                        ZStack {
                            RoundedRectangle(cornerRadius: 24).fill(WalkunoStyle.ink)
                            VStack(spacing: 8) {
                                Image(systemName: "figure.walk").font(.title3)
                                Text("6 240").font(.system(.headline, design: .rounded, weight: .bold))
                                Capsule().fill(WalkunoStyle.electric.opacity(0.2))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(WalkunoStyle.electric).frame(width: 34)
                                    }.frame(width: 44, height: 4)
                            }.foregroundStyle(WalkunoStyle.electric)
                        }.frame(width: 84, height: 104)
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.secondary.opacity(0.3), lineWidth: 3))
                    }.previewSurface()
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label("widgets.gallery.install.title", systemImage: "plus.circle.fill")
                        .font(.headline).foregroundStyle(accent)
                    Text("widgets.gallery.install.body").font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
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

    private func previewHeading(_ title: String) -> some View {
        HStack {
            BrandMark(size: 18, theme: model.effectiveTheme).foregroundStyle(accent)
            Text("Walkuno").font(.caption.weight(.bold))
            Spacer()
            Text(LocalizedStringKey(title)).font(.caption2).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 14) {
            previewHeading("today.this.week")
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("6 240").font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("today.steps").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(distanceText(4680, unit: model.preferences.unit))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(accent)
            }
            WidgetGalleryPlot(style: .weeklyLine, accent: accent).frame(height: 80)
            HStack {
                Label("widget.average", systemImage: "chart.line.uptrend.xyaxis")
                Spacer()
                Text("7 120").monospacedDigit()
            }.font(.caption).foregroundStyle(.secondary)
        }
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

private struct WidgetGalleryPlot: View {
    var style: WidgetGalleryChart
    var accent: Color
    private var values: [Double] {
        switch style {
        case .hourly: [1, 2, 1, 4, 8, 5, 3, 6, 10, 7, 4, 2]
        case .goalTracking: [0, 1, 1.5, 3, 3.4, 4, 6, 6.2, 8, 9, 9.2, 10]
        case .weekly, .weeklyLine: [4, 7, 5, 9, 6, 8, 6.24]
        case .dailyRhythm: [1, 1, 2, 4, 7, 9, 7, 5, 3, 2, 1, 1]
        }
    }

    var body: some View {
        Chart {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                if style == .goalTracking || style == .weeklyLine {
                    AreaMark(x: .value("x", index), y: .value("y", value))
                        .interpolationMethod(.monotone)
                        .foregroundStyle(LinearGradient(colors: [accent.opacity(0.25), accent.opacity(0.01)],
                                                        startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("x", index), y: .value("y", value))
                        .interpolationMethod(.monotone).lineStyle(StrokeStyle(lineWidth: 3))
                        .foregroundStyle(accent)
                } else {
                    BarMark(x: .value("x", index), y: .value("y", value))
                        .cornerRadius(4).foregroundStyle(accent.gradient)
                }
            }
            if style == .goalTracking || style == .weekly || style == .weeklyLine {
                RuleMark(y: .value("goal", 8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary.opacity(0.5))
            }
        }
        .chartXAxis(.hidden).chartYAxis(.hidden)
        .chartYScale(domain: 0...11)
    }
}

private extension View {
    func previewSurface() -> some View {
        self
            .dynamicTypeSize(.medium)
            .padding(18)
            .frame(maxWidth: .infinity)
            .background(.background, in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.primary.opacity(0.06)))
            .accessibilityHidden(true)
    }
}
