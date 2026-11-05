import WidgetKit
import SwiftUI
import AppIntents
import Charts

// Original identifiers remain valid for installed small widgets.
enum WidgetDisplayStyle: String, AppEnum {
    case ring, numbers, distance, distanceAndSteps, comparison, floors, weekly, weeklyLine
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.style")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .ring: "widget.style.ring", .numbers: "widget.style.numbers", .distance: "widget.style.distance",
        .distanceAndSteps: "widget.style.distanceAndSteps", .comparison: "widget.style.comparison",
        .floors: "widget.style.floors", .weekly: "widget.style.weekly", .weeklyLine: "widget.style.weeklyLine"
    ]
    var title: String { L("widget.style.\(rawValue)") }
    var symbol: String {
        switch self {
        case .distance, .distanceAndSteps: "figure.walk"
        case .comparison: "arrow.up.right"
        case .floors: "stairs"
        case .weekly, .weeklyLine: "calendar"
        default: "shoeprints.fill"
        }
    }
    var showsGoalRing: Bool { self == .ring || self == .distanceAndSteps || self == .comparison }
}

enum WidgetChartStyle: String, AppEnum {
    case hourly, goalTracking, weekly, weeklyLine, dailyRhythm
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.style")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .hourly: "widget.chart.hourly", .goalTracking: "widget.chart.goalTracking",
        .weekly: "widget.style.weekly", .weeklyLine: "widget.style.weeklyLine",
        .dailyRhythm: "widget.chart.dailyRhythm"
    ]
    var title: String {
        switch self {
        case .weekly, .weeklyLine: L("widget.style.\(rawValue)")
        default: L("widget.chart.\(rawValue)")
        }
    }
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
        case .weekly, .weeklyLine: return stepsText(weeklySteps)
        default: return stepsText(steps)
        }
    }
    private var compactValue: String {
        switch entry.style {
        case .ring, .numbers, .distanceAndSteps: WidgetNumbers.steps(steps)
        case .weekly, .weeklyLine: WidgetNumbers.steps(weeklySteps)
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
            case .accessoryRectangular: lockRectangle
            case .accessoryInline:
                Label("\(compactValue) \(valueUnit)\(entry.style == .distanceAndSteps ? " · " + distanceText(entry.snapshot?.today.meters, unit: unit) : "")",
                      systemImage: entry.style.symbol)
            default:
                #if os(iOS)
                home
                #else
                circular
                #endif
            }
        }
        .privacySensitive()
        .widgetURL(URL(string: "walkuno://today"))
        .modifier(WidgetSurface(theme: theme))
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
                } else if entry.style == .weekly || entry.style == .weeklyLine {
                    Text("widget.sevenDays.short").font(.system(size: 8))
                    Group {
                        if entry.style == .weeklyLine {
                            WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true, showsDays: false)
                        } else {
                            WidgetWeekBars(days: week, today: entry.date, accent: theme.accent, showsDays: false)
                        }
                    }.frame(height: 12)
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
    private var lockRectangle: some View {
        HStack(spacing: 8) {
            circular.frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.style.title).font(.caption2.bold())
                Text(distanceText(entry.snapshot?.today.meters, unit: unit)).font(.caption2)
                Text("\(L("widget.goal.short")) · \(entry.snapshot?.goal.formatted() ?? "—")")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }.lineLimit(1).minimumScaleFactor(0.6)
        }
    }
    #if os(iOS)
    private var home: some View {
        let small = family == .systemSmall
        let large = family == .systemLarge
        return VStack(alignment: .leading, spacing: small ? 4 : 8) {
            WidgetHeader(theme: theme, title: small ? nil : entry.style.title)
            HStack(spacing: 14) {
                if entry.style.showsGoalRing {
                    WidgetCounter(snapshot: entry.snapshot).frame(width: small ? 60 : large ? 86 : 68, height: small ? 60 : large ? 86 : 68)
                        .frame(maxWidth: small ? .infinity : nil)
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(compactValue).font(.system(size: small ? 32 : 40, weight: .bold, design: .rounded))
                            .lineLimit(1).minimumScaleFactor(0.45)
                        Text(valueUnit).font(.caption2).foregroundStyle(.secondary)
                    }
                }
                if !small {
                    if !large && (entry.style == .weekly || entry.style == .weeklyLine) {
                        Group {
                            if entry.style == .weekly { WidgetWeekBars(days: week, today: entry.date, accent: theme.accent) }
                            else { WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true) }
                        }.frame(height: 62)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                        WidgetValue(title: "metric.distance", value: distanceText(entry.snapshot?.today.meters, unit: unit))
                        WidgetValue(title: "widget.goal.short", value: entry.snapshot?.goal.formatted() ?? "—")
                        if entry.style == .comparison {
                            Text(widgetChangeText(entry.snapshot?.change(for: .steps))).font(.headline).foregroundStyle(theme.accent)
                            Text("widget.sameTime.short").font(.system(size: 8)).foregroundStyle(.secondary)
                        }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if (small || large) && (entry.style == .weekly || entry.style == .weeklyLine) {
                Group {
                    if entry.style == .weekly { WidgetWeekBars(days: week, today: entry.date, accent: theme.accent) }
                    else { WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: small) }
                }.frame(maxHeight: small ? 45 : .infinity)
            } else if small {
                Text(entry.style == .comparison ? L("widget.sameTime.short") : distanceText(entry.snapshot?.today.meters, unit: unit))
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, alignment: entry.style.showsGoalRing ? .center : .leading)
            } else if large {
                WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: !large)
            }
            if large {
                WidgetSummaryRow(snapshot: entry.snapshot)
                Text("widget.chart.goalTracking").font(.caption.bold()).foregroundStyle(theme.accent)
                WidgetGoalChart(snapshot: entry.snapshot, accent: theme.accent, compact: false)
            }
            Spacer(minLength: 0)
            WidgetUpdatedLabel(date: entry.snapshot?.updatedAt)
        }
    }
    #endif
}

struct WalkunoChartWidgetView: View {
    var entry: WalkunoChartEntry
    @Environment(\.widgetFamily) private var family
    private var compact: Bool { family == .accessoryRectangular }
    private var small: Bool {
        #if os(iOS)
        family == .systemSmall
        #else
        false
        #endif
    }
    private var large: Bool {
        #if os(iOS)
        family == .systemLarge
        #else
        false
        #endif
    }
    private var theme: WalkunoTheme { entry.snapshot?.theme ?? .mint }
    private var week: [ActivityDay] { entry.snapshot?.recentWeek() ?? [] }
    private var average: Int? { ActivitySummary(days: week, goals: .init()).average }
    private var isWeek: Bool { entry.style == .weekly || entry.style == .weeklyLine }

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : small ? 4 : 6) {
            if !compact { WidgetHeader(theme: theme, title: small ? nil : entry.style.title) }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(small || compact ? WidgetNumbers.steps(entry.snapshot?.today.steps) : stepsText(entry.snapshot?.today.steps))
                    .font(.system(size: compact ? 16 : small ? 25 : 30, weight: .bold, design: .rounded))
                Text("today.steps").font(.system(size: compact ? 9 : 11)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if !small && !compact {
                    Text(distanceText(entry.snapshot?.today.meters, unit: entry.snapshot?.unit ?? .kilometers))
                        .font(.caption).foregroundStyle(theme.accent)
                }
            }.lineLimit(1).minimumScaleFactor(0.6)
            chart
            if isWeek {
                Text("\(L("widget.average")) · \(small || compact ? WidgetNumbers.steps(average) : stepsText(average))")
                    .foregroundStyle(theme.accent).lineLimit(1).minimumScaleFactor(0.65)
            } else if entry.style == .goalTracking {
                Text("\(L("widget.goal.short")) · \(entry.snapshot?.goal.formatted() ?? "—")")
                    .foregroundStyle(theme.accent).lineLimit(1).minimumScaleFactor(0.65)
            } else {
                Text("\(WidgetNumbers.percentageChange(entry.snapshot?.change(for: .steps))) \(L("widget.sameTime.short"))")
                    .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.65)
            }
            if large {
                WidgetSummaryRow(snapshot: entry.snapshot)
                Text(isWeek ? "widget.chart.dailyRhythm" : "widget.style.weeklyLine")
                    .font(.caption.bold()).foregroundStyle(theme.accent)
                Group {
                    if isWeek { WidgetDailyRhythm(snapshot: entry.snapshot, compact: true) }
                    else { WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true) }
                }.frame(height: 65)
            }
            if !compact { WidgetUpdatedLabel(date: entry.snapshot?.updatedAt) }
        }
        .font(.system(size: compact ? 9 : 11, design: .rounded))
        .privacySensitive()
        .widgetURL(URL(string: "walkuno://today"))
        .modifier(WidgetSurface(theme: theme))
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var chart: some View {
        switch entry.style {
        case .weekly: WidgetWeekBars(days: week, today: entry.date, accent: theme.accent, showsDays: !compact)
        case .weeklyLine: WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: compact || small, showsDays: !compact)
        case .hourly: WidgetHourlyBars(activity: entry.snapshot?.activity, accent: theme.accent, compact: compact || small)
        case .goalTracking: WidgetGoalChart(snapshot: entry.snapshot, accent: theme.accent, compact: compact || small)
        case .dailyRhythm: WidgetDailyRhythm(snapshot: entry.snapshot, compact: compact || small)
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
    var compact: Bool
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
                .chartXScale(domain: 0.0...24.0, range: .plotDimension(padding: 0))
                .chartYScale(domain: .automatic(includesZero: true))
                .chartYAxis(.hidden).chartLegend(.hidden)
                .chartXAxis(.hidden)
                .padding(.bottom, compact ? 8 : 12)
                .overlay(alignment: .bottom) {
                    GeometryReader { geometry in
                        ForEach(Array(buckets.enumerated()), id: \.element.id) { index, bucket in
                            let hour = Calendar.current.component(.hour, from: bucket.date)
                            if hour.isMultiple(of: 3) {
                                Text(hour, format: .number.precision(.integerLength(2)))
                                    .font(.system(size: compact ? 6 : 8, design: .rounded)).monospacedDigit()
                                    .foregroundStyle(.secondary).fixedSize()
                                    .position(x: geometry.size.width * (Double(index) + 0.5) / 24,
                                              y: geometry.size.height / 2)
                            }
                        }
                    }.frame(height: compact ? 8 : 12).accessibilityHidden(true)
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

private struct WidgetWeekCurve: View {
    var days: [ActivityDay]
    var today: Date
    var accent: Color
    var compact = false
    var showsDays = true
    var body: some View {
        let maximum = Double(max(1, days.compactMap(\.steps).max() ?? 1))
        Chart {
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                if let steps = day.steps {
                    let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
                    // Missing days break the line instead of inventing a zero or a connecting value.
                    let segment = days.prefix(index).filter { $0.steps == nil }.count
                    LineMark(x: .value("Day", Double(index) + 0.5), y: .value("Steps", steps),
                             series: .value("Segment", segment))
                        .foregroundStyle(accent.opacity(0.7))
                        .lineStyle(StrokeStyle(lineWidth: compact ? 1.5 : 2.5, lineCap: .round))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("Day", Double(index) + 0.5), y: .value("Steps", steps))
                        .foregroundStyle(accent.opacity(isToday ? 1 : 0.7))
                        .symbolSize(showsDays ? (isToday ? (compact ? 18 : 40) : (compact ? 8 : 20)) : 5)
                }
            }
        }
        .chartXScale(domain: 0.0...Double(max(1, days.count)), range: .plotDimension(padding: 0))
        .chartYScale(domain: 0.0...(maximum * 1.15), range: .plotDimension(padding: showsDays ? 3 : 1))
        .chartXAxis(.hidden).chartYAxis(.hidden).chartLegend(.hidden)
        .overlay {
            if days.compactMap(\.steps).isEmpty {
                Text("—").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, showsDays ? 14 : 0)
        .overlay(alignment: .bottom) {
            if showsDays {
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
                        Text(day.date.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 9, weight: isToday ? .heavy : .regular))
                            .foregroundStyle(isToday ? .primary : .secondary).frame(minWidth: 0, maxWidth: .infinity)
                            .background(isToday ? accent.opacity(0.25) : .clear, in: Capsule())
                    }
                }.accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.style.weeklyLine"))
        .accessibilityValue(days.map {
            "\($0.date.formatted(.dateTime.weekday(.wide).day().month())): \(stepsText($0.steps)) \(L("today.steps"))"
        }.joined(separator: ", "))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            let steps = offset == 0 ? 10432 : [8200, 12400, 7100, 9600, 5400, 8800][offset - 1]
            return ActivityDay(date: calendar.date(byAdding: .day, value: -offset, to: today)!,
                               steps: steps, meters: Double(steps) * 0.8, kilocalories: Double(steps) * 0.035,
                               exerciseMinutes: Double(steps) / 180, floors: Double(steps / 650))
        }
        let historyDays = (0..<740).map { offset in
            let steps = 3200 + ((offset * 2767 + 3171) % 10200)
            return ActivityDay(date: calendar.date(byAdding: .day, value: -offset, to: today)!, steps: steps,
                               meters: Double(steps) * 0.8, kilocalories: Double(steps) * 0.035,
                               exerciseMinutes: Double(steps) / 180, floors: Double(steps / 650))
        }.filter { $0.date < week.first!.date } + week
        return .init(updatedAt: now, today: .init(date: today, steps: 10432, meters: 8345, kilocalories: 365, exerciseMinutes: 58, floors: 9),
                     goal: 12000, week: week, theme: .mint, unit: .kilometers,
                     activity: .init(sampledAt: now, previousCutoff: previousCutoff,
                                     todayHours: hours(on: today, through: now, total: 10432),
                                     yesterdayHours: hours(on: yesterday, through: today, total: 11500),
                                     yesterdayAtSameTime: .init(date: yesterday, steps: 8200, meters: 6300), usual: reference),
                     display: .init(), history: .init(days: historyDays, goals: .init(), includeYear: true, now: now))
    }
}

struct WalkunoActivityWidget: Widget {
    let kind = "WalkunoActivity"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WalkunoWidgetIntent.self, provider: WalkunoProvider()) { WalkunoWidgetView(entry: $0) }
            .configurationDisplayName("widget.name").description("widget.description")
            #if os(iOS)
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
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
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
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
        #if os(iOS)
        WalkunoTrendsWidget()
        WalkunoDashboardWidget()
        #endif
    }
}

// MARK: - Shared widget design

private struct WidgetSurface: ViewModifier {
    var theme: WalkunoTheme
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    private var home: Bool {
        #if os(iOS)
        family == .systemSmall || family == .systemMedium || family == .systemLarge
        #else
        false
        #endif
    }
    func body(content: Content) -> some View {
        content
            .environment(\.colorScheme, home ? .dark : scheme)
            .containerBackground(for: .widget) {
                if home {
                    LinearGradient(colors: [WalkunoStyle.ink, WalkunoStyle.ink, theme.secondaryAccent.opacity(0.28)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                } else { WalkunoStyle.ink }
            }
    }
}

private struct WidgetHeader: View {
    var theme: WalkunoTheme
    var title: String?
    var body: some View {
        HStack(spacing: 5) {
            BrandMark(size: 14, theme: theme)
            Text("Walkuno").font(.system(size: 11, weight: .bold, design: .rounded))
            Spacer(minLength: 2)
            if let title { Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary) }
        }.lineLimit(1).minimumScaleFactor(0.65).foregroundStyle(theme.accent)
    }
}

private struct WidgetValue: View {
    var title: String
    var value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L(title)).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).monospacedDigit()
        }.lineLimit(1).minimumScaleFactor(0.6).accessibilityElement(children: .combine)
    }
}

private struct WidgetSummaryRow: View {
    var snapshot: WidgetSnapshot?
    var body: some View {
        HStack(spacing: 10) {
            WidgetValue(title: "metric.distance", value: distanceText(snapshot?.today.meters, unit: snapshot?.unit ?? .kilometers))
            Spacer(minLength: 0)
            WidgetValue(title: "metric.exercise", value: (snapshot?.today.exerciseMinutes.map { Int($0.rounded()).formatted() } ?? "—") + " min")
            Spacer(minLength: 0)
            if snapshot?.display?.showEnergy != false {
                WidgetValue(title: "metric.energy", value: (snapshot?.today.kilocalories.map { Int($0.rounded()).formatted() } ?? "—") + " kcal")
            } else {
                WidgetValue(title: "metric.floors", value: stepsText(snapshot?.today.floors.map { Int($0.rounded()) }))
            }
        }
    }
}

/// Static versions of the app's five counters, sized for a WidgetKit snapshot.
private struct WidgetCounter: View {
    var snapshot: WidgetSnapshot?
    private var theme: WalkunoTheme { snapshot?.theme ?? .mint }
    private var progress: Double { ActivityMath.progress(steps: snapshot?.today.steps, goal: snapshot?.goal ?? 8000) }
    private var style: CounterStyle { snapshot?.display?.counter ?? .ring }
    private var hasBase: Bool { style == .path || style == .milestones || style == .minimal }
    var body: some View {
        ZStack {
            switch style {
            case .ring:
                ProgressRing(progress: progress, accent: theme.accent, secondaryAccent: theme.secondaryAccent, lineWidth: 6).padding(5)
            case .horizon:
                Circle().trim(from: 0, to: 0.75).stroke(theme.accent.opacity(0.18), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(135)).padding(5)
                Circle().trim(from: 0, to: 0.75 * min(1, progress))
                    .stroke(theme.accent.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(135)).padding(5)
            case .path:
                ZStack {
                    WidgetRouteShape().stroke(theme.accent.opacity(0.18), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    WidgetRouteShape().trim(from: 0, to: min(1, progress))
                        .stroke(theme.accent.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                }.frame(height: 15).frame(maxHeight: .infinity, alignment: .bottom)
            case .milestones:
                GeometryReader { geometry in
                    HStack(alignment: .bottom, spacing: 2) {
                        ForEach(0..<10) { index in
                            let height = geometry.size.height * (0.4 + Double(index) / 15)
                            let fill = min(1, max(0, progress * 10 - Double(index)))
                            RoundedRectangle(cornerRadius: 1).fill(theme.accent.opacity(0.18))
                                .overlay(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 1).fill(theme.accent.gradient).frame(height: height * fill)
                                }.frame(height: height)
                        }
                    }.frame(maxHeight: .infinity, alignment: .bottom)
                }.frame(height: 15).frame(maxHeight: .infinity, alignment: .bottom)
            case .minimal:
                GeometryReader { geometry in
                    Capsule().fill(theme.accent.opacity(0.18))
                        .overlay(alignment: .leading) { Capsule().fill(theme.accent).frame(width: geometry.size.width * min(1, progress)) }
                }.frame(height: 3).padding(.horizontal, 4).frame(maxHeight: .infinity, alignment: .bottom)
            }
            VStack(spacing: 2) {
                Text(WidgetNumbers.steps(snapshot?.today.steps))
                    .font(.system(size: style == .minimal ? 24 : 20, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.4)
                Text("today.steps").font(.system(size: 8)).foregroundStyle(.secondary)
                if snapshot?.today.steps != nil {
                    Text(progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.system(size: 8, weight: .semibold)).foregroundStyle(theme.accent)
                }
            }.padding(.horizontal, hasBase ? 2 : 12).offset(y: hasBase ? -8 : 0)
        }.widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stepsText(snapshot?.today.steps)) \(L("today.steps")), \(L("widget.goal.short")) \(snapshot?.goal.formatted() ?? "—")")
    }
}

private struct WidgetRouteShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w * 0.05, y: h * 0.75))
        path.addCurve(to: CGPoint(x: w * 0.40, y: h * 0.25),
                      control1: CGPoint(x: w * 0.23, y: h * 0.78), control2: CGPoint(x: w * 0.20, y: h * 0.12))
        path.addCurve(to: CGPoint(x: w * 0.69, y: h * 0.66),
                      control1: CGPoint(x: w * 0.54, y: h * 0.35), control2: CGPoint(x: w * 0.52, y: h * 0.90))
        path.addCurve(to: CGPoint(x: w * 0.95, y: h * 0.24),
                      control1: CGPoint(x: w * 0.82, y: h * 0.45), control2: CGPoint(x: w * 0.79, y: h * 0.17))
        return path
    }
}

/// The home page's 24 clock-hour pairs: today in the palette, yesterday in grey.
private struct WidgetDailyRhythm: View {
    var snapshot: WidgetSnapshot?
    var compact: Bool
    private var theme: WalkunoTheme { snapshot?.theme ?? .mint }
    var body: some View {
        let rhythm = snapshot.map {
            DailyRhythmActivity(date: $0.today.date, hours: $0.activity?.todayHours ?? [],
                                previousHours: $0.activity?.yesterdayHours ?? [], now: $0.updatedAt)
        }
        Group {
            if let rhythm, rhythm.hours.contains(where: { $0.steps != nil || $0.previousSteps != nil }) {
                Chart {
                    ForEach(rhythm.hours) { hour in
                        if let previous = hour.previousSteps {
                            RectangleMark(xStart: .value("Hour", Double(hour.hour) + 0.08), xEnd: .value("Hour", Double(hour.hour) + 0.46),
                                          yStart: .value("Steps", 0), yEnd: .value("Steps", previous))
                                .foregroundStyle(.gray.opacity(0.5)).cornerRadius(1)
                        }
                        if let current = hour.steps {
                            RectangleMark(xStart: .value("Hour", Double(hour.hour) + 0.52), xEnd: .value("Hour", Double(hour.hour) + 0.9),
                                          yStart: .value("Steps", 0), yEnd: .value("Steps", current))
                                .foregroundStyle(theme.accent).cornerRadius(1)
                        }
                    }
                }
                .chartXScale(domain: 0...24, range: .plotDimension(padding: 0))
                .chartYAxis(.hidden).chartLegend(.hidden)
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 24]) { value in
                        AxisValueLabel { if let hour = value.as(Int.self) { Text("\(hour)h").font(.system(size: compact ? 7 : 9)) } }
                    }
                }
                .accessibilityLabel(Text("widget.chart.dailyRhythm"))
            } else { WidgetChartUnavailable() }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#if os(iOS)
// MARK: - Configurable trends

enum WidgetMetric: String, AppEnum {
    case steps, distance, energy, exerciseTime, floors
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.metric")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .steps: "metric.steps", .distance: "metric.distance", .energy: "metric.energy",
        .exerciseTime: "metric.exercise", .floors: "metric.floors"
    ]
    var activity: ActivityMetric { ActivityMetric(rawValue: rawValue) ?? .steps }
    var title: String { L(self == .exerciseTime ? "metric.exercise" : "metric.\(rawValue)") }
    func text(_ value: Double?, unit: DistanceUnit, compact: Bool = false) -> String {
        guard let value, value.isFinite else { return "—" }
        switch self {
        case .distance: return distanceText(value, unit: unit)
        case .energy: return (compact ? WidgetNumbers.steps(Int(value.rounded())) : Int(value.rounded()).formatted()) + " kcal"
        case .exerciseTime: return Int(value.rounded()).formatted() + " min"
        case .steps, .floors: return compact ? WidgetNumbers.steps(Int(value.rounded())) : Int(value.rounded()).formatted()
        }
    }
}

enum WidgetPeriod: String, AppEnum {
    case week, month, year
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "statistics.period")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .week: "widget.sevenDays.short", .month: "period.month", .year: "period.year"
    ]
    var title: String { L(self == .week ? "widget.sevenDays.short" : "period.\(rawValue)") }
}

enum WidgetTrendChart: String, AppEnum {
    case curve, bars, comparison, calendar
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "widget.graph")
    static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .curve: "widget.graph.curve", .bars: "widget.graph.bars",
        .comparison: "widget.graph.comparison", .calendar: "widget.graph.calendar"
    ]
}

struct WalkunoTrendsIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.trends.name"
    static let description = IntentDescription("widget.trends.description")
    @Parameter(title: "widget.metric", default: .steps) var metric: WidgetMetric
    @Parameter(title: "statistics.period", default: .week) var period: WidgetPeriod
    @Parameter(title: "widget.graph", default: .curve) var chart: WidgetTrendChart
}

struct WalkunoTrendsEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
    var metric: WidgetMetric
    var period: WidgetPeriod
    var chart: WidgetTrendChart
}

struct WalkunoTrendsProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> WalkunoTrendsEntry {
        .init(date: .now, snapshot: .preview(), metric: .steps, period: .week, chart: .curve)
    }
    func recommendations() -> [AppIntentRecommendation<WalkunoTrendsIntent>] {
        WidgetTrendChart.allCases.map { chart in
            let intent = WalkunoTrendsIntent(); intent.chart = chart
            return .init(intent: intent, description: L("widget.graph.\(chart.rawValue)"))
        }
    }
    func snapshot(for configuration: WalkunoTrendsIntent, in context: Context) async -> WalkunoTrendsEntry {
        entry(configuration, at: .now, snapshot: context.isPreview ? .preview() : WidgetCache.current())
    }
    func timeline(for configuration: WalkunoTrendsIntent, in context: Context) async -> Timeline<WalkunoTrendsEntry> {
        let now = Date.now, midnight = WidgetCache.midnight(after: .now)
        return .init(entries: [entry(configuration, at: now, snapshot: WidgetCache.current()),
                               entry(configuration, at: midnight, snapshot: nil)],
                     policy: .after(min(now.addingTimeInterval(1800), midnight)))
    }
    private func entry(_ config: WalkunoTrendsIntent, at date: Date, snapshot: WidgetSnapshot?) -> WalkunoTrendsEntry {
        .init(date: date, snapshot: snapshot, metric: config.metric, period: config.period, chart: config.chart)
    }
}

struct WalkunoTrendsView: View {
    var entry: WalkunoTrendsEntry
    @Environment(\.widgetFamily) private var family
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var lock: Bool { family == .accessoryRectangular }
    private var theme: WalkunoTheme { entry.snapshot?.theme ?? .mint }
    private var metric: WidgetMetric { entry.metric == .energy && entry.snapshot?.display?.showEnergy == false ? .steps : entry.metric }
    private var period: WidgetPeriod { entry.chart == .calendar ? .month : entry.period }
    private var cached: WidgetHistoryPeriod? { entry.snapshot?.history?.periods.first { $0.period == period.rawValue } }
    private var current: [ActivityDay] {
        if period == .week { return entry.snapshot?.recentWeek() ?? [] }
        return (period == .year ? cached?.dailyAverages : cached?.current) ?? []
    }
    private var previous: [ActivityDay] { (period == .year ? cached?.previousDailyAverages : cached?.previous) ?? [] }
    private var average: Double? {
        if period == .week { return MetricSummary(days: current, metric: metric.activity).average }
        return cached.flatMap { metric.activity.value(in: $0.average) }
    }
    private var valueText: String { metric.text(average, unit: entry.snapshot?.unit ?? .kilometers, compact: small || lock) }
    var body: some View {
        VStack(alignment: .leading, spacing: lock ? 2 : small ? 4 : 6) {
            if !lock { WidgetHeader(theme: theme, title: small ? nil : period.title) }
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(valueText).font(.system(size: lock ? 16 : small ? 24 : 28, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.5)
                if !small && !lock {
                    Spacer(minLength: 0)
                    Text(metric.title).font(.caption).foregroundStyle(theme.accent)
                }
            }
            if !lock {
                Text(small ? "\(L("widget.average")) · \(metric.title)" : L("widget.dailyAverage"))
                    .font(.system(size: 9)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            Group {
                if entry.chart == .calendar {
                    WidgetCalendar(days: current, progress: entry.snapshot?.history?.monthProgress ?? [], metric: metric,
                                   unit: entry.snapshot?.unit ?? .kilometers, accent: theme.accent, compact: small || lock)
                } else {
                    WidgetHistoryChart(days: current, previous: previous, metric: metric, period: period,
                                       chart: entry.chart, average: average, theme: theme, unit: entry.snapshot?.unit ?? .kilometers, compact: small || lock)
                }
            }
            if large {
                HStack {
                    WidgetValue(title: "widget.total", value: metric.text(MetricSummary(days: cached?.current ?? current, metric: metric.activity).total,
                                                                        unit: entry.snapshot?.unit ?? .kilometers))
                    Spacer(minLength: 0)
                    WidgetValue(title: "widget.best", value: metric.text(current.compactMap { metric.activity.value(in: $0) }.max(),
                                                                       unit: entry.snapshot?.unit ?? .kilometers))
                }
            }
            if entry.chart == .comparison {
                HStack(spacing: 5) {
                    Circle().fill(theme.accent).frame(width: 5, height: 5); Text("widget.current")
                    Circle().fill(.gray).frame(width: 5, height: 5); Text("widget.previous")
                }.font(.system(size: lock ? 7 : 9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
            } else if lock {
                Text("\(L("widget.average")) · \(metric.title)").font(.system(size: 8)).foregroundStyle(.secondary)
            } else {
                Text("\(period.title) · \(metric.title)").font(.system(size: 9)).foregroundStyle(theme.accent).lineLimit(1)
            }
            if !lock { WidgetUpdatedLabel(date: entry.snapshot?.updatedAt) }
        }
        .privacySensitive().widgetURL(URL(string: "walkuno://statistics"))
        .modifier(WidgetSurface(theme: theme)).accessibilityElement(children: .combine)
    }
}

private struct WidgetHistoryChart: View {
    var days: [ActivityDay]
    var previous: [ActivityDay]
    var metric: WidgetMetric
    var period: WidgetPeriod
    var chart: WidgetTrendChart
    var average: Double?
    var theme: WalkunoTheme
    var unit: DistanceUnit
    var compact: Bool
    private var count: Int { max(1, max(days.count, previous.count)) }
    private var maximum: Double {
        max(1, max((days + (chart == .comparison ? previous : [])).compactMap { metric.activity.value(in: $0) }.max() ?? 1, average ?? 0)) * 1.15
    }
    var body: some View {
        Group {
            if days.compactMap({ metric.activity.value(in: $0) }).isEmpty && (chart != .comparison || previous.compactMap({ metric.activity.value(in: $0) }).isEmpty) {
                Text("chart.no.data").font(.system(size: 10)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart {
                    if let average {
                        RuleMark(y: .value("Average", average)).foregroundStyle(theme.secondaryAccent.opacity(0.7))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    }
                    ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                        if let value = metric.activity.value(in: day) {
                            if chart == .curve {
                                let segment = days.prefix(index).filter { metric.activity.value(in: $0) == nil }.count
                                LineMark(x: .value("Day", Double(index) + 0.5), y: .value("Value", value), series: .value("Segment", segment))
                                    .foregroundStyle(theme.accent).interpolationMethod(.monotone)
                                    .lineStyle(StrokeStyle(lineWidth: compact ? 2 : 3, lineCap: .round))
                                PointMark(x: .value("Day", Double(index) + 0.5), y: .value("Value", value))
                                    .foregroundStyle(theme.accent).symbolSize(compact ? 6 : 15)
                            } else {
                                RectangleMark(xStart: .value("Day", Double(index) + (chart == .comparison ? 0.5 : 0.15)),
                                              xEnd: .value("Day", Double(index) + 0.9), yStart: .value("Value", 0), yEnd: .value("Value", value))
                                    .foregroundStyle(theme.accent.gradient).cornerRadius(2)
                            }
                        }
                    }
                    if chart == .comparison {
                        ForEach(Array(previous.enumerated()), id: \.offset) { index, day in
                            if let value = metric.activity.value(in: day) {
                                RectangleMark(xStart: .value("Day", Double(index) + 0.08), xEnd: .value("Day", Double(index) + 0.45),
                                              yStart: .value("Value", 0), yEnd: .value("Value", value))
                                    .foregroundStyle(.gray.opacity(0.5)).cornerRadius(2)
                            }
                        }
                    }
                }
                .chartXScale(domain: 0...Double(count), range: .plotDimension(padding: 0))
                .chartYScale(domain: 0...maximum).chartYAxis(.hidden).chartXAxis(.hidden).chartLegend(.hidden)
                .padding(.top, 2)
                .accessibilityLabel(Text(metric.title))
                .accessibilityValue(days.map { "\($0.date.formatted(.dateTime.day().month().year())): \(metric.text(metric.activity.value(in: $0), unit: unit))" }.joined(separator: ", "))
                if !compact {
                    HStack {
                        Text(period == .year ? days.first?.date.formatted(.dateTime.month(.abbreviated)) ?? "" : days.first?.date.formatted(.dateTime.day().month(.abbreviated)) ?? "")
                        Spacer()
                        Text(period == .year ? days.last?.date.formatted(.dateTime.month(.abbreviated)) ?? "" : days.last?.date.formatted(.dateTime.day().month(.abbreviated)) ?? "")
                    }.font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct WidgetCalendar: View {
    var days: [ActivityDay]
    var progress: [Double?]
    var metric: WidgetMetric
    var unit: DistanceUnit
    var accent: Color
    var compact: Bool
    private var offset: Int { days.first.map { (Calendar.current.component(.weekday, from: $0.date) - Calendar.current.firstWeekday + 7) % 7 } ?? 0 }
    var body: some View {
        if days.isEmpty {
            Text("chart.no.data").font(.system(size: 9)).foregroundStyle(.secondary)
                .lineLimit(2).minimumScaleFactor(0.7).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let maximum = max(1, days.compactMap { metric.activity.value(in: $0) }.max() ?? 1)
            let rows = (offset + days.count + 6) / 7
            GeometryReader { geometry in
                let gap: CGFloat = compact ? 3 : 4
                let width = max(1, (geometry.size.width - 6 * gap) / 7)
                let height = max(1, (geometry.size.height - CGFloat(rows - 1) * gap) / CGFloat(rows))
                VStack(spacing: gap) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: gap) {
                            ForEach(0..<7, id: \.self) { column in
                                let index = row * 7 + column - offset
                                if days.indices.contains(index) {
                                    let day = days[index]
                                    let value = metric.activity.value(in: day)
                                    let intensity = metric == .steps && progress.indices.contains(index) ? progress[index] : value.map { $0 / maximum }
                                    RoundedRectangle(cornerRadius: compact ? 2 : 4)
                                        .fill(value == nil ? Color.primary.opacity(0.06) : accent.opacity(0.18 + 0.82 * min(1, max(0, intensity ?? 0))))
                                        .overlay {
                                            if !compact {
                                                Text(day.date.formatted(.dateTime.day())).font(.system(size: min(10, height * 0.55), weight: .medium))
                                                    .foregroundStyle(value == nil ? Color.secondary : WalkunoStyle.ink)
                                            }
                                        }
                                        .overlay {
                                            if Calendar.current.isDateInToday(day.date) {
                                                RoundedRectangle(cornerRadius: compact ? 2 : 4).strokeBorder(.primary.opacity(0.8), lineWidth: 1)
                                            }
                                        }
                                        .accessibilityLabel("\(day.date.formatted(.dateTime.day().month())): \(metric.text(value, unit: unit))")
                                        .frame(width: width, height: height)
                                } else { Color.clear.frame(width: width, height: height).accessibilityHidden(true) }
                            }
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityLabel(Text("widget.graph.calendar"))
        }
    }
}

// MARK: - At-a-glance dashboard

struct WalkunoDashboardView: View {
    var entry: WalkunoEntry
    @Environment(\.widgetFamily) private var family
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var lock: Bool { family == .accessoryRectangular }
    private var theme: WalkunoTheme { entry.snapshot?.theme ?? .mint }
    private var week: [ActivityDay] { entry.snapshot?.recentWeek() ?? [] }
    private var average: Int? { ActivitySummary(days: week, goals: .init()).average }
    var body: some View {
        VStack(alignment: .leading, spacing: lock ? 2 : small ? 4 : 6) {
            if !lock { WidgetHeader(theme: theme, title: small ? nil : L("tab.today")) }
            if lock {
                HStack(spacing: 6) {
                    WidgetCounter(snapshot: entry.snapshot).frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(distanceText(entry.snapshot?.today.meters, unit: entry.snapshot?.unit ?? .kilometers)).font(.caption2.bold())
                        WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true, showsDays: false).frame(height: 19)
                        Text("\(L("widget.average")) \(WidgetNumbers.steps(average))").font(.system(size: 8)).foregroundStyle(.secondary)
                    }
                }
            } else if small {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(WidgetNumbers.steps(entry.snapshot?.today.steps)).font(.system(size: 27, weight: .bold, design: .rounded))
                    Text("today.steps").font(.system(size: 9)).foregroundStyle(.secondary)
                }.lineLimit(1).minimumScaleFactor(0.5)
                Text(distanceText(entry.snapshot?.today.meters, unit: entry.snapshot?.unit ?? .kilometers))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(theme.accent)
                WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true, showsDays: false)
                Text("\(L("widget.average")) · \(WidgetNumbers.steps(average))").font(.system(size: 9)).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 15) {
                    WidgetCounter(snapshot: entry.snapshot).frame(width: large ? 100 : 75, height: large ? 100 : 75)
                    VStack(alignment: .leading, spacing: 8) {
                        WidgetValue(title: "metric.distance", value: distanceText(entry.snapshot?.today.meters, unit: entry.snapshot?.unit ?? .kilometers))
                        WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true, showsDays: large)
                        Text("\(L("widget.average")) · \(stepsText(average))").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }.frame(height: large ? 100 : 75)
                if large {
                    WidgetSummaryRow(snapshot: entry.snapshot)
                    Text("widget.chart.dailyRhythm").font(.caption.bold()).foregroundStyle(theme.accent)
                    WidgetDailyRhythm(snapshot: entry.snapshot, compact: false)
                    Text("widget.chart.goalTracking").font(.caption.bold()).foregroundStyle(theme.accent)
                    WidgetGoalChart(snapshot: entry.snapshot, accent: theme.accent, compact: true)
                }
            }
            if !lock { WidgetUpdatedLabel(date: entry.snapshot?.updatedAt) }
        }.privacySensitive().widgetURL(URL(string: "walkuno://today"))
            .modifier(WidgetSurface(theme: theme)).accessibilityElement(children: .combine)
    }
}

struct WalkunoTrendsWidget: Widget {
    let kind = "WalkunoTrends"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WalkunoTrendsIntent.self, provider: WalkunoTrendsProvider()) { WalkunoTrendsView(entry: $0) }
            .configurationDisplayName("widget.trends.name").description("widget.trends.description")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct WalkunoDashboardWidget: Widget {
    let kind = "WalkunoDashboard"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WalkunoDashboardProvider()) { WalkunoDashboardView(entry: $0) }
            .configurationDisplayName("widget.dashboard.name").description("widget.dashboard.description")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

struct WalkunoDashboardProvider: TimelineProvider {
    func placeholder(in context: Context) -> WalkunoEntry { .init(date: .now, snapshot: .preview(), style: .ring) }
    func getSnapshot(in context: Context, completion: @escaping (WalkunoEntry) -> Void) {
        completion(.init(date: .now, snapshot: context.isPreview ? .preview() : WidgetCache.current(), style: .ring))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WalkunoEntry>) -> Void) {
        let now = Date.now, midnight = WidgetCache.midnight(after: .now)
        completion(.init(entries: [.init(date: now, snapshot: WidgetCache.current(), style: .ring),
                                   .init(date: midnight, snapshot: nil, style: .ring)],
                         policy: .after(min(now.addingTimeInterval(1800), midnight))))
    }
}
#endif
