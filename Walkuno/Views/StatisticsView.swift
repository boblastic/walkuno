import SwiftUI

struct StatisticsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var metric: ActivityMetric = .steps
    @State private var showPremium = false
    @State private var showWidgetSettings = false
    @State private var chartScrubbing = false
    private var earliestFree: Date { Calendar.current.date(byAdding: .day, value: -30, to: .now)! }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    StatisticsInsightsView(metric: metric, earliest: model.purchases.isPremium ? nil : Calendar.current.startOfDay(for: earliestFree)) {
                        showPremium = true
                    }
                    Button { showWidgetSettings = true } label: {
                        Label("statistics.widgets.customize", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("statistics.widgets.customize")
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 24)
                .contentShape(Rectangle())
            }
            .accessibilityIdentifier("statistics.content")
            .refreshable { await model.refresh() }
            .scrollBounceBehavior(.always, axes: .vertical)
            .scrollDisabled(chartScrubbing)
            .environment(\.chartScrubbing, $chartScrubbing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Reserve the menu's height initially, then let the insights scroll behind its glass.
        .safeAreaInset(edge: .top, spacing: 0) {
            metricPicker
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .background(WalkunoStyle.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPremium) { PremiumView() }
        .sheet(isPresented: $showWidgetSettings) { StatisticsWidgetSettingsView() }
    }

    private var metricPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(ActivityMetric.allCases) { choice in
                    Button { metric = choice } label: {
                        Text(L(choice.shortTitleKey))
                            .font(.caption.weight(.semibold))
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .foregroundStyle(metric == choice ? WalkunoStyle.ink : Color.primary)
                            .background(metric == choice ? model.effectiveTheme.accent : Color.primary.opacity(0.05), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(L(choice.titleKey)))
                    .accessibilityAddTraits(metric == choice ? .isSelected : [])
                    .accessibilityIdentifier("statistics.metric.\(choice.rawValue)")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
        .fixedSize(horizontal: false, vertical: true)
        .background { WalkunoGlassSurface() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("insights.metric"))
        .accessibilityIdentifier("statistics.metric")
    }
}

private extension StatisticsWidget {
    var titleKey: String {
        switch self {
        case .dailyGoal: "goal.title"
        case .clock: "insights.clock.title"
        case .day: "insights.day"
        case .trends: "insights.trends"
        case .history: "insights.all.years"
        case .records: "insights.records"
        }
    }
}

struct DailyGoalCard: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("goal.title")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("statistics.dailyGoal.title")
                DailyGoalMetricTile(metric: .steps, prominent: true)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                         count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 12) {
                    ForEach(ActivityMetric.allCases.filter { $0 != .steps }) { metric in
                        DailyGoalMetricTile(metric: metric)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statistics.dailyGoal")
    }
}

private struct DailyGoalMetricTile: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    var metric: ActivityMetric
    var prominent = false

    private var value: Double? { metric.value(in: model.today) }
    private var goal: Double { model.preferences.goal(for: metric) }
    private var progress: Double? { value.map { $0 / goal } }
    private var unit: DistanceUnit { model.preferences.unit }
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }

    var body: some View {
        Group {
            if prominent {
                HStack(spacing: 16) {
                    counter
                    details.frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 8) {
                    counter
                    details
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L(metric.titleKey)))
        .accessibilityValue(Text(metric.clockText(value, unit: unit)) + Text(", ") +
                            Text("goals.target \(metric.clockText(goal, unit: unit))") + Text(", \(percentage)"))
        .accessibilityIdentifier("statistics.dailyGoal.\(metric.rawValue)")
    }

    private var counter: some View {
        CompactStepCounterFace(progress: progress, text: metric.clockNumber(value, unit: unit),
                               theme: model.effectiveTheme, style: model.effectiveCounter)
            .frame(width: 88, height: 88)
    }

    private var details: some View {
        VStack(spacing: 5) {
            Text(L(metric.titleKey))
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text("goals.target \(metric.clockText(goal, unit: unit))")
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 4) {
                if let progress, progress >= 1 {
                    Image(systemName: "checkmark").font(.caption2.weight(.bold))
                }
                Text(percentage).monospacedDigit()
            }
            .font(.caption.weight(.bold)).foregroundStyle(accent)
        }
    }

    private var percentage: String {
        progress?.formatted(.percent.precision(.fractionLength(0))) ?? "—"
    }
}

private struct StatisticsWidgetSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.preferences.statisticsWidgets.order) { widget in
                        Toggle(isOn: Binding(get: {
                            !model.preferences.statisticsWidgets.hidden.contains(widget)
                        }, set: { visible in
                            if visible { model.preferences.statisticsWidgets.hidden.remove(widget) }
                            else { model.preferences.statisticsWidgets.hidden.insert(widget) }
                            model.persist()
                        })) {
                            Text(L(widget.titleKey))
                        }
                        .accessibilityIdentifier("statistics.widgets.toggle.\(widget.rawValue)")
                    }
                    .onMove { source, destination in
                        model.preferences.statisticsWidgets.order.move(fromOffsets: source, toOffset: destination)
                        model.persist()
                    }
                } footer: {
                    Text("statistics.widgets.instructions")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle(Text("statistics.widgets.customize"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .appHeader()
        }
    }
}
