import SwiftUI
import Charts

struct ExplorerView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var period: ActivityPeriod = .week
    @State private var anchor = Date.now
    @State private var chartScrubbing = false
    @State private var cancelledPageDrag = false
    @State private var showPremium = false
    @State private var detailDate: Date?
    @State private var pageWindow: ExplorerPageWindow?
    @State private var pageOffset: CGFloat = 0
    @State private var pageWidth: CGFloat = 0
    @State private var isSliding = false
    @State private var preparedHours: [Date: DayDetailHours] = [:]
    @State private var hoursRevision: HoursRevision?
    private var accent: Color { model.effectiveTheme.accent }
    private var calendar: Calendar {
        var calendar = Calendar.current
        if period == .week { calendar.firstWeekday = 2 }
        return calendar
    }
    private var interval: DateInterval { period.interval(containing: anchor, calendar: calendar) }
    private var earliestFree: Date { calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: .now))! }
    private var earliest: Date? { model.purchases.isPremium ? nil : earliestFree }
    private var dateStyle: Date.FormatStyle { .init(capitalizationContext: .beginningOfSentence) }
    private var periodTitle: String {
        if period == .week {
            let last = calendar.date(byAdding: .day, value: -1, to: interval.end)!
            return interval.start.formatted(.dateTime.day().month(.abbreviated)) + " – " + last.formatted(.dateTime.day().month(.abbreviated))
        }
        return anchor.formatted(period == .year ? dateStyle.year() : period == .day ? dateStyle.day().month(.wide) : dateStyle.month(.wide).year())
    }

    var body: some View {
        ZStack {
            ScrollView {
                if let window = pageWindow {
                    pageContent(window.current)
                        // Overlay pages share the scroll position and don't inflate the current page's height.
                        .overlay(alignment: .topLeading) { neighbor(window.previous, offset: -pageWidth) }
                        .overlay(alignment: .topLeading) { neighbor(window.next, offset: pageWidth) }
                        .offset(x: pageOffset)
                        .background {
                            GeometryReader { geometry in
                                Color.clear.onChange(of: geometry.size.width, initial: true) { _, width in pageWidth = width }
                            }
                        }
                        .contentShape(Rectangle())
                }
            }
            // Keep gesture coordinates fixed while the cards move and scroll underneath.
            .contentShape(Rectangle())
            .simultaneousGesture(pageDrag)
            .scrollDisabled(chartScrubbing)
            .accessibilityIdentifier("explorer.scroll")
            .environment(\.chartScrubbing, $chartScrubbing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .safeAreaInset(edge: .top, spacing: 0) {
            periodControls.padding(.horizontal, 16).padding(.bottom, 8).zIndex(1)
        }
        .background(WalkunoStyle.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPremium) { PremiumView() }
        .onChange(of: pageRequest, initial: true) { _, _ in preparePages() }
        .onChange(of: anchor) { _, _ in
            if pageWindow?.current.id != interval.start { preparePages() }
        }
        .task(id: hoursRequest) { await prepareHours() }
        .onChange(of: model.purchases.isPremium) { _, premium in
            if !premium && (period == .year || interval.end <= earliestFree) {
                period = .week; anchor = .now
            }
        }
        .sheet(item: Binding(get: { detailDate.map { SelectedDay(date: $0) } }, set: { detailDate = $0?.date })) { selection in
            NavigationStack { DayDetailView(date: selection.date).appHeader() }
        }
    }

    private var periodControls: some View {
        VStack(spacing: 6) {
            Picker("statistics.period", selection: Binding(get: { period }, set: { value in
                guard !isSliding else { return }
                if value == .year && !model.purchases.isPremium { showPremium = true; return }
                guard period != value else { return }
                period = value; pageOffset = 0
            })) {
                ForEach(ActivityPeriod.allCases) { value in Text(L("period.\(value.rawValue)")).tag(value) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("statistics.explorer.period")
            HStack(spacing: 4) {
                Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .accessibilityLabel(Text("statistics.previous")).accessibilityIdentifier("explorer.previous")
                Text(periodTitle)
                    .font(.headline).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                    .accessibilityIdentifier("explorer.period.title")
                Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44).contentShape(Rectangle()) }
                    .disabled(interval.contains(.now)).accessibilityLabel(Text("statistics.next"))
                    .accessibilityIdentifier("explorer.next")
            }.buttonStyle(.plain)
        }
        .padding(12)
        .background { WalkunoGlassSurface() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("explorer.controls")
    }

    private func pageContent(_ page: ExplorerActivity) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            if period == .day {
                DayDetailContent(date: page.anchor, preparedHours: preparedHours[calendar.startOfDay(for: page.anchor)] ?? .loading)
            } else {
                WalkunoCard {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("statistics.total").font(.subheadline).foregroundStyle(.secondary)
                        Text(stepsText(page.summary.total)).font(.system(.largeTitle, design: .rounded, weight: .bold)).contentTransition(.numericText())
                        if let change = ActivityMath.change(current: page.summary.total, previous: page.previousTotal) {
                            Text("statistics.change \(change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always())))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Chart(page.chartDays) { day in
                            if let steps = day.steps {
                                BarMark(x: .value(L("chart.date"), day.date, unit: period == .year ? .month : .day), y: .value(L("today.steps"), steps))
                                    .foregroundStyle(model.effectiveTheme.tint(for: scheme).gradient).cornerRadius(5)
                            }
                        }
                        .chartXScale(domain: page.interval.start...page.interval.end.addingTimeInterval(-1))
                        .chartXAxis {
                            AxisMarks(values: .stride(by: period == .year ? .month : .day, count: period == .week ? 1 : period == .month ? 5 : 2)) { _ in
                                AxisValueLabel(format: period == .year ? dateStyle.month(.abbreviated) : .dateTime.day())
                            }
                        }
                        .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in AxisGridLine().foregroundStyle(.primary.opacity(0.06)); AxisValueLabel() } }
                        .frame(height: 180)
                        .accessibilityIdentifier("explorer.chart")
                        .accessibilityLabel(Text("statistics.chart.accessibility \(stepsText(page.summary.total)) \(page.summary.observedDays)"))
                        .chartInspection("explorer.chart") { proxy in
                            let inspectedDays = period == .year
                                ? page.calendarMonths.map { ActivityDay(date: $0.date, steps: $0.summary.total) }
                                : ActivityMath.days(in: page.interval, available: page.chartDays,
                                                    now: page.interval.end.addingTimeInterval(-1), calendar: calendar)
                            return inspectedDays.compactMap { day in
                                let component: Calendar.Component = period == .year ? .month : .day
                                let bucket = calendar.dateInterval(of: component, for: day.date)
                                let middle = bucket.map { $0.start.addingTimeInterval($0.duration / 2) } ?? day.date
                                return ChartInspectionPoint(proxy: proxy, x: middle, y: day.steps.map(Double.init),
                                    title: day.date.formatted(period == .year ? .dateTime.month(.wide).year() : .dateTime.day().month(.abbreviated).year()),
                                    value: day.steps.map { stepsText($0) + " " + L("today.steps") } ?? L("chart.no.data"), color: model.effectiveTheme.tint(for: scheme))
                            }
                        }
                        .id(page.id)
                    }
                }
                HStack(spacing: 12) {
                    MetricCard(title: "statistics.average", value: stepsText(page.summary.average), symbol: "chart.line.uptrend.xyaxis", color: accent)
                    MetricCard(title: "statistics.goals", value: "\(page.summary.achievedDays)/\(page.summary.observedDays)", symbol: "checkmark.seal", color: model.effectiveTheme.secondaryAccent)
                }
                WalkunoCard {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("statistics.highlights").font(.headline)
                        LabeledContent("metric.distance", value: distanceText(page.summary.meters, unit: model.preferences.unit))
                        LabeledContent("statistics.best") {
                            if let best = page.summary.best {
                                Text("\(best.date.formatted(.dateTime.day().month(.abbreviated))) · \(stepsText(best.steps)) \(L("today.steps"))")
                                    .lineLimit(1).minimumScaleFactor(0.7)
                            } else { Text("—") }
                        }
                        .font(.subheadline)
                        .accessibilityIdentifier("explorer.best.day")
                        LabeledContent("metric.floors", value: ActivityMetric.floors.text(page.total(for: .floors), unit: model.preferences.unit))
                            .accessibilityIdentifier("explorer.total.floors")
                        if model.preferences.showEnergy {
                            LabeledContent("metric.energy", value: ActivityMetric.energy.text(page.total(for: .energy), unit: model.preferences.unit))
                                .accessibilityIdentifier("explorer.total.energy")
                        }
                        LabeledContent("metric.exercise", value: ActivityMetric.exerciseTime.text(page.total(for: .exerciseTime), unit: model.preferences.unit))
                            .accessibilityIdentifier("explorer.total.exercise")
                        if period == .year, let bestMonth = page.bestMonth {
                            LabeledContent("statistics.best.month") {
                                Text(bestMonth.formatted(dateStyle.month(.wide))).accessibilityIdentifier("explorer.best.month")
                            }
                        }
                        Text("statistics.coverage \(page.summary.observedDays)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                calendarCard(page)
            }
            if !model.purchases.isPremium {
                Button { showPremium = true } label: {
                    Label("premium.history.cta", systemImage: "sparkles").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).controlSize(.large)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func neighbor(_ page: ExplorerActivity?, offset: CGFloat) -> some View {
        Group {
            if let page {
                pageContent(page).offset(x: offset)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var pageDrag: some Gesture {
        DragGesture(minimumDistance: 18)
            .onChanged { value in
                guard !isSliding else { return }
                if chartScrubbing { cancelledPageDrag = true; pageOffset = 0; return }
                guard !cancelledPageDrag else { return }
                guard abs(value.translation.width) > abs(value.translation.height) * 1.3, !reduceMotion else { return }
                let hasNeighbor = value.translation.width > 0 ? pageWindow?.previous != nil : pageWindow?.next != nil
                pageOffset = min(pageWidth, max(-pageWidth, value.translation.width * (hasNeighbor ? 1 : 0.15)))
            }
            .onEnded { value in
                defer { cancelledPageDrag = false }
                guard !isSliding, !chartScrubbing, !cancelledPageDrag else { settlePage(); return }
                let travel = value.translation.width
                let predicted = value.predictedEndTranslation.width
                guard abs(travel) > abs(value.translation.height) * 1.3,
                      abs(travel) > 35 || (abs(travel) > 18 && abs(predicted) > pageWidth * 0.4) else {
                    settlePage(); return
                }
                move(travel > 0 ? -1 : 1)
            }
    }

    private func move(_ offset: Int) {
        guard !isSliding else { return }
        guard let date = ActivityMath.adjacentAnchor(to: anchor, period: period, offset: offset, calendar: calendar) else {
            settlePage(); return
        }
        if let earliest, period.interval(containing: date, calendar: calendar).end <= earliest {
            settlePage(); showPremium = true; return
        }
        guard !reduceMotion, pageWidth > 0 else { selectAnchor(date); return }
        let originPeriod = period
        let originAnchor = anchor
        isSliding = true
        withAnimation(.easeOut(duration: 0.22), completionCriteria: .logicallyComplete) {
            pageOffset = offset < 0 ? pageWidth : -pageWidth
        } completion: {
            if period == originPeriod && anchor == originAnchor { selectAnchor(date) }
            else { settlePage() }
            isSliding = false
        }
    }

    private func selectAnchor(_ date: Date) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            anchor = date; pageOffset = 0
            preparePages(reusing: true)
        }
    }

    private func settlePage() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { pageOffset = 0 }
    }

    private struct PageRequest: Equatable {
        var period: ActivityPeriod
        var days: [ActivityDay]
        var goals: GoalHistory
        var earliest: Date?
        var today: Date
        var calendar: Calendar
    }

    private var pageRequest: PageRequest {
        .init(period: period, days: model.days, goals: model.preferences.goals, earliest: earliest,
              today: calendar.startOfDay(for: .now), calendar: calendar)
    }

    private func preparePages(reusing: Bool = false) {
        pageWindow = .init(period: period, anchor: anchor, available: model.days, goals: model.preferences.goals,
                           earliest: earliest, calendar: calendar, reusing: reusing ? pageWindow : nil)
    }

    private struct HoursRevision: Equatable {
        var updated: Date?
        var todayHours: [HourActivity]
        var calendar: Calendar
        var earliest: Date?
    }

    private struct HoursRequest: Equatable {
        var dates: [Date]
        var revision: HoursRevision
    }

    private var hoursRequest: HoursRequest {
        let dates = period == .day ? [pageWindow?.current, pageWindow?.previous, pageWindow?.next]
            .compactMap { $0.map { calendar.startOfDay(for: $0.anchor) } } : []
        return .init(dates: dates, revision: .init(updated: model.lastUpdated, todayHours: model.hours, calendar: calendar, earliest: earliest))
    }

    @MainActor private func prepareHours() async {
        let request = hoursRequest
        if hoursRevision != request.revision { preparedHours = [:]; hoursRevision = request.revision }
        preparedHours = preparedHours.filter { request.dates.contains($0.key) }
        // Fetch the visible day and both neighbors concurrently, retaining completed values on navigation.
        await withTaskGroup(of: (Date, DayDetailHours?).self) { group in
            for date in request.dates where preparedHours[date] == nil {
                group.addTask { @MainActor in
                    do {
                        let values = try await model.hourly(on: date)
                        try Task.checkCancellation()
                        return (date, DayDetailHours(values: values))
                    } catch {
                        return (date, Task.isCancelled ? nil : DayDetailHours(failed: true))
                    }
                }
            }
            for await (date, result) in group {
                guard !Task.isCancelled, let result else { continue }
                preparedHours[date] = result
            }
        }
    }

    private func calendarCard(_ page: ExplorerActivity) -> some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("calendar.title").font(.headline)
                if period == .year {
                    monthGrid(page)
                } else {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                        ForEach(0..<page.calendarOffset, id: \.self) { _ in Color.clear.frame(minHeight: 40).accessibilityHidden(true) }
                        ForEach(page.calendarDays) { day in
                            let locked = !model.purchases.isPremium && day.date < earliestFree
                            let progress = ActivityMath.progress(steps: day.steps, goal: model.preferences.goals.value(on: day.date))
                            Button {
                                if locked { showPremium = true } else { detailDate = day.date }
                            } label: {
                                VStack(spacing: 6) {
                                    if period == .week {
                                        Text(day.date.formatted(.dateTime.weekday(.abbreviated))).font(.caption2.weight(.semibold))
                                    }
                                    Text(day.date.formatted(.dateTime.day())).font(.caption.weight(.medium))
                                }
                                    .frame(maxWidth: .infinity, minHeight: period == .week ? 60 : 40)
                                    .foregroundStyle(!locked && day.steps != nil && progress > 0.55 ? WalkunoStyle.ink : scheme == .dark ? .white : .primary)
                                    .background(locked || day.steps == nil ? Color.primary.opacity(0.035) : accent.opacity(0.12 + min(progress, 1) * 0.6), in: RoundedRectangle(cornerRadius: 9))
                                    .overlay(alignment: .bottom) {
                                        if day.steps == nil { Circle().fill(.secondary).frame(width: 3, height: 3).padding(.bottom, 4) }
                                    }
                            }.buttonStyle(.plain)
                                .disabled(day.date > Date.now)
                                .accessibilityIdentifier("explorer.calendar.day.\(Calendar.current.component(.day, from: day.date))")
                                .accessibilityLabel(Text("\(day.date.formatted(date: .complete, time: .omitted)), \(locked ? L("premium.title") : day.steps.map { $0.formatted() + " " + L("today.steps") } ?? L("chart.no.data"))"))
                        }
                    }
                }
                Text(period == .year ? "calendar.legend.months" : "calendar.legend").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func monthGrid(_ page: ExplorerActivity) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            ForEach(page.calendarMonths) { month in
                let progress = month.progress ?? 0
                Button {
                    anchor = month.date; period = .month; pageOffset = 0
                } label: {
                    Text(month.date.formatted(dateStyle.month(.abbreviated)))
                        .font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .foregroundStyle(month.progress != nil && progress > 0.55 ? WalkunoStyle.ink : scheme == .dark ? .white : .primary)
                        .background(month.progress == nil ? Color.primary.opacity(0.035) : accent.opacity(0.12 + min(progress, 1) * 0.6), in: RoundedRectangle(cornerRadius: 9))
                        .overlay(alignment: .bottom) {
                            if month.progress == nil { Circle().fill(.secondary).frame(width: 3, height: 3).padding(.bottom, 4) }
                        }
                }
                .buttonStyle(.plain)
                .disabled(month.date > Date.now)
                .accessibilityIdentifier("explorer.calendar.month.\(calendar.component(.month, from: month.date))")
                .accessibilityLabel(Text("\(month.date.formatted(dateStyle.month(.wide).year())), \(stepsText(month.summary.total)) \(L("today.steps")), \(month.progress.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? L("chart.no.data"))"))
            }
        }
    }
}

private struct SelectedDay: Identifiable { var date: Date; var id: Date { date } }

private struct ExplorerHourlyChart: View {
    var date: Date
    var hours: [HourActivity]
    var accent: Color

    var body: some View {
        let activity = ExplorerHourlyActivity(date: date, available: hours)
        let maximum = max(1_000, Double(activity.hours.compactMap(\.steps).max() ?? 0) * 1.15)
        Chart(activity.hours) { hour in
            if let steps = hour.steps, steps > 0 {
                BarMark(x: .value(L("chart.hour"), hour.date, unit: .hour), y: .value(L("today.steps"), steps))
                    .foregroundStyle(accent.gradient).cornerRadius(3)
            } else {
                // A decorative dash occupies the empty hour without inventing a step count.
                RuleMark(xStart: .value(L("chart.hour"), hour.date.addingTimeInterval(900)),
                         xEnd: .value(L("chart.hour"), hour.date.addingTimeInterval(2_700)), y: .value(L("today.steps"), 0))
                    .foregroundStyle(Color.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, dash: [1, 3]))
                    .accessibilityLabel(Text(hour.date.formatted(.dateTime.hour())))
                    .accessibilityValue(Text(hour.steps == nil ? L("chart.no.data") : "0 " + L("today.steps")))
            }
        }
        .chartXScale(domain: activity.interval.start...activity.interval.end.addingTimeInterval(-1))
        .chartYScale(domain: 0...maximum)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted)))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine(stroke: StrokeStyle(dash: [2, 4])).foregroundStyle(Color.primary.opacity(0.08))
                AxisValueLabel()
            }
        }
        .accessibilityLabel(Text("chart.hourly"))
        .id(date)
        .accessibilityIdentifier("explorer.day.hourly")
        .chartInspection("explorer.day.hourly") { proxy in
            activity.hours.compactMap { hour in
                ChartInspectionPoint(proxy: proxy, x: hour.date.addingTimeInterval(1800), y: hour.steps.map(Double.init),
                    title: hour.date.formatted(.dateTime.hour().minute()),
                    value: hour.steps.map { stepsText($0) + " " + L("today.steps") } ?? L("chart.no.data"), color: accent)
            }
        }
    }
}

struct DayDetailView: View {
    var date: Date
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ScrollView { DayDetailContent(date: date).padding(24) }
            .background(WalkunoStyle.background(scheme))
            .navigationTitle(date.formatted(.dateTime.day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.done") { dismiss() } } }
    }
}

struct DayDetailHours: Sendable {
    var values: [HourActivity] = []
    var isLoading = false
    var failed = false
    static var loading: Self { .init(isLoading: true) }
}

struct DayDetailContent: View {
    @Environment(\.colorScheme) private var scheme
    var date: Date
    @Environment(AppModel.self) private var model
    var preparedHours: DayDetailHours? = nil
    @State private var loadedHours: [HourActivity] = []
    @State private var loadError = false
    @State private var isLoading = false
    private var hours: [HourActivity] { preparedHours?.values ?? loadedHours }
    private var error: Bool { preparedHours?.failed ?? loadError }
    private var loading: Bool { preparedHours?.isLoading ?? isLoading }
    private var day: ActivityDay? { model.days.first { Calendar.current.isDate($0.date, inSameDayAs: date) } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WalkunoCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("chart.hourly").font(.headline)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(stepsText(day?.steps)).font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .contentTransition(.numericText()).accessibilityIdentifier("explorer.day.total")
                        Text("today.steps").font(.subheadline).foregroundStyle(.secondary)
                    }
                    ExplorerHourlyChart(date: date, hours: hours, accent: model.effectiveTheme.tint(for: scheme)).frame(height: 180)
                    if loading { ProgressView() }
                    if error { Text("health.refresh.error").font(.caption).foregroundStyle(.secondary) }
                    if !loading && hours.allSatisfy({ $0.steps == nil }) { Text("chart.no.data").font(.caption).foregroundStyle(.secondary) }
                }
            }
            LabeledContent("metric.distance", value: distanceText(day?.meters, unit: model.preferences.unit))
            if model.preferences.showEnergy {
                LabeledContent("metric.energy", value: day?.kilocalories.map { Int($0).formatted() + " kcal" } ?? "—")
            }
            LabeledContent("metric.exercise", value: ActivityMetric.exerciseTime.text(day?.exerciseMinutes, unit: model.preferences.unit))
            LabeledContent("metric.floors", value: ActivityMetric.floors.text(day?.floors, unit: model.preferences.unit))
            if let peak = hours.filter({ $0.steps != nil }).max(by: { ($0.steps ?? 0) < ($1.steps ?? 0) }) {
                LabeledContent("statistics.peak", value: peak.date.formatted(.dateTime.hour()))
            }
            DisclosureGroup("chart.values") {
                ForEach(hours) { hour in
                    LabeledContent(hour.date.formatted(.dateTime.hour()), value: stepsText(hour.steps)).font(.subheadline).padding(.vertical, 4)
                }
            }.padding(.top)
        }
        .task(id: date) {
            guard preparedHours == nil else { return }
            isLoading = true; loadError = false; loadedHours = []
            defer { isLoading = false }
            do {
                let values = try await model.hourly(on: date)
                try Task.checkCancellation()
                loadedHours = values
            } catch { if !Task.isCancelled { loadError = true } }
        }
    }
}
