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
        case .dailyGoal: "goals.daily"
        case .clock: "insights.clock.title"
        case .day: "insights.day"
        case .trends: "insights.trends"
        case .history: "insights.all.years"
        case .records: "insights.records"
        }
    }
}

struct DailyGoalCard: View {
    var body: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("goals.daily")
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("statistics.dailyGoal.title")
                HStack(alignment: .top, spacing: 4) {
                    ForEach(ActivityMetric.allCases) { metric in
                        DailyGoalMetricCounter(metric: metric)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("statistics.dailyGoal")
    }
}

private struct DailyGoalMetricCounter: View {
    @Environment(AppModel.self) private var model
    @ScaledMetric(relativeTo: .caption2) private var goalFontSize = 9
    var metric: ActivityMetric

    // This overview deliberately treats missing daily measurements as zero.
    private var value: Double { metric.value(in: model.today) ?? 0 }
    private var goal: Double { model.preferences.goal(for: metric) }
    private var unit: DistanceUnit { model.preferences.unit }

    var body: some View {
        VStack(spacing: 4) {
            Color.clear
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    GeometryReader { geometry in
                        counter
                            .environment(\.dynamicTypeSize, .medium)
                            .frame(width: 220, height: 220)
                            .scaleEffect(geometry.size.width / 220)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            VStack(spacing: 0) {
                Text(L(metric.shortTitleKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(model.effectiveTheme.accent)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityIdentifier("statistics.dailyGoal.label.\(metric.rawValue)")
                Text(metric.clockText(goal, unit: unit))
                    .font(.system(size: goalFontSize)).monospacedDigit().foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .accessibilityIdentifier("statistics.dailyGoal.goal.\(metric.rawValue)")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(L(metric.titleKey)))
        .accessibilityValue(Text(metric.clockText(value, unit: unit)) + Text(", ") +
                            Text("goals.target \(metric.clockText(goal, unit: unit))"))
        .accessibilityIdentifier("statistics.dailyGoal.\(metric.rawValue)")
    }

    private var counter: some View {
        CounterPlayback(value: value, goal: goal, animateEntry: true, animateUpdates: true,
                        replayOnAppear: true) { displayedValue, trail in
            StepCounterFace(displayedSteps: displayedValue, trail: trail, hasSteps: true,
                            goal: goal, title: "", theme: model.effectiveTheme,
                            style: .horizon, effect: model.effectiveEffect,
                            numberText: metric.clockNumber(displayedValue, unit: unit),
                            showsRemaining: false, showsAnnotations: false)
                .overlay {
                    GeometryReader { geometry in
                        Text(metric.clockUnit(unit))
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.7)
                            .frame(width: geometry.size.width * 0.65, height: 30)
                            .position(x: geometry.size.width / 2, y: geometry.size.height * 0.79)
                    }
                    .accessibilityHidden(true)
                }
        }
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
