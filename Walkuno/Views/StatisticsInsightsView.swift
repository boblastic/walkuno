import SwiftUI
import Charts

extension ActivityMetric {
    var shortTitleKey: String {
        switch self {
        case .energy: "metric.energy.short"
        case .exerciseTime: "metric.exercise.short"
        case .floors: "metric.floors.short"
        case .steps, .distance: titleKey
        }
    }

    var titleKey: String {
        switch self {
        case .steps: "metric.steps"
        case .distance: "metric.distance"
        case .energy: "metric.energy"
        case .exerciseTime: "metric.exercise"
        case .floors: "metric.floors"
        }
    }

    func clockNumber(_ value: Double?, unit: DistanceUnit) -> String {
        guard let value else { return "—" }
        let number = self == .distance ? unit.convert(meters: value) : value
        return number.formatted(.number.precision(.fractionLength(self == .distance ? 1 : 0)))
    }

    func clockUnit(_ unit: DistanceUnit) -> String {
        switch self {
        case .distance: unit.symbol
        case .energy: "kcal"
        case .exerciseTime: "min"
        case .steps: L("unit.steps")
        case .floors: L("unit.floors")
        }
    }

    func clockText(_ value: Double?, unit: DistanceUnit) -> String {
        clockNumber(value, unit: unit) + " " + clockUnit(unit)
    }

    func text(_ value: Double?, unit: DistanceUnit, signed: Bool = false) -> String {
        guard let value else { return "—" }
        let sign = signed && value > 0 ? "+" : ""
        switch self {
        case .distance: return sign + distanceText(value, unit: unit)
        case .exerciseTime:
            let minutes = Int(abs(value).rounded())
            return (value < 0 ? "−" : sign) + String(format: "%d:%02d", minutes / 60, minutes % 60) + " h"
        case .energy: return sign + value.formatted(.number.precision(.fractionLength(0))) + " kcal"
        case .floors, .steps: return sign + value.formatted(.number.precision(.fractionLength(0)))
        }
    }
}

private struct InsightHeader: View {
    var title: String
    var metric: ActivityMetric
    var font: Font = .headline

    var body: some View {
        Text(L(title)).font(font).frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityValue(Text(L(metric.titleKey)))
            .accessibilityIdentifier("insights.header.\(title)")
    }
}

private struct InsightValue: View {
    var title: String
    var value: String
    var color: Color = .primary
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L(title)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.system(.title, design: .rounded, weight: .bold)).foregroundStyle(color)
                .minimumScaleFactor(0.6).lineLimit(1).contentTransition(.numericText())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecordAverageLabel: View {
    @Environment(\.colorScheme) private var scheme
    var value: String

    var body: some View {
        Text("today.chart.average \(value)")
            .font(.caption2.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(Color.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(WalkunoStyle.card(scheme), in: RoundedRectangle(cornerRadius: 4))
            .allowsHitTesting(false)
    }
}

struct StatisticsInsightsView: View {
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    var earliest: Date?
    var onPremium: () -> Void
    private var days: [ActivityDay] { model.days.filter { $0.date >= (earliest ?? .distantPast) && $0.date <= .now } }
    @State private var activity: DailyActivitySnapshot?
    @State private var loadedID: String?
    @State private var loading = false
    @State private var failed = false
    private var taskID: String {
        "\(metric.rawValue)-\(earliest?.timeIntervalSince1970 ?? 0)-\(model.lastUpdated?.timeIntervalSince1970 ?? 0)-\(model.preferences.healthRequested)-\(model.days.count)-\(model.preferences.statisticsWidgets.visible.contains(.clock) || model.preferences.statisticsWidgets.visible.contains(.day))"
    }
    private var currentActivity: DailyActivitySnapshot? { loadedID == taskID ? activity : nil }
    private var clock: ActivityClockSnapshot {
        model.activityClock(metric: metric, data: currentActivity)
    }


    var body: some View {
        VStack(spacing: 20) {
            ForEach(model.preferences.statisticsWidgets.visible) { widget in
                widgetView(widget)
            }
        }
        .task(id: taskID) {
            let requestID = taskID
            guard loadedID != requestID || activity == nil else { return }
            loading = true; failed = false; activity = nil; loadedID = nil
            guard model.preferences.statisticsWidgets.visible.contains(.clock) || model.preferences.statisticsWidgets.visible.contains(.day) else {
                loading = false; return
            }
            do {
                let result = try await model.dailyActivity(metric: metric, earliest: earliest)
                try Task.checkCancellation()
                guard taskID == requestID else { return }
                activity = result; loadedID = requestID; loading = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { failed = true; loading = false } }
        }
    }

    @ViewBuilder private func widgetView(_ widget: StatisticsWidget) -> some View {
        switch widget {
        case .clock:
            StepsClockCard(snapshot: clock, loading: loading, failed: failed).id(metric)
        case .day:
            DailyComparisonCard(metric: metric, comparison: currentActivity?.comparison, loading: loading, failed: failed)
        case .trends:
            TrendsCard(days: days, onPremium: onPremium, metric: metric)
        case .history:
            if model.purchases.isPremium {
                YearHistoryCard(days: days, metric: metric)
            } else {
                Button(action: onPremium) {
                    Label("premium.feature.analysis", systemImage: "lock.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).accessibilityIdentifier("insights.history.unlock")
            }
        case .records:
            ActivityRecordCard(days: model.days, onPremium: onPremium, metric: metric)
        }
    }
}

private struct DailyComparisonCard: View {
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    var comparison: DayComparison?
    var loading: Bool
    var failed: Bool
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private var baseline: Color { model.effectiveTheme.secondaryTint(for: scheme) }
    private var chartMaximum: Double {
        let values = (comparison?.points.compactMap(\.current) ?? []) + (comparison?.usualDayPoints.compactMap(\.usual) ?? [])
        return max(values.max() ?? 0, model.preferences.goal(for: metric)) * 1.15
    }
    var body: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 10) {
                    InsightHeader(title: "insights.day", metric: metric, font: .subheadline.weight(.semibold))
                        .lineLimit(2).minimumScaleFactor(0.8)
                    dayLegend(title: "insights.today", value: comparison?.current, color: accent, dashed: false)
                    dayLegend(title: "insights.usual", value: comparison?.usualDayTotal, color: baseline, dashed: true)
                }
                Chart {
                    RuleMark(y: .value(L("goal.title"), model.preferences.goal(for: metric)))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 4]))
                            .annotation(position: .bottom, alignment: .trailing, spacing: 3) {
                                Text("goals.target \(metric.clockText(model.preferences.goal(for: metric), unit: model.preferences.unit))")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                    ForEach(comparison?.usualDayPoints ?? []) { point in
                        if let usual = point.usual {
                            LineMark(x: .value(L("chart.hour"), point.hour), y: .value(L("insights.usual"), usual), series: .value("series", "usual"))
                                .foregroundStyle(baseline).lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
                        }
                    }
                    ForEach(comparison?.points ?? []) { point in
                        if let current = point.current {
                            LineMark(x: .value(L("chart.hour"), point.hour), y: .value(L("insights.today"), current), series: .value("series", "today"))
                                .foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 4, lineCap: .round))
                        }
                    }
                    if let last = comparison?.points.last, let value = last.current {
                        RuleMark(x: .value(L("chart.hour"), last.hour)).foregroundStyle(Color.secondary.opacity(0.2))
                        PointMark(x: .value(L("chart.hour"), last.hour), y: .value(L("insights.today"), value))
                            .foregroundStyle(accent).symbolSize(55)
                    }
                }
                .chartXScale(domain: 0...24, range: .plotDimension(padding: 0))
                .chartYScale(domain: 0...chartMaximum).chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                        AxisGridLine().foregroundStyle(Color.primary.opacity(0.07))
                        AxisValueLabel(anchor: value.index == 0 ? .topLeading : value.index == 4 ? .topTrailing : .top,
                                       collisionResolution: .disabled) {
                            if let hour = value.as(Int.self) { Text("\(hour):00").font(.caption2) }
                        }
                    }
                }
                .frame(height: 180)
                .accessibilityIdentifier("insights.day.chart")
                .overlay { if loading { ProgressView() } }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(Text("\(L(metric.titleKey)), \(L("insights.today")) \(metric.text(comparison?.current, unit: model.preferences.unit)), \(L("insights.usual")) \(metric.text(comparison?.usualDayTotal, unit: model.preferences.unit))"))
                .accessibilityValue(Text("goals.target \(metric.clockText(model.preferences.goal(for: metric), unit: model.preferences.unit))"))
                .chartInspection("insights.day.chart", resetKey: metric.rawValue) { proxy in
                    let usual = comparison?.usualDayPoints ?? []
                    let current = comparison?.points ?? []
                    let hours = Set(usual.map(\.hour) + current.map(\.hour)).sorted()
                    return hours.compactMap { hour in
                        let today = current.first { $0.hour == hour }?.current
                        let baselineValue = usual.first { $0.hour == hour }?.usual
                        guard today != nil || baselineValue != nil else { return nil }
                        let label = String(format: "%d:%02d", Int(hour), Int((hour * 60).rounded()) % 60)
                        let value = "\(L("insights.today")): \(metric.text(today, unit: model.preferences.unit))\n\(L("insights.usual")): \(metric.text(baselineValue, unit: model.preferences.unit))"
                        return ChartInspectionPoint(proxy: proxy, x: hour, y: today ?? baselineValue,
                                                    title: label, value: value, color: accent)
                    }
                }
                if failed {
                    Text("health.refresh.error").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }

    }

    private func dayLegend(title: String, value: Double?, color: Color, dashed: Bool) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: 3))
                    path.addLine(to: CGPoint(x: 12, y: 3))
                }
                .stroke(color, style: StrokeStyle(lineWidth: dashed ? 2 : 3, lineCap: .round, dash: dashed ? [4, 3] : []))
                .frame(width: 12, height: 6)
                .accessibilityHidden(true)
                Text(L(title)).font(.caption2.weight(.medium))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Text(metric.text(value, unit: model.preferences.unit))
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit().contentTransition(.numericText())
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights.day.legend." + title)
    }
}

private struct TrendBar: Identifiable {
    var id: Int
    var value: Double?
    var current: Bool
    var date: Date
    var position: Int
}

private struct TrendsCard: View {
    var days: [ActivityDay]
    var onPremium: () -> Void
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    @State private var period: TrendPeriod = .sevenDays
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private var trend: ActivityTrend { ActivityStatistics.trend(days: days, metric: metric, period: period) }
    private func bars(_ slots: [TrendChartSlot]) -> [TrendBar] {
        // Each period keeps all its calendar positions, including unmeasured and future dates.
        let previous = slots.compactMap(\.previous)
        let current = slots.compactMap(\.current)
        return (previous + current).enumerated().map { index, bucket in
            TrendBar(id: index, value: bucket.summary(for: metric).average,
                     current: index >= previous.count, date: bucket.id, position: index)
        }
    }

    private func axisPositions(_ bars: [TrendBar]) -> [Int] {
        guard period == .month else { return bars.map(\.position) }
        return bars.filter { bar in
            let day = Calendar.current.component(.day, from: bar.date)
            let last = Calendar.current.range(of: .day, in: .month, for: bar.date)?.count ?? 31
            return day == 1 || day == 10 || day == 20 || day == last
        }.map(\.position)
    }

    private func axisLabelAnchor(_ bar: TrendBar) -> UnitPoint {
        guard period == .month else { return .top }
        let calendar = Calendar.current
        let day = calendar.component(.day, from: bar.date)
        // Keep month endpoints inside the plot and separate the adjacent last/first labels.
        if day == 1 { return .topLeading }
        if day == calendar.range(of: .day, in: .month, for: bar.date)?.count { return .topTrailing }
        return .top
    }

    private func axisLabel(_ bar: TrendBar) -> String {
        switch period {
        case .sevenDays, .week: return bar.date.formatted(.dateTime.locale(AppLocalization.locale).weekday(.narrow))
        case .month: return bar.date.formatted(.dateTime.locale(AppLocalization.locale).day())
        case .year: return bar.date.formatted(.dateTime.locale(AppLocalization.locale).month(.narrow))
        }
    }

    var body: some View {
        let trend = trend
        let slots = ActivityStatistics.trendChart(days: days, period: period)
        let chartBars = bars(slots)
        let boundary = Double(chartBars.first(where: \.current)?.position ?? chartBars.count) - 0.5
        WalkunoCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 12) {
                    InsightHeader(title: "insights.trends", metric: metric)
                    if let difference = trend.difference {
                        Label {
                            Text(metric.text(difference, unit: model.preferences.unit, signed: true))
                                .font(.system(.subheadline, design: .rounded, weight: .bold))
                        } icon: {
                            Image(systemName: abs(difference) < 0.5 ? "equal.circle.fill" : difference > 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        }
                        .foregroundStyle(difference >= 0 ? accent : WalkunoTheme.coral.tint(for: scheme))
                        .lineLimit(1).minimumScaleFactor(0.6)
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                Picker("statistics.period", selection: Binding(get: { period }, set: { value in
                    if value != .sevenDays && !model.purchases.isPremium { onPremium() } else { period = value }
                })) {
                    ForEach([TrendPeriod.sevenDays, .month, .year]) { Text(L("trend.\($0.rawValue)")).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("insights.trend.period")
                Chart {
                    ForEach(chartBars) { bar in
                        if let value = bar.value {
                            BarMark(x: .value(L("chart.date"), bar.position), y: .value(L(metric.titleKey), value),
                                    width: period == .month ? .fixed(2) : .automatic)
                                .foregroundStyle(bar.current ? accent.gradient : Color.secondary.opacity(0.35).gradient)
                                .cornerRadius(period == .month ? 1 : 5)
                                .accessibilityLabel(Text("\(bar.date.appFormatted(date: .abbreviated, time: .omitted)), \(L(bar.current ? "insights.current" : "insights.previous"))"))
                                .accessibilityValue(Text(metric.text(value, unit: model.preferences.unit)))
                        }
                    }
                    if let average = trend.current.average {
                        RuleMark(xStart: .value(L("chart.date"), boundary),
                                 xEnd: .value(L("chart.date"), Double(chartBars.count) - 0.5),
                                 y: .value(L("insights.daily.average"), average)).foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    if let average = trend.previous.average {
                        RuleMark(xStart: .value(L("chart.date"), -0.5),
                                 xEnd: .value(L("chart.date"), boundary),
                                 y: .value(L("insights.previous"), average)).foregroundStyle(Color.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXScale(domain: -0.5...max(0.5, Double(chartBars.count) - 0.5), range: .plotDimension(padding: 0))
                .chartForegroundStyleScale(domain: ["previous", "current"], range: [Color.secondary.opacity(0.35), accent])
                .chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: axisPositions(chartBars)) { value in
                        if let index = value.as(Int.self), chartBars.indices.contains(index) {
                            AxisValueLabel(anchor: axisLabelAnchor(chartBars[index]), collisionResolution: .disabled) {
                                Text(axisLabel(chartBars[index])).font(.caption2)
                                    .foregroundStyle(chartBars[index].current ? accent : Color.secondary)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden).frame(height: 175)
                .accessibilityIdentifier("insights.trend.chart")
                .chartInspection("insights.trend.chart", resetKey: "\(metric.rawValue)-\(period.rawValue)") { proxy in
                    chartBars.compactMap { bar in
                        return ChartInspectionPoint(proxy: proxy, x: bar.position, y: bar.value,
                            title: bar.date.appFormatted(date: .abbreviated, time: .omitted) + " · " + L(bar.current ? "insights.current" : "insights.previous"),
                            value: metric.text(bar.value, unit: model.preferences.unit), color: bar.current ? accent : .secondary)
                    }
                }
                .overlay { if chartBars.allSatisfy({ $0.value == nil }) { Text("chart.no.data").font(.caption).foregroundStyle(.secondary) } }
                HStack {
                    trendLegend(title: "insights.previous", value: trend.previous.average, color: .secondary)
                    Spacer()
                    trendLegend(title: "insights.current", value: trend.current.average, color: accent)
                }
            }
        }
        .onChange(of: model.purchases.isPremium) { _, premium in if !premium && period != .sevenDays { period = .sevenDays } }
    }

    private func trendLegend(title: String, value: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L(title), systemImage: "circle.fill").font(.caption2).foregroundStyle(color)
            Text(metric.text(value, unit: model.preferences.unit)).font(.caption.weight(.semibold))
        }
    }
}

private struct ActivityRecordCard: View {
    var days: [ActivityDay]
    var onPremium: () -> Void
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    @State private var period: ActivityPeriod = .year
    private var effectivePeriod: ActivityPeriod { model.purchases.isPremium ? period : .day }
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }

    var body: some View {
        let record = ActivityStatistics.record(days: days, metric: metric, period: effectivePeriod)
        WalkunoCard {
            VStack(alignment: .leading, spacing: 20) {
                InsightHeader(title: "insights.record.\(effectivePeriod.rawValue)", metric: metric)
                Picker("insights.records", selection: Binding(get: { effectivePeriod }, set: { value in
                    if value != .day && !model.purchases.isPremium { onPremium() } else { period = value }
                })) {
                    ForEach(ActivityPeriod.allCases) { Text(L("period.\($0.rawValue)")).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("insights.record.period")
                if let record {
                    HStack(alignment: .top) {
                        InsightValue(title: "insights.period.total", value: metric.text(record.summary(for: metric).total, unit: model.preferences.unit))
                        Image(systemName: "trophy.fill").font(.title).foregroundStyle(accent).accessibilityHidden(true)
                    }
                    Text(recordLabel(record)).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                    if effectivePeriod == .day {
                        RecordHourlyChart(date: record.id, metric: metric)
                    } else {
                        recordChart(record)
                    }
                } else { Text("chart.no.data").font(.subheadline).foregroundStyle(.secondary) }
            }
        }
    }

    private func recordLabel(_ record: ActivityBucket) -> String {
        switch effectivePeriod {
        case .day: record.id.formatted(Date.FormatStyle(date: .complete, time: .omitted, capitalizationContext: .beginningOfSentence).locale(AppLocalization.locale))
        case .week: record.id.formatted(.dateTime.locale(AppLocalization.locale).day().month(.abbreviated).year()) + " – " + record.interval.end.addingTimeInterval(-1).formatted(.dateTime.locale(AppLocalization.locale).day().month(.abbreviated).year())
        case .month: record.id.formatted(Date.FormatStyle(capitalizationContext: .beginningOfSentence).locale(AppLocalization.locale).month(.wide).year())
        case .year: record.id.formatted(.dateTime.locale(AppLocalization.locale).year())
        }
    }

    private func recordChart(_ record: ActivityBucket) -> some View {
        let aggregation: ActivityPeriod = effectivePeriod == .year ? .month : .day
        let buckets = ActivityStatistics.buckets(days: record.days, period: aggregation)
        let values = buckets.compactMap { $0.summary(for: metric).total }
        let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        return Chart {
            ForEach(buckets) { bucket in
                if let value = bucket.summary(for: metric).total {
                    BarMark(x: .value(L("chart.date"), bucket.id, unit: effectivePeriod == .year ? .month : .day), y: .value(L(metric.titleKey), value))
                        .foregroundStyle(accent.gradient).cornerRadius(7)
                        .accessibilityLabel(Text(bucket.id.appFormatted(date: .abbreviated, time: .omitted)))
                        .accessibilityValue(Text(metric.text(value, unit: model.preferences.unit)))
                }
            }
            if let average {
                RuleMark(y: .value(L("insights.average"), average)).foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .annotation(position: .top, alignment: .trailing, spacing: 4) {
                        RecordAverageLabel(value: metric.text(average, unit: model.preferences.unit))
                    }
                    .accessibilityLabel(Text("insights.average"))
                    .accessibilityValue(Text(metric.text(average, unit: model.preferences.unit)))
            }
        }
        .chartXScale(domain: record.interval.start...record.interval.end.addingTimeInterval(-1))
        .chartXAxis {
            AxisMarks(values: .stride(by: effectivePeriod == .year ? .month : .day, count: effectivePeriod == .month ? 5 : 1)) {
                AxisValueLabel(format: effectivePeriod == .year ? .dateTime.locale(AppLocalization.locale).month(.narrow) : .dateTime.locale(AppLocalization.locale).day())
            }
        }.chartYAxis(.hidden).frame(height: 175)
        .accessibilityIdentifier("insights.record.chart")
        .chartInspection("insights.record.chart", resetKey: "\(metric.rawValue)-\(effectivePeriod.rawValue)") { proxy in
            ChartInspectionPoint.buckets(in: record.interval, by: effectivePeriod == .year ? .month : .day).compactMap { interval in
                let bucket = buckets.first { $0.id == interval.start }
                let amount = bucket?.summary(for: metric).total
                let middle = interval.start.addingTimeInterval(interval.duration / 2)
                return ChartInspectionPoint(proxy: proxy, x: middle, y: amount,
                    title: effectivePeriod == .year
                        ? interval.start.formatted(.dateTime.locale(AppLocalization.locale).month(.wide).year()).uppercased(with: .current)
                        : interval.start.formatted(.dateTime.locale(AppLocalization.locale).day().month(.abbreviated).year()),
                    value: metric.text(amount, unit: model.preferences.unit), color: accent)
            }
        }
    }
}

private struct RecordHourlyChart: View {
    var date: Date
    var metric: ActivityMetric
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var hours: [HourActivity] = []
    @State private var loading = true
    @State private var failed = false
    @State private var loadedRequest: Request?

    private struct Request: Hashable {
        var date: Date
        var metric: ActivityMetric
        var updatedAt: Date?
    }
    private var request: Request { .init(date: date, metric: metric, updatedAt: model.lastUpdated) }
    private var visibleHours: [HourActivity] { loadedRequest == request ? hours : [] }

    var body: some View {
        let interval = ActivityPeriod.day.interval(containing: date)
        let values = visibleHours.compactMap { metric.value(in: $0) }
        let average = values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
        VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(visibleHours) { hour in
                    if let value = metric.value(in: hour) {
                        BarMark(x: .value(L("chart.hour"), hour.date, unit: .hour),
                                y: .value(L(metric.titleKey), value))
                            .foregroundStyle(model.effectiveTheme.tint(for: scheme).gradient).cornerRadius(3)
                            .accessibilityLabel(Text(hour.date.formatted(.dateTime.locale(AppLocalization.locale).hour().minute())))
                            .accessibilityValue(Text(metric.text(value, unit: model.preferences.unit)))
                    }
                }
                if let average {
                    RuleMark(y: .value(L("insights.average"), average)).foregroundStyle(Color.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .annotation(position: .top, alignment: .trailing, spacing: 4) {
                            RecordAverageLabel(value: metric.text(average, unit: model.preferences.unit))
                        }
                        .accessibilityLabel(Text("insights.average"))
                        .accessibilityValue(Text(metric.text(average, unit: model.preferences.unit)))
                }
            }
            .chartXScale(domain: interval.start...interval.end)
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) {
                    AxisValueLabel(format: .dateTime.locale(AppLocalization.locale).hour(.defaultDigits(amPM: .omitted)))
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 175)
            .overlay { if loading { ProgressView() } }
            .accessibilityLabel(Text("chart.hourly"))
            .accessibilityIdentifier("insights.record.hourly")
            .chartInspection("insights.record.hourly", resetKey: "\(metric.rawValue)-\(date.timeIntervalSinceReferenceDate)") { proxy in
                ChartInspectionPoint.buckets(in: interval, by: .hour).compactMap { bucket in
                    let hour = visibleHours.first { $0.date == bucket.start }
                    let amount = hour.flatMap { metric.value(in: $0) }
                    return ChartInspectionPoint(proxy: proxy, x: bucket.start.addingTimeInterval(bucket.duration / 2), y: amount,
                        title: bucket.start.formatted(.dateTime.locale(AppLocalization.locale).hour().minute()),
                        value: metric.text(amount, unit: model.preferences.unit), color: model.effectiveTheme.tint(for: scheme))
                }
            }
            if failed {
                Text("health.refresh.error").font(.caption).foregroundStyle(.secondary)
            } else if !loading && values.isEmpty {
                Text("chart.no.data").font(.caption).foregroundStyle(.secondary)
            }
        }
        .task(id: request) {
            let currentRequest = request
            loading = true; failed = false; hours = []; loadedRequest = nil
            do {
                let result = try await model.hourly(on: date, metric: metric)
                try Task.checkCancellation()
                hours = result; loadedRequest = currentRequest; loading = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { failed = true; loading = false } }
        }
    }
}

private struct YearHistoryCard: View {
    var days: [ActivityDay]
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    @State private var averages = true
    @AppStorage("statistics.history.horizontal") private var horizontal = true
    @Environment(\.colorScheme) private var scheme
    @ScaledMetric(relativeTo: .caption) private var yearLabelWidth = 76
    @ScaledMetric(relativeTo: .caption) private var labelHeight = 22
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }

    var body: some View {
        let years = ActivityStatistics.buckets(days: days, period: .year)
        let values = years.compactMap { value($0) }
        let maximum = max(values.max() ?? 1, 1)
        let best = years.filter { value($0) != nil }.max { (value($0) ?? 0) < (value($1) ?? 0) }?.id
        WalkunoCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    InsightHeader(title: "insights.all.years", metric: metric)
                    Button { horizontal.toggle() } label: {
                        Image(systemName: horizontal ? "rectangle.grid.1x2" : "rectangle.grid.3x1")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(accent)
                    .accessibilityLabel(Text(L(horizontal ? "insights.layout.show.vertical" : "insights.layout.show.horizontal")))
                    .accessibilityValue(Text(L(horizontal ? "insights.layout.horizontal" : "insights.layout.vertical")))
                    .accessibilityIdentifier("insights.history.orientation")
                }
                Picker("insights.aggregation", selection: $averages) {
                    Text("insights.totals").tag(false)
                    Text("insights.averages").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("insights.history.mode")
                if !averages {
                    InsightValue(title: "insights.total", value: metric.text(MetricSummary(days: days, metric: metric).total, unit: model.preferences.unit))
                }
                if values.isEmpty { Text("chart.no.data").font(.subheadline).foregroundStyle(.secondary) }
                if horizontal && !years.isEmpty {
                    GeometryReader { geometry in
                        let columnWidth = geometry.size.width / CGFloat(years.count)
                        let labels = visibleYearIndices(count: years.count, width: geometry.size.width)
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(years.enumerated()), id: \.element.id) { index, year in
                                yearColumn(year, maximum: maximum, best: best, width: columnWidth,
                                           showLabel: labels.contains(index),
                                           alignment: columnWidth >= yearLabelWidth ? .center
                                               : index == 0 ? .leading : index == years.count - 1 ? .trailing : .center)
                                    .frame(width: columnWidth)
                            }
                        }
                    }
                    .frame(height: 140 + labelHeight * 2 + 16)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("insights.history.horizontal")
                    .plotInspection("insights.history.horizontal", resetKey: "\(metric.rawValue)-\(averages)") { size in
                        years.enumerated().map { index, year in
                            let amount = value(year)
                            let title = ([year.id.formatted(.dateTime.locale(AppLocalization.locale).year())]
                                         + (year.id == best ? [L("insights.best.year")] : [])
                                         + (year.interval.end > .now ? [L("insights.partial")] : [])).joined(separator: " · ")
                            return ChartInspectionPoint(x: size.width * (CGFloat(index) + 0.5) / CGFloat(years.count),
                                y: amount.map { labelHeight + 8 + 140 * (1 - min(1, max(0, $0 / maximum))) },
                                title: title, value: metric.text(amount, unit: model.preferences.unit), color: accent)
                        }
                    }
                    if let current = years.last, current.interval.end > .now {
                        Text(current.id.formatted(.dateTime.locale(AppLocalization.locale).year()) + " · " + L("insights.partial"))
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                } else {
                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 14) {
                        ForEach(Array(years.reversed())) { year in
                            let description = ([year.id.formatted(.dateTime.locale(AppLocalization.locale).year())]
                                               + (year.id == best ? [L("insights.best.year")] : [])
                                               + (year.interval.end > .now ? [L("insights.partial")] : [])).joined(separator: ", ")
                            GridRow {
                                yearRowBar(year, maximum: maximum, best: best)
                                Text(metric.text(value(year), unit: model.preferences.unit))
                                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                                    .monospacedDigit().lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .gridColumnAlignment(.trailing)
                            }
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(description))
                            .accessibilityValue(Text(metric.text(value(year), unit: model.preferences.unit)))
                            .accessibilityIdentifier("insights.history.year.\(Calendar.current.component(.year, from: year.id))")
                        }
                    }

                }
            }
        }
    }

    private func yearRowBar(_ year: ActivityBucket, maximum: Double, best: Date?) -> some View {
        GeometryReader { geometry in
            let amount = value(year)
            let filledWidth = amount.map { max($0 > 0 ? 4 : 0, geometry.size.width * min(1, max(0, $0 / maximum))) } ?? 0
            ZStack(alignment: .leading) {
                Capsule().fill(accent.opacity(0.08))
                Capsule().fill(accent.gradient).frame(width: filledWidth)
                yearRowLabel(year, best: best).foregroundStyle(Color.primary)
                // Match the text contrast to the filled and empty portions of the bar.
                yearRowLabel(year, best: best).foregroundStyle(WalkunoStyle.ink)
                    .mask(alignment: .leading) { Rectangle().frame(width: filledWidth) }
            }
        }
        .frame(height: max(36, labelHeight + 14))
        .accessibilityHidden(true)
    }

    private func yearRowLabel(_ year: ActivityBucket, best: Date?) -> some View {
        HStack(spacing: 4) {
            Text(year.id.formatted(.dateTime.locale(AppLocalization.locale).year()))
                .font(.caption.weight(.semibold))
            if year.id == best { Image(systemName: "trophy.fill").font(.caption2) }
            if year.interval.end > .now { Text("insights.partial").font(.caption2) }
        }
        .lineLimit(1).minimumScaleFactor(0.65)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func visibleYearIndices(count: Int, width: CGFloat) -> Set<Int> {
        guard count > 1 else { return [0] }
        let labelCount = min(count, max(2, Int(width / yearLabelWidth)))
        // Keep both ends of the history and distribute the other labels evenly.
        return Set((0..<labelCount).map { index in
            Int((Double(index) * Double(count - 1) / Double(labelCount - 1)).rounded())
        })
    }

    private func yearColumn(_ year: ActivityBucket, maximum: Double, best: Date?, width: CGFloat,
                            showLabel: Bool, alignment: Alignment) -> some View {
        let showValue = width >= yearLabelWidth
        let yearTitle = year.id.formatted(.dateTime.locale(AppLocalization.locale).year())
        let description = ([yearTitle] + (year.id == best ? [L("insights.best.year")] : [])
                           + (year.interval.end > .now ? [L("insights.partial")] : [])).joined(separator: ", ")
        return VStack(spacing: 8) {
            ZStack {
                Text(metric.text(value(year), unit: model.preferences.unit))
                    .font(.system(.caption, design: .rounded, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .opacity(showValue ? 1 : 0)
                if !showValue && year.id == best {
                    Image(systemName: "trophy.fill").font(.caption).foregroundStyle(accent)
                }
            }
            .frame(height: labelHeight)
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Capsule().fill(accent.opacity(0.08))
                    if let amount = value(year) {
                        Capsule().fill(accent.gradient)
                            .frame(height: max(amount > 0 ? 4 : 0, geometry.size.height * min(1, amount / maximum)))
                    }
                }
            }
            .frame(width: min(26, width * 0.6), height: 140)
            Color.clear.frame(height: labelHeight)
                .overlay(alignment: alignment) {
                    if showLabel {
                        HStack(spacing: 4) {
                            Text(yearTitle).font(.caption.weight(.semibold))
                            if showValue && year.id == best {
                                Image(systemName: "trophy.fill").font(.caption2).foregroundStyle(accent)
                            }
                        }
                        .fixedSize()
                        .accessibilityIdentifier("insights.history.label.\(Calendar.current.component(.year, from: year.id))")
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(description))
        .accessibilityValue(Text(metric.text(value(year), unit: model.preferences.unit)))
        .accessibilityIdentifier("insights.history.year.\(Calendar.current.component(.year, from: year.id))")
    }

    private func value(_ bucket: ActivityBucket) -> Double? {
        let summary = bucket.summary(for: metric)
        return averages ? summary.average : summary.total
    }
}
