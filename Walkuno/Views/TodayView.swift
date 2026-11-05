import SwiftUI
import Charts
import Observation

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var period: ActivityPeriod = .day
    @State private var anchor = Date.now
    @State private var chartWindowAnchor: Date?
    @State private var showGoal = false
    @State private var showDetail = false
    @State private var showShare = false
    @State private var showPremium = false
    @State private var ringReplay = 0
    @State private var pageWindow: DashboardPageWindow?
    @State private var paging = CounterPagingState()
    @State private var hasNavigated = false
    @State private var selectedHours: [HourActivity] = []
    @State private var selectedPreviousHours: [HourActivity] = []
    @State private var loadedHoursDate: Date?
    @State private var loadingHours = false
    @State private var hoursError = false
    @State private var previousHoursError = false

    private var accent: Color { model.effectiveTheme.accent }
    private var ink: Color { model.effectiveTheme.tint(for: scheme) }
    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }
    private var earliest: Date? {
        model.purchases.isPremium ? nil : calendar.date(byAdding: .day, value: -30, to: calendar.startOfDay(for: .now))
    }
    private var activity: DashboardActivity {
        pageWindow?.page(containing: anchor, period: period)?.activity ??
            .init(period: period, anchor: anchor, available: model.days, goals: model.preferences.goals, earliest: earliest, calendar: calendar)
    }
    private var isCurrentPeriod: Bool { activity.interval.contains(.now) }
    private var title: String { title(for: anchor, activity: activity) }
    private func title(for anchor: Date, activity: DashboardActivity) -> String {
        if period == .day {
            if calendar.isDateInToday(anchor) { return L("tab.today") }
            if calendar.isDateInYesterday(anchor) { return L("today.yesterday") }
            return formattedDate(anchor, .dateTime.day().month(.abbreviated))
        }
        if period == .week {
            if activity.interval.contains(.now) { return L("today.this.week") }
            return L("period.week")
        }
        if period == .year { return anchor.formatted(.dateTime.year()) }
        return formattedDate(anchor, .dateTime.month(.wide))
    }
    private var dateRange: String {
        if period == .day { return formattedDate(anchor, .dateTime.weekday(.wide).day().month(.wide).year()) }
        if period == .month { return formattedDate(anchor, .dateTime.month(.wide).year()) }
        if period == .year { return anchor.formatted(.dateTime.year()) }
        let last = calendar.date(byAdding: .day, value: -1, to: activity.interval.end)!
        return formattedDate(activity.interval.start, .dateTime.day().month(.abbreviated)) + " – " + formattedDate(last, .dateTime.day().month(.abbreviated).year())
    }
    private func formattedDate(_ date: Date, _ format: Date.FormatStyle) -> String {
        var format = format
        format.capitalizationContext = .beginningOfSentence
        return date.formatted(format)
    }
    private var chartActivity: DashboardTrendActivity {
        .init(period: period, anchor: period == .day ? chartWindowAnchor ?? anchor : anchor,
              available: model.days, earliest: earliest, calendar: calendar)
    }
    private var streak: Int? {
        guard let last = activity.days.last else { return nil }
        let accessible = model.days.filter { day in earliest.map { day.date >= $0 } ?? true }
        return ActivityMath.currentStreak(days: accessible, goals: model.preferences.goals, endingOn: last.date)
    }
    private var hours: [HourActivity] {
        if calendar.isDateInToday(anchor) { return model.hours }
        return loadedHoursDate == calendar.startOfDay(for: anchor) ? selectedHours : []
    }
    private var previousHours: [HourActivity] {
        if calendar.isDateInToday(anchor) { return model.yesterdayHours }
        return loadedHoursDate == calendar.startOfDay(for: anchor) ? selectedPreviousHours : []
    }
    private var previousSteps: Int? {
        let previous = period.previous(anchor, calendar: calendar)
        let previousInterval = period.interval(containing: previous, calendar: calendar)
        guard earliest.map({ previousInterval.start >= $0 }) ?? true else { return nil }
        let end = min(previousInterval.end, calendar.date(byAdding: .day, value: activity.days.count, to: previousInterval.start)!)
        let days = model.days.filter { $0.date >= previousInterval.start && $0.date < end }
        return ActivitySummary(days: days, goals: model.preferences.goals).total
    }
    private var counterReplay: String { "\(period.rawValue)-\(calendar.startOfDay(for: anchor).timeIntervalSinceReferenceDate)-\(ringReplay)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if model.isDemo { Label("demo.banner", systemImage: "sparkles").font(.caption).foregroundStyle(model.effectiveTheme.secondaryTint(for: scheme)) }
                Picker("statistics.period", selection: Binding(get: { period }, set: { value in
                    guard !paging.isSliding else { return }
                    if value == .year && !model.purchases.isPremium { showPremium = true }
                    else if value != period { hasNavigated = true; period = value }
                })) {
                    ForEach(ActivityPeriod.allCases) { value in
                        Text(L("period.\(value.rawValue)")).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("today.period")

                VStack(spacing: 12) {
                    periodNavigation
                    counter
                    metrics
                    TodayTrendChart(activity: chartActivity, selectedDate: period == .day ? anchor : nil,
                                    goal: model.preferences.goals.value(on: anchor), accent: ink, period: period) { date in
                        // Keep all seven days available while comparing dates in this window.
                        chartWindowAnchor = chartWindowAnchor ?? anchor
                        selectAnchor(date)
                    }
                }
                .contentShape(Rectangle())
                // A swipe must win over the counter's tap-to-detail gesture.
                .highPriorityGesture(DragGesture(minimumDistance: 30)
                    .onChanged { value in
                        guard !paging.isSliding, !reduceMotion,
                              abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                        let hasNeighbor = value.translation.width > 0 ? pageWindow?.previous != nil : pageWindow?.next != nil
                        let translation = hasNeighbor ? value.translation.width : value.translation.width * 0.15
                        paging.offset = min(paging.width, max(-paging.width, translation))
                    }
                    .onEnded { value in
                        guard !paging.isSliding else { return }
                        guard abs(value.translation.width) > 35,
                              abs(value.translation.width) > abs(value.translation.height) * 1.5 else { settleCounter(); return }
                        move(value.translation.width > 0 ? -1 : 1)
                    })

                if activity.summary.total == nil && !model.isLoading { HealthEmptyView() }
                if model.isLoading {
                    HStack { ProgressView(); Text("health.refreshing").font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity)
                }
                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(.secondary)
                }
                if period == .day && calendar.isDateInToday(anchor) && model.celebration {
                    Label("today.celebration", systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(WalkunoStyle.ink)
                        .padding().frame(maxWidth: .infinity).background(accent, in: RoundedRectangle(cornerRadius: 18))
                        .transition(reduceMotion ? .identity : .scale.combined(with: .opacity))
                        .sensoryFeedback(.success, trigger: model.celebration)
                }
                if period == .day { hourlyCard } else { periodSummary }
                comparisonCard
                if activity.summary.total != nil && (activity.total(for: .exerciseTime) == nil || activity.total(for: .floors) == nil) {
                    Button { Task { await model.connectHealth() } } label: {
                        Label("today.health.metrics", systemImage: "heart.text.clipboard").font(.caption)
                    }.frame(maxWidth: .infinity).tint(ink)
                }
                HStack(spacing: 12) {
                    Button { showGoal = true } label: { Label("goal.edit", systemImage: "scope").frame(maxWidth: .infinity) }
                    Button { showShare = true } label: { Label("share.title", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                        .disabled(activity.summary.total == nil)
                }.buttonStyle(.bordered).controlSize(.large).font(.subheadline)
                if let updated = model.lastUpdated {
                    Text("today.updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                    if model.usingCache { Text("today.cached").font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity) }
                }
            }.padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 28)
        }
        .background(WalkunoStyle.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .refreshable { await model.refresh(); ringReplay += 1 }
        .onChange(of: pageRequest, initial: true) { _, _ in preparePages() }
        .task(id: HoursRequest(date: calendar.startOfDay(for: anchor), period: period, updated: model.lastUpdated)) { await loadHours() }
        .onChange(of: model.today.date) { previous, current in
            chartWindowAnchor = nil
            if calendar.isDate(anchor, inSameDayAs: previous) { anchor = current }
        }
        .onChange(of: period) { _, _ in
            chartWindowAnchor = nil
            if let earliest, anchor < earliest { anchor = earliest }
        }
        .onChange(of: model.purchases.isPremium) { _, premium in
            if !premium {
                chartWindowAnchor = nil
                if period == .year { period = .day }
                if let earliest, anchor < earliest { anchor = .now }
            }
        }
        .sheet(isPresented: $showGoal) { GoalEditor() }
        .sheet(isPresented: $showDetail) { NavigationStack { DayDetailView(date: anchor).appHeader() } }
        .sheet(isPresented: $showShare) { ShareCardView(anchor: anchor, initialScope: ShareScope(rawValue: period.rawValue) ?? .day) }
        .sheet(isPresented: $showPremium) { PremiumView() }
    }

    private var periodNavigation: some View {
        HStack(spacing: 4) {
            Button { move(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel(Text("statistics.previous")).accessibilityIdentifier("today.previous")
            VStack(spacing: 2) {
                Text(dateRange).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).accessibilityIdentifier("today.date")
                if !isCurrentPeriod {
                    Button("today.return.current") { chartWindowAnchor = nil; selectAnchor(.now) }
                        .font(.caption.weight(.semibold)).accessibilityIdentifier("today.current")
                }
            }.frame(maxWidth: .infinity)
            Button { move(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .disabled(isCurrentPeriod).accessibilityLabel(Text("statistics.next")).accessibilityIdentifier("today.next")
        }.buttonStyle(.plain)
    }

    private var counter: some View {
        TodayCounterCarousel(
            current: TodayAnimatedCounter(steps: activity.summary.total, goal: activity.goal, title: title,
                                          theme: model.effectiveTheme, showsRing: model.effectiveCounter == .ring,
                                          replay: counterReplay,
                                          animateEntry: model.preferences.animatePeriodChanges || (!hasNavigated && period == .day && calendar.isDateInToday(anchor)),
                                          animateUpdates: model.preferences.animatePeriodChanges || (period == .day && calendar.isDateInToday(anchor)))
                .id("\(period.rawValue)-\(activity.interval.start.timeIntervalSinceReferenceDate)")
                .frame(width: counterDiameter, height: counterDiameter),
            previous: preparedCounter(pageWindow?.previous), next: preparedCounter(pageWindow?.next), paging: paging)
                .frame(height: counterDiameter)
                .clipped()
                .background {
                    RadialGradient(colors: [accent.opacity(0.14), .clear], center: .center, startRadius: 20, endRadius: 150)
                        // Let the halo fade behind neighboring content without changing the counter's layout.
                        .frame(width: 300, height: 300)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
        .onTapGesture {
            if period == .day && !paging.isSliding { showDetail = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(Text(dateRange) + Text(", ") + Text("today.counter.accessibility \(stepsText(activity.summary.total)) \(activity.goal.formatted())"))
        .accessibilityHint(period == .day ? Text("today.detail.hint") : Text("today.swipe.hint"))
        .accessibilityAction { if period == .day && !paging.isSliding { showDetail = true } }
        .accessibilityAction(named: Text("statistics.previous")) { move(-1) }
        .accessibilityAction(named: Text("statistics.next")) { move(1) }
        .accessibilityIdentifier("today.counter")
    }

    private var counterDiameter: CGFloat { typeSize.isAccessibilitySize ? 280 : 232 }

    private func preparedCounter(_ page: DashboardPageWindow.Page?) -> some View {
        Group {
            if let page {
                TodayCounterFrame(displayedSteps: Double(page.activity.summary.total ?? 0), phase: 1,
                                  hasSteps: page.activity.summary.total != nil, goal: page.activity.goal,
                                  title: title(for: page.anchor, activity: page.activity), theme: model.effectiveTheme,
                                  showsRing: model.effectiveCounter == .ring)
                    .frame(width: counterDiameter, height: counterDiameter)
            } else { Color.clear.frame(width: counterDiameter, height: counterDiameter) }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var metrics: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: typeSize.isAccessibilitySize ? 2 : model.preferences.showEnergy ? 5 : 4), spacing: 8) {
            TodayMetric(title: "today.streak", value: stepsText(streak), symbol: "flame.fill", color: model.effectiveTheme.secondaryAccent)
            if model.preferences.showEnergy {
                TodayMetric(title: "today.kcal", value: activity.total(for: .energy).map { Int($0).formatted() } ?? "—", symbol: "bolt.heart.fill", color: model.effectiveTheme.secondaryAccent)
            }
            TodayMetric(title: LocalizedStringKey(model.preferences.unit.symbol), value: activity.total(for: .distance).map { model.preferences.unit.convert(meters: $0).formatted(.number.precision(.fractionLength(1))) } ?? "—", symbol: "location.fill", color: accent)
            TodayMetric(title: "today.exercise", value: exerciseText, symbol: "stopwatch", color: accent)
            TodayMetric(title: "today.floors", value: activity.total(for: .floors).map { Int($0).formatted() } ?? "—", symbol: "stairs", color: accent)
        }
    }

    private var exerciseText: String {
        guard let minutes = activity.total(for: .exerciseTime) else { return "—" }
        let rounded = Int(minutes.rounded())
        return "\(rounded / 60):" + String(format: "%02d", rounded % 60)
    }

    private var hourlyCard: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack { Text("today.rhythm").font(.headline); Spacer(); Image(systemName: "chart.bar.xaxis").foregroundStyle(ink) }
                DailyRhythmChart(date: anchor, hours: hours, previousHours: previousHours, title: title, accent: ink)
                if loadingHours { ProgressView() }
                else if hoursError { Text("health.refresh.error").font(.caption).foregroundStyle(.secondary) }
                else if let peak = hours.filter({ $0.steps != nil }).max(by: { ($0.steps ?? 0) < ($1.steps ?? 0) }) {
                    Text("today.peak \(peak.date.formatted(.dateTime.hour()))").font(.caption).foregroundStyle(.secondary)
                } else { Text("chart.no.data").font(.caption).foregroundStyle(.secondary) }
                if !loadingHours && (previousHoursError || !previousHours.contains(where: { $0.steps != nil })) {
                    Text("today.rhythm.previous.unavailable").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var periodSummary: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("today.average").font(.caption).foregroundStyle(.secondary)
                        Text(stepsText(activity.summary.average)).font(.title3.bold()).monospacedDigit()
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("statistics.goals").font(.caption).foregroundStyle(.secondary)
                        Text("\(activity.summary.achievedDays) / \(activity.days.count)").font(.title3.bold()).monospacedDigit()
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("statistics.coverage \(activity.summary.observedDays)").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var comparisonCard: some View {
        WalkunoCard {
            HStack(spacing: 14) {
                Image(systemName: (ActivityMath.change(current: activity.summary.total, previous: previousSteps) ?? 0) < 0 ? "arrow.down.right" : "arrow.up.right")
                    .font(.title3.weight(.semibold)).foregroundStyle(WalkunoStyle.ink)
                    .frame(width: 40, height: 40).background(accent, in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("today.comparison.\(period.rawValue)")).font(.subheadline.weight(.semibold))
                    if let change = ActivityMath.change(current: activity.summary.total, previous: previousSteps) {
                        Text(change.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always()))).font(.title3.weight(.bold))
                    } else { Text("comparison.unavailable").font(.caption).foregroundStyle(.secondary) }
                    if isCurrentPeriod { Text("today.comparison.elapsed").font(.caption2).foregroundStyle(.secondary) }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func move(_ offset: Int) {
        guard !paging.isSliding else { return }
        guard let date = ActivityMath.adjacentAnchor(to: anchor, period: period, offset: offset, calendar: calendar) else { settleCounter(); return }
        if let earliest, period.interval(containing: date, calendar: calendar).end <= earliest {
            settleCounter(); showPremium = true; return
        }
        chartWindowAnchor = nil
        let destination = period.interval(containing: date, calendar: calendar).contains(.now) ? .now : date
        guard !reduceMotion, paging.width > 0 else { selectAnchor(destination); return }
        paging.isSliding = true
        withAnimation(.easeInOut(duration: 0.5), completionCriteria: .logicallyComplete) {
            paging.offset = offset < 0 ? paging.width : -paging.width
        } completion: {
            selectAnchor(destination)
            paging.isSliding = false
        }
    }

    private func selectAnchor(_ date: Date) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            hasNavigated = true
            anchor = date
            paging.offset = 0
            preparePages()
        }
    }

    private func settleCounter() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { paging.offset = 0 }
    }

    private struct PageRequest: Equatable {
        var date: Date
        var period: ActivityPeriod
        var days: [ActivityDay]
        var goals: GoalHistory
        var earliest: Date?
        var calendar: Calendar
    }

    private var pageRequest: PageRequest {
        .init(date: calendar.startOfDay(for: anchor), period: period, days: model.days,
              goals: model.preferences.goals, earliest: earliest, calendar: calendar)
    }

    private func preparePages() {
        pageWindow = .init(period: period, anchor: anchor, available: model.days,
                           goals: model.preferences.goals, earliest: earliest, calendar: calendar)
    }

    private struct HoursRequest: Equatable {
        var date: Date
        var period: ActivityPeriod
        var updated: Date?
    }

    @MainActor private func loadHours() async {
        selectedHours = []; selectedPreviousHours = []; loadedHoursDate = nil
        hoursError = false; previousHoursError = false
        guard period == .day, !calendar.isDateInToday(anchor) else { loadingHours = false; return }
        let date = calendar.startOfDay(for: anchor)
        loadingHours = true
        do {
            let values = try await model.hourly(on: date)
            try Task.checkCancellation()
            selectedHours = values; loadedHoursDate = date
        } catch {
            guard !Task.isCancelled else { return }
            hoursError = true
        }
        if let previous = calendar.date(byAdding: .day, value: -1, to: date),
           earliest.map({ previous >= $0 }) ?? true {
            do {
                let values = try await model.hourly(on: previous)
                try Task.checkCancellation()
                selectedPreviousHours = values; loadedHoursDate = date
            } catch {
                guard !Task.isCancelled else { return }
                previousHoursError = true
            }
        }
        guard !Task.isCancelled else { return }
        loadingHours = false
    }
}

private struct TodayMetric: View {
    var title: LocalizedStringKey
    var value: String
    var symbol: String
    var color: Color
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol).font(.caption2.weight(.semibold)).accessibilityHidden(true)
            Text(value).font(.system(.title3, design: .rounded, weight: .bold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.65)
            Text(title).font(.caption2).foregroundStyle(WalkunoStyle.ink.opacity(0.88)).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 58).padding(.horizontal, 4).padding(.vertical, 5)
        .foregroundStyle(WalkunoStyle.ink)
        .background(color, in: RoundedRectangle(cornerRadius: 19))
        .accessibilityElement(children: .combine)
    }
}

private struct TodayTrendChart: View {
    var activity: DashboardTrendActivity
    var selectedDate: Date?
    var goal: Int
    var accent: Color
    var period: ActivityPeriod
    var onSelectDay: (Date) -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var selectionFeedback = 0

    private var days: [ActivityDay] { activity.days }
    private var summary: ActivitySummary { activity.summary }
    private let referenceStroke = StrokeStyle(lineWidth: 1.5, dash: [2, 4])

    private var isolatedSegments: Set<Int> {
        Set(Dictionary(grouping: activity.points.filter { $0.steps != nil }, by: \.segment)
            .filter { $0.value.count == 1 }.keys)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(L(period == .day ? "today.last.seven" : "today.period.rhythm"))
                    .font(.caption.weight(.semibold))
                    .accessibilityIdentifier("today.trend.title")
                Spacer(minLength: 0)
                Text("today.chart.goal \(goal.formatted())").foregroundStyle(.secondary)
                    .accessibilityIdentifier("today.trend.goal")
                Text("today.chart.average \(stepsText(summary.average))").foregroundStyle(accent)
                    .accessibilityIdentifier("today.trend.average")
            }
            .font(.caption2).monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
            Chart {
                RuleMark(xStart: .value(L("chart.date"), activity.domain.lowerBound),
                         xEnd: .value(L("chart.date"), activity.domain.upperBound),
                         y: .value(L("goal.title"), goal))
                    .foregroundStyle(Color.secondary.opacity(0.5)).lineStyle(referenceStroke)
                if let average = summary.average {
                    RuleMark(xStart: .value(L("chart.date"), activity.domain.lowerBound),
                             xEnd: .value(L("chart.date"), activity.domain.upperBound),
                             y: .value(L("insights.average"), average))
                        .foregroundStyle(accent).lineStyle(referenceStroke)
                }
                ForEach(activity.points) { point in
                    if let steps = point.steps {
                        AreaMark(x: .value(L("chart.date"), point.date), y: .value(L("today.steps"), steps), series: .value("segment", point.segment))
                            .foregroundStyle(LinearGradient(colors: [accent.opacity(0.48), accent.opacity(0.03)], startPoint: .top, endPoint: .bottom))
                            .interpolationMethod(.monotone)
                        LineMark(x: .value(L("chart.date"), point.date), y: .value(L("today.steps"), steps), series: .value("segment", point.segment))
                            .foregroundStyle(accent).lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round)).interpolationMethod(.monotone)
                        if isolatedSegments.contains(point.segment) || (selectedDate.map { Calendar.current.isDate(point.date, inSameDayAs: $0) } ?? false) {
                            PointMark(x: .value(L("chart.date"), point.date), y: .value(L("today.steps"), steps))
                                .foregroundStyle(accent).symbolSize(65)
                        }
                    }
                }
            }
            .chartYScale(domain: 0...max(Double(goal), activity.points.compactMap(\.steps).max() ?? 0) * 1.15)
            .chartXScale(domain: activity.domain, range: .plotDimension(padding: 0))
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: activity.tickDates) { value in
                    AxisGridLine().foregroundStyle(Color.primary.opacity(0.07))
                    AxisValueLabel(centered: false, anchor: .top, collisionResolution: .disabled, offsetsMarks: false) {
                        if let date = value.as(Date.self) {
                            Text(tickLabel(date))
                                .accessibilityIdentifier("today.trend.tick.\(value.index)")
                        }
                    }
                }
            }
            // Reuse the former legend row's height for the plot, keeping the card's overall height.
            .frame(height: 91)
            .accessibilityIdentifier("today.trend.chart")
            .accessibilityLabel(Text("statistics.chart.accessibility \(stepsText(summary.total)) \(summary.observedDays)"))
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    if period == .day, let plotAnchor = proxy.plotFrame {
                        let plot = geometry[plotAnchor]
                        ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                            if let x = proxy.position(forX: day.date) {
                                let previous = index > 0 ? proxy.position(forX: days[index - 1].date) ?? x : x
                                let next = index + 1 < days.count ? proxy.position(forX: days[index + 1].date) ?? x : x
                                let left = index == 0 ? 0 : (previous + x) / 2
                                let right = index == days.count - 1 ? plot.width : (x + next) / 2
                                Button {
                                    selectionFeedback += 1
                                    onSelectDay(day.date)
                                } label: {
                                    Rectangle().fill(.clear).contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .frame(width: max(0, right - left), height: geometry.size.height)
                                .position(x: plot.minX + (left + right) / 2, y: geometry.size.height / 2)
                                .accessibilityLabel(Text(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide))))
                                .accessibilityValue(Text(stepsText(day.steps)) + Text(" ") + Text("today.steps"))
                                .accessibilityHint(Text("today.chart.select.hint"))
                                .accessibilityAddTraits(selectedDate.map { Calendar.current.isDate(day.date, inSameDayAs: $0) } == true ? .isSelected : [])
                                .accessibilityIdentifier("today.trend.day.\(index)")
                            }
                        }
                    }
                }
            }
            .sensoryFeedback(.selection, trigger: selectionFeedback)
            if days.allSatisfy({ $0.steps == nil }) { Text("chart.no.data").font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(14)
        .background(WalkunoStyle.card(scheme), in: RoundedRectangle(cornerRadius: 23))
    }

    private func tickLabel(_ date: Date) -> String {
        switch period {
        case .day, .week: date.formatted(.dateTime.weekday(.narrow))
        case .month: date.formatted(.dateTime.day())
        case .year: date.formatted(.dateTime.month(.narrow))
        }
    }
}

// Only the carousel observes the drag offset; charts and summaries do not rebuild on every gesture frame.
@MainActor @Observable
private final class CounterPagingState {
    var offset: CGFloat = 0
    var width: CGFloat = 0
    var isSliding = false
}

private struct TodayCounterCarousel<Current: View, Neighbor: View>: View {
    var current: Current
    var previous: Neighbor
    var next: Neighbor
    var paging: CounterPagingState

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                page(previous, position: -1, width: geometry.size.width)
                page(current, position: 0, width: geometry.size.width)
                page(next, position: 1, width: geometry.size.width)
            }
            .offset(x: -geometry.size.width + paging.offset)
            .onChange(of: geometry.size.width, initial: true) { _, width in paging.width = width }
        }
    }

    private func page<Content: View>(_ content: Content, position: CGFloat, width: CGFloat) -> some View {
        let displacement = min(1, max(-1, position + paging.offset / max(width, 1)))
        return content
            .frame(width: width)
            .scaleEffect(1 - abs(displacement) * 0.08)
            .rotation3DEffect(.degrees(Double(displacement) * -20), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
    }
}

/// One interpolated step value drives both the number and the ring, including totals above the goal.
private struct TodayAnimatedCounter: View {
    var steps: Int?
    var goal: Int
    var title: String
    var theme: WalkunoTheme
    var showsRing: Bool
    var replay: String
    var animateEntry: Bool
    var animateUpdates: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedSteps = 0.0
    @State private var sweepPhase = 1.0
    @State private var lastReplay: String?

    init(steps: Int?, goal: Int, title: String, theme: WalkunoTheme, showsRing: Bool, replay: String,
         animateEntry: Bool, animateUpdates: Bool) {
        self.steps = steps
        self.goal = goal
        self.title = title
        self.theme = theme
        self.showsRing = showsRing
        self.replay = replay
        self.animateEntry = animateEntry
        self.animateUpdates = animateUpdates
        _displayedSteps = State(initialValue: animateEntry ? 0 : Double(steps ?? 0))
    }

    private struct Request: Equatable {
        var steps: Int?
        var goal: Int
        var replay: String
        var reduceMotion: Bool
        var animateEntry: Bool
        var animateUpdates: Bool
    }

    var body: some View {
        let animates = !reduceMotion && (lastReplay == nil ? animateEntry : animateUpdates)
        TodayCounterFrame(displayedSteps: animates ? displayedSteps : Double(steps ?? 0), phase: animates ? sweepPhase : 1, hasSteps: steps != nil,
                          goal: goal, title: title, theme: theme, showsRing: showsRing)
            .task(id: Request(steps: steps, goal: goal, replay: replay, reduceMotion: reduceMotion,
                              animateEntry: animateEntry, animateUpdates: animateUpdates)) {
                let shouldReplay = lastReplay != replay
                let animationEnabled = lastReplay == nil ? animateEntry : animateUpdates
                lastReplay = replay
                let target = Double(steps ?? 0)
                guard !reduceMotion, animationEnabled, target > 0 else { snap(to: target); return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    if shouldReplay { displayedSteps = 0 }
                    sweepPhase = 0
                }
                do {
                    try await Task.sleep(for: .milliseconds(40))
                    withAnimation(.easeInOut(duration: shouldReplay ? 2.0 : 1.2)) {
                        displayedSteps = target; sweepPhase = 1
                    }
                } catch { return }
            }
            .onDisappear { snap(to: Double(steps ?? 0)); lastReplay = nil }
    }

    private func snap(to value: Double) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { displayedSteps = value; sweepPhase = 1 }
    }
}

private struct TodayCounterFrame: View, Animatable {
    var displayedSteps: Double
    var phase: Double
    var hasSteps: Bool
    var goal: Int
    var title: String
    var theme: WalkunoTheme
    var showsRing: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var counterSize = 55
    @Environment(\.colorScheme) private var scheme

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(displayedSteps, phase) }
        set { displayedSteps = newValue.first; phase = newValue.second }
    }
    private var progress: Double { goal > 0 ? max(0, displayedSteps) / Double(goal) : 0 }

    var body: some View {
        ZStack {
            if showsRing {
                SparklingRing(progress: progress, phase: phase, accent: theme.tint(for: scheme),
                              secondaryAccent: theme.secondaryTint(for: scheme))
                    .transaction { $0.animation = nil; $0.disablesAnimations = true }.padding(10)
            }
            VStack(spacing: 5) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(theme.tint(for: scheme))
                    .lineLimit(1).minimumScaleFactor(0.7)
                Text(hasSteps ? Int(max(0, displayedSteps).rounded()).formatted() : "—")
                    .font(.system(size: min(counterSize, 82), weight: .bold, design: .rounded)).monospacedDigit()
                    .tracking(-2).minimumScaleFactor(0.4).lineLimit(1)
                    .frame(maxWidth: .infinity)
                Text("today.of \(goal.formatted())").font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    .font(.caption2.weight(.bold)).foregroundStyle(WalkunoStyle.ink)
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(theme.accent, in: Capsule()).padding(.top, 4)
            }.padding(.horizontal, 32)
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
        }
    }
}

/// Interpolating the ring and its trail together keeps every star attached to the moving tip.
private struct SparklingRing: View, Animatable {
    var progress: Double
    var phase: Double
    var accent: Color
    var secondaryAccent: Color

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(progress, phase) }
        set { progress = newValue.first; phase = newValue.second }
    }

    var body: some View {
        ZStack {
            ProgressRing(progress: progress, accent: accent, secondaryAccent: secondaryAccent)
                // The enclosing animatable view already supplies the interpolated progress.
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
            if phase > 0, phase < 1, progress > 0 {
                Canvas { context, size in
                    drawTrail(context: &context, size: size)
                }
                .padding(-40)
            }
        }
    }

    /// One drawing surface for the whole trail; no timer or particle views remain at rest.
    private func drawTrail(context: inout GraphicsContext, size: CGSize) {
        // Leave room outside the stroke so the drawing surface never clips stars or their glow.
        let radius = min(size.width, size.height) / 2 - 40
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let visibility = pow(max(0, sin(.pi * phase)), 0.35)

        for index in 0..<32 {
            let tail = Double(index) / 31
            let fraction = progress - tail * 0.14
            guard fraction > 0 else { continue }
            let angle = fraction * 2 * .pi - .pi / 2
            let drift = index == 0 ? 0 : sin(Double(index) * 2.4 + phase * 8) * (16 + tail * 10)
            let starRadius = radius + drift
            let pulse = sin(phase * 25 + Double(index) * 1.8)
            let twinkle = 0.45 + 0.55 * pulse * pulse
            let length = index == 0 ? 22 : Double(9 + (index * 7) % 8) * (0.6 + 0.4 * twinkle)
            let half = length / 2
            var particle = context
            particle.opacity = visibility * (index == 0 ? 1 : twinkle * (1 - tail * 0.5))
            particle.translateBy(x: center.x + cos(angle) * starRadius,
                                 y: center.y + sin(angle) * starRadius)
            particle.rotate(by: .degrees(phase * 70 + Double(index) * 31))
            particle.addFilter(.shadow(color: accent.opacity(0.85), radius: index == 0 ? 8 : 4))

            var star = Path()
            star.move(to: CGPoint(x: 0, y: -half))
            star.addQuadCurve(to: CGPoint(x: half, y: 0), control: .zero)
            star.addQuadCurve(to: CGPoint(x: 0, y: half), control: .zero)
            star.addQuadCurve(to: CGPoint(x: -half, y: 0), control: .zero)
            star.addQuadCurve(to: CGPoint(x: 0, y: -half), control: .zero)
            star.closeSubpath()
            particle.fill(star, with: .color(index % 3 == 0 ? .white : accent))
        }
    }
}

struct MetricCard: View {
    var title: LocalizedStringKey
    var value: String
    var symbol: String
    var color: Color
    var body: some View {
        WalkunoCard(tint: color) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.title3.weight(.semibold))
                    .frame(width: 38, height: 38)
                    .background(WalkunoStyle.ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                Text(value).font(.system(.title2, design: .rounded, weight: .bold)).lineLimit(1).minimumScaleFactor(0.7)
                Text(title).font(.caption.weight(.medium)).foregroundStyle(WalkunoStyle.ink.opacity(0.88))
            }.frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(WalkunoStyle.ink)
        }.accessibilityElement(children: .combine)
    }
}

private struct DailyRhythmChart: View {
    var date: Date
    var hours: [HourActivity]
    var previousHours: [HourActivity]
    var title: String
    var accent: Color

    private var previousColor: Color { .gray.opacity(0.5) }

    var body: some View {
        let rhythm = DailyRhythmActivity(date: date, hours: hours, previousHours: previousHours)
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { legend(currentHour: rhythm.currentHour) }
                VStack(alignment: .leading, spacing: 6) { legend(currentHour: rhythm.currentHour) }
            }
            .font(.caption).foregroundStyle(.secondary)
            VStack(spacing: 4) {
                Chart {
                    ForEach(rhythm.hours) { hour in
                        if let steps = hour.steps {
                            RectangleMark(xStart: .value(L("chart.hour"), Double(hour.hour) + 0.54),
                                          xEnd: .value(L("chart.hour"), Double(hour.hour) + 0.92),
                                          yStart: .value(L("today.steps"), 0),
                                          yEnd: .value(L("today.steps"), steps))
                                .foregroundStyle(accent.gradient).cornerRadius(2)
                                .accessibilityLabel(Text("\(title), \(hour.hour.formatted()) \(L("chart.hour"))"))
                                .accessibilityValue(Text("\(steps.formatted()) \(L("today.steps"))"))
                        }
                        if let steps = hour.previousSteps {
                            RectangleMark(xStart: .value(L("chart.hour"), Double(hour.hour) + 0.08),
                                          xEnd: .value(L("chart.hour"), Double(hour.hour) + 0.46),
                                          yStart: .value(L("today.steps"), 0),
                                          yEnd: .value(L("today.steps"), steps))
                                .foregroundStyle(previousColor).cornerRadius(2)
                                .accessibilityLabel(Text("\(L("today.rhythm.previous")), \(hour.hour.formatted()) \(L("chart.hour"))"))
                                .accessibilityValue(Text("\(steps.formatted()) \(L("today.steps"))"))
                        }
                    }
                    if let currentHour = rhythm.currentHour {
                        RuleMark(x: .value(L("today.rhythm.now"), currentHour))
                            .foregroundStyle(accent.opacity(0.65))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .accessibilityLabel(Text("today.rhythm.now"))
                    }
                }
                .chartXScale(domain: 0.0...24.0, range: .plotDimension(padding: 0))
                .chartYScale(domain: .automatic(includesZero: true))
                .chartLegend(.hidden)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 110)
                .accessibilityLabel(Text("today.rhythm.accessibility"))
                .accessibilityIdentifier("today.rhythm.chart")
                HStack(spacing: 0) {
                    ForEach(0..<24, id: \.self) { hour in
                        VStack(spacing: 3) {
                            Rectangle().fill(.secondary.opacity(0.35)).frame(width: 1, height: 3)
                            Text(hour.formatted()).font(.system(size: 9)).monospacedDigit()
                                .accessibilityIdentifier("today.rhythm.hour.\(hour)")
                        }.frame(maxWidth: .infinity)
                    }
                }.foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private func legend(currentHour: Double?) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(accent).frame(width: 8, height: 8)
            Text(title)
        }
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(previousColor).frame(width: 8, height: 8)
            Text("today.rhythm.previous")
                .accessibilityIdentifier("today.rhythm.previous")
        }
        if currentHour != nil {
            Label("today.rhythm.now", systemImage: "clock")
                .accessibilityIdentifier("today.rhythm.now")
        }
    }
}

struct HourlyChart: View {
    var hours: [HourActivity]
    var accent: Color
    var body: some View {
        Chart(hours) { hour in
            if let steps = hour.steps {
                BarMark(x: .value(L("chart.hour"), hour.date, unit: .hour), y: .value(L("today.steps"), steps))
                    .foregroundStyle(accent.gradient).cornerRadius(3)
            }
        }
        .chartXAxis { AxisMarks(values: .stride(by: .hour, count: 6)) { _ in AxisValueLabel(format: .dateTime.hour(.defaultDigits(amPM: .omitted))); AxisTick() } }
        .chartYAxis(.hidden)
        .accessibilityLabel(Text("chart.hourly"))
    }
}

struct HealthEmptyView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("health.empty.title", systemImage: "heart.text.clipboard").font(.headline)
                if model.preferences.healthRequested {
                    Text("health.empty.connected.body").font(.subheadline).foregroundStyle(.secondary)
                } else {
                    Text("health.empty.body").font(.subheadline).foregroundStyle(.secondary)
                    Button("health.connect") { Task { await model.connectHealth() } }
                        .buttonStyle(.borderedProminent).tint(model.effectiveTheme.accent).foregroundStyle(WalkunoStyle.ink)
                    Text("health.permissions.path").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
