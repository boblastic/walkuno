import SwiftUI

extension WalkunoTheme {
    func counterLinearGradient(for scheme: ColorScheme) -> LinearGradient {
        LinearGradient(colors: [secondaryTint(for: scheme), tint(for: scheme)], startPoint: .leading, endPoint: .trailing)
    }
}

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

/// A static miniature of the selected face, using the same drawing as the counter.
struct CounterStyleThumbnail: View {
    var theme: WalkunoTheme
    var style: CounterStyle

    var body: some View {
        StepCounterFace(displayedSteps: 6240, hasSteps: true, goal: 8000,
                        title: "", theme: theme, style: style)
            .environment(\.dynamicTypeSize, .medium)
            .frame(width: 220, height: 220)
            .scaleEffect(0.14)
            .frame(width: 22, height: 30)
            .accessibilityHidden(true)
            .allowsHitTesting(false)
    }
}

/// All five designs use the same interpolated value, semantic palette and layout
/// in the dashboard and settings preview. The finite particle trail fades after the value settles.
struct StepCounterFace: View {
    var displayedSteps: Double
    var trail: CounterTrailFrame? = nil
    var hasSteps: Bool
    var goal: Double
    var title: String
    var theme: WalkunoTheme
    var style: CounterStyle
    var effect: CounterEffect = .stars
    var distance: String? = nil
    var numberText: String? = nil
    var objectiveText: String? = nil
    var showsRemaining = true
    var showsAnnotations = true
    var celebratesGoal = false
    @ScaledMetric(relativeTo: .largeTitle) private var counterSize = 55
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    private var progress: CounterProgress { .init(value: hasSteps ? displayedSteps : 0, goal: goal) }
    private var accent: Color { theme.tint(for: scheme) }
    private var secondary: Color { theme.secondaryTint(for: scheme) }
    private var gradient: LinearGradient {
        theme.counterLinearGradient(for: scheme)
    }
    private var overflow: Color {
        progress.overflowLap.truncatingRemainder(dividingBy: 2) == 1 ? .white.opacity(0.88) : WalkunoStyle.ink.opacity(0.85)
    }
    private var number: String { hasSteps ? numberText ?? Int(max(0, displayedSteps).rounded()).formatted() : "—" }

    var body: some View {
        GeometryReader { geometry in
            let width = style == .ring ? min(geometry.size.width, geometry.size.height, typeSize.isAccessibilitySize ? 320 : 300) : min(geometry.size.width - 12, 340)
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

    @ViewBuilder private var heading: some View {
        if showsAnnotations {
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(accent)
                .lineLimit(1).minimumScaleFactor(0.65)
        }
    }

    private func count(size: CGFloat, alignment: Alignment = .center) -> some View {
        Text(number)
            .font(.system(size: min(counterSize * size / 55, typeSize.isAccessibilitySize ? 92 : size), weight: .bold, design: .rounded))
            .monospacedDigit().tracking(-2.5).lineLimit(1).minimumScaleFactor(0.35)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    @ViewBuilder private var objective: some View {
        if showsAnnotations {
            Group {
                if let objectiveText { Text(objectiveText) }
                else { Text("today.of \(Int(goal).formatted())") }
            }
            .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    private func total(size: CGFloat, alignment: Alignment = .center) -> some View {
        VStack(alignment: alignment == .leading ? .leading : .center, spacing: 0) {
            count(size: size, alignment: alignment)
            objective
            if let distance {
                Text(distance)
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.secondaryTint(for: scheme))
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .padding(.top, 5)
            }
        }
    }

    @ViewBuilder private var percentage: some View {
        if showsAnnotations {
            HStack(spacing: 4) {
                if hasSteps, progress.ratio >= 1 { Image(systemName: "checkmark").font(.caption2.weight(.bold)) }
                Text(hasSteps ? progress.ratio.formatted(.percent.precision(.fractionLength(0))) : "—")
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            }
            .font(.caption2.weight(.bold)).foregroundStyle(WalkunoStyle.ink)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(theme.accent, in: Capsule())
            .fixedSize(horizontal: false, vertical: true)
            .goalSurpassingStars(isActive: celebratesGoal && hasSteps && progress.ratio >= 1, theme: theme)
        }
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
                total(size: distance == nil ? 55 : 62)
                percentage.padding(.top, 4)
            }.padding(.horizontal, 32)
        }
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
                    total(size: 58)
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
            total(size: 64)
            CounterRoute(progress: progress, accent: accent, secondary: secondary, overflow: overflow, trail: trail, effect: effect,
                         starAccent: theme.accent, starSecondary: theme.secondaryAccent)
                .frame(height: typeSize.isAccessibilitySize ? 90 : 76)
                .padding(.top, 8)
            HStack {
                if showsRemaining { remaining; Spacer(minLength: 8) }
                percentage
            }
                .padding(.horizontal, 4)
        }
        .frame(maxHeight: .infinity)
    }

    private var milestones: some View {
        VStack(spacing: 5) {
            heading
            total(size: 64)
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
                if showsRemaining, hasSteps, let next = progress.nextMilestone(goal: Int(goal)) {
                    Text("counter.next \(next.formatted())").font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                } else if showsRemaining { remaining }
                Spacer(minLength: 0)
                percentage
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var typographic: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { heading; Spacer(minLength: 8); percentage }
            total(size: 86, alignment: .leading)
                .padding(.top, 3)
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
            if showsRemaining { remaining.padding(.top, 4) }
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

/// A static, legible version of the home counter for calendar cells.
struct CompactStepCounterFace: View {
    var progress: Double?
    var text: String
    var theme: WalkunoTheme
    var style: CounterStyle
    var celebratesGoal = false
    @Environment(\.colorScheme) private var scheme

    private var value: CounterProgress { .init(steps: progress ?? 0, goal: 1) }
    private var accent: Color { theme.tint(for: scheme) }
    private var hasBase: Bool { style == .path || style == .milestones || style == .minimal }
    private var overflow: Color {
        value.overflowLap.truncatingRemainder(dividingBy: 2) == 1 ? .white.opacity(0.88) : WalkunoStyle.ink.opacity(0.85)
    }
    private var gradient: LinearGradient {
        theme.counterLinearGradient(for: scheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let stroke = max(2.5, size * 0.065)
            ZStack {
                switch style {
                case .ring:
                    track(Circle().path(in: CGRect(x: stroke, y: stroke, width: size - 2 * stroke, height: size - 2 * stroke)),
                          stroke: stroke)
                        .rotationEffect(.degrees(-90))
                case .horizon:
                    track(CounterArc(center: CGPoint(x: size / 2, y: size / 2), radius: size / 2 - stroke)
                        .path(in: .zero), stroke: stroke)
                case .path:
                    track(CounterRouteShape(inset: stroke).path(in: CGRect(x: 0, y: size * 0.65, width: size, height: size * 0.3)),
                          stroke: stroke)
                case .milestones:
                    HStack(alignment: .bottom, spacing: max(1, size * 0.025)) {
                        ForEach(0..<10) { index in
                            let height = size * 0.3 * (0.4 + Double(index) / 15)
                            RoundedRectangle(cornerRadius: 1.5).fill(accent.opacity(0.14))
                                .overlay(alignment: .bottom) {
                                    RoundedRectangle(cornerRadius: 1.5).fill(gradient)
                                        .frame(height: height * value.segmentFill(index))
                                }
                                .overlay(alignment: .bottom) {
                                    if value.ratio > 1 {
                                        Capsule().fill(overflow).frame(width: max(1, stroke * 0.35),
                                                                      height: height * value.segmentFill(index, overflow: true))
                                    }
                                }
                                .frame(height: height)
                        }
                    }
                    .padding(.horizontal, stroke).padding(.bottom, stroke)
                    .frame(height: size, alignment: .bottom)
                case .minimal:
                    track(Path { path in
                        path.move(to: CGPoint(x: stroke, y: size - stroke * 2))
                        path.addLine(to: CGPoint(x: size - stroke, y: size - stroke * 2))
                    }, stroke: stroke)
                }
                Text(text)
                    .font(.system(size: size * (hasBase ? 0.32 : 0.29), weight: .bold, design: .rounded))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                    .foregroundStyle(progress == nil ? Color.secondary : Color.primary)
                    .frame(width: size * (hasBase ? 0.95 : 0.65))
                    .goalSurpassingStars(isActive: celebratesGoal && value.ratio >= 1, theme: theme)
                    .offset(y: hasBase ? -size * 0.14 : 0)
            }
            .opacity(progress == nil ? 0.45 : 1)
            .frame(width: size, height: size)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .accessibilityHidden(true)
    }

    private func track(_ path: Path, stroke: CGFloat) -> some View {
        ZStack {
            path.stroke(accent.opacity(0.14), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
            path.trimmedPath(from: 0, to: value.fraction)
                .stroke(gradient, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                .opacity(value.fraction > 0 ? 1 : 0)
            if value.ratio > 1 {
                path.trimmedPath(from: 0, to: value.overflowFraction)
                    .stroke(overflow, style: StrokeStyle(lineWidth: stroke * 0.35, lineCap: .round))
            }
        }
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

    var body: some View {
        GeometryReader { geometry in
            let path = CounterRouteShape().path(in: CGRect(origin: .zero, size: geometry.size))
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

private struct CounterRouteShape: Shape {
    var inset: CGFloat = 16

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height, x = rect.minX, y = rect.minY
        var path = Path()
        path.move(to: CGPoint(x: x + inset, y: y + h * 0.75))
        path.addCurve(to: CGPoint(x: x + w * 0.40, y: y + h * 0.25),
                      control1: CGPoint(x: x + w * 0.23, y: y + h * 0.78), control2: CGPoint(x: x + w * 0.20, y: y + h * 0.12))
        path.addCurve(to: CGPoint(x: x + w * 0.69, y: y + h * 0.66),
                      control1: CGPoint(x: x + w * 0.54, y: y + h * 0.35), control2: CGPoint(x: x + w * 0.52, y: y + h * 0.90))
        path.addCurve(to: CGPoint(x: rect.maxX - inset, y: y + h * 0.24),
                      control1: CGPoint(x: x + w * 0.82, y: y + h * 0.45), control2: CGPoint(x: x + w * 0.79, y: y + h * 0.17))
        return path
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
    var distance: String? = nil
    var replay: String
    var animateEntry: Bool
    var animateUpdates: Bool
    var celebratesGoal = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        CounterPlaybackView(steps: steps, goal: goal, title: title, theme: theme, style: style, effect: effect, distance: distance,
                            animateEntry: animateEntry && !reduceMotion, animateUpdates: animateUpdates,
                            celebratesGoal: celebratesGoal)
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
    var distance: String? = nil
    var animateEntry: Bool
    var animateUpdates: Bool
    var celebratesGoal: Bool

    var body: some View {
        CounterPlayback(value: steps.map(Double.init), goal: Double(goal), animateEntry: animateEntry, animateUpdates: animateUpdates) { value, trail in
            StepCounterFace(displayedSteps: value, trail: trail, hasSteps: steps != nil,
                            goal: Double(goal), title: title, theme: theme, style: style, effect: effect, distance: distance,
                            celebratesGoal: celebratesGoal)
        }
    }
}

/// The clock and home counter share their easing, duration, live updates and finite effect tail.
struct AnimatedCounterRing: View {
    var value: Double?
    var goal: Double
    var theme: WalkunoTheme
    var counterStyle: CounterStyle
    var effect: CounterEffect
    var lineWidth: CGFloat = 12
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        CounterPlayback(value: value, goal: goal, animateEntry: true, animateUpdates: true, replayOnAppear: true) { value, trail in
            SparklingRing(progress: .init(value: value, goal: goal), trail: trail, effect: effect,
                          accent: theme.tint(for: scheme), secondaryAccent: theme.secondaryTint(for: scheme),
                          starAccent: theme.accent, starSecondary: theme.secondaryAccent, lineWidth: lineWidth,
                          gradient: counterStyle == .ring ? nil : AnyShapeStyle(theme.counterLinearGradient(for: scheme)))
                .transaction { $0.animation = nil; $0.disablesAnimations = true }
        }
        .accessibilityHidden(true)
    }
}

struct CounterPlayback<Content: View>: View {
    var value: Double?
    var goal: Double
    var animateEntry: Bool
    var animateUpdates: Bool
    var replayOnAppear: Bool
    var content: (Double, CounterTrailFrame?) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settledValue: Double
    @State private var playback: Playback?
    @State private var hasStarted = false

    init(value: Double?, goal: Double, animateEntry: Bool, animateUpdates: Bool, replayOnAppear: Bool = false,
         @ViewBuilder content: @escaping (Double, CounterTrailFrame?) -> Content) {
        self.value = value; self.goal = goal
        self.animateEntry = animateEntry; self.animateUpdates = animateUpdates
        self.replayOnAppear = replayOnAppear; self.content = content
        _settledValue = State(initialValue: animateEntry ? 0 : (value ?? 0))
    }

    private struct Playback {
        let id = UUID()
        var started: Date
        var from: Double
        var target: Double
        var goal: Double
        var duration: Double

        func frame(at date: Date) -> CounterTrailFrame {
            CounterTrailFrame(elapsed: date.timeIntervalSince(started), duration: duration,
                              startRatio: from / (goal > 0 ? goal : 1), endRatio: target / (goal > 0 ? goal : 1))
        }
        func value(at date: Date) -> Double { frame(at: date).ratio(at: date.timeIntervalSince(started)) * (goal > 0 ? goal : 1) }
    }

    private struct Request: Equatable {
        var value: Double?
        var goal: Double
        var reduceMotion: Bool
        var animateEntry: Bool
        var animateUpdates: Bool
    }

    var body: some View {
        // Keep the face's identity when the sweep settles so its percentage stars
        // can finish without being interrupted or replayed. The sweep clock pauses at rest.
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: playback == nil || reduceMotion)) { context in
            let current = reduceMotion ? nil : playback
            let frame = current?.frame(at: context.date)
            let displayed = reduceMotion ? (value ?? 0) : (current?.value(at: context.date) ?? settledValue)
            content(displayed, frame?.isActive == true ? frame : nil)
        }
        .task(id: Request(value: value, goal: goal, reduceMotion: reduceMotion,
                          animateEntry: animateEntry, animateUpdates: animateUpdates)) {
            let entry = !hasStarted
            let enabled = entry ? animateEntry : animateUpdates
            hasStarted = true
            let target = (value ?? 0)
            let from = playback?.value(at: .now) ?? settledValue
            guard !reduceMotion, enabled, goal > 0, value != nil, from != target else {
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
        .onDisappear {
            finish(at: replayOnAppear ? 0 : (value ?? 0))
            if replayOnAppear { hasStarted = false }
        }
    }

    private func finish(at value: Double) {
        settledValue = value
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
    var lineWidth: CGFloat = 18
    var gradient: AnyShapeStyle? = nil

    var body: some View {
        ZStack {
            ProgressRing(progress: progress.ratio, accent: accent, secondaryAccent: secondaryAccent,
                         lineWidth: lineWidth, gradient: gradient)
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
