import SwiftUI

struct StatisticsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var metric: ActivityMetric = .steps
    @State private var showPremium = false
    @State private var chartScrubbing = false
    private var earliestFree: Date { Calendar.current.date(byAdding: .day, value: -30, to: .now)! }

    var body: some View {
        ZStack {
            ScrollView {
                StatisticsInsightsView(metric: metric, earliest: model.purchases.isPremium ? nil : Calendar.current.startOfDay(for: earliestFree)) {
                    showPremium = true
                }
                .padding(24)
                .contentShape(Rectangle())
            }
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
        .onChange(of: model.preferences.showEnergy) { _, visible in
            if !visible && metric == .energy { metric = .steps }
        }
    }

    private var metricPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 4) {
                ForEach(ActivityMetric.allCases.filter { model.preferences.showEnergy || $0 != .energy }) { choice in
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
