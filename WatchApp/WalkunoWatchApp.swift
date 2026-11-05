import SwiftUI
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
    @ObservationIgnored private var widgetActivity: WidgetActivityDetail?
    var goal: Int { preferences.goals.value(on: .now) }
    var current: ActivityDay {
        Calendar.current.isDateInToday(today.date) ? today : .init(date: Calendar.current.startOfDay(for: .now))
    }
    var progress: Double { ActivityMath.progress(steps: current.steps, goal: goal) }

    init() {
        if let snapshot = LocalStore.snapshot(), snapshot.isCurrent() {
            today = snapshot.today; week = snapshot.week; updatedAt = snapshot.updatedAt
            widgetActivity = snapshot.activity
        }
        bridge.onReceive = { [weak self] goals, theme, unit in
            guard let self else { return }
            self.preferences.goals.merge(goals)
            self.preferences.theme = theme
            self.preferences.unit = unit
            self.persist(sync: false)
        }
    }
    func start() async {
        guard preferences.healthRequested else { return }
        prepareForHealthDelivery()
        await refresh()
        bridge.send(preferences)
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
            persist(sync: false)
            // A failed hourly query must not hide the refreshed daily totals.
            do {
                let detail = try await widgetQuery
                try Task.checkCancellation()
                guard token == generation else { return false }
                widgetActivity = detail
                persist(sync: false)
            } catch is CancellationError { return false }
            catch { if token == generation { message = L("health.refresh.error") } }
            return true
        } catch is CancellationError { return false }
        catch {
            if token == generation { message = L("health.refresh.error") }
            return false
        }
    }
    func persist(sync: Bool = true) {
        LocalStore.save(preferences)
        if let updatedAt {
            let snapshot = WidgetSnapshot(updatedAt: updatedAt, today: current, goal: goal, week: week,
                                          theme: preferences.theme, unit: preferences.unit, activity: widgetActivity)
            do { try LocalStore.save(snapshot); WidgetCenter.shared.reloadAllTimelines() }
            catch { message = L("cache.error") }
        }
        if sync { bridge.send(preferences) }
    }
    func setGoal(_ value: Int) { preferences.goals.set(value); persist() }
    func reset() async {
        generation += 1
        preferences.healthRequested = false
        refreshCoordinator.cancel()
        loading = false
        await health.stop()
        do {
            try LocalStore.clear()
            preferences = .init(); today = .init(date: Calendar.current.startOfDay(for: .now))
            week = []; updatedAt = nil; message = nil; widgetActivity = nil
            WidgetCenter.shared.reloadAllTimelines()
        } catch { message = L("reset.error") }
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
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await model.refresh() } } }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in Task { await model.refresh() } }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in Task { await model.refresh() } }
        }
    }
}

struct WatchRootView: View {
    @Environment(WatchModel.self) private var model
    var body: some View {
        TabView {
            ScrollView {
                VStack(spacing: 12) {
                    HStack(spacing: 4) {
                        BrandMark(size: 16, theme: model.preferences.theme)
                        Text("Walkuno").font(.caption.bold()).foregroundStyle(model.preferences.theme.accent)
                    }
                    ZStack {
                        ProgressRing(progress: model.progress, accent: model.preferences.theme.accent,
                                     secondaryAccent: model.preferences.theme.secondaryAccent, lineWidth: 10)
                        VStack(spacing: 4) {
                            Text(stepsText(model.current.steps)).font(.system(.title, design: .rounded, weight: .bold)).minimumScaleFactor(0.4).lineLimit(1)
                            Text("today.steps").font(.caption2).foregroundStyle(.secondary)
                            Text("today.of \(model.goal.formatted())").font(.system(size: 10)).foregroundStyle(.secondary).minimumScaleFactor(0.7).lineLimit(1)
                        }.padding(18)
                    }.frame(height: 140)
                        .accessibilityElement(children: .combine)
                    Text(distanceText(model.current.meters, unit: model.preferences.unit)).font(.headline)
                    if model.progress >= 1 { Label("watch.goal.reached", systemImage: "sparkles").font(.caption).foregroundStyle(model.preferences.theme.accent) }
                    if model.current.steps == nil {
                        Text(L(model.preferences.healthRequested ? "health.empty.connected.body" : "health.empty.body")).font(.caption2)
                    }
                    if !model.preferences.healthRequested {
                        Button("health.connect") { Task { await model.connect() } }
                    }
                    if model.loading { ProgressView() }
                    if let message = model.message { Text(message).font(.caption2).foregroundStyle(.secondary) }
                    if let date = model.updatedAt { Text(date, style: .time).font(.caption2).foregroundStyle(.secondary) }
                }.padding(.horizontal, 8)
            }.background(WalkunoStyle.ink.ignoresSafeArea())
            List {
                Text("watch.recent").font(.headline)
                ForEach(model.week.reversed()) { day in
                    LabeledContent(day.date.formatted(.dateTime.weekday(.abbreviated)), value: stepsText(day.steps))
                }
            }
            WatchGoalView().background(WalkunoStyle.ink.ignoresSafeArea())
        }.tabViewStyle(.verticalPage)
            .sensoryFeedback(.success, trigger: model.progress >= 1)
    }
}

struct WatchGoalView: View {
    @Environment(WatchModel.self) private var model
    @State private var goal = 8000
    @State private var confirmReset = false
    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Text("goal.title").font(.headline)
                Text(goal.formatted()).font(.system(.title, design: .rounded, weight: .bold))
                HStack {
                    Button { goal = max(500, goal - 500) } label: { Image(systemName: "minus") }.accessibilityLabel(Text("goal.decrease"))
                    Button { goal = min(100000, goal + 500) } label: { Image(systemName: "plus") }.accessibilityLabel(Text("goal.increase"))
                }
                Button("common.save") { model.setGoal(goal) }.disabled(goal == model.goal)
                Text("watch.goal.sync").font(.caption2).foregroundStyle(.secondary)
                Button("reset.title", role: .destructive) { confirmReset = true }.font(.caption2)
            }
        }.onAppear { goal = model.goal }
            .onChange(of: model.goal) { _, value in goal = value }
            .confirmationDialog("reset.title", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("reset.confirm", role: .destructive) { Task { await model.reset() } }
            } message: { Text("reset.body") }
    }
}
