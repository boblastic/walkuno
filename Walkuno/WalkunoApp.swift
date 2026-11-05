import SwiftUI
import UIKit
import Observation

@MainActor
final class WalkunoAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppModel.shared.prepareForHealthDelivery()
        return true
    }
}

/// Serializes system icon requests so a quick second palette choice wins.
@MainActor @Observable
final class ThemeAppIcon {
    private(set) var error: String?
    private var desired: WalkunoTheme = .mint
    private var updating = false

    func synchronize(with theme: WalkunoTheme) async {
        desired = theme
        let app = UIApplication.shared
        guard app.supportsAlternateIcons, app.applicationState == .active, !updating else { return }
        updating = true
        defer { updating = false }
        while app.applicationState == .active {
            let requested = desired
            let name = requested == .mint ? nil : "AppIcon-" + requested.rawValue
            guard app.alternateIconName != name else { return }
            do {
                try await app.setAlternateIconName(name)
                assert(app.alternateIconName == name)
                error = nil
            } catch {
                NSLog("Walkuno icon request %@, active %@, error %@", name ?? "primary",
                      app.alternateIconName ?? "primary", String(describing: error))
                // Some OS versions report a confirmation-dialog error after applying the icon.
                if app.alternateIconName == name {
                    self.error = nil
                    continue
                }
                if requested != desired { continue }
                self.error = L("icon.update.error")
                return
            }
        }
    }

    func clearError() { error = nil }
}

@main
struct WalkunoApp: App {
    @UIApplicationDelegateAdaptor(WalkunoAppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .task { await model.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await model.refresh()
                            await model.purchases.refreshEntitlements()
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in Task { await model.refresh() } }
                .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in Task { await model.refresh() } }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @State private var selection = 0
    @State private var appIcon = ThemeAppIcon()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        content.tint(model.effectiveTheme.tint(for: scheme))
            .environment(\.locale, AppLocalization.locale)
            .task(id: "\(model.purchases.hasLoadedEntitlements)-\(model.effectiveTheme.rawValue)") {
                if model.purchases.hasLoadedEntitlements {
                    await appIcon.synchronize(with: model.effectiveTheme)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active && model.purchases.hasLoadedEntitlements {
                    Task { await appIcon.synchronize(with: model.effectiveTheme) }
                }
            }
            .alert("icon.update.title", isPresented: Binding(
                get: { appIcon.error != nil },
                set: { if !$0 { appIcon.clearError() } }
            )) {
                Button("common.done") { appIcon.clearError() }
            } message: { Text(appIcon.error ?? "") }
    }

    @ViewBuilder private var content: some View {
        if model.preferences.onboardingComplete {
            TabView(selection: $selection) {
                NavigationStack { TodayView().appHeader() }
                    .tabItem { Label("tab.today", systemImage: "circle.dotted.circle.fill") }.tag(0)
                NavigationStack { StatisticsView().appHeader() }
                    .tabItem { Label("tab.statistics", systemImage: "chart.bar.xaxis") }.tag(1)
                NavigationStack { ExplorerView().appHeader() }
                    .tabItem { Label("tab.explorer", systemImage: "calendar") }.tag(2)
                NavigationStack { AchievementsView().appHeader() }
                    .tabItem { Label("tab.achievements", systemImage: "rosette") }.tag(3)
                NavigationStack { SettingsView().toolbar(.hidden, for: .navigationBar).appHeader(settingsIsCurrent: true) }
                    .tabItem { Label("tab.settings", systemImage: "slider.horizontal.3") }.tag(4)
            }
            .onOpenURL { url in
                guard url.scheme == "walkuno" else { return }
                switch url.host {
                case "today": selection = 0
                case "statistics": selection = 1
                case "explorer": selection = 2
                default: break
                }
            }
        } else { OnboardingView().appHeader() }
    }
}
