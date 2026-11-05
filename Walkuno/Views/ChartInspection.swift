import SwiftUI
import Charts
import UIKit

/// Positions are relative to the plot, so dates, categories and grouped bars share the same interaction.
struct ChartInspectionPoint: Equatable {
    var x: CGFloat
    var y: CGFloat?
    var title: String
    var value: String
    var color: Color

    static func buckets(in interval: DateInterval, by component: Calendar.Component, calendar: Calendar = .current) -> [DateInterval] {
        var result: [DateInterval] = []
        var cursor = interval.start
        while cursor < interval.end {
            guard let next = calendar.date(byAdding: component, value: 1, to: cursor), next > cursor else { break }
            let end = min(next, interval.end)
            result.append(DateInterval(start: cursor, end: end))
            cursor = end
        }
        return result
    }

    init(x: CGFloat, y: CGFloat?, title: String, value: String, color: Color) {
        self.x = x
        self.y = y
        self.title = title
        self.value = value
        self.color = color
    }

    init?(proxy: ChartProxy, x: some Plottable, y: Double?, title: String, value: String, color: Color) {
        guard let position = proxy.position(forX: x) else { return nil }
        self.x = position
        self.y = y.flatMap { proxy.position(forY: $0) }
        self.title = title
        self.value = value
        self.color = color
    }
}

private struct ChartScrubbingKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    var chartScrubbing: Binding<Bool>? {
        get { self[ChartScrubbingKey.self] }
        set { self[ChartScrubbingKey.self] = newValue }
    }
}

extension View {
    func chartInspection(_ identifier: String, resetKey: String = "", points: @escaping (ChartProxy) -> [ChartInspectionPoint]) -> some View {
        modifier(ChartInspectionModifier(identifier: identifier, resetKey: resetKey, points: points))
    }

    func plotInspection(_ identifier: String, resetKey: String = "", points: @escaping (CGSize) -> [ChartInspectionPoint]) -> some View {
        modifier(ChartInspectionModifier(identifier: identifier, resetKey: resetKey, points: { _ in [] }, plotPoints: points))
    }
}

private struct ChartInspectionModifier: ViewModifier {
    var identifier: String
    var resetKey: String
    var points: (ChartProxy) -> [ChartInspectionPoint]
    var plotPoints: ((CGSize) -> [ChartInspectionPoint])? = nil
    @Environment(\.chartScrubbing) private var pagingScrubbing
    @State private var selection: Selection?
    @State private var dismissalID: UUID?

    private struct Selection {
        var point: ChartInspectionPoint
        var frame: CGRect
        var touch: CGPoint
        var x: CGFloat { min(frame.maxX, max(frame.minX, frame.minX + point.x)) }
        var y: CGFloat { frame.minY + (point.y ?? frame.height) }
    }

    func body(content: Content) -> some View {
        inspectedContent(content)
        // Keep the tooltip outside Charts' generated accessibility representation.
        .overlay {
            GeometryReader { geometry in
                if let selection {
                    Color.clear.overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selection.point.title).font(.caption2).foregroundStyle(.secondary)
                            Text(selection.point.value).font(.caption.weight(.semibold)).foregroundStyle(.primary)
                        }
                        .padding(10).frame(width: min(190, geometry.size.width), alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(selection.point.color.opacity(0.3)) }
                        .fixedSize(horizontal: false, vertical: true)
                        // Anchor the bottom above the finger, even for very small bars.
                        .offset(x: min(max(0, selection.x - 95), max(0, geometry.size.width - 190)),
                                y: min(selection.touch.y, selection.y) - 18 - geometry.size.height)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier(identifier + ".selection")
                    }
                }
            }.allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .task(id: dismissalID) {
            guard dismissalID != nil else { return }
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
            selection = nil
        }
        .onChange(of: resetKey) { _, _ in selection = nil; dismissalID = nil }
        .onDisappear { pagingScrubbing?.wrappedValue = false; selection = nil; dismissalID = nil }
    }

    @ViewBuilder
    private func inspectedContent(_ content: Content) -> some View {
        if let plotPoints {
            content.overlay {
                GeometryReader { geometry in
                    touchOverlay(frame: CGRect(origin: .zero, size: geometry.size), samples: plotPoints(geometry.size))
                }
            }
        } else {
            content.chartOverlay { proxy in
                GeometryReader { geometry in
                    if let anchor = proxy.plotFrame {
                        touchOverlay(frame: geometry[anchor], samples: points(proxy))
                    }
                }
            }
        }
    }

    private func touchOverlay(frame: CGRect, samples: [ChartInspectionPoint]) -> some View {
        ZStack(alignment: .topLeading) {
            ChartInspectionTouchSurface(
                onTap: { location in
                    select(at: location, frame: frame, samples: samples)
                    dismissalID = UUID()
                },
                onInspect: { select(at: $0, frame: frame, samples: samples) },
                onScrubbingChanged: { active in
                    pagingScrubbing?.wrappedValue = active
                    dismissalID = active ? nil : UUID()
                }
            )
            .accessibilityHidden(true)
            if let selection {
                Path { path in
                    path.move(to: CGPoint(x: selection.x, y: frame.minY))
                    path.addLine(to: CGPoint(x: selection.x, y: frame.maxY))
                }
                .stroke(selection.point.color.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .allowsHitTesting(false).accessibilityHidden(true)
                if selection.point.y != nil {
                    Circle().fill(selection.point.color).frame(width: 8, height: 8)
                        .position(x: selection.x, y: selection.y).allowsHitTesting(false).accessibilityHidden(true)
                }
            }
        }
        .onChange(of: samples) { _, samples in
            if let selection { select(at: selection.touch, frame: frame, samples: samples) }
        }
    }

    private func select(at touch: CGPoint, frame: CGRect, samples: [ChartInspectionPoint]) {
        guard let point = samples.min(by: { abs($0.x - (touch.x - frame.minX)) < abs($1.x - (touch.x - frame.minX)) }) else {
            selection = nil; return
        }
        selection = Selection(point: point, frame: frame, touch: touch)
    }

}

/// Native recognizers let the enclosing scroll view cancel an unrecognized hold.
/// A zero-distance SwiftUI drag can capture scrolling even when sequenced after a hold.
private struct ChartInspectionTouchSurface: UIViewRepresentable {
    var onTap: (CGPoint) -> Void
    var onInspect: (CGPoint) -> Void
    var onScrubbingChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(surface: self) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let hold = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.inspect(_:)))
        hold.minimumPressDuration = 0.4
        hold.allowableMovement = 8
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tap(_:)))
        tap.require(toFail: hold)
        view.addGestureRecognizer(hold)
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.surface = self
    }

    final class Coordinator: NSObject {
        var surface: ChartInspectionTouchSurface
        private var inspecting = false

        init(surface: ChartInspectionTouchSurface) { self.surface = surface }

        @objc func tap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            surface.onTap(recognizer.location(in: recognizer.view))
        }

        @objc func inspect(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began:
                inspecting = true
                surface.onScrubbingChanged(true)
                surface.onInspect(recognizer.location(in: recognizer.view))
            case .changed:
                surface.onInspect(recognizer.location(in: recognizer.view))
            case .ended:
                surface.onInspect(recognizer.location(in: recognizer.view))
                finishInspection()
            case .cancelled, .failed:
                finishInspection()
            default:
                break
            }
        }

        private func finishInspection() {
            // An ordinary scroll must not extend a previous tap's tooltip lifetime.
            guard inspecting else { return }
            inspecting = false
            surface.onScrubbingChanged(false)
        }
    }
}
