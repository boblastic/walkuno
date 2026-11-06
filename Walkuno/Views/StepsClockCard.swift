import SwiftUI

struct StepsClockCard: View {
    var snapshot: ActivityClockSnapshot
    var loading: Bool
    var failed: Bool
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { model.effectiveTheme.tint(for: scheme) }
    private var baseline: Color { model.effectiveTheme.secondaryTint(for: scheme) }
    private var metric: ActivityMetric { snapshot.metric }
    private var distance: String {
        let value = model.today.meters.map {
            model.preferences.unit.convert(meters: $0).formatted(.number.precision(.fractionLength(1)))
        } ?? "—"
        return "\(value) \(model.preferences.unit.symbol)"
    }

    var body: some View {
        WalkunoCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("insights.clock.title").font(.subheadline.weight(.semibold))
                            .lineLimit(2).minimumScaleFactor(0.8)
                            .accessibilityIdentifier("insights.clock.title")
                            .accessibilityValue(Text(L(metric.titleKey)))
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    totals(snapshot)
                }
                StepClockDial(snapshot: snapshot, unit: model.preferences.unit,
                              detail: metric == .steps ? distance : metric.clockUnit(model.preferences.unit), theme: model.effectiveTheme,
                              counterStyle: model.effectiveCounter, effect: model.effectiveEffect)
                    .accessibilityIdentifier("insights.clock.chart")

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        progressStatus(snapshot)
                        Spacer(minLength: 8)
                        goalLabel
                    }
                    VStack(alignment: .trailing, spacing: 8) {
                        progressStatus(snapshot).frame(maxWidth: .infinity, alignment: .leading)
                        goalLabel
                    }
                }
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
                if failed {
                    Text("health.refresh.error").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var goalLabel: some View {
        Text("goals.target \(metric.clockText(snapshot.goal, unit: model.preferences.unit))")
            .font(.caption).foregroundStyle(.secondary).fixedSize()
            .accessibilityIdentifier("insights.clock.goal")
    }

    private func legend(title: String, color: Color, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            Path { path in
                path.move(to: CGPoint(x: 0, y: 3)); path.addLine(to: CGPoint(x: 12, y: 3))
            }.stroke(color, style: StrokeStyle(lineWidth: dashed ? 2 : 3, lineCap: .round, dash: dashed ? [4, 3] : []))
                .frame(width: 12, height: 6).accessibilityHidden(true)
            Text(L(title)).font(.caption2.weight(.medium))
                .lineLimit(1).minimumScaleFactor(0.7)
        }
    }

    private func totals(_ snapshot: ActivityClockSnapshot) -> some View {
        Group {
            total(title: "insights.today", value: snapshot.current, color: accent, dashed: false, id: "today")
            total(title: "insights.usual", value: snapshot.usual, color: baseline, dashed: true, id: "usual")
        }
    }

    private func total(title: String, value: Double?, color: Color, dashed: Bool, id: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            legend(title: title, color: color, dashed: dashed)
            Text(metric.text(value, unit: model.preferences.unit))
                .font(.system(.subheadline, design: .rounded, weight: .bold)).monospacedDigit()
                .contentTransition(.numericText()).lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(color)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("insights.clock." + id)
    }

    private func gapLabel(_ difference: Double) -> String {
        guard metric.clockNumber(abs(difference), unit: model.preferences.unit) != metric.clockNumber(0, unit: model.preferences.unit) else { return L("insights.clock.same") }
        let key = difference > 0 ? "insights.clock.more %@" : "insights.clock.less %@"
        return String(format: L(key), metric.clockText(abs(difference), unit: model.preferences.unit))
    }

    @ViewBuilder private func progressStatus(_ snapshot: ActivityClockSnapshot) -> some View {
        if let difference = snapshot.difference {
            Text(snapshot.change.map {
                $0.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always(includingZero: false)))
                    + " " + L("insights.today")
            } ?? gapLabel(difference))
            .font(.subheadline.weight(.medium)).foregroundStyle(accent)
            .monospacedDigit().fixedSize(horizontal: true, vertical: false)
            .accessibilityLabel(Text(gapLabel(difference)))
            .accessibilityValue(Text(snapshot.change.map {
                $0.formatted(.percent.precision(.fractionLength(0)).sign(strategy: .always(includingZero: false)))
            } ?? ""))
            .accessibilityIdentifier("insights.clock.difference")
        } else if loading {
            ProgressView().controlSize(.mini)
        }
    }
}

private struct StepClockDial: View {
    let snapshot: ActivityClockSnapshot
    let unit: DistanceUnit
    let detail: String
    let theme: WalkunoTheme
    let counterStyle: CounterStyle
    let effect: CounterEffect
    @Environment(\.colorScheme) private var scheme
    private var accent: Color { theme.tint(for: scheme) }
    private var baseline: Color { theme.secondaryTint(for: scheme) }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size.width
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size * 0.23
            let inner = radius + 16
            let outer = size / 2 - 22
            let referenceRadius = radius - 11
            ZStack {
                Circle().stroke(Color.primary.opacity(0.07), lineWidth: 1)
                    .frame(width: inner * 2, height: inner * 2)
                Circle().stroke(Color.primary.opacity(0.07), lineWidth: 1)
                    .frame(width: outer * 2, height: outer * 2)
                ForEach(snapshot.hours) { hour in
                    let angle = (Double(hour.hour) + 0.5) / 24 * 2 * .pi - .pi / 2
                    if let value = hour.value, value > 0 {
                        Path { path in
                            path.move(to: point(center, angle: angle, radius: inner))
                            path.addLine(to: point(center, angle: angle,
                                                   radius: inner + (outer - inner) * value / snapshot.hourlyMaximum))
                        }.stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    }
                    Circle().fill(Color.secondary.opacity(hour.hasElapsed ? 0.55 : 0.15))
                        .frame(width: 2.5, height: 2.5)
                        .position(point(center, angle: angle, radius: outer + 4))
                }
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text(String(format: "%02d", hour)).font(.caption2).foregroundStyle(.secondary)
                        .position(point(center, angle: Double(hour) / 24 * 2 * .pi - .pi / 2, radius: outer + 13))
                }
                AnimatedCounterRing(value: snapshot.current, goal: snapshot.goal, theme: theme,
                                    counterStyle: counterStyle, effect: effect)
                    .frame(width: radius * 2, height: radius * 2)
                Circle().stroke(Color.primary.opacity(0.06), lineWidth: 2)
                    .frame(width: referenceRadius * 2, height: referenceRadius * 2)
                if let progress = snapshot.usualProgress {
                    Circle().trim(from: 0, to: min(1, progress))
                        .stroke(baseline, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [3, 5]))
                        .rotationEffect(.degrees(-90))
                        .frame(width: referenceRadius * 2, height: referenceRadius * 2)
                    Circle().fill(baseline).frame(width: 6, height: 6)
                        .position(point(center, angle: min(1, progress) * 2 * .pi - .pi / 2, radius: referenceRadius))
                }
                VStack(spacing: 3) {
                    Text(snapshot.metric.clockNumber(snapshot.current, unit: unit))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
                        .accessibilityIdentifier("insights.clock.total")
                    Text(detail)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.6)
                    if let progress = snapshot.progress {
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .font(.system(size: 12, weight: .semibold)).monospacedDigit()
                    }
                }.frame(width: max(40, (referenceRadius - 7) * 2))
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("insights.clock.title"))
        .accessibilityValue(Text(accessibilitySummary + ", " + detail))
        .accessibilityChildren {
            ForEach(snapshot.hours.filter { $0.value != nil }) { hour in
                Text("\(String(format: "%02d:00", hour.hour))–\(String(format: "%02d:00", hour.hour + 1))")
                    .accessibilityValue(Text(snapshot.metric.clockText(hour.value, unit: unit)))
            }
        }
    }

    private var accessibilitySummary: String {
        let current = snapshot.metric.clockText(snapshot.current, unit: unit)
        let usual = snapshot.metric.clockText(snapshot.usual, unit: unit)
        return String(format: L("insights.clock.summary %@ %@"), current, usual)
    }

    private func point(_ center: CGPoint, angle: Double, radius: Double) -> CGPoint {
        CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}
