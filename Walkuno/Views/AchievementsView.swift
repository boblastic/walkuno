import SwiftUI

struct AchievementsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showPremium = false
    @State private var showShare = false
    @State private var showAllJourneys = false
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private var columns: [GridItem] { Array(repeating: GridItem(.flexible(), alignment: .top), count: typeSize.isAccessibilitySize ? 1 : 2) }

    var body: some View {
        let summary = AchievementSummary(days: model.days, goals: model.preferences.goals)
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("achievements.subtitle").font(.subheadline).foregroundStyle(.secondary)
                records(summary)
                goals(summary)
                streaks(summary)
                journeys(summary)
                WalkunoCard {
                    VStack(spacing: 16) {
                        LabeledContent("achievements.total", value: stepsText(summary.totalSteps))
                        if model.purchases.isPremium {
                            LabeledContent("achievements.week", value: stepsText(bestTotal(component: .weekOfYear)))
                            LabeledContent("achievements.month", value: stepsText(bestTotal(component: .month)))
                        } else {
                            Button { showPremium = true } label: { Label("achievements.advanced", systemImage: "sparkles") }
                        }
                    }.font(.subheadline)
                }
                Text("achievements.scope").font(.caption).foregroundStyle(.secondary)
                Button { showShare = true } label: {
                    Label("share.title", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }.buttonStyle(.bordered).disabled(summary.record(for: .steps) == nil)
            }.padding(24)
        }
        .background(WalkunoStyle.background(scheme))
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showPremium) { PremiumView() }
        .sheet(isPresented: $showShare) { ShareCardView(initialScope: .record) }
    }

    private func records(_ summary: AchievementSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("trophies.records", subtitle: "trophies.records.note", symbol: "trophy.fill")
            WalkunoCard {
                VStack(spacing: 20) {
                    record(.steps, summary: summary, prominent: true)
                    Divider()
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 22) {
                        ForEach([ActivityMetric.energy, .distance, .exerciseTime, .floors]) { metric in
                            record(metric, summary: summary)
                        }
                    }
                }
            }
        }
    }

    private func record(_ metric: ActivityMetric, summary: AchievementSummary, prominent: Bool = false) -> some View {
        let day = summary.record(for: metric)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: recordSymbol(metric)).font(.system(size: prominent ? 25 : 18, weight: .semibold))
                    .foregroundStyle(accent).frame(width: prominent ? 54 : 38, height: prominent ? 54 : 38)
                    .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: prominent ? 18 : 13))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L(metric.titleKey)).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    Text(metric.text(day.flatMap { metric.value(in: $0) }, unit: model.preferences.unit))
                        .font(.system(prominent ? .largeTitle : .headline, design: .rounded, weight: .bold))
                        .minimumScaleFactor(0.7).lineLimit(1)
                }
            }
            Text(day.map { $0.date.formatted(date: .abbreviated, time: .omitted) } ?? L("chart.no.data"))
                .font(.caption2).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine).accessibilityIdentifier("trophies.record.\(metric.rawValue)")
    }

    private func goals(_ summary: AchievementSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("trophies.goals", subtitle: "trophies.goals.note", symbol: "target")
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(summary.dailyGoals) { goal in
                    TrophyProgressCard(
                        title: L("trophies.goal.\(goal.multiplier)"),
                        symbol: ["target", "bolt.fill", "bolt.shield.fill"][goal.multiplier - 1],
                        rank: goal.multiplier, count: goal.count, progress: goal.progress,
                        detail: String(format: L("trophies.steps.progress"), stepsText(goal.steps), stepsText(goal.target)),
                        context: L("insights.today"), accent: accent, available: goal.steps != nil
                    ).accessibilityIdentifier("trophies.goal.\(goal.multiplier)")
                }
                ForEach(summary.perfectPeriods) { period in
                    TrophyProgressCard(
                        title: L("trophies.perfect.\(period.id)"),
                        symbol: period.period == .week ? "calendar.badge.checkmark" : period.period == .month ? "star.circle.fill" : "crown.fill",
                        rank: period.period == .week ? 1 : period.period == .month ? 2 : 3,
                        count: period.count, progress: period.progress,
                        detail: String(format: L("trophies.days.progress"), period.achievedDays, period.requiredDays),
                        context: L("trophies.current.\(period.id)"), accent: accent,
                        note: period.canComplete ? L("trophies.perfect.possible") : String(format: L("trophies.perfect.restart"), period.nextStart.formatted(date: .abbreviated, time: .omitted))
                    ).accessibilityIdentifier("trophies.perfect.\(period.id)")
                }
            }
        }
    }

    private func streaks(_ summary: AchievementSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("trophies.streaks", subtitle: "trophies.streaks.note", symbol: "flame.fill")
            WalkunoCard {
                HStack(alignment: .top, spacing: 16) {
                    streakValue("trophies.streak.current", count: summary.currentStreak)
                    Divider()
                    streakValue("achievements.streak", count: summary.longestStreak)
                }.fixedSize(horizontal: false, vertical: true)
            }
            ForEach(summary.streaks) { streak in
                WalkunoCard {
                    HStack(spacing: 18) {
                        TrophyMedallion(symbol: "flame.fill", rank: streak.target == 7 ? 1 : streak.target == 15 ? 2 : 3,
                                        unlocked: streak.firstReached != nil, accent: accent).frame(width: 66, height: 76)
                        VStack(alignment: .leading, spacing: 9) {
                            Text(String(format: L("trophies.streak.title"), streak.target)).font(.headline)
                            if let date = streak.firstReached {
                                Label(String(format: L("trophies.earned"), date.formatted(date: .abbreviated, time: .omitted)), systemImage: "checkmark.seal.fill")
                                    .font(.caption).foregroundStyle(accent)
                            } else {
                                Text(String(format: L("trophies.days.progress"), min(streak.current, streak.target), streak.target))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            TrophyProgressBar(progress: streak.progress, accent: accent)
                        }
                    }
                }.accessibilityElement(children: .combine).accessibilityIdentifier("trophies.streak.\(streak.target)")
            }
        }
    }

    private func journeys(_ summary: AchievementSummary) -> some View {
        let catalog = DistanceTrophy.catalog
        let next = catalog.first { $0.progress(totalMeters: summary.totalMeters).completed == 0 }
        let previewIDs = Set(catalog.prefix(3).map(\.id) + [next?.id].compactMap { $0 })
        let visible = showAllJourneys ? catalog : catalog.filter { previewIDs.contains($0.id) }
        return VStack(alignment: .leading, spacing: 14) {
            sectionTitle("trophies.journeys", subtitle: "trophies.journeys.note", symbol: "map.fill")
            WalkunoCard {
                HStack(spacing: 14) {
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath").font(.title).foregroundStyle(accent)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 5) {
                        Text("trophies.distance.total").font(.caption).foregroundStyle(.secondary)
                        Text(distanceText(summary.totalMeters, unit: model.preferences.unit))
                            .font(.system(.title2, design: .rounded, weight: .bold))
                    }
                    Spacer(minLength: 0)
                }
            }
            ForEach(visible) { trophy in
                JourneyTrophyCard(trophy: trophy, totalMeters: summary.totalMeters, unit: model.preferences.unit,
                                  accent: accent, isNext: trophy.id == next?.id)
            }
            Button { showAllJourneys.toggle() } label: {
                HStack {
                    Text(showAllJourneys ? L("trophies.collection.less") : String(format: L("trophies.collection.all"), catalog.count))
                    Spacer()
                    Image(systemName: showAllJourneys ? "chevron.up" : "chevron.down")
                }.font(.subheadline.weight(.semibold)).padding(.vertical, 10)
            }.accessibilityIdentifier("trophies.collection")
            Text("trophies.journeys.scope").font(.caption).foregroundStyle(.secondary)
        }
    }

    private func streakValue(_ title: String, count: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(L(title)).font(.caption).foregroundStyle(.secondary)
            Text(String(format: L("trophies.days"), count)).font(.system(.title3, design: .rounded, weight: .bold))
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionTitle(_ title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(L(title), systemImage: symbol).font(.title3.bold())
                .accessibilityAddTraits(.isHeader).accessibilityIdentifier(title)
            Text(L(subtitle)).font(.caption).foregroundStyle(.secondary)
        }
    }

    private func bestTotal(component: Calendar.Component) -> Int? {
        Dictionary(grouping: model.days.filter { $0.date <= .now }, by: { Calendar.current.dateInterval(of: component, for: $0.date)!.start })
            .values.compactMap { ActivitySummary(days: $0, goals: model.preferences.goals).total }.max()
    }

    private func recordSymbol(_ metric: ActivityMetric) -> String {
        switch metric {
        case .steps: "shoeprints.fill"
        case .energy: "flame.fill"
        case .distance: "point.topleft.down.to.point.bottomright.curvepath"
        case .exerciseTime: "stopwatch.fill"
        case .floors: "figure.stairs"
        }
    }
}

private struct TrophyProgressCard: View {
    var title: String
    var symbol: String
    var rank: Int
    var count: Int
    var progress: Double
    var detail: String
    var context: String
    var accent: Color
    var available = true
    var note: String? = nil
    var body: some View {
        WalkunoCard {
            VStack(spacing: 12) {
                TrophyMedallion(symbol: symbol, rank: rank, unlocked: count > 0, accent: accent)
                    .frame(width: 78, height: 90)
                Text(title).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                    .frame(minHeight: 38, alignment: .top)
                Text(String(format: L("trophies.times"), count)).font(.system(.headline, design: .rounded))
                    .foregroundStyle(count > 0 ? accent : .secondary)
                VStack(alignment: .leading, spacing: 7) {
                    Text(context).font(.caption2).foregroundStyle(.secondary)
                    TrophyProgressBar(progress: progress, accent: accent)
                    Text(detail).font(.caption2.weight(.medium)).monospacedDigit()
                    if !available { Text("chart.no.data").font(.caption2).foregroundStyle(.secondary) }
                    if let note { Text(note).font(.caption2).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true) }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity)
        }.accessibilityElement(children: .combine)
    }
}

private struct TrophyMedallion: View {
    @Environment(\.colorScheme) private var scheme
    var symbol: String
    var rank: Int
    var unlocked: Bool
    var accent: Color
    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            ZStack(alignment: .top) {
                HStack(spacing: 3) {
                    UnevenRoundedRectangle(bottomLeadingRadius: 4, bottomTrailingRadius: 2).rotationEffect(.degrees(16))
                    UnevenRoundedRectangle(bottomLeadingRadius: 2, bottomTrailingRadius: 4).rotationEffect(.degrees(-16))
                }.foregroundStyle(accent.opacity(unlocked ? 0.8 : 0.14))
                    .frame(width: side * 0.48, height: side * 0.5).offset(y: side * 0.61)
                Circle().fill(WalkunoStyle.card(scheme))
                    .overlay(Circle().fill(LinearGradient(colors: [accent.opacity(unlocked ? 0.3 : 0.08), accent.opacity(unlocked ? 0.1 : 0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                    .overlay(Circle().strokeBorder(accent.opacity(unlocked ? 0.65 : 0.2), lineWidth: 2))
                    .overlay(Circle().strokeBorder(accent.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: unlocked ? [] : [2, 4])).padding(6))
                    .overlay {
                        VStack(spacing: 5) {
                            Image(systemName: symbol).font(.system(size: side * 0.32, weight: .semibold))
                            HStack(spacing: 3) {
                                ForEach(0..<rank, id: \.self) { _ in Image(systemName: "star.fill").font(.system(size: side * 0.075)) }
                            }
                        }.foregroundStyle(unlocked ? accent : .secondary)
                    }.frame(width: side, height: side)
            }
        }.accessibilityHidden(true)
    }
}

private struct TrophyProgressBar: View {
    var progress: Double
    var accent: Color
    var body: some View {
        ProgressView(value: min(1, max(0, progress))).tint(accent)
            .accessibilityLabel(Text("trophies.progress"))
            .accessibilityValue(Text(min(1, max(0, progress)).formatted(.percent.precision(.fractionLength(0)))))
    }
}

private struct JourneyTrophyCard: View {
    var trophy: DistanceTrophy
    var totalMeters: Double?
    var unit: DistanceUnit
    var accent: Color
    var isNext: Bool
    var body: some View {
        let progress = trophy.progress(totalMeters: totalMeters)
        WalkunoCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    JourneyArtwork(trophy: trophy, accent: accent, unlocked: progress.completed > 0).frame(width: 64, height: 72)
                    VStack(alignment: .leading, spacing: 5) {
                        if isNext { Text("trophies.journey.next").font(.caption2.weight(.bold)).foregroundStyle(accent) }
                        Text(L(trophy.titleKey)).font(.headline)
                        Text(journeyDistance(trophy.meters)).font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    if progress.completed > 0 {
                        Text("×\(progress.completed.formatted())").font(.system(.subheadline, design: .rounded, weight: .bold))
                            .padding(.horizontal, 9).padding(.vertical, 6).background(accent.opacity(0.12), in: Capsule())
                            .foregroundStyle(accent)
                            .accessibilityLabel(Text(String(format: L("trophies.times"), progress.completed)))
                    }
                }
                TrophyProgressBar(progress: progress.fraction, accent: accent)
                HStack(alignment: .firstTextBaseline) {
                    Text(String(format: L("trophies.distance.progress"), progress.cycleMeters.map(journeyDistance) ?? "—", journeyDistance(trophy.meters))).monospacedDigit()
                    Spacer(minLength: 8)
                    if progress.completed > 0 { Text("trophies.journey.again").foregroundStyle(.secondary) }
                }.font(.caption2)
            }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("trophies.journey.\(trophy.id)")
    }

    private func journeyDistance(_ meters: Double) -> String {
        if unit == .kilometers && meters < 1_000 { return meters.formatted(.number.precision(.fractionLength(0))) + " m" }
        let precision = meters < 100_000 ? 0...3 : 0...1
        return unit.convert(meters: meters).formatted(.number.precision(.fractionLength(precision))) + " " + unit.symbol
    }
}

/// A small illustrated stamp: a route through hills, an orbit, or a city horizon.
private struct JourneyArtwork: View {
    var trophy: DistanceTrophy
    var accent: Color
    var unlocked: Bool
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(accent.opacity(unlocked ? 0.14 : 0.06))
            if trophy.id == "goldenGate" {
                Path { path in
                    path.move(to: CGPoint(x: 5, y: 44)); path.addLine(to: CGPoint(x: 59, y: 44))
                    for x: CGFloat in [18, 46] {
                        path.move(to: CGPoint(x: x, y: 19)); path.addLine(to: CGPoint(x: x, y: 53))
                    }
                    path.move(to: CGPoint(x: 5, y: 37)); path.addLine(to: CGPoint(x: 18, y: 23))
                    path.addQuadCurve(to: CGPoint(x: 46, y: 23), control: CGPoint(x: 32, y: 53))
                    path.addLine(to: CGPoint(x: 59, y: 37))
                    for x: CGFloat in [24, 32, 40] {
                        path.move(to: CGPoint(x: x, y: x == 32 ? 37 : 33)); path.addLine(to: CGPoint(x: x, y: 44))
                    }
                }.stroke(accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            } else if trophy.landscape == .space {
                Ellipse().stroke(accent.opacity(0.25), lineWidth: 1).frame(width: 57, height: 28).rotationEffect(.degrees(-30))
                Image(systemName: "sparkle").font(.system(size: 8)).offset(x: 18, y: -23)
            } else if trophy.landscape == .world {
                Circle().strokeBorder(accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [2, 3])).padding(5)
            } else {
                Path { path in
                    path.move(to: CGPoint(x: 5, y: 55))
                    path.addQuadCurve(to: CGPoint(x: 59, y: 55), control: CGPoint(x: 32, y: 30))
                    path.move(to: CGPoint(x: 17, y: 63))
                    path.addQuadCurve(to: CGPoint(x: 47, y: 59), control: CGPoint(x: 42, y: 42))
                }.stroke(accent.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            }
            if trophy.id != "goldenGate" {
                Image(systemName: trophy.symbol).font(.system(size: 28, weight: .medium)).offset(y: -5)
            }
        }.foregroundStyle(accent).accessibilityHidden(true)
    }
}
