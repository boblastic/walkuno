import SwiftUI
import StoreKit

struct PremiumView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var showPrivacy = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Image(systemName: "sparkles").font(.system(size: 44)).foregroundStyle(model.effectiveTheme.tint(for: scheme)).padding(.top, 20)
                    Text("premium.headline").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("premium.body").foregroundStyle(.secondary)
                    #if DEBUG
                    WalkunoCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("premium.development.title").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            Toggle("premium.development.pro", isOn: Binding(
                                get: { model.purchases.isDevelopmentProEnabled },
                                set: { model.purchases.isDevelopmentProEnabled = $0 }
                            ))
                            .accessibilityIdentifier("premium.development.pro")
                            Text("premium.development.note").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    #endif
                    VStack(alignment: .leading, spacing: 20) {
                        Label("premium.feature.history", systemImage: "calendar")
                        Label("premium.feature.themes", systemImage: "paintpalette")
                        Label("premium.feature.counter", systemImage: "circle.dotted.circle")
                        Label("premium.feature.records", systemImage: "trophy")
                        Label("premium.feature.analysis", systemImage: "chart.bar.xaxis")
                        Label("premium.feature.widgets", systemImage: "square.grid.2x2")
                        Label("premium.feature.effects", systemImage: "sparkles")
                    }.font(.subheadline.weight(.medium))
                    if model.purchases.isPremium {
                        Label("premium.active", systemImage: "checkmark.seal.fill").foregroundStyle(model.effectiveTheme.tint(for: scheme))
                    } else if model.purchases.products.isEmpty {
                        WalkunoCard { Text("purchase.unavailable").font(.subheadline).foregroundStyle(.secondary) }
                        Button("purchase.retry") { Task { await model.purchases.load() } }
                    } else {
                        ForEach(model.purchases.products, id: \.id) { product in
                            Button { Task { await model.purchases.buy(product) } } label: {
                                WalkunoCard {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 5) {
                                            Text(product.displayName).font(.headline)
                                            Text(L(product.type == .autoRenewable ? "premium.annual.condition" : "premium.lifetime.condition"))
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(product.displayPrice).font(.title3.bold())
                                    }
                                }
                            }.buttonStyle(.plain).disabled(model.purchases.isBusy)
                        }
                    }
                    if model.purchases.isBusy { ProgressView().frame(maxWidth: .infinity) }
                    Button("purchase.restore") { Task { await model.purchases.restore() } }.font(.subheadline).disabled(model.purchases.isBusy)
                    Text("premium.renewal").font(.caption2).foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Button("privacy.title") { showPrivacy = true }
                        Link("premium.terms", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }.font(.caption)
                    Text("premium.free.note").font(.caption).foregroundStyle(.secondary)
                }.padding(28)
            }
            .background(WalkunoStyle.background(scheme))
            .navigationTitle("premium.title").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
            .task { await model.purchases.load() }
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
            .alert("purchase.title", isPresented: Binding(get: { model.purchases.message != nil }, set: { if !$0 { model.purchases.message = nil } })) {
                Button("common.done") { model.purchases.message = nil }
            } message: { Text(model.purchases.message ?? "") }
            .appHeader(subscriptionLinkEnabled: false)
        }
    }
}
