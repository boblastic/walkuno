import SwiftUI
import Observation

extension WalkunoTheme {
    var accent: Color {
        switch self {
        case .mint: WalkunoStyle.electric
        case .coral: WalkunoStyle.coral
        case .glacier: Color(red: 0.24, green: 0.80, blue: 1)
        case .sunshine: Color(red: 1, green: 0.83, blue: 0.23)
        case .lime: Color(red: 0.77, green: 0.965, blue: 0.235)
        case .rose: Color(red: 1, green: 0.44, blue: 0.77)
        case .violet: Color(red: 0.75, green: 0.54, blue: 1)
        case .indigo: Color(red: 0.55, green: 0.61, blue: 1)
        case .turquoise: Color(red: 0.13, green: 0.885, blue: 0.82)
        }
    }

    /// Keep the vivid fills while giving text and controls enough contrast on white.
    func tint(for scheme: ColorScheme) -> Color {
        guard scheme == .light else { return accent }
        return switch self {
        case .mint: WalkunoStyle.lightStride
        case .coral: Color(red: 0.71, green: 0.235, blue: 0.085)
        case .glacier: Color(red: 0, green: 0.42, blue: 0.62)
        case .sunshine: Color(red: 0.51, green: 0.36, blue: 0)
        case .lime: Color(red: 0.32, green: 0.43, blue: 0)
        case .rose: Color(red: 0.68, green: 0.12, blue: 0.43)
        case .violet: Color(red: 0.49, green: 0.22, blue: 0.71)
        case .indigo: Color(red: 0.27, green: 0.32, blue: 0.72)
        case .turquoise: Color(red: 0, green: 0.43, blue: 0.40)
        }
    }
    var secondaryAccent: Color {
        switch self {
        case .mint: WalkunoStyle.strideTeal
        case .coral: Color(red: 0.72, green: 0.24, blue: 0.16)
        case .glacier: Color(red: 0.10, green: 0.48, blue: 0.73)
        case .sunshine: Color(red: 0.77, green: 0.48, blue: 0.10)
        case .lime: Color(red: 0.39, green: 0.65, blue: 0.16)
        case .rose: Color(red: 0.68, green: 0.23, blue: 0.52)
        case .violet: Color(red: 0.45, green: 0.30, blue: 0.76)
        case .indigo: Color(red: 0.32, green: 0.38, blue: 0.76)
        case .turquoise: Color(red: 0.06, green: 0.53, blue: 0.52)
        }
    }

    func secondaryTint(for scheme: ColorScheme) -> Color {
        if self == .mint && scheme == .light { return WalkunoStyle.lightTeal }
        return scheme == .light ? tint(for: scheme) : secondaryAccent
    }
    var titleKey: String { "theme.\(rawValue)" }
}

enum WalkunoStyle {
    // Walkuno, in the same sRGB space as the app icon.
    static let ink = Color(.sRGB, red: 10/255, green: 36/255, blue: 44/255)
    static let electric = Color(.sRGB, red: 163/255, green: 1, blue: 112/255)
    static let strideTeal = Color(.sRGB, red: 49/255, green: 185/255, blue: 159/255)
    static let lightStride = Color(.sRGB, red: 55/255, green: 101/255, blue: 28/255)
    static let lightTeal = Color(.sRGB, red: 0, green: 103/255, blue: 88/255)
    static let coral = Color(red: 1, green: 0.47, blue: 0.28)
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? ink : Color(.sRGB, red: 239/255, green: 246/255, blue: 241/255)
    }
    static func card(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(.sRGB, red: 19/255, green: 53/255, blue: 60/255) : .white
    }
}

struct WalkunoCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var tint: Color? = nil
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(20)
            .background(tint ?? WalkunoStyle.card(scheme), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(.primary.opacity(0.045)))
    }
}

struct ProgressRing: View {
    var progress: Double
    var accent: Color
    var secondaryAccent: Color? = nil
    var lineWidth: CGFloat = 18
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ProgressRingDrawing(progress: progress, accent: accent, secondaryAccent: secondaryAccent ?? accent.opacity(0.88), lineWidth: lineWidth)
            .animation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.85), value: progress)
            .accessibilityHidden(true)
    }
}

/// Interpolate the total before deriving laps, so crossing 200% keeps moving clockwise.
private struct ProgressRingDrawing: View, Animatable {
    var progress: Double
    var accent: Color
    var secondaryAccent: Color
    var lineWidth: CGFloat

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    private var total: Double { progress.isFinite ? max(progress, 0) : 0 }
    private var extraLaps: Double { max(total - 1, 0) }
    private var completedExtraLaps: Double { floor(extraLaps) }
    private var currentExtraLap: Double { extraLaps - completedExtraLaps }

    private func lapColor(_ lap: Double) -> Color {
        lap.truncatingRemainder(dividingBy: 2) == 0 ? .white.opacity(0.85) : WalkunoStyle.ink.opacity(0.85)
    }

    var body: some View {
        ZStack {
            Circle().stroke(accent.opacity(0.18), lineWidth: lineWidth)
            Circle().trim(from: 0, to: min(total, 1))
                // Matching both ends prevents a hard color seam across the rounded cap at twelve o'clock.
                .stroke(AngularGradient(colors: [accent, secondaryAccent, accent], center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: accent.opacity(0.28), radius: 10)
            // Keep the first 100% visible; each additional lap traces a contrasting lane
            // through it. Alternate the lane color to keep later laps visible as well.
            if total > 1 {
                if completedExtraLaps > 0 {
                    Circle().stroke(lapColor(completedExtraLaps - 1), lineWidth: lineWidth * 0.4)
                }
                if currentExtraLap > 0 {
                    Circle().trim(from: 0, to: currentExtraLap)
                        .stroke(lapColor(completedExtraLaps), style: StrokeStyle(lineWidth: lineWidth * 0.4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                GeometryReader { geometry in
                    let radius = min(geometry.size.width, geometry.size.height) / 2
                    let angle = total.truncatingRemainder(dividingBy: 1) * 2 * .pi - .pi / 2
                    let tipColor = lapColor(currentExtraLap > 0 ? completedExtraLaps : completedExtraLaps - 1)
                    Circle().fill(accent)
                        .overlay { Circle().fill(tipColor).padding(lineWidth * 0.3) }
                        .frame(width: lineWidth, height: lineWidth)
                        .shadow(color: WalkunoStyle.ink.opacity(0.45), radius: lineWidth * 0.25, y: 2)
                        .position(x: geometry.size.width / 2 + cos(angle) * radius,
                                  y: geometry.size.height / 2 + sin(angle) * radius)
                }
            }
            Circle().strokeBorder(accent.opacity(0.16), style: StrokeStyle(lineWidth: 2, dash: [1, 8]))
                .padding(lineWidth + 9)
        }
    }
}

struct BrandMark: View {
    @Environment(\.colorScheme) private var scheme
    var size: CGFloat = 24
    var theme: WalkunoTheme = .mint

    // The two silhouettes follow 02-Grande-foulee.svg in SwiftUI Path notation.
    private static let rear = Path("""
        138 71 m 143 75 137 84 q 106 111 l 102 115 96 117 q 63 136 l
        58 139 53 138 q 46 136 l 50 128 l 85 103 l 116 77 l 128 66 138 71 q h
        112 122 m 122 121 130 128 q 165 151 l 171 156 177 165 q 193 185 l
        197 190 202 189 q 216 186 l 226 193 l 200 204 l 193 207 185 201 q
        152 172 l 111 151 l 99 144 100 136 q 101 126 112 122 q h
        """)!
    private static let front = Path("""
        118 77 m 127 70 l 137 64 145 70 q 150 74 151 83 q 162 105 l
        179 95 l 192 83 l 195 81 198 84 q 201 88 l 193 101 l 166 123 l
        157 131 149 127 q 142 126 138 120 q 130 107 l 124 133 l
        122 143 114 150 q 88 172 l 82 177 75 180 q 50 188 l 61 195 l
        67 197 l 70 199 68 203 q 67 205 l 55 205 l 52 205 48 202 q
        30 191 l 26 188 29 182 q 63 163 l 91 137 l 105 97 l 109 85 118 77 q h
        """)!
    private static let head = Path(ellipseIn: CGRect(x: 131, y: 31, width: 30, height: 30))

    var body: some View {
        Canvas { context, bounds in
            // Fit the figure itself at small sizes, without the home-screen icon's padding.
            let scale = min(bounds.width, bounds.height) / 204
            context.translateBy(x: bounds.width / 2, y: bounds.height / 2)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -127, y: -118)
            let foreground = theme.tint(for: scheme)
            let background = theme.secondaryTint(for: scheme)
            context.fill(Self.rear, with: .color(background))
            context.fill(Self.front, with: .color(foreground))
            context.fill(Self.head, with: .color(foreground))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// SwiftUI uses the locale environment; programmatic strings use the same bundle.
enum AppLocalization {
    @Observable fileprivate final class Selection: @unchecked Sendable {
        let lock = NSRecursiveLock()
        var language: AppLanguage = .system
    }
    private static let selection = Selection()
    private static let bundles: [String: Bundle] = Dictionary(uniqueKeysWithValues:
        AppLanguage.allCases.filter { $0 != .system }.compactMap { language in
            guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { return nil }
            return (language.rawValue, bundle)
        })

    static func configure(_ language: AppLanguage) {
        selection.lock.lock()
        defer { selection.lock.unlock() }
        selection.language = language
    }

    static var languageCode: String {
        selection.lock.lock()
        let language = selection.language
        selection.lock.unlock()
        return language.resolvedCode()
    }

    static var locale: Locale {
        let code = languageCode
        // Keep the phone's regional conventions while changing the text language.
        let region = Locale.current.region?.identifier
        return Locale(identifier: region.map { code + "_" + $0 } ?? code)
    }

    static var bundle: Bundle { bundles[languageCode] ?? bundles["en"] ?? .main }
}

func L(_ key: String) -> String { AppLocalization.bundle.localizedString(forKey: key, value: nil, table: nil) }

extension Date {
    func appFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time).locale(AppLocalization.locale))
    }
}

func stepsText(_ value: Int?) -> String {
    value.map { $0.formatted(.number) } ?? "—"
}

func distanceText(_ meters: Double?, unit: DistanceUnit) -> String {
    guard let meters else { return "—" }
    return unit.convert(meters: meters).formatted(.number.precision(.fractionLength(1))) + " " + unit.symbol
}
