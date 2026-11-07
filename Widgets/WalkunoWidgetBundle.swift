import WidgetKit
import SwiftUI

@main
struct WalkunoWidgetBundle: WidgetBundle {
    var body: some Widget {
        WalkunoActivityWidget()
        WalkunoChartWidget()
        #if os(iOS)
        WalkunoDashboardWidget()
        WalkunoDailyGoalWidget()
        #endif
    }
}
