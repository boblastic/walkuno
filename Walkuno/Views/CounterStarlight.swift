import SwiftUI

extension View {
    /// A brief celebration attached to an objective percentage, without changing its layout.
    func goalSurpassingStars(isActive: Bool, theme: WalkunoTheme) -> some View {
        modifier(GoalSurpassingStars(isActive: isActive, theme: theme))
    }
}

private struct GoalSurpassingStars: ViewModifier {
    var isActive: Bool
    var theme: WalkunoTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var started: Date?

    private let durationMultiplier = 2.0
    private var shouldAnimate: Bool { isActive && !reduceMotion && scenePhase == .active }

    func body(content: Content) -> some View {
        content.overlay {
            if let started, shouldAnimate {
                TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(started) / durationMultiplier
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        // Padding leaves room for the stars while the label keeps its original bounds.
                        let radiusX = max(4, (size.width - 36) / 2)
                        let radiusY = max(4, (size.height - 36) / 2)
                        for index in 0..<8 {
                            let age = elapsed - Double(index % 4) * 0.10
                            let life = 1.6 + Double(index % 3) * 0.15
                            guard age >= 0, age < life else { continue }
                            let t = age / life
                            let angle = Double(index) * .pi / 4 + 0.18
                            let flight = (10 + Double(index % 3) * 3) * (1 - pow(1 - t, 2))
                            let point = CGPoint(x: center.x + cos(angle) * (radiusX + 3 + flight),
                                                y: center.y + sin(angle) * (radiusY + 3 + flight))
                            let shimmer = 0.75 + 0.25 * sin(age * 23 + Double(index))
                            let opacity = min(1, age / 0.08) * pow(1 - t, 1.2) * shimmer
                            let half = (2.4 + Double(index % 3) * 0.55) * (1 - t * 0.45)
                            var star = Path()
                            star.move(to: CGPoint(x: 0, y: -half))
                            star.addQuadCurve(to: CGPoint(x: half * 0.75, y: 0), control: CGPoint(x: half * 0.12, y: -half * 0.12))
                            star.addQuadCurve(to: CGPoint(x: 0, y: half), control: CGPoint(x: half * 0.12, y: half * 0.12))
                            star.addQuadCurve(to: CGPoint(x: -half * 0.75, y: 0), control: CGPoint(x: -half * 0.12, y: half * 0.12))
                            star.addQuadCurve(to: CGPoint(x: 0, y: -half), control: CGPoint(x: -half * 0.12, y: -half * 0.12))
                            star.closeSubpath()
                            var particle = context
                            particle.opacity = opacity
                            particle.translateBy(x: point.x, y: point.y)
                            particle.rotate(by: .radians(t * 0.8 + angle))
                            let halo = half * 2.2
                            particle.fill(Path(ellipseIn: CGRect(x: -halo, y: -halo, width: halo * 2, height: halo * 2)),
                                          with: .radialGradient(Gradient(colors: [theme.accent.opacity(0.3), .clear]),
                                                                center: .zero, startRadius: 0, endRadius: halo))
                            particle.fill(star, with: .linearGradient(Gradient(colors: [.white, theme.accent, theme.secondaryAccent]),
                                                                      startPoint: CGPoint(x: 0, y: -half), endPoint: CGPoint(x: 0, y: half)))
                        }
                    }
                }
                .padding(-18)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        // A Boolean trigger avoids replaying the burst for every step above the objective.
        .task(id: shouldAnimate) {
            started = nil
            guard shouldAnimate else { return }
            started = .now
            do {
                try await Task.sleep(for: .seconds(2.4 * durationMultiplier))
                guard !Task.isCancelled else { return }
                started = nil
            } catch { return }
        }
        .onDisappear { started = nil }
    }
}

/// Four materials share the counter's finite playback and historical positions.
/// The animation driver supplies time; no clock or decorative layer survives at rest.
struct CounterStarlight: View {
    var trail: CounterTrailFrame?
    var effect: CounterEffect = .stars
    var accent: Color
    var secondary: Color
    var pointAt: (Double) -> CGPoint
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if let trail, !reduceMotion, trail.elapsed.isFinite, trail.duration.isFinite,
               trail.duration > 0, trail.elapsed >= 0,
               trail.elapsed < trail.duration + CounterTrailFrame.lifetime,
               trail.startRatio != trail.endRatio {
                Canvas { context, _ in
                    // Keep the caller's coordinates while leaving room for drifting stars and halos.
                    context.translateBy(x: 24, y: 24)
                    switch effect {
                    case .stars: drawTrail(in: context, frame: trail)
                    case .fire: drawFire(in: context, frame: trail)
                    case .aurora: drawAurora(in: context, frame: trail)
                    case .liquid: drawLiquid(in: context, frame: trail)
                    }
                }
                .padding(-24)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawTrail(in context: GraphicsContext, frame: CounterTrailFrame) {
        let rate = 55.0
        let last = Int(floor(min(frame.elapsed, frame.duration) * rate))
        let first = max(0, last - 49, Int(ceil(max(0, frame.elapsed - CounterTrailFrame.lifetime) * rate)))
        if first <= last {
            for index in first...last {
                let born = Double(index) / rate
                let age = frame.elapsed - born
                let lifetime = 0.4 + seed(index, 1) * 0.4
                guard age >= 0, age < lifetime else { continue }
                let ageFraction = age / lifetime
                let fraction = frame.marker(at: born)
                let origin = pointAt(fraction)
                let direction = tangent(at: fraction)
                let sign = frame.endRatio >= frame.startRatio ? 1.0 : -1.0
                let curl = sin(ageFraction * .pi)
                let sideways = (seed(index, 2) * 2 - 1) * (10 + seed(index, 3) * 10) * pow(ageFraction, 0.85)
                    + curl * cos(seed(index, 4) * 2 * .pi) * 4
                let along = -(4 + seed(index, 5) * 9) * ageFraction * sign
                    + curl * sin(seed(index, 4) * 2 * .pi) * 3
                var dx = direction.x * along - direction.y * sideways
                var dy = direction.y * along + direction.x * sideways
                let distance = hypot(dx, dy)
                if distance > 24 { dx *= 24 / distance; dy *= 24 / distance }
                let birth = min(1, age / 0.055)
                let opacity = birth * birth * (3 - 2 * birth) * pow(1 - ageFraction, 1.3)
                    * (0.68 + seed(index, 6) * 0.32)
                let size = (4 + pow(seed(index, 7), 1.4) * 9) * (1 - ageFraction * 0.68)
                let rotation = seed(index, 8) * 90 + (seed(index, 9) * 2 - 1) * ageFraction * 55
                drawStar(in: context, at: CGPoint(x: origin.x + dx, y: origin.y + dy),
                         size: size, rotation: rotation, opacity: opacity, hero: size > 10)
            }
        }
        // This small leading glint disappears before the last drifting stars.
        if frame.elapsed < frame.duration {
            let birth = min(1, frame.elapsed / 0.10)
            let fade = min(1, (frame.duration - frame.elapsed) / 0.20)
            drawStar(in: context, at: pointAt(frame.marker(at: frame.elapsed)),
                     size: 17 + sin(frame.elapsed * 7) * 1.2,
                     rotation: -8 + sin(frame.elapsed * 3) * 7,
                     opacity: birth * fade * 0.9, hero: true)
        }
    }

    private func envelope(_ frame: CounterTrailFrame) -> Double {
        min(1, frame.elapsed / 0.12) * max(0, 1 - max(0, frame.elapsed - frame.duration) / CounterTrailFrame.lifetime)
    }

    private func glow(in context: GraphicsContext, at point: CGPoint, radius: Double, color: Color, opacity: Double) {
        var c = context
        c.opacity *= opacity
        c.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
               with: .radialGradient(Gradient(colors: [color.opacity(0.65), color.opacity(0.18), .clear]),
                                     center: point, startRadius: 0, endRadius: radius))
    }

    private func flame(in context: GraphicsContext, at point: CGPoint, height: Double, width: Double,
                       curl: Double, rotation: Double, opacity: Double) {
        var c = context
        c.translateBy(x: point.x, y: point.y)
        c.rotate(by: .radians(rotation))
        c.opacity *= opacity
        var silhouette = Path()
        silhouette.move(to: CGPoint(x: -width, y: 2))
        silhouette.addCurve(to: CGPoint(x: curl, y: -height),
                            control1: CGPoint(x: -width * 1.6, y: -height * 0.45),
                            control2: CGPoint(x: width * 0.6 + curl, y: -height * 0.55))
        silhouette.addCurve(to: CGPoint(x: width, y: 2),
                            control1: CGPoint(x: curl - width * 0.3, y: -height * 0.30),
                            control2: CGPoint(x: width * 1.8, y: -height * 0.24))
        silhouette.closeSubpath()
        c.fill(silhouette, with: .linearGradient(Gradient(stops: [
            .init(color: Color(red: 1, green: 0.12, blue: 0.025).opacity(0), location: 0),
            .init(color: .orange, location: 0.34), .init(color: .yellow, location: 0.74),
            .init(color: Color(red: 1, green: 0.97, blue: 0.83), location: 1)]),
            startPoint: CGPoint(x: 0, y: -height), endPoint: CGPoint(x: 0, y: 3)))
        c.scaleBy(x: 0.44, y: 0.55)
        c.fill(silhouette, with: .linearGradient(Gradient(colors: [.yellow.opacity(0), .white.opacity(0.95)]),
                                                startPoint: CGPoint(x: 0, y: -height), endPoint: .zero))
    }

    private func drawFire(in context: GraphicsContext, frame: CounterTrailFrame) {
        let last = Int(min(frame.elapsed, frame.duration) * 48)
        let first = max(0, Int(max(0, frame.elapsed - 0.8) * 48))
        guard first <= last else { return }
        for index in first...last {
            let born = Double(index) / 48
            let age = frame.elapsed - born
            let life = 0.42 + seed(index, 10) * 0.37
            guard age < life else { continue }
            let t = age / life
            let origin = pointAt(frame.marker(at: born))
            let rise = (6 + seed(index, 11) * 21) * t
            let sway = sin(t * 5 + seed(index, 12) * 6) * 5 * t
            let p = CGPoint(x: origin.x + sway, y: origin.y - rise)
            let alpha = min(1, age / 0.04) * pow(1 - t, 1.5)
            glow(in: context, at: p, radius: 15 * (1 - t * 0.5), color: .orange, opacity: alpha * 0.45)
            flame(in: context, at: p, height: (13 + seed(index, 13) * 17) * (1 - t * 0.65),
                  width: (3 + seed(index, 14) * 3) * (1 - t * 0.7),
                  curl: sin(frame.elapsed * 17 + Double(index)) * 5,
                  rotation: sin(frame.elapsed * 8 + Double(index)) * 0.18, opacity: alpha * 0.8)
            if index.isMultiple(of: 3) {
                let ember = CGPoint(x: p.x + sway * 0.5, y: p.y - 8 * t)
                glow(in: context, at: ember, radius: 5, color: .yellow, opacity: alpha)
                context.fill(Path(ellipseIn: CGRect(x: ember.x, y: ember.y, width: 1.7, height: 2.8)), with: .color(.yellow.opacity(alpha)))
            }
        }
        if frame.elapsed < frame.duration {
            let p = pointAt(frame.marker(at: frame.elapsed))
            let fade = min(1, (frame.duration - frame.elapsed) / 0.16) * envelope(frame)
            glow(in: context, at: p, radius: 26, color: .orange, opacity: fade * 0.8)
            flame(in: context, at: p, height: 27 + sin(frame.elapsed * 23) * 4, width: 7,
                  curl: sin(frame.elapsed * 14) * 6,
                  rotation: sin(frame.elapsed * 9) * 0.12, opacity: fade)
        }
    }

    private func drawAurora(in context: GraphicsContext, frame: CounterTrailFrame) {
        let end = min(frame.elapsed, frame.duration)
        let start = max(0, frame.elapsed - 0.75)
        guard start < end else { return }
        let colors: [Color] = [Color(red: 0.25, green: 1, blue: 0.82), Color(red: 0.38, green: 0.65, blue: 1), Color(red: 0.86, green: 0.40, blue: 1)]
        let visibility = envelope(frame)
        for ribbon in 0..<3 {
            var previous: (CGPoint, Double, Double)?
            for index in 0...56 {
                let born = start + (end - start) * Double(index) / 56
                let fraction = frame.marker(at: born)
                let age = max(0, frame.elapsed - born)
                let t = min(1, age / 0.75)
                let d = tangent(at: fraction)
                let base = pointAt(fraction)
                let flutter = sin(born * 14 - frame.elapsed * 5 + Double(ribbon) * 1.8)
                let drift = (Double(ribbon) - 1) * (4 + t * 5) + flutter * (3 + t * 7)
                let p = CGPoint(x: base.x - d.y * drift, y: base.y + d.x * drift)
                let width = (2 + sin(t * .pi) * 8) * (1 - t) + 0.5
                if let (q, oldFraction, oldWidth) = previous, abs(fraction - oldFraction) < 0.25 {
                    var veil = Path()
                    veil.move(to: CGPoint(x: q.x - d.y * oldWidth, y: q.y + d.x * oldWidth))
                    veil.addLine(to: CGPoint(x: p.x - d.y * width, y: p.y + d.x * width))
                    veil.addLine(to: CGPoint(x: p.x + d.y * width, y: p.y - d.x * width))
                    veil.addLine(to: CGPoint(x: q.x + d.y * oldWidth, y: q.y - d.x * oldWidth))
                    veil.closeSubpath()
                    var layer = context
                    layer.opacity = visibility * pow(1 - t, 0.7)
                    layer.fill(veil, with: .linearGradient(Gradient(colors: [colors[ribbon].opacity(0), colors[ribbon].opacity(0.65), accent.opacity(0.55), .clear]),
                        startPoint: CGPoint(x: p.x - d.y * width, y: p.y + d.x * width),
                        endPoint: CGPoint(x: p.x + d.y * width, y: p.y - d.x * width)))
                    var ridge = Path(); ridge.move(to: q); ridge.addLine(to: p)
                    layer.stroke(ridge, with: .color(colors[ribbon].opacity(0.8)), style: StrokeStyle(lineWidth: 0.65, lineCap: .round))
                }
                previous = (p, fraction, width)
            }
        }
        let p = pointAt(frame.marker(at: end))
        glow(in: context, at: p, radius: 24, color: colors[0], opacity: visibility * 0.55)
        glow(in: context, at: p, radius: 9, color: .white, opacity: visibility * 0.6)
    }

    private func pearl(in context: GraphicsContext, at point: CGPoint, radius: Double, opacity: Double) {
        var c = context; c.opacity *= opacity
        let sphere = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        c.fill(sphere, with: .radialGradient(Gradient(stops: [
            .init(color: .white, location: 0), .init(color: accent, location: 0.25),
            .init(color: secondary, location: 0.60), .init(color: WalkunoStyle.ink, location: 0.85),
            .init(color: accent.opacity(0.9), location: 1)]),
            center: CGPoint(x: point.x - radius * 0.32, y: point.y - radius * 0.42), startRadius: 0, endRadius: radius * 1.65))
        c.stroke(sphere, with: .color(accent.opacity(0.6)), lineWidth: 0.6)
        let highlight = Path(ellipseIn: CGRect(x: point.x - radius * 0.53, y: point.y - radius * 0.65, width: radius * 0.65, height: radius * 0.26))
        c.fill(highlight, with: .color(.white.opacity(0.85)))
    }

    private func drawLiquid(in context: GraphicsContext, frame: CounterTrailFrame) {
        let end = min(frame.elapsed, frame.duration), start = max(0, frame.elapsed - 0.65)
        guard start < end else { return }
        let visibility = envelope(frame)
        var previous: (CGPoint, Double)?
        for index in 0...48 {
            let born = start + (end - start) * Double(index) / 48
            let fraction = frame.marker(at: born)
            let p = pointAt(fraction), t = max(0, frame.elapsed - born) / 0.8
            if let (q, oldFraction) = previous, abs(fraction - oldFraction) < 0.25 {
                var stroke = Path(); stroke.move(to: q); stroke.addLine(to: p)
                var c = context; c.opacity = visibility * pow(max(0, 1 - t), 1.4)
                c.stroke(stroke, with: .color(accent.opacity(0.85)),
                         style: StrokeStyle(lineWidth: 3 + 9 * (1 - t), lineCap: .round))
                c.stroke(stroke, with: .color(.white.opacity(0.55)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
            previous = (p, fraction)
        }
        for index in 0..<12 {
            let born = end - Double(index) * 0.047
            guard born >= 0 else { continue }
            let age = frame.elapsed - born
            guard age < 0.7 else { continue }
            let fraction = frame.marker(at: born), d = tangent(at: fraction)
            let p = pointAt(fraction), sign = index.isMultiple(of: 2) ? 1.0 : -1.0
            let flight = sin(age / 0.7 * .pi) * (8 + seed(index, 22) * 8) * sign
            let drop = CGPoint(x: p.x - d.y * flight, y: p.y + d.x * flight)
            pearl(in: context, at: drop, radius: (2 + seed(index, 23) * 2.2) * (1 - age / 0.7), opacity: visibility * (1 - age / 0.7))
        }
        let p = pointAt(frame.marker(at: end))
        glow(in: context, at: p, radius: 24, color: accent, opacity: visibility * 0.45)
        // Concentric wavelets and a pearlescent head melt together as the sweep settles.
        for index in 0..<2 {
            let cycle = (frame.elapsed * 2.2 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
            let r = 8 + cycle * 12
            context.stroke(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r * 0.55, width: r * 2, height: r * 1.1)),
                           with: .color(accent.opacity((1 - cycle) * visibility * 0.4)), lineWidth: 0.8)
        }
        pearl(in: context, at: p, radius: 10 * visibility, opacity: visibility)
    }

    private func seed(_ index: Int, _ channel: Double) -> Double {
        let value = sin(Double(index) * 12.9898 + channel * 78.233) * 43_758.5453
        return value - floor(value)
    }

    private func tangent(at fraction: Double) -> CGPoint {
        let before = pointAt(max(0, fraction - 0.002))
        let after = pointAt(min(1, fraction + 0.002))
        let dx = after.x - before.x, dy = after.y - before.y
        let length = hypot(dx, dy)
        guard length > 0.001 else { return CGPoint(x: 1, y: 0) }
        return CGPoint(x: dx / length, y: dy / length)
    }

    private func starPath(half: Double) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: -half))
        path.addQuadCurve(to: CGPoint(x: half * 0.78, y: 0), control: CGPoint(x: half * 0.10, y: -half * 0.10))
        path.addQuadCurve(to: CGPoint(x: 0, y: half), control: CGPoint(x: half * 0.10, y: half * 0.10))
        path.addQuadCurve(to: CGPoint(x: -half * 0.78, y: 0), control: CGPoint(x: -half * 0.10, y: half * 0.10))
        path.addQuadCurve(to: CGPoint(x: 0, y: -half), control: CGPoint(x: -half * 0.10, y: -half * 0.10))
        path.closeSubpath()
        return path
    }

    private func drawStar(in context: GraphicsContext, at point: CGPoint, size: Double,
                          rotation: Double, opacity: Double, hero: Bool = false) {
        var drawing = context
        drawing.opacity *= opacity
        drawing.translateBy(x: point.x, y: point.y)
        drawing.rotate(by: .degrees(rotation))
        let half = size / 2
        let star = starPath(half: half)
        let glowRadius = size * (hero ? 1.05 : 0.8)
        let glow = Path(ellipseIn: CGRect(x: -glowRadius, y: -glowRadius,
                                          width: glowRadius * 2, height: glowRadius * 2))
        drawing.fill(glow, with: .radialGradient(
            Gradient(stops: [.init(color: accent.opacity(hero ? 0.48 : 0.25), location: 0),
                             .init(color: secondary.opacity(hero ? 0.22 : 0.1), location: 0.38),
                             .init(color: accent.opacity(0), location: 1)]),
            center: .zero, startRadius: 0, endRadius: glowRadius))

        drawing.fill(star, with: .linearGradient(
            Gradient(stops: [.init(color: .white, location: 0),
                             .init(color: .white.opacity(0.95), location: 0.24),
                             .init(color: accent, location: 0.48),
                             .init(color: secondary, location: 0.78),
                             .init(color: accent, location: 1)]),
            startPoint: CGPoint(x: -half * 0.6, y: -half), endPoint: CGPoint(x: half * 0.7, y: half)))

        if hero {
            // Separate curved facets give the center a polished, jewel-like bevel.
            var lightFacet = Path()
            lightFacet.move(to: .zero)
            lightFacet.addLine(to: CGPoint(x: 0, y: -half))
            lightFacet.addQuadCurve(to: CGPoint(x: -half * 0.78, y: 0),
                                    control: CGPoint(x: -half * 0.10, y: -half * 0.10))
            lightFacet.closeSubpath()
            drawing.fill(lightFacet, with: .linearGradient(
                Gradient(colors: [.white.opacity(0.92), .white.opacity(0.08)]),
                startPoint: CGPoint(x: 0, y: -half), endPoint: .zero))

            var darkFacet = Path()
            darkFacet.move(to: .zero)
            darkFacet.addLine(to: CGPoint(x: 0, y: half))
            darkFacet.addQuadCurve(to: CGPoint(x: half * 0.78, y: 0),
                                   control: CGPoint(x: half * 0.10, y: half * 0.10))
            darkFacet.closeSubpath()
            drawing.fill(darkFacet, with: .color(secondary.opacity(0.4)))
        }

        drawing.stroke(star, with: .linearGradient(
            Gradient(colors: [scheme == .light ? accent : .white.opacity(0.9),
                              accent.opacity(0.7), secondary.opacity(0.85)]),
            startPoint: CGPoint(x: -half, y: -half), endPoint: CGPoint(x: half, y: half)),
            lineWidth: hero ? 0.7 : 0.4)
        drawing.fill(starPath(half: half * (hero ? 0.28 : 0.20)), with: .color(.white.opacity(0.96)))
    }
}
