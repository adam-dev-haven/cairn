import SwiftUI

enum NavSection: String, CaseIterable, Identifiable {
    case today, week, mountain, boulder, bar, coach, journal, settings
    var id: String { rawValue }
    var name: String {
        switch self {
        case .today: "Today"
        case .week: "This week"
        case .mountain: "The mountain"
        case .boulder: "Bouldering"
        case .bar: "Calisthenics"
        case .coach: "Coach"
        case .journal: "Journal"
        case .settings: "Settings"
        }
    }
    var symbol: String {
        switch self {
        case .today: "sun.horizon"
        case .week: "calendar"
        case .mountain: "mountain.2"
        case .boulder: "figure.climbing"
        case .bar: "figure.strengthtraining.functional"
        case .coach: "person.wave.2"
        case .journal: "book.closed"
        case .settings: "slider.horizontal.3"
        }
    }
    var key: KeyEquivalent {
        switch self {
        case .today: "1"
        case .week: "2"
        case .mountain: "3"
        case .boulder: "4"
        case .bar: "5"
        case .coach: "7"
        case .journal: "6"
        case .settings: ","
        }
    }
}

@Observable
final class Navigator {
    var section: NavSection = ProcessInfo.processInfo.environment["CAIRN_SECTION"].flatMap(NavSection.init(rawValue:)) ?? .today
    /// Bump to ask Today to open the logger for the first unfinished item.
    var logRequest = ProcessInfo.processInfo.environment["CAIRN_LOG"] != nil ? 1 : 0
    /// The frosted info bubble at the bottom of the screen, if one is up.
    var bubble: Bubble?

    func show(_ title: String, symbol: String = "info.circle", @ViewBuilder _ content: () -> some View) {
        withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
            bubble = Bubble(title: title, symbol: symbol, content: AnyView(content()))
        }
    }

    func dismissBubble() {
        withAnimation(.easeOut(duration: 0.2)) { bubble = nil }
    }
}

struct Bubble: Identifiable {
    let id = UUID()
    var title: String
    var symbol: String
    var content: AnyView
}

/// Small explanations and quick edits live here instead of popovers or full
/// sheets: a frosted card that rises from the bottom, over whatever you were
/// looking at, and goes away with a tap outside, a swipe down, or ✕.
struct BubbleHost: View {
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    @State private var drag: CGFloat = 0
    @State private var contentHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if nav.bubble != nil {
                Color.black.opacity(0.08)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { nav.dismissBubble() }
                    .transition(.opacity)
            }
            if let b = nav.bubble {
                VStack(alignment: .leading, spacing: 12) {
                    Capsule().fill(Ink.lineStrong).frame(width: 36, height: 4).frame(maxWidth: .infinity)
                    HStack(spacing: 10) {
                        Image(systemName: b.symbol).font(.system(size: 15, weight: .medium)).foregroundStyle(Ink.red)
                        Text(b.title).font(Face.title).foregroundStyle(Ink.ink)
                        Spacer()
                        Button { nav.dismissBubble() } label: { Image(systemName: "xmark") }
                            .buttonStyle(QuietIconButton())
                            .accessibilityLabel("Close")
                            .keyboardShortcut(.cancelAction)
                    }
                    // As tall as the content, up to a cap; beyond that it scrolls.
                    ScrollView {
                        b.content
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GeometryReader { g in
                                Color.clear.preference(key: BubbleHeight.self, value: g.size.height)
                            })
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(height: min(max(contentHeight, 20), compact ? 360 : 440))
                    .onPreferenceChange(BubbleHeight.self) { contentHeight = $0 }
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(.regularMaterial)
                        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Ink.sheet.opacity(0.86)))
                        .shadow(color: Ink.wash.opacity(0.18), radius: 28, y: 12)
                )
                .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 1))
                .frame(maxWidth: compact ? .infinity : 520)
                .padding(.horizontal, compact ? 10 : 0)
                .padding(.bottom, compact ? 8 : 24)
                .offset(y: max(0, drag))
                .gesture(DragGesture()
                    .onChanged { drag = $0.translation.height }
                    .onEnded { v in
                        if v.translation.height > 80 { nav.dismissBubble() }
                        withAnimation(.spring(duration: 0.3)) { drag = 0 }
                    })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .id(b.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

struct Banner: View {
    enum Tone { case red, quiet }
    var text: String
    var tone: Tone
    var action: (String, () -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(tone == .red ? Ink.red : Ink.ink).frame(width: 7, height: 7)
            Text(text).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let action {
                Button(action.0, action: action.1).buttonStyle(InkButtonStyle(filled: false))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.sheet).shadow(color: Ink.ink.opacity(0.08), radius: 14, y: 6))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Ink.line))
        .frame(maxWidth: 720)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct MiniRoute: View {
    var progress: Double
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            var ridge = Path()
            ridge.move(to: CGPoint(x: 0, y: h))
            ridge.addLine(to: CGPoint(x: w * 0.30, y: h * 0.45))
            ridge.addLine(to: CGPoint(x: w * 0.42, y: h * 0.55))
            ridge.addLine(to: CGPoint(x: w * 0.66, y: h * 0.04))
            ridge.addLine(to: CGPoint(x: w * 0.80, y: h * 0.38))
            ridge.addLine(to: CGPoint(x: w, y: h * 0.62))
            ridge.addLine(to: CGPoint(x: w, y: h))
            ridge.closeSubpath()
            ctx.fill(ridge, with: .linearGradient(Gradient(colors: [Ink.wash.opacity(0.28), Ink.wash.opacity(0.02)]),
                                                  startPoint: CGPoint(x: w * 0.6, y: 0), endPoint: CGPoint(x: w * 0.5, y: h)))
            let pts = [CGPoint(x: w * 0.04, y: h * 0.98), CGPoint(x: w * 0.36, y: h * 0.80), CGPoint(x: w * 0.24, y: h * 0.62),
                       CGPoint(x: w * 0.52, y: h * 0.42), CGPoint(x: w * 0.46, y: h * 0.26), CGPoint(x: w * 0.66, y: h * 0.06)]
            var route = Path(); route.addLines(pts)
            ctx.stroke(route, with: .color(Ink.ink.opacity(0.35)), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
            let p = Polyline(pts).point(at: max(0, min(1, progress)))
            ctx.stroke(Polyline(pts).path(upTo: progress), with: .color(Ink.ink), lineWidth: 1.2)
            ctx.fill(Path(ellipseIn: CGRect(x: p.x - 3.5, y: p.y - 3.5, width: 7, height: 7)), with: .color(Ink.red))
        }
        .accessibilityLabel("Route progress \(Int(progress * 100)) percent")
    }
}

/// Stacked stones. The mark.
struct CairnMark: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let stones: [(CGFloat, CGFloat, CGFloat)] = [(0.5, 0.86, 0.95), (0.47, 0.60, 0.72), (0.53, 0.38, 0.52), (0.5, 0.17, 0.34)]
            for (i, s) in stones.enumerated() {
                let sw = w * s.2, sh = h * 0.2
                let r = CGRect(x: w * s.0 - sw / 2, y: h * s.1 - sh / 2, width: sw, height: sh)
                ctx.fill(Path(ellipseIn: r), with: .color(i == 3 ? Ink.red : Ink.ink))
            }
        }
    }
}

/// Arc-length walking along a polyline, shared by the route drawings.
struct Polyline {
    var points: [CGPoint]
    init(_ points: [CGPoint]) { self.points = points }

    var lengths: [CGFloat] {
        zip(points, points.dropFirst()).map { hypot($1.x - $0.x, $1.y - $0.y) }
    }

    func point(at t: Double) -> CGPoint {
        guard points.count > 1 else { return points.first ?? .zero }
        let ls = lengths
        let total = ls.reduce(0, +)
        var target = CGFloat(max(0, min(1, t))) * total
        for (i, l) in ls.enumerated() {
            if target <= l || i == ls.count - 1 {
                let f = l > 0 ? min(1, target / l) : 0
                let a = points[i], b = points[i + 1]
                return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
            }
            target -= l
        }
        return points.last!
    }

    func path(upTo t: Double) -> Path {
        var p = Path()
        guard points.count > 1 else { return p }
        let ls = lengths
        let total = ls.reduce(0, +)
        var target = CGFloat(max(0, min(1, t))) * total
        p.move(to: points[0])
        for (i, l) in ls.enumerated() {
            if target >= l { p.addLine(to: points[i + 1]); target -= l; continue }
            let f = l > 0 ? target / l : 0
            let a = points[i], b = points[i + 1]
            p.addLine(to: CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f))
            break
        }
        return p
    }
}

private struct BubbleHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
