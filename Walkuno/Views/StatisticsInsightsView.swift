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

    var body: some View {
        Text(L(title)).font(.headline).frame(maxWidth: .infinity, alignment: .leading)
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

private struct InsightDetails: View {
    var days: [ActivityDay]
    var identifier = "insights.details"
    @Environment(AppModel.self) private var model
    var body: some View {
        DisclosureGroup("insights.details") {
            Text("insights.details.totals").font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 12)
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 18) {
                ForEach(ActivityMetric.allCases.filter { model.preferences.showEnergy || $0 != .energy }) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L(metric.titleKey)).font(.caption).foregroundStyle(.secondary)
                        Text(metric.text(MetricSummary(days: days, metric: metric).total, unit: model.preferences.unit))
                            .font(.system(.headline, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                    }
                }
            }.padding(.top, 16)
        }.font(.subheadline).accessibilityIdentifier(identifier)
    }
}

struct StatisticsInsightsView: View {
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    var earliest: Date?
    var onPremium: () -> Void
    private var days: [ActivityDay] { model.days.filter { $0.date >= (earliest ?? .distantPast) && $0.date <= .now } }

    var body: some View {
        VStack(spacing: 20) {
            DailyComparisonCard(earliest: earliest, metric: metric)
            TrendsCard(days: days, onPremium: onPremium, metric: metric)
            WeekdayProfileCard(days: days, metric: metric)
            ActivityRecordCard(days: days, onPremium: onPremium, metric: metric)
            YearHistoryCard(days: days, metric: metric)
            VStack(alignment: .leading, spacing: 10) {
                Text("insights.data.note").font(.caption).foregroundStyle(.secondary)
                if !model.isDemo && (model.today.exerciseMinutes == nil || model.today.floors == nil) {
                    Button("insights.health.connect") { Task { await model.connectHealth() } }
                        .font(.caption.weight(.semibold))
                    Text("insights.exercise.note").font(.caption2).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DailyComparisonCard: View {
    var earliest: Date?
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    @State private var comparison: DayComparison?
    @State private var loading = false
    @State private var failed = false
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private var baseline: Color { model.effectiveTheme.secondaryTint(for: scheme) }
    private var taskID: String {
        "\(metric.rawValue)-\(earliest?.timeIntervalSince1970 ?? 0)-\(model.lastUpdated?.timeIntervalSince1970 ?? 0)-\(model.preferences.healthRequested)-\(model.days.count)"
    }
    private var message: String {
        guard let current = comparison?.current, let usual = comparison?.usual else { return L("insights.day.unavailable") }
        let delta = usual > 0 ? (current - usual) / usual : (current > 0 ? 1 : 0)
        return L(abs(delta) <= 0.05 ? "insights.day.same" : delta > 0 ? "insights.day.ahead" : "insights.day.behind")
    }

    var body: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 20) {
                InsightHeader(title: "insights.day", metric: metric)
                HStack(alignment: .top, spacing: 12) {
                    InsightValue(title: "insights.today", value: metric.text(comparison?.current, unit: model.preferences.unit), color: accent)
                    InsightValue(title: "insights.usual", value: metric.text(comparison?.usual, unit: model.preferences.unit), color: baseline)
                }
                Chart {
                    ForEach(comparison?.points ?? []) { point in
                        if let usual = point.usual {
                            LineMark(x: .value(L("chart.hour"), point.hour), y: .value(L("insights.usual"), usual), series: .value("series", "usual"))
                                .foregroundStyle(baseline).lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [5, 4]))
                        }
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
                .chartXScale(domain: 0...24).chartYScale(domain: .automatic(includesZero: true)).chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                        AxisValueLabel { if let hour = value.as(Int.self) { Text("\(hour):00").font(.caption2) } }
                    }
                }
                .frame(height: 180)
                .overlay { if loading { ProgressView() } }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("\(L(metric.titleKey)), \(L("insights.today")) \(metric.text(comparison?.current, unit: model.preferences.unit)), \(L("insights.usual")) \(metric.text(comparison?.usual, unit: model.preferences.unit))"))
                Text(failed ? L("health.refresh.error") : message).font(.subheadline).foregroundStyle(.secondary)
                if let comparison, comparison.baselineDays > 0 {
                    Text(String(format: L("insights.day.basis"), comparison.baselineDays,
                                (model.lastUpdated ?? .now).formatted(date: .omitted, time: .shortened)))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .task(id: taskID) {
            loading = true; failed = false; comparison = nil
            do {
                let result = try await model.dayComparison(metric: metric, earliest: earliest)
                try Task.checkCancellation()
                comparison = result; loading = false
            } catch is CancellationError { }
            catch { if !Task.isCancelled { failed = true; loading = false } }
        }
    }
}

private struct TrendBar: Identifiable {
    var id: Int
    var value: Double?
    var current: Bool
    var date: Date
}

private struct TrendsCard: View {
    var days: [ActivityDay]
    var onPremium: () -> Void
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    @State private var period: TrendPeriod = .week
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private var trend: ActivityTrend { ActivityStatistics.trend(days: days, metric: metric, period: period) }
    private func bars(_ trend: ActivityTrend) -> [TrendBar] {
        let aggregation: ActivityPeriod = period == .year ? .month : .day
        func buckets(_ interval: DateInterval, _ rows: [ActivityDay], current: Bool) -> [TrendBar] {
            let allDays = ActivityMath.days(in: interval, available: rows)
            return ActivityStatistics.buckets(days: allDays, period: aggregation).enumerated().map { index, bucket in
                TrendBar(id: index, value: bucket.summary(for: metric).average, current: current, date: bucket.id)
            }
        }
        let previous = buckets(trend.previousInterval, trend.previousDays, current: false)
        let current = buckets(trend.currentInterval, trend.currentDays, current: true)
        return previous + current.enumerated().map { index, bar in
            TrendBar(id: previous.count + index, value: bar.value, current: true, date: bar.date)
        }
    }

    var body: some View {
        let trend = trend
        WalkunoCard {
            VStack(alignment: .leading, spacing: 20) {
                InsightHeader(title: "insights.trends", metric: metric)
                Picker("statistics.period", selection: Binding(get: { period }, set: { value in
                    if value == .year && !model.purchases.isPremium { onPremium() } else { period = value }
                })) {
                    ForEach(TrendPeriod.allCases) { Text(L("trend.\($0.rawValue)")).tag($0) }
                }.pickerStyle(.segmented).accessibilityIdentifier("insights.trend.period")
                HStack(alignment: .top) {
                    InsightValue(title: "insights.daily.average", value: metric.text(trend.current.average, unit: model.preferences.unit))
                    if let difference = trend.difference {
                        VStack(alignment: .trailing, spacing: 6) {
                            Image(systemName: abs(difference) < 0.5 ? "equal.circle.fill" : difference > 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            Text(metric.text(difference, unit: model.preferences.unit, signed: true)).font(.system(.title3, design: .rounded, weight: .bold))
                                .minimumScaleFactor(0.6).lineLimit(1)
                        }.foregroundStyle(difference >= 0 ? accent : WalkunoTheme.coral.tint(for: scheme))
                    }
                }
                Chart {
                    ForEach(bars(trend)) { bar in
                        if let value = bar.value {
                            BarMark(x: .value(L("chart.date"), bar.id), y: .value(L(metric.titleKey), value))
                                .foregroundStyle(bar.current ? accent.gradient : Color.secondary.opacity(0.35).gradient).cornerRadius(5)
                                .accessibilityLabel(Text("\(bar.date.formatted(date: .abbreviated, time: .omitted)), \(L(bar.current ? "insights.current" : "insights.previous"))"))
                                .accessibilityValue(Text(metric.text(value, unit: model.preferences.unit)))
                        }
                    }
                    if let average = trend.current.average {
                        RuleMark(y: .value(L("insights.daily.average"), average)).foregroundStyle(accent)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    if let average = trend.previous.average {
                        RuleMark(y: .value(L("insights.previous"), average)).foregroundStyle(Color.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXScale(domain: -0.5...max(0.5, Double(bars(trend).count) - 0.5))
                .chartXAxis(.hidden).chartYAxis(.hidden).frame(height: 155)
                .overlay { if trend.current.average == nil && trend.previous.average == nil { Text("chart.no.data").font(.caption).foregroundStyle(.secondary) } }
                HStack {
                    trendLegend(title: "insights.previous", value: trend.previous.average, color: .secondary)
                    Spacer()
                    trendLegend(title: "insights.current", value: trend.current.average, color: accent)
                }
                Text("insights.trend.note").font(.caption).foregroundStyle(.secondary)
                Text(String(format: L("insights.trend.coverage"), trend.current.observedDays, trend.previous.observedDays))
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .onChange(of: model.purchases.isPremium) { _, premium in if !premium && period == .year { period = .week } }
    }

    private func trendLegend(title: String, value: Double?, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(L(title), systemImage: "circle.fill").font(.caption2).foregroundStyle(color)
            Text(metric.text(value, unit: model.preferences.unit)).font(.caption.weight(.semibold))
        }
    }
}

private struct WeekdayProfileCard: View {
    var days: [ActivityDay]
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private func weekdayName(_ weekday: Int, short: Bool = false) -> String {
        let formatter = DateFormatter()
        return short ? formatter.veryShortWeekdaySymbols[weekday - 1] : formatter.weekdaySymbols[weekday - 1]
    }

    var body: some View {
        let weekdays = ActivityStatistics.weekdays(days: days, metric: metric)
        let best = weekdays.filter { $0.summary.average != nil }.max { ($0.summary.average ?? 0) < ($1.summary.average ?? 0) }
        let average = MetricSummary(days: days.filter { $0.date < Calendar.current.startOfDay(for: .now) }, metric: metric).average
        WalkunoCard {
            VStack(alignment: .leading, spacing: 20) {
                InsightHeader(title: "insights.weekday", metric: metric)
                HStack(alignment: .top, spacing: 12) {
                    InsightValue(title: "insights.daily.average", value: metric.text(average, unit: model.preferences.unit))
                    InsightValue(title: "insights.best.weekday", value: best.map { weekdayName($0.weekday).capitalized } ?? "—", color: accent)
                }
                Chart {
                    ForEach(weekdays) { day in
                        if let value = day.summary.average {
                            BarMark(x: .value(L("chart.date"), String(day.weekday)), y: .value(L(metric.titleKey), value))
                                .foregroundStyle(accent.opacity(day.weekday == best?.weekday ? 1 : 0.45).gradient).cornerRadius(12)
                                .accessibilityLabel(Text(weekdayName(day.weekday)))
                                .accessibilityValue(Text(metric.text(value, unit: model.preferences.unit)))
                        }
                    }
                    if let average {
                        RuleMark(y: .value(L("insights.daily.average"), average)).foregroundStyle(Color.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                }
                .chartXScale(domain: weekdays.map { String($0.weekday) })
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel { if let text = value.as(String.self), let weekday = Int(text) { Text(weekdayName(weekday, short: true)) } }
                    }
                }
                .chartYAxis(.hidden).frame(height: 175)
                if let best {
                    Text(String(format: L("insights.weekday.summary"), weekdayName(best.weekday), metric.text(best.summary.average, unit: model.preferences.unit), L(metric.titleKey).lowercased()))
                        .font(.subheadline).foregroundStyle(.secondary)
                } else { Text("chart.no.data").font(.subheadline).foregroundStyle(.secondary) }
                Text("insights.weekday.note").font(.caption2).foregroundStyle(.secondary)
                InsightDetails(days: days.filter { $0.date < Calendar.current.startOfDay(for: .now) })
            }
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
                    recordChart(record)
                    Text(String(format: L("insights.record.coverage"), record.summary(for: metric).observedDays))
                        .font(.caption).foregroundStyle(.secondary)
                    if record.interval.end > .now { Text("insights.in.progress").font(.caption2).foregroundStyle(.secondary) }
                    InsightDetails(days: record.days, identifier: "insights.record.details")
                } else { Text("chart.no.data").font(.subheadline).foregroundStyle(.secondary) }
            }
        }
    }

    private func recordLabel(_ record: ActivityBucket) -> String {
        switch effectivePeriod {
        case .day: record.id.formatted(Date.FormatStyle(date: .complete, time: .omitted, capitalizationContext: .beginningOfSentence))
        case .week: record.id.formatted(.dateTime.day().month(.abbreviated).year()) + " – " + record.interval.end.addingTimeInterval(-1).formatted(.dateTime.day().month(.abbreviated).year())
        case .month: record.id.formatted(Date.FormatStyle(capitalizationContext: .beginningOfSentence).month(.wide).year())
        case .year: record.id.formatted(.dateTime.year())
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
                        .accessibilityLabel(Text(bucket.id.formatted(date: .abbreviated, time: .omitted)))
                        .accessibilityValue(Text(metric.text(value, unit: model.preferences.unit)))
                }
            }
            if let average {
                RuleMark(y: .value(L("insights.average"), average)).foregroundStyle(Color.secondary)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            }
        }
        .chartXScale(domain: record.interval.start...record.interval.end.addingTimeInterval(-1))
        .chartXAxis {
            AxisMarks(values: .stride(by: effectivePeriod == .year ? .month : .day, count: effectivePeriod == .month ? 5 : 1)) {
                AxisValueLabel(format: effectivePeriod == .year ? .dateTime.month(.narrow) : .dateTime.day())
            }
        }.chartYAxis(.hidden).frame(height: effectivePeriod == .day ? 90 : 175)
    }
}

private struct YearHistoryCard: View {
    var days: [ActivityDay]
    @Environment(AppModel.self) private var model
    var metric: ActivityMetric
    @State private var averages = true
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }

    var body: some View {
        let years = ActivityStatistics.buckets(days: days, period: .year).reversed()
        let values = years.compactMap { value($0) }
        let maximum = max(values.max() ?? 1, 1)
        let best = years.filter { value($0) != nil }.max { (value($0) ?? 0) < (value($1) ?? 0) }?.id
        let overall = MetricSummary(days: days, metric: metric)
        WalkunoCard {
            VStack(alignment: .leading, spacing: 20) {
                InsightHeader(title: "insights.all.years", metric: metric)
                Picker("insights.aggregation", selection: $averages) {
                    Text("insights.totals").tag(false)
                    Text("insights.averages").tag(true)
                }.pickerStyle(.segmented).accessibilityIdentifier("insights.history.mode")
                InsightValue(title: averages ? "insights.daily.average" : "insights.total", value: metric.text(averages ? overall.average : overall.total, unit: model.preferences.unit))
                if values.isEmpty { Text("chart.no.data").font(.subheadline).foregroundStyle(.secondary) }
                ForEach(Array(years)) { year in
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(year.id.formatted(.dateTime.year())).font(.subheadline.weight(.semibold))
                            if year.id == best { Image(systemName: "trophy.fill").font(.caption).foregroundStyle(accent).accessibilityLabel(Text("insights.best.year")) }
                            if year.interval.end > .now { Text("insights.partial").font(.caption2).foregroundStyle(.secondary) }
                            Spacer(minLength: 4)
                            Text(metric.text(value(year), unit: model.preferences.unit)).font(.system(.subheadline, design: .rounded, weight: .semibold))
                        }
                        GeometryReader { geometry in
                            Capsule().fill(accent.opacity(0.08))
                            if let amount = value(year) {
                                Capsule().fill(accent.gradient).frame(width: max(amount > 0 ? 4 : 0, geometry.size.width * min(1, amount / maximum)))
                            }
                        }.frame(height: 18).accessibilityHidden(true)
                    }.accessibilityElement(children: .combine)
                }
                Text(model.purchases.isPremium ? "insights.years.note" : "insights.years.free.note").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func value(_ bucket: ActivityBucket) -> Double? {
        let summary = bucket.summary(for: metric)
        return averages ? summary.average : summary.total
    }
}
