import SwiftUI

extension CounterStyle {
    var titleKey: String { "counter.\(rawValue)" }
    var descriptionKey: String { "counter.\(rawValue).description" }
    var symbol: String {
        switch self {
        case .ring: "circle.dotted.circle"
        case .horizon: "sun.horizon"
        case .path: "point.topleft.down.to.point.bottomright.curvepath"
        case .milestones: "chart.bar.fill"
        case .minimal: "textformat.123"
        }
    }
}

/// All five designs use the same interpolated value, semantic palette and layout
/// in the dashboard and settings preview. The finite particle trail fades after the value settles.
struct StepCounterFace: View {
    var displayedSteps: Double
    var trail: CounterTrailFrame? = nil
    var hasSteps: Bool
    var goal: Int
    var title: String
    var theme: WalkunoTheme
    var style: CounterStyle
    var effect: CounterEffect = .stars
    @ScaledMetric(relativeTo: .largeTitle) private var counterSize = 55
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var progress: CounterProgress { .init(steps: hasSteps ? displayedSteps : 0, goal: goal) }
    private var accent: Color { theme.tint(for: scheme) }
    private var secondary: Color { theme.secondaryTint(for: scheme) }
    private var gradient: LinearGradient {
        LinearGradient(colors: [secondary, accent], startPoint: .leading, endPoint: .trailing)
    }
    private var overflow: Color {
        progress.overflowLap.truncatingRemainder(dividingBy: 2) == 1 ? .white.opacity(0.88) : WalkunoStyle.ink.opacity(0.85)
    }
    private var number: String { hasSteps ? Int(max(0, displayedSteps).rounded()).formatted() : "—" }

    var body: some View {
        GeometryReader { geometry in
            let width = style == .ring ? min(geometry.size.width, typeSize.isAccessibilitySize ? 280 : 232) : min(geometry.size.width - 12, 340)
            Group {
                switch style {
                case .ring: ring
                case .horizon: horizon
                case .path: path
                case .milestones: milestones
                case .minimal: typographic
                }
            }
            .frame(width: max(0, width), height: geometry.size.height)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        // Playback supplies a complete frame; nested views must not interpolate again.
        .transaction { $0.animation = nil; $0.disablesAnimations = true }
    }

    private var heading: some View {
        Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(accent)
            .lineLimit(1).minimumScaleFactor(0.65)
    }

    private func count(size: CGFloat, alignment: Alignment = .center) -> some View {
        Text(number)
            .font(.system(size: min(counterSize * size / 55, typeSize.isAccessibilitySize ? 92 : size), weight: .bold, design: .rounded))
            .monospacedDigit().tracking(-2.5).lineLimit(1).minimumScaleFactor(0.35)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    private var objective: some View {
        Text("today.of \(goal.formatted())")
            .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
    }

    private var percentage: some View {
        HStack(spacing: 4) {
            if hasSteps, progress.ratio >= 1 { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
            Text(hasSteps ? progress.ratio.formatted(.percent.precision(.fractionLength(0))) : "—")
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
        }
        .font(.caption2.weight(.bold)).foregroundStyle(WalkunoStyle.ink)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(theme.accent, in: Capsule())
        .fixedSize(horizontal: false, vertical: true)
    }

    private var remaining: some View {
        Group {
            if !hasSteps { Text("chart.no.data") }
            else if progress.ratio > 1 { Text("counter.extra \(Int(max(0, displayedSteps - Double(goal))).formatted())") }
            else if progress.ratio == 1 { Text("counter.complete") }
            else { Text("counter.remaining \(Int(max(0, Double(goal) - displayedSteps)).formatted())") }
        }
        .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
    }

    private var ring: some View {
        ZStack {
            SparklingRing(progress: progress, trail: trail, effect: effect, accent: accent, secondaryAccent: secondary,
                          starAccent: theme.accent, starSecondary: theme.secondaryAccent)
                .padding(18)
            VStack(spacing: 5) {
                heading
                count(size: 55)
                objective
                percentage.padding(.top, 4)
            }.padding(.horizontal, 32)
        }
        .frame(width: typeSize.isAccessibilitySize ? 280 : 232, height: typeSize.isAccessibilitySize ? 280 : 232)
    }

    private var horizon: some View {
        GeometryReader { geometry in
            let radius = min(geometry.size.width * 0.43, geometry.size.height * 0.46)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height * 0.56)
            let arc = CounterArc(center: center, radius: radius)
            ZStack {
                arc.stroke(accent.opacity(0.12), style: StrokeStyle(lineWidth: 17, lineCap: .round))
                arc.trim(from: 0, to: progress.fraction)
                    .stroke(gradient, style: StrokeStyle(lineWidth: 17, lineCap: .round))
                    .shadow(color: accent.opacity(0.22), radius: 9, y: 2)
                    .opacity(progress.fraction > 0 ? 1 : 0)
                if progress.ratio > 1 {
                    arc.trim(from: 0, to: progress.overflowFraction)
                        .stroke(overflow, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
                Canvas { context, _ in
                    for index in 0...40 {
                        let angle = (150 + Double(index) * 6) * .pi / 180
                        let major = index.isMultiple(of: 5)
                        let start = radius - 17
                        let end = start - (major ? 7.0 : 3.0)
                        var tick = Path()
                        tick.move(to: CGPoint(x: center.x + cos(angle) * start, y: center.y + sin(angle) * start))
                        tick.addLine(to: CGPoint(x: center.x + cos(angle) * end, y: center.y + sin(angle) * end))
                        context.stroke(tick, with: .color(accent.opacity(major ? 0.42 : 0.15)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    }
                }
                starlight { fraction in
                    let angle = (150 + fraction * 240) * .pi / 180
                    return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                }
                VStack(spacing: 4) {
                    heading
                    count(size: 58)
                    objective
                }
                .frame(width: radius * 1.48)
                .position(x: center.x, y: center.y + 2)
                percentage.position(x: center.x, y: geometry.size.height - 19)
            }
        }
        .accessibilityHidden(true)
    }

    private var path: some View {
        VStack(spacing: 5) {
            heading
            count(size: 64)
            objective
            CounterRoute(progress: progress, accent: accent, secondary: secondary, overflow: overflow, trail: trail, effect: effect,
                         starAccent: theme.accent, starSecondary: theme.secondaryAccent)
                .frame(height: typeSize.isAccessibilitySize ? 90 : 76)
                .padding(.top, 8)
            HStack { remaining; Spacer(minLength: 8); percentage }
                .padding(.horizontal, 4)
        }
        .frame(maxHeight: .infinity)
    }

    private var milestones: some View {
        VStack(spacing: 5) {
            heading
            count(size: 64)
            objective
            GeometryReader { geometry in
                let gap: CGFloat = 7
                let width = max(1, (geometry.size.width - gap * 9) / 10)
                ZStack {
                    HStack(alignment: .bottom, spacing: gap) {
                        ForEach(0..<10) { index in
                            let height = geometry.size.height * (0.40 + Double(index) / 15)
                            let fill = progress.segmentFill(index)
                            let extra = progress.segmentFill(index, overflow: true)
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 5).fill(accent.opacity(0.12))
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(LinearGradient(colors: [secondary, accent], startPoint: .bottom, endPoint: .top))
                                    .frame(height: height * fill)
                                    .opacity(fill > 0 ? 1 : 0)
                                if progress.ratio > 1 {
                                    Capsule().fill(overflow).frame(width: 3, height: max(0, height - 12) * extra)
                                        .padding(.bottom, 6).opacity(extra > 0 ? 1 : 0)
                                }
                            }
                            .frame(width: width, height: height)
                        }
                    }
                    .frame(height: geometry.size.height, alignment: .bottom)
                    starlight { fraction in
                        // Follow the skyline continuously, with room for the star at both ends.
                        CGPoint(x: width / 2 + (geometry.size.width - width) * fraction,
                                y: geometry.size.height * (0.60 - 0.60 * fraction) - 6)
                    }
                }
            }
            .frame(height: typeSize.isAccessibilitySize ? 80 : 60)
            .padding(.top, 22).padding(.bottom, 7)
            HStack(spacing: 8) {
                if hasSteps, let next = progress.nextMilestone(goal: goal) {
                    Text("counter.next \(next.formatted())").font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                } else { remaining }
                Spacer(minLength: 0)
                percentage
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var typographic: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { heading; Spacer(minLength: 8); percentage }
            count(size: 86, alignment: .leading)
                .padding(.top, 3)
            objective
            GeometryReader { geometry in
                let trackWidth = max(0, geometry.size.width - 28)
                ZStack(alignment: .leading) {
                    Capsule().fill(accent.opacity(0.12))
                    Capsule().fill(gradient).frame(width: trackWidth * progress.fraction)
                        .shadow(color: accent.opacity(0.18), radius: 7)
                    if progress.ratio > 1 {
                        Capsule().fill(overflow).frame(width: max(0, trackWidth - 8) * progress.overflowFraction, height: 3)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.horizontal, 14)
                starlight { fraction in
                    CGPoint(x: 14 + trackWidth * fraction, y: geometry.size.height / 2)
                }
            }
            .frame(height: 9).padding(.top, 22).padding(.bottom, 10)
            remaining.padding(.top, 4)
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, 8)
    }

    private func starlight(pointAt: @escaping (Double) -> CGPoint) -> some View {
        CounterStarlight(trail: trail, effect: effect,
                         accent: theme.accent, secondary: theme.secondaryAccent,
                         pointAt: pointAt)
    }
}

private struct CounterArc: Shape {
    var center: CGPoint
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: center, radius: radius, startAngle: .degrees(150), endAngle: .degrees(390), clockwise: false)
        return path
    }
}

private struct CounterRoute: View {
    var progress: CounterProgress
    var accent: Color
    var secondary: Color
    var overflow: Color
    var trail: CounterTrailFrame? = nil
    var effect: CounterEffect = .stars
    var starAccent: Color
    var starSecondary: Color

    private func route(in size: CGSize) -> Path {
        let w = size.width, h = size.height
        var path = Path()
        path.move(to: CGPoint(x: 16, y: h * 0.75))
        path.addCurve(to: CGPoint(x: w * 0.40, y: h * 0.25),
                      control1: CGPoint(x: w * 0.23, y: h * 0.78), control2: CGPoint(x: w * 0.20, y: h * 0.12))
        path.addCurve(to: CGPoint(x: w * 0.69, y: h * 0.66),
                      control1: CGPoint(x: w * 0.54, y: h * 0.35), control2: CGPoint(x: w * 0.52, y: h * 0.90))
        path.addCurve(to: CGPoint(x: w - 16, y: h * 0.24),
                      control1: CGPoint(x: w * 0.82, y: h * 0.45), control2: CGPoint(x: w * 0.79, y: h * 0.17))
        return path
    }

    var body: some View {
        GeometryReader { geometry in
            let path = route(in: geometry.size)
            let start = CGPoint(x: 16, y: geometry.size.height * 0.75)
            ZStack {
                path.stroke(accent.opacity(0.12), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                path.trimmedPath(from: 0, to: progress.fraction)
                    .stroke(LinearGradient(colors: [secondary, accent], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .shadow(color: accent.opacity(0.2), radius: 7, y: 3)
                    .opacity(progress.fraction > 0 ? 1 : 0)
                if progress.ratio > 1 {
                    path.trimmedPath(from: 0, to: progress.overflowFraction)
                        .stroke(overflow, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                }
                ForEach(1..<5) { index in
                    let fraction = Double(index) / 4
                    let point = path.trimmedPath(from: 0, to: fraction).currentPoint ?? start
                    Circle().fill(fraction <= progress.fraction ? accent : secondary.opacity(0.45))
                        .frame(width: 5, height: 5).position(point)
                }
                CounterStarlight(trail: trail, effect: effect,
                                 accent: starAccent, secondary: starSecondary,
                                 pointAt: { fraction in
                    fraction > 0 ? path.trimmedPath(from: 0, to: fraction).currentPoint ?? start : start
                })
            }
        }
        .accessibilityHidden(true)
    }
}

/// Each replay gets fresh state before its first visible frame.
struct AnimatedStepCounter: View {
    var steps: Int?
    var goal: Int
    var title: String
    var theme: WalkunoTheme
    var style: CounterStyle
    var effect: CounterEffect = .stars
    var replay: String
    var animateEntry: Bool
    var animateUpdates: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CounterPlaybackView(steps: steps, goal: goal, title: title, theme: theme, style: style, effect: effect,
                            animateEntry: animateEntry && !reduceMotion, animateUpdates: animateUpdates)
            .id(replay)
    }
}

private struct CounterPlaybackView: View {
    var steps: Int?
    var goal: Int
    var title: String
    var theme: WalkunoTheme
    var style: CounterStyle
    var effect: CounterEffect = .stars
    var animateEntry: Bool
    var animateUpdates: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settledSteps: Double
    @State private var playback: Playback?
    @State private var hasStarted = false

    init(steps: Int?, goal: Int, title: String, theme: WalkunoTheme, style: CounterStyle, effect: CounterEffect,
         animateEntry: Bool, animateUpdates: Bool) {
        self.steps = steps; self.goal = goal; self.title = title
        self.theme = theme; self.style = style; self.effect = effect
        self.animateEntry = animateEntry; self.animateUpdates = animateUpdates
        _settledSteps = State(initialValue: animateEntry ? 0 : Double(steps ?? 0))
    }

    private struct Playback {
        let id = UUID()
        var started: Date
        var from: Double
        var target: Double
        var goal: Int
        var duration: Double

        func frame(at date: Date) -> CounterTrailFrame {
            CounterTrailFrame(elapsed: date.timeIntervalSince(started), duration: duration,
                              startRatio: from / Double(max(1, goal)), endRatio: target / Double(max(1, goal)))
        }
        func value(at date: Date) -> Double { frame(at: date).ratio(at: date.timeIntervalSince(started)) * Double(max(1, goal)) }
    }

    private struct Request: Equatable {
        var steps: Int?
        var goal: Int
        var reduceMotion: Bool
        var animateEntry: Bool
        var animateUpdates: Bool
    }

    var body: some View {
        ZStack {
            if let playback, !reduceMotion {
                // This clock exists only for the sweep and the final 0.8 seconds of dissipation.
                TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
                    let frame = playback.frame(at: context.date)
                    face(value: playback.value(at: context.date), trail: frame.isActive ? frame : nil)
                }
            } else {
                face(value: reduceMotion ? Double(steps ?? 0) : settledSteps, trail: nil)
            }
        }
        .task(id: Request(steps: steps, goal: goal, reduceMotion: reduceMotion,
                          animateEntry: animateEntry, animateUpdates: animateUpdates)) {
            let entry = !hasStarted
            let enabled = entry ? animateEntry : animateUpdates
            hasStarted = true
            let target = Double(steps ?? 0)
            let from = playback?.value(at: .now) ?? settledSteps
            guard !reduceMotion, enabled, goal > 0, steps != nil, from != target else {
                finish(at: target); return
            }
            let run = Playback(started: .now, from: from, target: target, goal: goal,
                               duration: entry ? 2 : 1.2)
            playback = run
            do {
                try await Task.sleep(for: .seconds(run.duration + CounterTrailFrame.lifetime))
                guard !Task.isCancelled, playback?.id == run.id else { return }
                finish(at: target)
            } catch { return }
        }
        // Remember that this request ran: returning from another tab must not reset a visible total.
        .onDisappear { finish(at: Double(steps ?? 0)) }
    }

    private func face(value: Double, trail: CounterTrailFrame?) -> some View {
        StepCounterFace(displayedSteps: value, trail: trail, hasSteps: steps != nil,
                        goal: goal, title: title, theme: theme, style: style, effect: effect)
    }

    private func finish(at value: Double) {
        settledSteps = value
        playback = nil
    }
}


/// The same interpolated progress drives the ring and its luminous leading star.
private struct SparklingRing: View {
    var progress: CounterProgress
    var trail: CounterTrailFrame? = nil
    var effect: CounterEffect = .stars
    var accent: Color
    var secondaryAccent: Color
    var starAccent: Color
    var starSecondary: Color

    var body: some View {
        ZStack {
            ProgressRing(progress: progress.ratio, accent: accent, secondaryAccent: secondaryAccent)
                // Playback already supplies the value for this frame.
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
            GeometryReader { geometry in
                let radius = min(geometry.size.width, geometry.size.height) / 2
                CounterStarlight(trail: trail, effect: effect,
                                 accent: starAccent, secondary: starSecondary,
                                 pointAt: { fraction in
                    let angle = fraction * 2 * .pi - .pi / 2
                    return CGPoint(x: geometry.size.width / 2 + cos(angle) * radius,
                                   y: geometry.size.height / 2 + sin(angle) * radius)
                })
            }
        }
    }
}
