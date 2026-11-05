import WidgetKit
import SwiftUI
import AppIntents
import Charts

// Original identifiers remain valid for installed small widgets.
enum WidgetDisplayStyle: String, AppEnum {
    case ring, numbers, distance, distanceAndSteps, comparison, floors, weekly
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.style")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .ring: "widget.style.ring", .numbers: "widget.style.numbers", .distance: "widget.style.distance",
        .distanceAndSteps: "widget.style.distanceAndSteps", .comparison: "widget.style.comparison",
        .floors: "widget.style.floors", .weekly: "widget.style.weekly"
    ]
    var title: String { L("widget.style.\(rawValue)") }
    var symbol: String {
        switch self {
        case .distance, .distanceAndSteps: "figure.walk"
        case .comparison: "arrow.up.right"
        case .floors: "stairs"
        case .weekly: "calendar"
        default: "shoeprints.fill"
        }
    }
    var showsGoalRing: Bool { self == .ring || self == .distanceAndSteps || self == .comparison }
}

enum WidgetChartStyle: String, AppEnum {
    case hourly, goalTracking, weekly
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.style")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .hourly: "widget.chart.hourly", .goalTracking: "widget.chart.goalTracking", .weekly: "widget.style.weekly"
    ]
    var title: String { self == .weekly ? L("widget.style.weekly") : L("widget.chart.\(rawValue)") }
}

struct WalkunoWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.configuration"
    static let description = IntentDescription("widget.configuration.description")
    @Parameter(title: "widget.style", default: .ring) var style: WidgetDisplayStyle
}

struct WalkunoChartIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.charts.configuration"
    static let description = IntentDescription("widget.charts.description")
    @Parameter(title: "widget.style", default: .hourly) var style: WidgetChartStyle
}

struct WalkunoEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
    var style: WidgetDisplayStyle
}

struct WalkunoChartEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
    var style: WidgetChartStyle
}

private enum WidgetCache {
    static func current() -> WidgetSnapshot? {
        guard let snapshot = LocalStore.snapshot(), snapshot.isCurrent() else { return nil }
        return snapshot
    }
    static func midnight(after date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: date))!
    }
}

struct WalkunoProvider: AppIntentTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<WalkunoWidgetIntent>] {
        WidgetDisplayStyle.allCases.filter { $0 != .numbers }.map { style in
            let intent = WalkunoWidgetIntent()
            intent.style = style
            return .init(intent: intent, description: style.title)
        }
    }
    func placeholder(in context: Context) -> WalkunoEntry { .init(date: .now, snapshot: .preview(), style: .ring) }
    func snapshot(for configuration: WalkunoWidgetIntent, in context: Context) async -> WalkunoEntry {
        .init(date: .now, snapshot: context.isPreview ? .preview() : WidgetCache.current(), style: configuration.style)
    }
    func timeline(for configuration: WalkunoWidgetIntent, in context: Context) async -> Timeline<WalkunoEntry> {
        let now = Date.now, midnight = WidgetCache.midnight(after: .now)
        return Timeline(entries: [.init(date: now, snapshot: WidgetCache.current(), style: configuration.style),
                                  .init(date: midnight, snapshot: nil, style: configuration.style)],
                        policy: .after(min(now.addingTimeInterval(30 * 60), midnight)))
    }
}

struct WalkunoChartProvider: AppIntentTimelineProvider {
    func recommendations() -> [AppIntentRecommendation<WalkunoChartIntent>] {
        WidgetChartStyle.allCases.map { style in
            let intent = WalkunoChartIntent()
            intent.style = style
            return .init(intent: intent, description: style.title)
        }
    }
    func placeholder(in context: Context) -> WalkunoChartEntry { .init(date: .now, snapshot: .preview(), style: .hourly) }
    func snapshot(for configuration: WalkunoChartIntent, in context: Context) async -> WalkunoChartEntry {
        .init(date: .now, snapshot: context.isPreview ? .preview() : WidgetCache.current(), style: configuration.style)
    }
    func timeline(for configuration: WalkunoChartIntent, in context: Context) async -> Timeline<WalkunoChartEntry> {
        let now = Date.now, midnight = WidgetCache.midnight(after: .now)
        return Timeline(entries: [.init(date: now, snapshot: WidgetCache.current(), style: configuration.style),
                                  .init(date: midnight, snapshot: nil, style: configuration.style)],
                        policy: .after(min(now.addingTimeInterval(30 * 60), midnight)))
    }
}

struct WalkunoWidgetView: View {
    var entry: WalkunoEntry
    @Environment(\.widgetFamily) private var family
    private var theme: WalkunoTheme { entry.snapshot?.theme ?? .mint }
    private var steps: Int? { entry.snapshot?.today.steps }
    private var progress: Double { ActivityMath.progress(steps: steps, goal: entry.snapshot?.goal ?? 8000) }
    private var unit: DistanceUnit { entry.snapshot?.unit ?? .kilometers }
    private var week: [ActivityDay] { entry.snapshot?.recentWeek() ?? [] }
    private var weeklySteps: Int? { ActivitySummary(days: week, goals: .init()).total }
    private var fullValue: String {
        switch entry.style {
        case .distance: return entry.snapshot?.today.meters.map { unit.convert(meters: $0).formatted(.number.precision(.fractionLength(1))) } ?? "—"
        case .floors: return stepsText(entry.snapshot?.today.floors.map { Int($0.rounded()) })
        case .comparison: return widgetChangeText(entry.snapshot?.change(for: .steps))
        case .weekly: return stepsText(weeklySteps)
        default: return stepsText(steps)
        }
    }
    private var compactValue: String {
        switch entry.style {
        case .ring, .numbers, .distanceAndSteps: WidgetNumbers.steps(steps)
        case .weekly: WidgetNumbers.steps(weeklySteps)
        case .floors: WidgetNumbers.steps(entry.snapshot?.today.floors.map { Int($0.rounded()) })
        case .comparison: WidgetNumbers.percentageChange(entry.snapshot?.change(for: .steps))
        default: fullValue
        }
    }
    private var valueUnit: String {
        switch entry.style {
        case .distance: unit.symbol
        case .floors: L("metric.floors")
        case .comparison: L("widget.vsYesterday")
        default: L("today.steps")
        }
    }
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryInline:
                Label("\(compactValue) \(valueUnit)\(entry.style == .distanceAndSteps ? " · " + distanceText(entry.snapshot?.today.meters, unit: unit) : "")",
                      systemImage: entry.style.symbol)
            default:
                #if os(iOS)
                smallHome
                #else
                circular
                #endif
            }
        }
        .privacySensitive()
        .widgetURL(URL(string: "walkuno://today"))
        .containerBackground(for: .widget) { WalkunoStyle.ink }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
    private var circular: some View {
        ZStack {
            if entry.style.showsGoalRing {
                ProgressRing(progress: progress, accent: theme.accent, secondaryAccent: theme.secondaryAccent, lineWidth: 5).padding(4)
            }
            VStack(spacing: 0) {
                Text(compactValue)
                    .font(.system(size: entry.style.showsGoalRing ? 13 : 20, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.45)
                if entry.style == .distanceAndSteps {
                    Text(distanceText(entry.snapshot?.today.meters, unit: unit)).font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.6)
                } else if entry.style == .weekly {
                    Text("widget.sevenDays.short").font(.system(size: 8))
                    WidgetWeekBars(days: week, today: entry.date, accent: theme.accent, showsDays: false)
                        .frame(height: 12)
                } else {
                    Text(valueUnit).font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.6)
                }
            }.padding(.horizontal, entry.style.showsGoalRing ? 9 : 3)
        }.widgetAccentable()
    }
    private var accessibilitySummary: String {
        var parts = [entry.style.title, "\(fullValue) \(valueUnit)"]
        if entry.style == .distanceAndSteps { parts.append(distanceText(entry.snapshot?.today.meters, unit: unit)) }
        if entry.style.showsGoalRing {
            parts.append("\(L("widget.goal")) \(stepsText(steps)) / \((entry.snapshot?.goal ?? 8000).formatted())")
        }
        if entry.style == .comparison { parts.append(L("widget.sameTime")) }
        return parts.joined(separator: ". ")
    }
    #if os(iOS)
    private var smallHome: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) { BrandMark(size: 14, theme: theme); Text("Walkuno").font(.caption.bold()) }.foregroundStyle(theme.accent)
            HStack(spacing: 10) {
                if entry.style.showsGoalRing {
                    ZStack {
                        ProgressRing(progress: progress, accent: theme.accent, secondaryAccent: theme.secondaryAccent, lineWidth: 5).padding(3)
                        Text(WidgetNumbers.steps(steps)).font(.system(size: 10, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.5).padding(6)
                    }.frame(width: 44, height: 44)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(compactValue).font(.system(.title, design: .rounded, weight: .bold)).lineLimit(1).minimumScaleFactor(0.5)
                    Text(valueUnit).font(.caption2).foregroundStyle(.secondary)
                    if entry.style == .distanceAndSteps {
                        Text(distanceText(entry.snapshot?.today.meters, unit: unit)).font(.caption2).lineLimit(1)
                    }
                }
            }
            if entry.style == .weekly {
                WidgetWeekBars(days: week, today: entry.date, accent: theme.accent)
            } else if entry.style == .comparison {
                Text("widget.sameTime").font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            WidgetUpdatedLabel(date: entry.snapshot?.updatedAt)
        }.foregroundStyle(.white).environment(\.colorScheme, .dark)
    }
    #endif
}

struct WalkunoChartWidgetView: View {
    var entry: WalkunoChartEntry
    @Environment(\.widgetFamily) private var family
    private var compact: Bool { family == .accessoryRectangular }
    private var theme: WalkunoTheme { entry.snapshot?.theme ?? .mint }
    private var steps: Int? { entry.snapshot?.today.steps }
    private var week: [ActivityDay] { entry.snapshot?.recentWeek() ?? [] }
    private var weeklySteps: Int? { ActivitySummary(days: week, goals: .init()).total }
    private var footerFont: Font { .system(size: compact ? 8 : 11, design: .rounded) }
    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 8) {
            if !compact {
                HStack(spacing: 5) {
                    BrandMark(size: 14, theme: theme)
                    Text("Walkuno").font(.caption.bold())
                    Spacer(minLength: 0)
                    Text(entry.style.title).font(.caption2).foregroundStyle(.secondary)
                }.foregroundStyle(theme.accent)
            }
            switch entry.style {
            case .weekly:
                WidgetWeekBars(days: week, today: entry.date, accent: theme.accent)
            case .hourly:
                WidgetHourlyBars(activity: entry.snapshot?.activity, accent: theme.accent, showsAxes: !compact)
            case .goalTracking:
                WidgetGoalChart(snapshot: entry.snapshot, accent: theme.accent, compact: compact)
            }
            footer.font(footerFont).lineLimit(1).minimumScaleFactor(0.65)
            if !compact { WidgetUpdatedLabel(date: entry.snapshot?.updatedAt) }
        }
        .privacySensitive()
        .widgetURL(URL(string: "walkuno://today"))
        .containerBackground(for: .widget) { WalkunoStyle.ink }
        .accessibilityElement(children: .combine)
        #if os(iOS)
        .foregroundStyle(.white).environment(\.colorScheme, .dark)
        #endif
    }
    @ViewBuilder private var footer: some View {
        switch entry.style {
        case .weekly:
            VStack(alignment: .leading, spacing: 1) {
                Text("\(L("tab.today")) · \(stepsText(steps)) \(L("today.steps"))")
                Text("\(L("widget.sevenDays.short")) · \(stepsText(weeklySteps)) \(L("today.steps"))").foregroundStyle(.secondary)
            }
        case .hourly:
            VStack(alignment: .leading, spacing: 1) {
                Text("\(stepsText(steps)) \(L("today.steps")) · \(distanceText(entry.snapshot?.today.meters, unit: entry.snapshot?.unit ?? .kilometers))")
                Text("\(compact ? WidgetNumbers.percentageChange(entry.snapshot?.change(for: .steps)) : widgetChangeText(entry.snapshot?.change(for: .steps))) \(L("widget.sameTime.short"))")
                    .foregroundStyle(.secondary)
            }
        case .goalTracking:
            VStack(alignment: .leading, spacing: 1) {
                Text("\(L("insights.today")) · \(stepsText(steps)) \(L("today.steps"))").foregroundStyle(theme.accent)
                Text("\(L("insights.usual")) · \(stepsText(entry.snapshot?.activity?.usual?.points.last?.usual.map { Int($0.rounded()) })) \(L("today.steps"))")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private func widgetChangeText(_ change: Double?) -> String {
    guard let change, change.isFinite else { return "—" }
    return change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always(includingZero: false)))
}

private struct WidgetHourlyBars: View {
    var activity: WidgetActivityDetail?
    var accent: Color
    var showsAxes: Bool
    var body: some View {
        let buckets = activity?.last24Hours() ?? []
        Group {
            if buckets.compactMap(\.steps).isEmpty {
                WidgetChartUnavailable()
            } else {
                Chart {
                    ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                        if let steps = bucket.steps {
                            RectangleMark(xStart: .value("Hour", Double(index) + 0.15), xEnd: .value("Hour", Double(index) + 0.85),
                                          yStart: .value("Steps", 0.0), yEnd: .value("Steps", Double(steps)))
                                .foregroundStyle(bucket.isToday ? accent : Color.gray.opacity(0.6)).cornerRadius(1)
                        }
                    }
                }
                .chartXScale(domain: 0.0...24.0)
                .chartYScale(domain: .automatic(includesZero: true))
                .chartYAxis(.hidden).chartLegend(.hidden)
                .chartXAxis {
                    if showsAxes {
                        AxisMarks(values: [0.5, 6.5, 12.5, 18.5, 23.5]) { value in
                            AxisValueLabel {
                                if let index = value.as(Double.self).map({ Int($0) }), buckets.indices.contains(index) {
                                    Text(buckets[index].date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)))).font(.system(size: 8))
                                }
                            }
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("widget.chart.hourly.accessibility"))
                .accessibilityValue(buckets.map { "\($0.date.formatted(.dateTime.day().month().hour())): \(stepsText($0.steps))" }.joined(separator: ", "))
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetGoalChart: View {
    var snapshot: WidgetSnapshot?
    var accent: Color
    var compact: Bool
    var body: some View {
        let points = snapshot?.activity?.cumulative(todaySteps: snapshot?.today.steps) ?? []
        let maximum = max(Double(snapshot?.goal ?? 8000), points.flatMap { [$0.current, $0.usual].compactMap { $0 } }.max() ?? 1)
        Group {
            if points.compactMap(\.current).isEmpty && points.compactMap(\.usual).isEmpty {
                WidgetChartUnavailable()
            } else {
                Chart {
                    if let goal = snapshot?.goal {
                        RuleMark(y: .value("Goal", goal)).foregroundStyle(Color.primary.opacity(0.2))
                            .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [5, 3]))
                            .annotation(position: .overlay, alignment: .topLeading) {
                                Text("\(L("widget.goal.short")) \(WidgetNumbers.steps(goal, abbreviateFrom: 1000))")
                                    .font(.system(size: compact ? 6 : 8)).foregroundStyle(.secondary)
                            }
                    }
                    ForEach(points) { point in
                        if let usual = point.usual {
                            LineMark(x: .value("Hour", point.hour), y: .value("Steps", usual), series: .value("Day", "usual"))
                                .foregroundStyle(Color.gray.opacity(0.8)).lineStyle(StrokeStyle(lineWidth: compact ? 1 : 1.5, dash: [2, 2]))
                        }
                        if let current = point.current {
                            LineMark(x: .value("Hour", point.hour), y: .value("Steps", current), series: .value("Day", "today"))
                                .foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round))
                        }
                    }
                    if let last = points.last, let current = last.current {
                        PointMark(x: .value("Hour", last.hour), y: .value("Steps", current)).foregroundStyle(accent).symbolSize(compact ? 10 : 28)
                    }
                }
                .chartXScale(domain: 0.0...24.0).chartYScale(domain: 0...max(1, maximum * 1.08))
                .chartYAxis(.hidden).chartLegend(.hidden)
                .chartXAxis(.hidden)
                .padding(.bottom, compact ? 8 : 12)
                .overlay(alignment: .bottom) {
                    HStack(spacing: 0) {
                        ForEach(compact ? [0, 12, 24] : [0, 6, 12, 18, 24], id: \.self) { hour in
                            if hour > 0 { Spacer(minLength: 0) }
                            Text(hour.formatted()).font(.system(size: compact ? 6 : 8)).foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("widget.chart.goal.accessibility"))
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetWeekBars: View {
    var days: [ActivityDay]
    var today: Date
    var accent: Color
    var showsDays = true
    var body: some View {
        GeometryReader { geometry in
            let peak = days.max { ($0.steps ?? -1) < ($1.steps ?? -1) }
            let maximum = Double(max(1, peak?.steps ?? 1))
            let barHeight = max(2, geometry.size.height - (showsDays ? 14 : 0))
            HStack(alignment: .bottom, spacing: showsDays ? 4 : 2) {
                ForEach(days) { day in
                    let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2).fill(.primary.opacity(0.04))
                            if let steps = day.steps {
                                RoundedRectangle(cornerRadius: 2).fill(accent.opacity(isToday ? 1 : 0.6))
                                    .frame(height: max(2, barHeight * Double(steps) / maximum))
                                    .overlay(alignment: .top) {
                                        if day.id == peak?.id, steps > 0, showsDays {
                                            Text(WidgetNumbers.steps(steps, abbreviateFrom: 1000))
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                .lineLimit(1).minimumScaleFactor(0.5).foregroundStyle(WalkunoStyle.ink)
                                                .padding(.top, 2)
                                        }
                                    }
                            } else {
                                Text("—").font(.system(size: 8)).foregroundStyle(.secondary)
                            }
                        }.frame(height: barHeight)
                        if showsDays {
                            Text(day.date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 9, weight: isToday ? .heavy : .regular))
                                .foregroundStyle(isToday ? .primary : .secondary).frame(maxWidth: .infinity)
                                .background(isToday ? accent.opacity(0.25) : .clear, in: Capsule())
                        }
                    }.frame(minWidth: 0, maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(day.date.formatted(.dateTime.weekday(.wide).day().month())): \(stepsText(day.steps)) \(L("today.steps"))")
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

private struct WidgetChartUnavailable: View {
    var body: some View {
        Text("widget.hourly.unavailable").font(.system(size: 9)).foregroundStyle(.secondary)
            .multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetUpdatedLabel: View {
    var date: Date?
    var body: some View {
        Group {
            if let date { HStack(spacing: 3) { Image(systemName: "arrow.clockwise"); Text(date, style: .time) } }
            else { Text("widget.open") }
        }.font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
    }
}

extension WidgetSnapshot {
    static func preview(at now: Date = .now) -> WidgetSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let clock = calendar.dateComponents([.hour, .minute, .second], from: now)
        let cutoffHour = Double(clock.hour ?? 0) + Double(clock.minute ?? 0) / 60 + Double(clock.second ?? 0) / 3600
        let weights = [0, 0, 0, 0, 0, 40, 220, 580, 820, 420, 110, 260, 760, 470, 320, 480, 670, 562, 840, 620, 320, 180, 60, 0]
        func hours(on date: Date, through end: Date, total: Int) -> [HourActivity] {
            let eligible = weights.indices.filter { calendar.date(byAdding: .hour, value: $0, to: date)! < end }
            let sum = max(1, eligible.map { weights[$0] }.reduce(0, +))
            return eligible.map { hour in
                let steps = Int(Double(total * weights[hour]) / Double(sum))
                return HourActivity(date: calendar.date(byAdding: .hour, value: hour, to: date)!, steps: steps, meters: Double(steps) * 0.72)
            }
        }
        let previousCutoff = WidgetActivityDetail.previousDayCutoff(for: now)
        let history = hours(on: yesterday, through: previousCutoff ?? yesterday, total: 8500)
        let reference = WidgetUsualActivity(comparison: .init(today: [], history: [history], metric: .steps, cutoffHour: cutoffHour))
        let week = (0..<7).reversed().map { offset in
            ActivityDay(date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                        steps: offset == 0 ? 10432 : [8200, 12400, 7100, 9600, 5400, 8800][offset - 1])
        }
        return .init(updatedAt: now, today: .init(date: today, steps: 10432, meters: 8345, floors: 9),
                     goal: 12000, week: week, theme: .mint, unit: .kilometers,
                     activity: .init(sampledAt: now, previousCutoff: previousCutoff,
                                     todayHours: hours(on: today, through: now, total: 10432),
                                     yesterdayHours: hours(on: yesterday, through: today, total: 11500),
                                     yesterdayAtSameTime: .init(date: yesterday, steps: 8200, meters: 6300), usual: reference))
    }
}

struct WalkunoActivityWidget: Widget {
    let kind = "WalkunoActivity"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WalkunoWidgetIntent.self, provider: WalkunoProvider()) { WalkunoWidgetView(entry: $0) }
            .configurationDisplayName("widget.name").description("widget.description")
            #if os(iOS)
            .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryInline])
            #else
            .supportedFamilies([.accessoryCircular, .accessoryInline])
            #endif
    }
}

struct WalkunoChartWidget: Widget {
    let kind = "WalkunoCharts"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WalkunoChartIntent.self, provider: WalkunoChartProvider()) { WalkunoChartWidgetView(entry: $0) }
            .configurationDisplayName("widget.charts.name").description("widget.charts.description")
            #if os(iOS)
            .supportedFamilies([.systemMedium, .systemLarge, .accessoryRectangular])
            #else
            .supportedFamilies([.accessoryRectangular])
            #endif
    }
}

@main
struct WalkunoWidgetBundle: WidgetBundle {
    var body: some Widget {
        WalkunoActivityWidget()
        WalkunoChartWidget()
    }
}
