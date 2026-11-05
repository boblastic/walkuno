import SwiftUI

/// A modal presentation of the same settings as the tab.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("common.done") { dismiss() }
                    }
                }
                .appHeader()
        }
    }
}
