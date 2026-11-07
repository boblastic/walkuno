import WidgetKit
import SwiftUI
import AppIntents
import Charts

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

struct WalkunoChartIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "widget.charts.configuration"
    static let description = IntentDescription("widget.charts.description")
    @Parameter(title: "widget.style", default: .hourly) var style: WidgetChartStyle
}

struct WalkunoEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
    var access: ProAccess = .init()
}

struct WalkunoChartEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot?
    var access: ProAccess = .init()
    var style: WidgetChartStyle
}

private enum WidgetCache {
    static func current() -> WidgetSnapshot? {
        guard let snapshot = LocalStore.snapshot(), snapshot.isCurrent() else { return nil }
        return snapshot
    }
    static func snapshot(isPreview: Bool) -> WalkunoEntry {
        let access = LocalStore.proAccess()
        if isPreview {
            return .init(date: .now, snapshot: access.isActive() ? current() ?? .preview() : .preview(),
                         access: .init(granted: true))
        }
        return .init(date: .now, snapshot: access.isActive() ? current() : nil, access: access)
    }
    static func timeline() -> Timeline<WalkunoEntry> {
        let now = Date.now
        let access = LocalStore.proAccess()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
        var entries = [WalkunoEntry(date: now, snapshot: access.isActive(at: now) ? current() : nil, access: access)]
        if access.isActive(at: now), let expiration = access.expiresAt, expiration < midnight {
            entries.append(.init(date: expiration, snapshot: nil, access: access))
        }
        entries.append(.init(date: midnight, snapshot: nil, access: access))
        return .init(entries: entries, policy: .after(min(now.addingTimeInterval(30 * 60), midnight)))
    }
}

// Keep widget kinds stable; a locked widget never receives health measurements.
struct WalkunoProvider: TimelineProvider {
    func placeholder(in context: Context) -> WalkunoEntry { WidgetCache.snapshot(isPreview: true) }
    func getSnapshot(in context: Context, completion: @escaping (WalkunoEntry) -> Void) {
        completion(WidgetCache.snapshot(isPreview: context.isPreview))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WalkunoEntry>) -> Void) {
        completion(WidgetCache.timeline())
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
    func placeholder(in context: Context) -> WalkunoChartEntry {
        let entry = WidgetCache.snapshot(isPreview: true)
        return .init(date: entry.date, snapshot: entry.snapshot, access: entry.access, style: .hourly)
    }
    func snapshot(for configuration: WalkunoChartIntent, in context: Context) async -> WalkunoChartEntry {
        let entry = WidgetCache.snapshot(isPreview: context.isPreview)
        return .init(date: entry.date, snapshot: entry.snapshot, access: entry.access, style: configuration.style)
    }
    func timeline(for configuration: WalkunoChartIntent, in context: Context) async -> Timeline<WalkunoChartEntry> {
        let timeline = WidgetCache.timeline()
        return .init(entries: timeline.entries.map {
            .init(date: $0.date, snapshot: $0.snapshot, access: $0.access, style: configuration.style)
        }, policy: timeline.policy)
    }
}

private struct WidgetProGate<Content: View>: View {
    var access: ProAccess
    var date: Date
    @ViewBuilder var content: () -> Content
    @Environment(\.walkunoWidgetFamily) private var family

    var body: some View {
        if access.isActive(at: date) {
            content()
        } else {
            Group {
                if family == .accessoryInline {
                    Label("Walkuno Pro", systemImage: "lock.fill")
                } else if family == .accessoryCircular {
                    VStack(spacing: 3) {
                        Image(systemName: "lock.fill")
                        Text("Pro").font(.caption2.bold())
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Walkuno Pro", systemImage: "lock.fill").font(.headline)
                        Text("widget.pro.required").font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .modifier(WidgetSurface(theme: .mint))
            .widgetURL(URL(string: "walkuno://pro"))
            .accessibilityElement(children: .combine)
        }
    }
}

struct WalkunoWidgetView: View {
    var entry: WalkunoEntry
    @Environment(\.walkunoWidgetFamily) private var family
    private var theme: WalkunoTheme { entry.snapshot?.theme ?? .mint }
    private var steps: Int? { entry.snapshot?.today.steps }
    private var progress: Double { ActivityMath.progress(steps: steps, goal: entry.snapshot?.goal ?? 8000) }
    private var unit: DistanceUnit { entry.snapshot?.unit ?? .kilometers }
    private var week: [ActivityDay] { entry.snapshot?.recentWeek() ?? [] }
    private var fullValue: String { stepsText(steps) }
    private var compactValue: String { WidgetNumbers.steps(steps) }
    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: lockRectangle
            case .accessoryInline:
                Label("\(compactValue) \(L("today.steps"))", systemImage: "shoeprints.fill")
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
            ProgressRing(progress: progress, accent: theme.accent, secondaryAccent: theme.secondaryAccent, lineWidth: 5).padding(4)
            VStack(spacing: 0) {
                Text(compactValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.45)
                #if os(watchOS)
                Text(distanceText(entry.snapshot?.today.meters, unit: unit))
                    .font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.6)
                #else
                Text("today.steps").font(.system(size: 8)).lineLimit(1).minimumScaleFactor(0.6)
                #endif
            }.padding(.horizontal, 9)
        }.widgetAccentable()
    }
    private var accessibilitySummary: String {
        var parts = [L("widget.name"), "\(fullValue) \(L("today.steps"))",
                     distanceText(entry.snapshot?.today.meters, unit: unit),
                     steps == nil ? "—" : progress.formatted(.percent.precision(.fractionLength(0))),
                     "\(L("widget.goal")) \(stepsText(steps)) / \((entry.snapshot?.goal ?? 8000).formatted())"]
        #if os(iOS)
        if family == .systemLarge {
            parts.append("\(L("widget.average")) \(stepsText(ActivitySummary(days: week, goals: .init()).average))")
            parts.append("\(L("metric.floors")) \(stepsText(entry.snapshot?.today.floors.map { Int($0.rounded()) }))")
            parts.append("\(L("metric.exercise")) \(entry.snapshot?.today.exerciseMinutes.map { Int($0.rounded()).formatted() } ?? "—") min")
            parts.append("\(L("metric.energy")) \(entry.snapshot?.today.kilocalories.map { Int($0.rounded()).formatted() } ?? "—") kcal")
            parts.append(L("widget.chart.goal.accessibility"))
        }
        #endif
        return parts.joined(separator: ". ")
    }
    private var lockRectangle: some View {
        HStack(spacing: 8) {
            circular.frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text("today.steps").font(.caption2.bold())
                Text(distanceText(entry.snapshot?.today.meters, unit: unit)).font(.caption2)
                Text("\(L("widget.goal.short")) · \(entry.snapshot?.goal.formatted() ?? "—")")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }.lineLimit(1).minimumScaleFactor(0.6)
        }
    }
    #if os(iOS)
    private var home: some View {
        GeometryReader { geometry in
            let small = family == .systemSmall
            let counterSize = min(geometry.size.width, max(0, geometry.size.height - 16))
            VStack(alignment: .leading, spacing: small ? 2 : 8) {
                WidgetHeader(theme: theme, title: small ? nil : L("period.week"))
                if small {
                    WidgetCounter(snapshot: entry.snapshot).frame(width: counterSize, height: counterSize)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        // The open arc leaves empty space below its drawing; center the visible content under the header.
                        .offset(y: (entry.snapshot?.display?.counter ?? .horizon) == .horizon ? counterSize * 0.09 : 0)
                } else {
                    WidgetLargeOverview(snapshot: entry.snapshot, date: entry.date)
                }
            }
        }
    }
    #endif
}

struct WalkunoChartWidgetView: View {
    var entry: WalkunoChartEntry
    @Environment(\.walkunoWidgetFamily) private var family
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
            if !compact { WidgetHeader(theme: theme, title: small ? nil : large && isWeek ? L("today.this.week") : entry.style.title) }
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text(small || compact ? WidgetNumbers.steps(entry.snapshot?.today.steps) : stepsText(entry.snapshot?.today.steps))
                    .font(.system(size: compact ? 16 : small ? 25 : 30, weight: .bold, design: .rounded))
                if small {
                    Text(distanceText(entry.snapshot?.today.meters, unit: entry.snapshot?.unit ?? .kilometers))
                        .font(.system(size: 8, weight: .medium)).foregroundStyle(theme.accent)
                } else if compact {
                    Text("today.steps").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if !small && !compact {
                    Text(distanceText(entry.snapshot?.today.meters, unit: entry.snapshot?.unit ?? .kilometers))
                        .font(.caption).foregroundStyle(theme.accent)
                }
            }.lineLimit(1).minimumScaleFactor(0.6)
            chart
            if large && isWeek {
                WidgetWeekReferences(days: week, goal: entry.snapshot?.goal, accent: theme.accent, horizontal: true)
            } else if isWeek {
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
                Text(isWeek ? "widget.chart.dailyRhythm" : "today.this.week")
                    .font(.caption.bold()).foregroundStyle(theme.accent)
                if !isWeek {
                    WidgetWeekReferences(days: week, goal: entry.snapshot?.goal, accent: theme.accent, horizontal: true)
                }
                Group {
                    if isWeek { WidgetDailyRhythm(snapshot: entry.snapshot, compact: true) }
                    else { WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true, goal: entry.snapshot?.goal) }
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
        case .weeklyLine: WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: compact || small,
                                          showsDays: !compact, goal: large ? entry.snapshot?.goal : nil)
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
    var access: ProAccess = .init()
    var accent: Color
    var compact: Bool
    var body: some View {
        let points = snapshot?.activity?.goalTracking(todaySteps: snapshot?.today.steps) ?? []
        let currentPoint = snapshot?.activity?.cumulative(todaySteps: snapshot?.today.steps).last
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
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("\(L("widget.goal.short")) \(WidgetNumbers.steps(goal, abbreviateFrom: 1000))")
                                        .foregroundStyle(.secondary)
                                    Text("\(L("widget.goal.currentValue")) \(stepsText(currentPoint?.current.map { Int($0.rounded()) }))")
                                        .foregroundStyle(accent)
                                    Text("\(L("widget.goal.usualValue")) \(stepsText(currentPoint?.usual.map { Int($0.rounded()) }))")
                                        .foregroundStyle(.secondary)
                                }
                                .font(.system(size: compact ? 6 : 8)).monospacedDigit()
                                .lineLimit(1).minimumScaleFactor(0.65)
                            }
                    }
                    if let currentPoint {
                        RuleMark(x: .value("Hour", currentPoint.hour))
                            .foregroundStyle(Color.primary.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 3]))
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
                    if let last = points.last(where: { $0.current != nil }), let current = last.current {
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
                .accessibilityValue("\(L("widget.goal.short")) \(stepsText(snapshot?.goal)); \(L("widget.goal.currentValue")) \(stepsText(currentPoint?.current.map { Int($0.rounded()) })); \(L("widget.goal.usualValue")) \(stepsText(currentPoint?.usual.map { Int($0.rounded()) }))")
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
    var goal: Int? = nil
    private var average: Int? { ActivitySummary(days: days, goals: .init()).average }
    var body: some View {
        let values = days.compactMap(\.steps) + (goal.map { [$0] } ?? []) + (goal == nil ? [] : average.map { [$0] } ?? [])
        let low = Double(values.min() ?? 0)
        let high = Double(values.max() ?? 1)
        let padding = max(1, (high - low) * 0.16, high * 0.04)
        Chart {
            if let goal {
                RuleMark(y: .value("Goal", goal)).foregroundStyle(Color.secondary.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                if let average {
                    RuleMark(y: .value("Average", average)).foregroundStyle(accent.opacity(0.6))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
            }
            if showsDays {
                ForEach(days.indices, id: \.self) { index in
                    RuleMark(x: .value("Day", Double(index) + 0.5))
                        .foregroundStyle(Color.primary.opacity(0.07)).lineStyle(StrokeStyle(lineWidth: 0.5))
                }
            }
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
        .chartYScale(domain: max(0, low - padding)...max(1, high + padding))
        .chartYAxis(.hidden).chartLegend(.hidden)
        .chartXAxis(.hidden)
        .overlay {
            if days.compactMap(\.steps).isEmpty {
                Text("—").font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, showsDays ? (compact ? 12 : 16) : 0)
        .overlay(alignment: .bottom) {
            if showsDays {
                HStack(spacing: 0) {
                    ForEach(days) { day in
                        let isToday = Calendar.current.isDate(day.date, inSameDayAs: today)
                        Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                            .font(.system(size: compact ? 7 : 9, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? accent : .secondary)
                            .lineLimit(1).minimumScaleFactor(0.6)
                            .frame(minWidth: 0, maxWidth: .infinity)
                    }
                }.accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("widget.style.weeklyLine"))
        .accessibilityValue(days.map {
            "\($0.date.formatted(.dateTime.weekday(.wide).day().month())): \(stepsText($0.steps)) \(L("today.steps"))"
        }.joined(separator: ", ") + (goal.map { "; \(L("widget.goal.short")) \($0.formatted()); \(L("widget.average")) \(stepsText(average))" } ?? ""))
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
        let reference = WidgetUsualActivity(comparison: .init(today: [], history: [history], metric: .steps, cutoffHour: cutoffHour,
                                                                  fullDayHistory: [hours(on: yesterday, through: today, total: 11500)]))
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
        StaticConfiguration(kind: kind, provider: WalkunoProvider()) { entry in
            WidgetProGate(access: entry.access, date: entry.date) { WalkunoWidgetView(entry: entry) }
        }
            .configurationDisplayName("widget.name").description("widget.description")
            #if os(iOS)
            .supportedFamilies([.systemSmall, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
            #else
            .supportedFamilies([.accessoryCircular, .accessoryInline])
            #endif
    }
}

struct WalkunoChartWidget: Widget {
    let kind = "WalkunoCharts"
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: WalkunoChartIntent.self, provider: WalkunoChartProvider()) { entry in
            WidgetProGate(access: entry.access, date: entry.date) { WalkunoChartWidgetView(entry: entry) }
        }
            .configurationDisplayName("widget.charts.name").description("widget.charts.description")
            #if os(iOS)
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
            #else
            .supportedFamilies([.accessoryRectangular])
            #endif
    }
}

// MARK: - Shared widget design

private struct WidgetCaptureKey: EnvironmentKey {
    static let defaultValue: WidgetFamily? = nil
}

extension EnvironmentValues {
    /// Supplies WidgetKit's content margins and background when capturing a complete widget in the app.
    var widgetCaptureFamily: WidgetFamily? {
        get { self[WidgetCaptureKey.self] }
        set { self[WidgetCaptureKey.self] = newValue }
    }
    var walkunoWidgetFamily: WidgetFamily { widgetCaptureFamily ?? widgetFamily }
}

private struct WidgetSurface: ViewModifier {
    @Environment(\.widgetCaptureFamily) private var captureFamily
    var theme: WalkunoTheme
    @Environment(\.walkunoWidgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    private var home: Bool {
        #if os(iOS)
        family == .systemSmall || family == .systemMedium || family == .systemLarge
        #else
        false
        #endif
    }
    @ViewBuilder func body(content: Content) -> some View {
        if captureFamily != nil {
            content
                .environment(\.colorScheme, .dark)
                .padding(home ? 16 : 0)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background { surface }
        } else {
            content
                .environment(\.colorScheme, home ? .dark : scheme)
                .containerBackground(for: .widget) { surface }
        }
    }
    @ViewBuilder private var surface: some View {
        if home {
            LinearGradient(colors: [WalkunoStyle.ink, WalkunoStyle.ink, theme.secondaryAccent.opacity(0.28)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else { WalkunoStyle.ink }
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
    var access: ProAccess = .init()
    var body: some View {
        HStack(spacing: 10) {
            WidgetValue(title: "metric.floors", value: stepsText(snapshot?.today.floors.map { Int($0.rounded()) }))
            Spacer(minLength: 0)
            WidgetValue(title: "metric.exercise", value: (snapshot?.today.exerciseMinutes.map { Int($0.rounded()).formatted() } ?? "—") + " min")
            Spacer(minLength: 0)
            WidgetValue(title: "metric.energy", value: (snapshot?.today.kilocalories.map { Int($0.rounded()).formatted() } ?? "—") + " kcal")
        }
    }
}

private struct WidgetWeekReferences: View {
    var days: [ActivityDay]
    var goal: Int?
    var accent: Color
    var horizontal = false
    var compact = false
    private var average: Int? { ActivitySummary(days: days, goals: .init()).average }
    var body: some View {
        Group {
            if horizontal {
                HStack(spacing: 8) { objective; mean }
            } else {
                VStack(spacing: compact ? 2 : 5) { objective; mean }
            }
        }
    }
    private var objective: some View { reference("widget.goal.short", value: goal, color: .secondary, dash: [5, 3]) }
    private var mean: some View { reference("widget.average", value: average, color: accent.opacity(0.6), dash: [2, 3]) }
    private func reference(_ title: String, value: Int?, color: Color, dash: [CGFloat]) -> some View {
        Group {
            if horizontal && compact {
                (Text(L(title)).foregroundColor(.secondary) + Text(" \(stepsText(value))").bold())
                    .monospacedDigit().frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: compact ? 3 : 4) {
                    Spacer(minLength: 0)
                    Path { path in path.move(to: .init(x: 0, y: 3)); path.addLine(to: .init(x: compact ? 9 : 14, y: 3)) }
                        .stroke(color, style: StrokeStyle(lineWidth: 1, dash: dash)).frame(width: compact ? 9 : 14, height: 6)
                    Text(L(title)).foregroundStyle(.secondary)
                    Text(stepsText(value)).bold().monospacedDigit()
                }
            }
        }.font(.system(size: compact ? 8 : 9)).lineLimit(1).minimumScaleFactor(0.65)
            .accessibilityElement(children: .combine)
    }
}

#if os(iOS)
private struct WidgetLargeOverview: View {
    var snapshot: WidgetSnapshot?
    var access: ProAccess = .init()
    var date: Date
    private var theme: WalkunoTheme { snapshot?.theme ?? .mint }
    private var week: [ActivityDay] { snapshot?.recentWeek() ?? [] }
    private var average: Int? { ActivitySummary(days: week, goals: .init()).average }
    var body: some View {
        GeometryReader { geometry in
            let size = min(132, geometry.size.width * 0.43, geometry.size.height * 0.43)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    WidgetCounter(snapshot: snapshot).frame(width: size, height: size)
                    VStack(alignment: .leading, spacing: 5) {
                        WidgetWeekReferences(days: week, goal: snapshot?.goal, accent: theme.accent)
                        WidgetWeekCurve(days: week, today: date, accent: theme.accent, compact: true, goal: snapshot?.goal)
                    }
                }.frame(height: size)
                WidgetSummaryRow(snapshot: snapshot)
                Text("widget.chart.goalTracking").font(.caption.bold()).foregroundStyle(theme.accent)
                WidgetGoalChart(snapshot: snapshot, accent: theme.accent, compact: false)
                WidgetUpdatedLabel(date: snapshot?.updatedAt)
            }
        }
    }

}
#endif

/// Static versions of the app's five counters, sized for a WidgetKit snapshot.
private struct WidgetCounter: View {
    var snapshot: WidgetSnapshot?
    var access: ProAccess = .init()
    private var theme: WalkunoTheme { snapshot?.theme ?? .mint }
    private var progress: Double { ActivityMath.progress(steps: snapshot?.today.steps, goal: snapshot?.goal ?? 8000) }
    private var style: CounterStyle { snapshot?.display?.counter ?? .horizon }
    private var hasBase: Bool { style == .path || style == .milestones || style == .minimal }
    private var overflow: Color {
        CounterProgress(steps: Double(snapshot?.today.steps ?? 0), goal: snapshot?.goal ?? 8000)
            .overflowLap.truncatingRemainder(dividingBy: 2) == 1 ? .white.opacity(0.88) : WalkunoStyle.ink.opacity(0.85)
    }
    private var extra: Double {
        CounterProgress(steps: Double(snapshot?.today.steps ?? 0), goal: snapshot?.goal ?? 8000).overflowFraction
    }
    private var gradient: LinearGradient {
        LinearGradient(colors: [theme.secondaryAccent, theme.accent], startPoint: .leading, endPoint: .trailing)
    }
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let stroke = max(4, size * 0.055)
            ZStack {
                switch style {
                case .ring:
                    ProgressRing(progress: progress, accent: theme.accent, secondaryAccent: theme.secondaryAccent, lineWidth: stroke)
                        .padding(stroke)
                case .horizon:
                    Circle().trim(from: 0, to: 2.0 / 3)
                        .stroke(theme.accent.opacity(0.18), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                        .rotationEffect(.degrees(150)).padding(stroke)
                    Circle().trim(from: 0, to: 2.0 / 3 * min(1, progress))
                        .stroke(gradient, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                        .rotationEffect(.degrees(150)).padding(stroke).opacity(progress > 0 ? 1 : 0)
                    if progress > 1 {
                        Circle().trim(from: 0, to: 2.0 / 3 * extra)
                            .stroke(overflow, style: StrokeStyle(lineWidth: stroke * 0.35, lineCap: .round))
                            .rotationEffect(.degrees(150)).padding(stroke)
                    }
                case .path:
                    ZStack {
                        WidgetRouteShape().stroke(theme.accent.opacity(0.18), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                        WidgetRouteShape().trim(from: 0, to: min(1, progress))
                            .stroke(gradient, style: StrokeStyle(lineWidth: stroke, lineCap: .round)).opacity(progress > 0 ? 1 : 0)
                        if progress > 1 {
                            WidgetRouteShape().trim(from: 0, to: extra)
                                .stroke(overflow, style: StrokeStyle(lineWidth: stroke * 0.35, lineCap: .round))
                        }
                    }.frame(height: size * 0.22).padding(.bottom, stroke)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                case .milestones:
                    HStack(alignment: .bottom, spacing: max(2, size * 0.025)) {
                        ForEach(0..<10) { index in
                            let height = size * 0.23 * (0.4 + Double(index) / 15)
                            let fill = min(1, max(0, progress * 10 - Double(index)))
                            let extraFill = min(1, max(0, extra * 10 - Double(index)))
                            RoundedRectangle(cornerRadius: 2).fill(theme.accent.opacity(0.18))
                                .overlay(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 2).fill(gradient).frame(height: height * fill)
                                }
                                .overlay(alignment: .bottom) {
                                    if progress > 1 {
                                        Capsule().fill(overflow).frame(width: 2, height: height * extraFill)
                                    }
                                }.frame(height: height)
                        }
                    }.padding(.horizontal, stroke).padding(.bottom, stroke)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                case .minimal:
                    Capsule().fill(theme.accent.opacity(0.18))
                        .overlay(alignment: .leading) {
                            Capsule().fill(gradient).frame(width: (size - stroke * 2) * min(1, progress))
                        }
                        .overlay(alignment: .leading) {
                            if progress > 1 {
                                Capsule().fill(overflow).frame(width: (size - stroke * 2) * extra, height: 2)
                            }
                        }
                        .frame(height: max(3, size * 0.04)).padding(.horizontal, stroke).padding(.bottom, stroke)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
                VStack(spacing: size * 0.025) {
                    Text(stepsText(snapshot?.today.steps))
                        .font(.system(size: size * (hasBase ? 0.32 : 0.26), weight: .bold, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.4)
                    if size >= 80 {
                        Text(distanceText(snapshot?.today.meters, unit: snapshot?.unit ?? .kilometers))
                            .font(.system(size: size * 0.105, weight: .medium)).foregroundStyle(.secondary)
                            .lineLimit(1).minimumScaleFactor(0.6)
                    }
                    Text(snapshot?.today.steps == nil ? "—" : progress.formatted(.percent.precision(.fractionLength(0))))
                        .font(.system(size: max(8, size * 0.10), weight: .bold)).foregroundStyle(theme.accent)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }.padding(.horizontal, size * (hasBase ? 0.06 : 0.17))
                    .offset(y: hasBase ? -size * 0.16 : style == .horizon ? -size * 0.02 : 0)
            }.frame(width: size, height: size)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }.widgetAccentable()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stepsText(snapshot?.today.steps)) \(L("today.steps")), \(distanceText(snapshot?.today.meters, unit: snapshot?.unit ?? .kilometers)), \(snapshot?.today.steps == nil ? "—" : progress.formatted(.percent.precision(.fractionLength(0))))")
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
    var access: ProAccess = .init()
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
// MARK: - At-a-glance dashboard

struct WalkunoDashboardView: View {
    var entry: WalkunoEntry
    @Environment(\.walkunoWidgetFamily) private var family
    private var small: Bool { family == .systemSmall }
    private var large: Bool { family == .systemLarge }
    private var lock: Bool { family == .accessoryRectangular }
    private var theme: WalkunoTheme { entry.snapshot?.theme ?? .mint }
    private var week: [ActivityDay] { entry.snapshot?.recentWeek() ?? [] }
    private var average: Int? { ActivitySummary(days: week, goals: .init()).average }
    var body: some View {
        VStack(alignment: .leading, spacing: lock ? 2 : small ? 4 : 6) {
            if !lock { WidgetHeader(theme: theme, title: small ? nil : L("today.this.week")) }
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
                    Text(WidgetNumbers.steps(entry.snapshot?.today.steps)).font(.system(size: 25, weight: .bold, design: .rounded))
                    Text(distanceText(entry.snapshot?.today.meters, unit: entry.snapshot?.unit ?? .kilometers))
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(theme.accent)
                }.lineLimit(1).minimumScaleFactor(0.5)
                WidgetWeekReferences(days: week, goal: entry.snapshot?.goal, accent: theme.accent, horizontal: true, compact: true)
                WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true, goal: entry.snapshot?.goal)
            } else {
                if large {
                    WidgetLargeOverview(snapshot: entry.snapshot, date: entry.date)
                } else {
                    HStack(spacing: 15) {
                        WidgetCounter(snapshot: entry.snapshot).frame(width: 105, height: 105)
                        VStack(alignment: .leading, spacing: 4) {
                            WidgetWeekReferences(days: week, goal: entry.snapshot?.goal, accent: theme.accent)
                            WidgetWeekCurve(days: week, today: entry.date, accent: theme.accent, compact: true, goal: entry.snapshot?.goal)
                        }
                    }
                }
            }
            if !lock && !large { WidgetUpdatedLabel(date: entry.snapshot?.updatedAt) }
        }.privacySensitive().widgetURL(URL(string: "walkuno://today"))
            .modifier(WidgetSurface(theme: theme)).accessibilityElement(children: .combine)
    }
}

struct WalkunoDashboardWidget: Widget {
    let kind = "WalkunoDashboard"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WalkunoProvider()) { entry in
            WidgetProGate(access: entry.access, date: entry.date) { WalkunoDashboardView(entry: entry) }
        }
            .configurationDisplayName("widget.dashboard.name").description("widget.dashboard.description")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryRectangular])
    }
}

#endif
