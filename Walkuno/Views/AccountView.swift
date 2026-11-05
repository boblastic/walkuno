import SwiftUI
import StoreKit

struct AccountView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    @State private var showPremium = false
    @State private var showSubscriptions = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label("account.local", systemImage: "person.crop.circle.fill").font(.headline)
                    Text("account.local.note").font(.subheadline).foregroundStyle(.secondary)
                }
                Section("account.access") {
                    LabeledContent("account.plan", value: L(model.purchases.isPremium ? "subscription.pro" : "subscription.free"))
                    Button(model.purchases.isPremium ? "premium.active" : "premium.title") { showPremium = true }
                        .accessibilityIdentifier("account.subscription")
                    Button("purchase.restore") { Task { await model.purchases.restore() } }
                        .disabled(model.purchases.isBusy)
                    Button("purchase.manage") { showSubscriptions = true }
                }
                Section {
                    NavigationLink { SettingsView().appHeader(accountIsCurrent: true) } label: { Label("tab.settings", systemImage: "slider.horizontal.3") }
                }
            }
            .scrollContentBackground(.hidden)
            .background(WalkunoStyle.background(scheme))
            .navigationTitle("account.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
            .sheet(isPresented: $showPremium) { PremiumView() }
            .manageSubscriptionsSheet(isPresented: $showSubscriptions)
            .alert("purchase.title", isPresented: Binding(get: { model.purchases.message != nil }, set: {
                if !$0 { model.purchases.message = nil }
            })) {
                Button("common.done") { model.purchases.message = nil }
            } message: { Text(model.purchases.message ?? "") }
            .appHeader(accountIsCurrent: true)
        }
    }
}
