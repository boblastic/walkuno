import SwiftUI
import Charts
import Observation
import WidgetKit
import WatchKit

@MainActor @Observable
final class WatchModel {
    static let shared = WatchModel()
    var preferences = LocalStore.preferences()
    var today = ActivityDay(date: Calendar.current.startOfDay(for: .now))
    var week: [ActivityDay] = []
    var updatedAt: Date?
    var message: String?
    var loading = false
    @ObservationIgnored private let health = HealthService()
    @ObservationIgnored private let bridge = WatchBridge()
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private let refreshCoordinator = ActivityRefreshCoordinator()
    private var widgetActivity: WidgetActivityDetail?
    var goal: Int { preferences.goals.value(on: .now) }
    var current: ActivityDay {
        Calendar.current.isDateInToday(today.date) ? today : .init(date: Calendar.current.startOfDay(for: .now))
    }
    var progress: Double { ActivityMath.progress(steps: current.steps, goal: goal) }

    var activity: WidgetActivityDetail? {
        guard let widgetActivity, Calendar.current.isDateInToday(widgetActivity.sampledAt) else { return nil }
        return widgetActivity
    }

    init() {
        if let snapshot = LocalStore.snapshot(), snapshot.isCurrent() {
            today = snapshot.today; week = snapshot.week; updatedAt = snapshot.updatedAt
            widgetActivity = snapshot.activity
        }
        bridge.onReceive = { [weak self] settings in
            guard let self else { return }
            self.preferences.goals.merge(settings.goals)
            self.preferences.theme = settings.theme
            self.preferences.unit = settings.unit
            if let style = settings.counterStyle { self.preferences.counterStyle = style }
            if let effect = settings.counterEffect { self.preferences.counterEffect = effect }
            self.persist()
        }
    }
    func start() async {
        guard preferences.healthRequested else { return }
        prepareForHealthDelivery()
        await refresh()
    }
    func prepareForHealthDelivery() {
        guard preferences.healthRequested else { return }
        health.observe { [weak self] in await self?.refresh() }
    }
    func connect() async {
        do {
            try await health.authorize()
            preferences.healthRequested = true
            persist()
            await start()
        } catch { message = L("health.connection.error") }
    }
    func refresh() async {
        guard preferences.healthRequested else { return }
        await refreshCoordinator.run { [weak self] in
            await self?.refreshRecentActivity() ?? false
        }
    }
    private func refreshRecentActivity() async -> Bool {
        guard preferences.healthRequested, !Task.isCancelled else { return false }
        let token = generation
        loading = true; defer { if token == generation { loading = false } }
        do {
            let refreshTime = Date.now
            let from = Calendar.current.date(byAdding: .day, value: -6, to: Calendar.current.startOfDay(for: refreshTime))!
            async let widgetQuery = health.widgetActivity(at: refreshTime)
            let days = try await health.history(from: from, now: refreshTime)
            try Task.checkCancellation()
            guard token == generation else { return false }
            week = Array(days.suffix(7))
            today = days.last ?? .init(date: Calendar.current.startOfDay(for: .now))
            updatedAt = refreshTime; message = nil
            widgetActivity = nil
            persist()
            // A failed hourly query must not hide the refreshed daily totals.
            do {
                let detail = try await widgetQuery
                try Task.checkCancellation()
                guard token == generation else { return false }
                widgetActivity = detail
                persist()
            } catch is CancellationError { return false }
            catch { if token == generation { message = L("health.refresh.error") } }
            return true
        } catch is CancellationError { return false }
        catch {
            if token == generation { message = L("health.refresh.error") }
            return false
        }
    }
    func persist() {
        LocalStore.save(preferences)
        if let updatedAt {
            let snapshot = WidgetSnapshot(updatedAt: updatedAt, today: current, goal: goal, week: week,
                                          theme: preferences.theme, unit: preferences.unit, activity: widgetActivity,
                                          display: .init(counter: preferences.counterStyle, showEnergy: preferences.showEnergy))
            do { try LocalStore.save(snapshot); WidgetCenter.shared.reloadAllTimelines() }
            catch { message = L("cache.error") }
        }
    }
}

@MainActor
final class WatchBackgroundDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() { WatchModel.shared.prepareForHealthDelivery() }
}

@main
struct WalkunoWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchBackgroundDelegate.self) private var appDelegate
    @State private var model = WatchModel.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            WatchRootView().environment(model).tint(model.preferences.theme.accent)
                .preferredColorScheme(.dark)
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refresh() } } }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in Task { await model.refresh() } }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in Task { await model.refresh() } }
        }
    }
}

/// One native scroll view gives the Digital Crown continuous control over the dashboard.
struct WatchRootView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width - 16)
            ScrollView {
                VStack(spacing: 16) {
                    AnimatedStepCounter(steps: model.current.steps, goal: model.goal, title: L("tab.today"),
                                        theme: model.preferences.theme, style: model.preferences.counterStyle,
                                        effect: model.preferences.counterEffect,
                                        distance: distanceText(model.current.meters, unit: model.preferences.unit),
                                        replay: model.current.date.description, animateEntry: true, animateUpdates: true)
                        // Reuse the phone's five faces at a consistent, watch-sized scale.
                        .frame(width: 260, height: 260)
                        .scaleEffect(width / 260)
                        .frame(width: width, height: width)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("today.counter.accessibility \(stepsText(model.current.steps)) \(model.goal.formatted())"))
                        .accessibilityValue(Text(L(model.preferences.counterStyle.titleKey)) + Text(", " + distanceText(model.current.meters, unit: model.preferences.unit)))
                        .accessibilityIdentifier("watch.counter")
                    WatchTrendChart(days: model.week + [model.current], goal: model.goal, accent: model.preferences.theme.accent)
                    WatchRhythmChart(date: model.current.date, hours: model.activity?.todayHours ?? [],
                                     previousHours: model.activity?.yesterdayHours ?? [], accent: model.preferences.theme.accent)
                    if model.current.steps == nil {
                        Text(L(model.preferences.healthRequested ? "health.empty.connected.body" : "health.empty.body"))
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if !model.preferences.healthRequested {
                        Button("health.connect") { Task { await model.connect() } }
                    }
                    if model.loading { ProgressView().accessibilityLabel(Text("health.refreshing")) }
                    if let message = model.message { Text(message).font(.caption2).foregroundStyle(.secondary) }
                    if let date = model.updatedAt {
                        Text("today.updated \(date.appFormatted(date: .omitted, time: .shortened))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 12)
            }
            .accessibilityIdentifier("watch.dashboard")
        }
        .background(WalkunoStyle.ink.ignoresSafeArea())
        .sensoryFeedback(.success, trigger: model.progress >= 1)
    }
}

private struct WatchTrendChart: View {
    var days: [ActivityDay]
    var goal: Int
    var accent: Color

    var body: some View {
        let activity = DashboardTrendActivity(period: .day, anchor: .now, available: days)
        let isolated = Set(Dictionary(grouping: activity.points.filter { $0.steps != nil }, by: \.segment)
            .filter { $0.value.count == 1 }.keys)
        VStack(alignment: .leading, spacing: 8) {
            Text("today.last.seven").font(.caption.weight(.semibold))
            HStack {
                Text("today.chart.goal \(goal.formatted())").foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text("today.chart.average \(stepsText(activity.summary.average))").foregroundStyle(accent)
            }.font(.system(size: 10)).lineLimit(1).minimumScaleFactor(0.7)
            Chart {
                RuleMark(y: .value(L("goal.title"), goal))
                    .foregroundStyle(Color.secondary.opacity(0.5)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                if let average = activity.summary.average {
                    RuleMark(y: .value(L("insights.average"), average))
                        .foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 4]))
                }
                ForEach(activity.points) { point in
                    if let steps = point.steps {
                        AreaMark(x: .value(L("chart.date"), point.date), y: .value(L("today.steps"), steps), series: .value("segment", point.segment))
                            .foregroundStyle(LinearGradient(colors: [accent.opacity(0.45), accent.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value(L("chart.date"), point.date), y: .value(L("today.steps"), steps), series: .value("segment", point.segment))
                            .foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 2)).interpolationMethod(.monotone)
                        if isolated.contains(point.segment) || Calendar.current.isDateInToday(point.date) {
                            PointMark(x: .value(L("chart.date"), point.date), y: .value(L("today.steps"), steps))
                                .foregroundStyle(accent).symbolSize(20)
                        }
                    }
                }
            }
            .chartXScale(domain: activity.domain, range: .plotDimension(padding: 8))
            .chartYScale(domain: 0...max(Double(goal), activity.points.compactMap(\.steps).max() ?? 0) * 1.15)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(preset: .aligned, values: activity.tickDates) { value in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.07))
                    AxisValueLabel(centered: false, anchor: .top, collisionResolution: .disabled, offsetsMarks: false) {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.locale(AppLocalization.locale).day())).font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 80)
            .accessibilityLabel(Text("today.last.seven"))
            .accessibilityIdentifier("watch.trend")
        }
    }
}

private struct WatchRhythmChart: View {
    var date: Date
    var hours: [HourActivity]
    var previousHours: [HourActivity]
    var accent: Color

    var body: some View {
        let rhythm = DailyRhythmActivity(date: date, hours: hours, previousHours: previousHours)
        VStack(alignment: .leading, spacing: 8) {
            Text("today.rhythm").font(.caption.weight(.semibold))
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { legend }
                VStack(alignment: .leading, spacing: 4) { legend }
            }.font(.caption2).foregroundStyle(.secondary)
            Chart {
                ForEach(rhythm.hours) { hour in
                    if let steps = hour.previousSteps {
                        RectangleMark(xStart: .value(L("chart.hour"), Double(hour.hour) + 0.08),
                                      xEnd: .value(L("chart.hour"), Double(hour.hour) + 0.46),
                                      yStart: .value(L("today.steps"), 0), yEnd: .value(L("today.steps"), steps))
                            .foregroundStyle(Color.gray.opacity(0.5)).cornerRadius(1)
                            .accessibilityLabel(Text("\(L("today.rhythm.previous")), \(hour.hour.formatted()) \(L("chart.hour"))"))
                    }
                    if let steps = hour.steps {
                        RectangleMark(xStart: .value(L("chart.hour"), Double(hour.hour) + 0.54),
                                      xEnd: .value(L("chart.hour"), Double(hour.hour) + 0.92),
                                      yStart: .value(L("today.steps"), 0), yEnd: .value(L("today.steps"), steps))
                            .foregroundStyle(accent.gradient).cornerRadius(1)
                            .accessibilityLabel(Text("\(L("tab.today")), \(hour.hour.formatted()) \(L("chart.hour"))"))
                    }
                }
                if let currentHour = rhythm.currentHour {
                    RuleMark(x: .value(L("today.rhythm.now"), currentHour))
                        .foregroundStyle(accent.opacity(0.65)).lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                }
            }
            .chartXScale(domain: 0.0...24.0, range: .plotDimension(padding: 3))
            .chartYScale(domain: .automatic(includesZero: true))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: [0.0, 6, 12, 18, 24]) { value in
                    AxisValueLabel(centered: false, anchor: .top, collisionResolution: .disabled, offsetsMarks: false) {
                        if let hour = value.as(Double.self) { Text(Int(hour).formatted()).font(.system(size: 9)) }
                    }
                }
            }
            .frame(height: 100)
            .accessibilityLabel(Text("today.rhythm.accessibility"))
            .accessibilityIdentifier("watch.rhythm")
            if !hours.contains(where: { $0.steps != nil }) {
                Text("chart.no.data").font(.caption2).foregroundStyle(.secondary)
            }
            if !previousHours.contains(where: { $0.steps != nil }) {
                Text("today.rhythm.previous.unavailable").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var legend: some View {
        Label { Text("tab.today") } icon: { Circle().fill(accent).frame(width: 6, height: 6) }
        Label { Text("today.rhythm.previous") } icon: { Circle().fill(.gray.opacity(0.5)).frame(width: 6, height: 6) }
    }
}
