import SwiftUI

/// Geometry of the drawn mountain, in unit coordinates (0…1 both ways, y down).
enum Peak {
    static let keyRidge: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.74), CGPoint(x: 0.09, y: 0.66), CGPoint(x: 0.16, y: 0.60), CGPoint(x: 0.22, y: 0.50),
        CGPoint(x: 0.28, y: 0.46), CGPoint(x: 0.33, y: 0.40), CGPoint(x: 0.37, y: 0.42), CGPoint(x: 0.42, y: 0.27),
        CGPoint(x: 0.46, y: 0.20), CGPoint(x: 0.50, y: 0.10), CGPoint(x: 0.535, y: 0.04), CGPoint(x: 0.57, y: 0.10),
        CGPoint(x: 0.61, y: 0.17), CGPoint(x: 0.65, y: 0.15), CGPoint(x: 0.70, y: 0.09), CGPoint(x: 0.75, y: 0.20),
        CGPoint(x: 0.81, y: 0.30), CGPoint(x: 0.87, y: 0.37), CGPoint(x: 0.93, y: 0.46), CGPoint(x: 1.00, y: 0.50),
    ]

    /// The ridge with rock in it: midpoint displacement between key points.
    static let ridge: [CGPoint] = {
        var rng = SeededRandom(seed: 314)
        var pts = keyRidge
        for level in 0..<4 {
            var next: [CGPoint] = [pts[0]]
            for (a, b) in zip(pts, pts.dropFirst()) {
                let len = hypot(b.x - a.x, b.y - a.y)
                let amp = len * (level == 0 ? 0.18 : 0.26)
                let mid = CGPoint(x: (a.x + b.x) / 2 + CGFloat(rng.next(-0.15, 0.15)) * len,
                                  y: (a.y + b.y) / 2 + CGFloat(rng.next(-1, 1)) * amp)
                next.append(mid)
                next.append(b)
            }
            pts = next
        }
        return pts
    }()

    static let far: [CGPoint] = [
        CGPoint(x: 0.00, y: 0.46), CGPoint(x: 0.08, y: 0.36), CGPoint(x: 0.16, y: 0.39), CGPoint(x: 0.25, y: 0.27),
        CGPoint(x: 0.33, y: 0.32), CGPoint(x: 0.62, y: 0.28), CGPoint(x: 0.76, y: 0.16), CGPoint(x: 0.82, y: 0.11),
        CGPoint(x: 0.88, y: 0.19), CGPoint(x: 0.95, y: 0.25), CGPoint(x: 1.00, y: 0.23),
    ]

    /// The route: wide switchbacks up the snowfield to the summit. Reads
    /// upward; the future is always above you.
    static let route: [CGPoint] = [
        CGPoint(x: 0.33, y: 0.965), CGPoint(x: 0.64, y: 0.905), CGPoint(x: 0.38, y: 0.83), CGPoint(x: 0.66, y: 0.75),
        CGPoint(x: 0.42, y: 0.665), CGPoint(x: 0.63, y: 0.58), CGPoint(x: 0.45, y: 0.49), CGPoint(x: 0.60, y: 0.40),
        CGPoint(x: 0.48, y: 0.31), CGPoint(x: 0.575, y: 0.22), CGPoint(x: 0.515, y: 0.14), CGPoint(x: 0.535, y: 0.05),
    ]

    static func ridgeY(at x: CGFloat) -> CGFloat {
        for (a, b) in zip(ridge, ridge.dropFirst()) where x >= min(a.x, b.x) && x <= max(a.x, b.x) {
            let f = (x - a.x) / max(0.0001, b.x - a.x)
            return a.y + (b.y - a.y) * f
        }
        return ridge.last!.y
    }

    static func scaled(_ pts: [CGPoint], _ size: CGSize) -> [CGPoint] {
        pts.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
    }
}

/// The sumi-e mountain: washes, brush streaks running down from the ridge,
/// white snow gullies left unpainted, lee faces darker. Deterministic.
struct MountainPainting: View {
    var body: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            let w = size.width, h = size.height

            // Far range — a pale wash, softened.
            var far = Path()
            far.move(to: CGPoint(x: 0, y: h))
            far.addLines(Peak.scaled(Peak.far, size))
            far.addLine(to: CGPoint(x: w, y: h))
            far.closeSubpath()
            var farCtx = ctx
            farCtx.addFilter(.blur(radius: 5))
            farCtx.fill(far, with: .linearGradient(Gradient(colors: [Ink.wash.opacity(0.13), Ink.wash.opacity(0.0)]),
                                                   startPoint: CGPoint(x: 0, y: h * 0.12), endPoint: CGPoint(x: 0, y: h * 0.55)))

            // Main mass — paper first so the far range sits behind, then a wash
            // that fades into snow.
            var mass = Path()
            mass.move(to: CGPoint(x: 0, y: h))
            mass.addLines(Peak.scaled(Peak.ridge, size))
            mass.addLine(to: CGPoint(x: w, y: h))
            mass.closeSubpath()
            ctx.fill(mass, with: .color(Ink.paper))
            var washCtx = ctx
            washCtx.clip(to: mass)
            washCtx.addFilter(.blur(radius: 16))
            washCtx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(Gradient(stops: [
                .init(color: Ink.wash.opacity(0.34), location: 0.0),
                .init(color: Ink.wash.opacity(0.12), location: 0.30),
                .init(color: Ink.wash.opacity(0.0), location: 0.58),
            ]), startPoint: CGPoint(x: 0, y: h * 0.04), endPoint: CGPoint(x: 0, y: h * 0.95)))

            // Rock ribs: the spurs that fall from each peak, as broad soft strokes.
            let ribs: [[CGPoint]] = [
                [CGPoint(x: 0.535, y: 0.05), CGPoint(x: 0.49, y: 0.22), CGPoint(x: 0.43, y: 0.40), CGPoint(x: 0.36, y: 0.55)],
                [CGPoint(x: 0.535, y: 0.05), CGPoint(x: 0.60, y: 0.25), CGPoint(x: 0.66, y: 0.42)],
                [CGPoint(x: 0.70, y: 0.09), CGPoint(x: 0.73, y: 0.28), CGPoint(x: 0.79, y: 0.48)],
                [CGPoint(x: 0.33, y: 0.40), CGPoint(x: 0.29, y: 0.52), CGPoint(x: 0.22, y: 0.66)],
            ]
            var ribCtx = ctx
            ribCtx.clip(to: mass)
            ribCtx.addFilter(.blur(radius: 7))
            for rib in ribs {
                var p = Path(); p.addLines(Peak.scaled(rib, size))
                ribCtx.stroke(p, with: .linearGradient(Gradient(colors: [Ink.wash.opacity(0.32), Ink.wash.opacity(0)]),
                                                       startPoint: CGPoint(x: rib[0].x * w, y: rib[0].y * h),
                                                       endPoint: CGPoint(x: rib.last!.x * w, y: rib.last!.y * h)),
                              style: StrokeStyle(lineWidth: w * 0.022, lineCap: .round, lineJoin: .round))
            }

            // Brush streaks. More ink high up, gullies left white by a slow wave,
            // lee faces (ridge falling to the right) darker.
            var rng = SeededRandom(seed: 2026)
            var streaks = ctx
            streaks.clip(to: mass)
            for _ in 0..<1400 {
                let ux = CGFloat(rng.next(0.0, 1.0))
                let top = Peak.ridgeY(at: ux)
                if rng.next() > Double(0.25 + 0.9 * (1 - top)) { continue }
                let band = (sin(ux * 29) + sin(ux * 11.3 + 1.3) + 0.6 * sin(ux * 53 + 0.4)) / 2.6
                if Double(band) + rng.next(-0.3, 0.3) < -0.05 { continue }
                let slope = (Peak.ridgeY(at: min(1, ux + 0.008)) - Peak.ridgeY(at: max(0, ux - 0.008))) / 0.016
                let lee: Double = slope > 0 ? 1.35 : 0.8
                let startY = top + CGFloat(rng.next(-0.002, 0.03))
                let long = rng.next() < 0.18
                let height = CGFloat(long ? rng.next(0.18, 0.42) : rng.next(0.03, 0.16)) * (1.02 - top)
                let lean = max(-0.2, min(0.2, slope * 0.14)) + CGFloat(rng.next(-0.035, 0.035))
                let x0 = ux * w, y0 = startY * h
                let x1 = x0 + lean * height * h, y1 = y0 + height * h
                let width = CGFloat(rng.next(0.5, long ? 4.0 : 7.5))
                var stroke = Path()
                stroke.move(to: CGPoint(x: x0, y: y0))
                stroke.addQuadCurve(to: CGPoint(x: x1, y: y1),
                                    control: CGPoint(x: (x0 + x1) / 2 + CGFloat(rng.next(-5, 5)), y: (y0 + y1) / 2))
                let alpha = min(0.75, rng.next(0.08, 0.5) * Double(1.25 - top) * lee)
                var sctx = streaks
                if rng.next() < 0.3 { sctx.addFilter(.blur(radius: CGFloat(rng.next(0.8, 3.0)))) }
                sctx.stroke(stroke, with: .linearGradient(Gradient(stops: [
                    .init(color: Ink.wash.opacity(alpha), location: 0),
                    .init(color: Ink.wash.opacity(alpha * 0.6), location: 0.45),
                    .init(color: Ink.wash.opacity(0), location: 1)]),
                    startPoint: CGPoint(x: x0, y: y0), endPoint: CGPoint(x: x1, y: y1)),
                    style: StrokeStyle(lineWidth: width, lineCap: .round))
            }

            // The ridge line: a pen with a little tremor, heavier on the peaks.
            let pts = Peak.scaled(Peak.ridge, size)
            for (a, b) in zip(pts, pts.dropFirst()) {
                var seg = Path(); seg.move(to: a); seg.addLine(to: b)
                let height = 1 - (a.y + b.y) / (2 * h)
                ctx.stroke(seg, with: .color(Ink.wash.opacity(0.55 + 0.35 * Double(height))),
                           style: StrokeStyle(lineWidth: 0.8 + 1.4 * height, lineCap: .round))
            }

            // Base mist — the snowfield where the route starts.
            let mist = Path(CGRect(x: 0, y: h * 0.72, width: w, height: h * 0.28))
            ctx.fill(mist, with: .linearGradient(Gradient(colors: [Ink.paper.opacity(0), Ink.paper]),
                                                 startPoint: CGPoint(x: 0, y: h * 0.72), endPoint: CGPoint(x: 0, y: h * 0.88)))
        }
        .accessibilityHidden(true)
    }
}

/// The route up to `t` (0…1), animatable so the line draws as you climb.
struct RouteLine: Shape {
    var t: Double
    var animatableData: Double {
        get { t }
        set { t = newValue }
    }
    func path(in rect: CGRect) -> Path {
        Polyline(Peak.scaled(Peak.route, rect.size)).path(upTo: t)
    }
}

struct FullRoute: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addLines(Peak.scaled(Peak.route, rect.size))
        return p
    }
}

/// The whole map: painting, route, camps, you, and the side quests.
struct MountainMap: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(Navigator.self) private var nav
    @AppStorage("mountain.lastSeen") private var lastSeen: Double = 0
    @State private var shown: Double = 0

    var weeks: Int { model.plan.weeks.count }

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let line = Polyline(Peak.scaled(Peak.route, size))
            let t = shown / Double(weeks)
            ZStack(alignment: .topLeading) {
                MountainPainting()

                FullRoute()
                    .stroke(Ink.ink.opacity(0.35), style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [1, 5]))
                RouteLine(t: t)
                    .stroke(Ink.ink.opacity(0.85), style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))

                // Camps, labelled in the left gutter like a topo.
                ForEach(0...weeks, id: \.self) { k in
                    let p = line.point(at: Double(k) / Double(weeks))
                    let reached = Double(k) <= shown + 0.001
                    let phaseStart = isPhaseStart(k)
                    Circle()
                        .fill(reached ? Ink.ink : Ink.paper)
                        .overlay(Circle().strokeBorder(Ink.ink, lineWidth: 1.1))
                        .frame(width: phaseStart ? 9 : 6, height: phaseStart ? 9 : 6)
                        .position(p)
                    if let label = campLabel(k) {
                        CampLabel(label: label, anchor: p, labelY: labelYs(line: line)[k] ?? p.y,
                                  gutter: compact ? size.width * 0.27 : min(230, size.width * 0.22), reached: reached)
                    }
                }

                // Side quests on spurs to the right of the route.
                ForEach(Array(Quests.badges.enumerated()), id: \.element.id) { _, badge in
                    let group = Quests.badges.filter { $0.nearWeek == badge.nearWeek }
                    let j = group.firstIndex(of: badge) ?? 0
                    let anchor = line.point(at: (Double(badge.nearWeek) - 0.5) / Double(weeks))
                    let flagPos = CGPoint(x: size.width * 0.70 + CGFloat(j) * 28 + CGFloat(badge.nearWeek % 2) * 14, y: anchor.y - 4 - CGFloat(j) * 3)
                    Path { p in p.move(to: anchor); p.addLine(to: flagPos) }
                        .stroke(Ink.ink.opacity(0.25), style: StrokeStyle(lineWidth: 0.8, dash: [1, 3]))
                    Button {
                        nav.show(badge.name, symbol: badge.symbol) { QuestPopover(badge: badge) }
                    } label: {
                        QuestFlag(badge: badge, unlocked: model.store.badges[badge.id] != nil)
                    }
                    .buttonStyle(.plain)
                    .position(x: flagPos.x + 6, y: flagPos.y - 9)
                }

                // You
                let you = line.point(at: t)
                YouMarker()
                    .position(x: you.x, y: you.y - 14)
                    .accessibilityLabel("You, at \(model.currentAltitude) metres")
            }
        }
        .onAppear {
            let target = model.routeProgress
            if reduceMotion || lastSeen > target {
                shown = target
            } else {
                shown = lastSeen
                withAnimation(.spring(duration: 2.2, bounce: 0.12).delay(0.35)) { shown = target }
            }
            lastSeen = target
        }
        .onChange(of: model.routeProgress) { _, new in
            withAnimation(reduceMotion ? nil : .spring(duration: 1.4, bounce: 0.1)) { shown = new }
            lastSeen = new
        }
    }

    // Phase boundaries become labelled camps with leader lines.
    func isPhaseStart(_ k: Int) -> Bool {
        if k == 0 || k == weeks { return true }
        return model.template(k).phase != model.template(k + 1).phase
    }

    /// Label rows pushed apart so no two overlap; leader lines elbow to the camp.
    func labelYs(line: Polyline) -> [Int: CGFloat] {
        let ks = (0...weeks).filter(isPhaseStart)
        var ys = ks.map { line.point(at: Double($0) / Double(weeks)).y }
        let gap: CGFloat = 34
        // Order by y, then enforce spacing top to bottom.
        let order = ys.indices.sorted { ys[$0] < ys[$1] }
        var last: CGFloat = -.infinity
        for i in order {
            if ys[i] < last + gap { ys[i] = last + gap }
            last = ys[i]
        }
        return Dictionary(uniqueKeysWithValues: zip(ks, ys))
    }

    func campLabel(_ k: Int) -> (String, String)? {
        guard isPhaseStart(k) else { return nil }
        if k == weeks {
            if compact { return ("Summit", Day.short(model.summitDate)) }
            return ("Summit · \(model.altitude(atProgress: Double(weeks)).formatted()) m", "Test week, \(Day.short(model.summitDate))")
        }
        let next = model.template(k + 1)
        let idx = model.plan.timeline.firstIndex { $0.template == k + 1 } ?? k
        let name = k == 0 ? "Base camp" : "Camp \(k)"
        let phase = next.phase == .deload ? "Deload hut" : next.phase.name
        if compact { return (phase, "wk \(k + 1) · \(Day.short(model.weekStart(idx)))") }
        return ("\(name) · \(phase)", "Week \(k + 1) · \(Day.short(model.weekStart(idx)))")
    }

}

struct CampLabel: View {
    var label: (String, String)
    var anchor: CGPoint
    var labelY: CGFloat
    var gutter: CGFloat
    var reached: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            Path { p in
                p.move(to: CGPoint(x: gutter + 8, y: labelY))
                p.addLine(to: CGPoint(x: gutter + 24, y: labelY))
                p.addLine(to: CGPoint(x: gutter + 40, y: anchor.y))
                p.addLine(to: CGPoint(x: anchor.x - 8, y: anchor.y))
            }
            .stroke(Ink.ink.opacity(reached ? 0.55 : 0.3), style: StrokeStyle(lineWidth: 0.6, dash: reached ? [] : [2, 3]))
            VStack(alignment: .trailing, spacing: 1) {
                Text(label.0).font(.system(size: 11.5, weight: .semibold).width(.expanded)).foregroundStyle(Ink.ink)
                Text(label.1).font(.system(size: 10.5)).foregroundStyle(Ink.ink2)
            }
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(Ink.paper.opacity(0.82)).blur(radius: 2))
            .frame(width: gutter, alignment: .trailing)
            .position(x: gutter / 2, y: labelY)
        }
        .allowsHitTesting(false)
    }
}

struct YouMarker: View {
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        ZStack {
            Circle().fill(Ink.red.opacity(0.18)).frame(width: 30, height: 30)
                .scaleEffect(pulse ? 1.25 : 0.9)
                .opacity(pulse ? 0 : 1)
            Circle().fill(Ink.red).frame(width: 22, height: 22)
                .shadow(color: Ink.red.opacity(0.35), radius: 6, y: 3)
            Image(systemName: "figure.climbing").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 2.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }
}

struct QuestFlag: View {
    var badge: Badge
    var unlocked: Bool
    @State private var hover = false
    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Ink.ink).frame(width: 1, height: 18).offset(x: 0, y: 0)
            FlagShape()
                .fill(unlocked ? Ink.red : Ink.paper)
                .overlay(FlagShape().stroke(unlocked ? Ink.red : Ink.ink, lineWidth: 1))
                .frame(width: 12, height: 9)
                .offset(x: 1, y: 0)
        }
        .frame(width: 14, height: 18, alignment: .topLeading)
        .scaleEffect(hover ? 1.35 : 1, anchor: .bottomLeading)
        .animation(.spring(duration: 0.25), value: hover)
        .onHover { hover = $0 }
        .help("\(badge.name) — \(badge.detail)")
        .contentShape(Rectangle().inset(by: -8))
        .accessibilityLabel("\(badge.name), \(unlocked ? "unlocked" : "not yet")")
        .accessibilityAddTraits(.isButton)
    }
}

struct FlagShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + r.height * 0.45))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

struct QuestPopover: View {
    @Environment(AppModel.self) private var model
    var badge: Badge
    var body: some View {
        let date = model.store.badges[badge.id].flatMap(Day.date)
        // Lives in the bottom bubble, which already shows the name and icon.
        VStack(alignment: .leading, spacing: 10) {
            Text(badge.detail).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
            Text(date.map { "Planted \(Day.short($0))" } ?? "\(badge.trail.name) · near week \(badge.nearWeek)")
                .font(Face.small).foregroundStyle(date != nil ? Ink.red : Ink.ink2)
            QuestActions(badge: badge)
        }
    }
}

// MARK: - The page

struct MountainPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @State private var newGoal = ""

    var body: some View {
        Page(title: "The mountain",
             subtitle: "\(model.plan.name) · \(Day.short(model.startDate)) → \(Day.short(model.endDate)) · summit at \(Int(AppModel.summitAltitude).formatted()) m") {
            VStack(alignment: .leading, spacing: 40) {
                if compact {
                    VStack(alignment: .leading, spacing: 18) {
                        MountainMap().frame(height: 560).padding(.horizontal, -16)
                        AltitudeColumn()
                    }
                } else {
                    ZStack(alignment: .topTrailing) {
                        MountainMap()
                            .frame(height: 640)
                        AltitudeColumn()
                            .padding(.top, 8)
                    }
                }

                QuestBoard()
                MissionBoard()
                GoalBoard()
                RouteLog()
            }
        }
    }
}

struct AltitudeColumn: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    var body: some View {
        let idx = model.calendarIndex(for: model.today)
        VStack(alignment: compact ? .leading : .trailing, spacing: 16) {
            VStack(alignment: compact ? .leading : .trailing, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(model.currentAltitude.formatted()).font(Face.display(compact ? 40 : 52)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text("m").font(Face.body).foregroundStyle(Ink.ink2)
                }
                Text(model.beforeStart ? "Base camp" : model.finished ? "Summit" : "between camp \(max(0, (model.currentWeek?.number ?? 1) - 1)) and \(model.currentWeek?.number ?? 1)")
                    .font(Face.small).foregroundStyle(Ink.ink2)
            }
            .foregroundStyle(Ink.ink)
            HStack(spacing: 22) {
                Stat(value: "\(model.streak)", label: "green weeks", size: 22)
                Stat(value: "\(model.totalPoints)", label: "points", size: 22)
                Stat(value: "\(model.store.badges.count)/\(Quests.badges.count)", label: "flags", size: 22)
            }
            if idx >= 0, idx < model.plan.timeline.count {
                Text("Next camp \(Day.short(model.weekStart(idx + 1)))").font(Face.small).foregroundStyle(Ink.ink2)
            }
        }
        .animation(.spring(duration: 0.8), value: model.currentAltitude)
    }
}

struct QuestBoard: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "Side quests", detail: "Flags off the route. Most plant themselves from your logs.")
            AdaptiveStack(spacing: 18) {
                ForEach(QuestTrail.allCases, id: \.self) { trail in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trail.name).font(Face.heading).foregroundStyle(Ink.ink).padding(.bottom, 6)
                        ForEach(Quests.badges.filter { $0.trail == trail }) { b in
                            QuestRow(badge: b)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .sheetCard(padding: 16)
                }
            }
        }
    }
}

struct QuestRow: View {
    @Environment(AppModel.self) private var model
    var badge: Badge
    var body: some View {
        let date = model.store.badges[badge.id].flatMap(Day.date)
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle().fill(date != nil ? Ink.red : Ink.sand).frame(width: 28, height: 28)
                Image(systemName: badge.symbol).font(.system(size: 12, weight: .medium))
                    .foregroundStyle(date != nil ? .white : Ink.ink2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.ink)
                Text(badge.detail).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                if let date {
                    Text(Day.short(date)).font(Face.tiny).foregroundStyle(Ink.red)
                } else if model.store.revokedBadges.contains(badge.id) {
                    Button("Taken back · restore") { model.restoreBadge(badge.id) }
                        .buttonStyle(TextLinkStyle()).font(Face.small).foregroundStyle(Ink.ink2)
                } else if badge.manual {
                    Button("I did this") { model.restoreBadge(badge.id) }
                        .buttonStyle(TextLinkStyle()).font(Face.small).foregroundStyle(Ink.ink)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contextMenu {
            if date != nil {
                Button("Take it back") { model.revokeBadge(badge.id) }
            } else if model.store.revokedBadges.contains(badge.id) {
                Button("Restore") { model.restoreBadge(badge.id) }
            } else if badge.manual {
                Button("Mark as done") { model.restoreBadge(badge.id) }
            }
        }
    }
}

struct MissionBoard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "Side missions", detail: "Weekly and monthly. They reset; they never expire on you.")
            AdaptiveStack(spacing: 14) {
                ForEach(Quests.missions) { m in
                    let done = model.missionDone(m, on: model.today)
                    let auto = ["drill", "never-twice", "floor-four"].contains(m.id)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: m.symbol).font(.system(size: 14)).foregroundStyle(done ? Ink.red : Ink.ink)
                            Spacer()
                            Text(m.period == .week ? "this week" : "this month").font(Face.tiny).foregroundStyle(Ink.ink2)
                        }
                        Text(m.title).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Ink.ink)
                        Text(m.detail).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        if auto {
                            Label(done ? "Done" : "Tracks itself", systemImage: done ? "checkmark.circle.fill" : "circle.dashed")
                                .font(Face.small).foregroundStyle(done ? Ink.red : Ink.ink2)
                        } else {
                            Button { model.toggleMission(m, on: model.today) } label: {
                                Label(done ? "Done" : "Mark done", systemImage: done ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain).font(Face.small).foregroundStyle(done ? Ink.red : Ink.ink)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: compact ? nil : 150, alignment: .topLeading)
                    .sheetCard(padding: 16)
                }
            }
        }
    }
}

struct GoalBoard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @State private var title = ""
    @State private var byWeek = 14
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "Your own goals", detail: "Side goals you set. They sit beside the route until you tick them.")
            VStack(spacing: 0) {
                ForEach(model.store.goals) { g in
                    HStack(spacing: 12) {
                        Button {
                            model.mutate { s in
                                if let i = s.goals.firstIndex(where: { $0.id == g.id }) {
                                    s.goals[i].done = s.goals[i].done == nil ? Day.key(model.today) : nil
                                }
                            }
                        } label: {
                            Image(systemName: g.done != nil ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 16)).foregroundStyle(g.done != nil ? Ink.red : Ink.ink2)
                        }.buttonStyle(.plain)
                        Text(g.title).font(Face.body).foregroundStyle(Ink.ink).strikethrough(g.done != nil, color: Ink.ink3)
                        Spacer()
                        if let w = g.byWeek { Text("by week \(w)").font(Face.small).foregroundStyle(Ink.ink2) }
                        Button { model.mutate { $0.goals.removeAll { $0.id == g.id } } } label: { Image(systemName: "xmark") }
                            .buttonStyle(QuietIconButton())
                    }
                    .padding(.vertical, 10)
                    Rule(seed: g.title.count)
                }
                AdaptiveStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "plus").foregroundStyle(Ink.ink2)
                        TextField("Add a goal — “Send the purple V3 in the cave”", text: $title)
                            .textFieldStyle(.plain).font(Face.body)
                            .onSubmit(add)
                    }
                    HStack(spacing: 12) {
                        Picker("By week", selection: $byWeek) {
                            ForEach(1...model.plan.weeks.count, id: \.self) { Text("by week \($0)").tag($0) }
                        }.labelsHidden().frame(width: 120)
                        if compact { Spacer() }
                        Button("Add", action: add).buttonStyle(InkButtonStyle()).disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(.top, 12)
            }
            .sheetCard(padding: 18)
        }
    }

    func add() {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        model.mutate { $0.goals.append(SideGoal(title: t, byWeek: byWeek)) }
        title = ""
    }
}

struct RouteLog: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "The route so far", detail: "Every calendar week of the climb. Repeats and return weeks show where the plan bent.")
            VStack(spacing: 0) {
                let cur = model.calendarIndex(for: model.today)
                ForEach(Array(model.plan.timeline.enumerated()), id: \.element.id) { i, e in
                    let w = model.blockWeek(at: i)!
                    let score = model.score(week: i)
                    HStack(spacing: 14) {
                        Circle().fill(Ink.phaseDot(w.phase)).frame(width: 10, height: 10)
                        if compact {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("Week \(w.number) · \(w.phase.name)").font(.system(size: 13, weight: .semibold))
                                Text(Day.short(model.weekStart(i))).font(Face.small).foregroundStyle(Ink.ink2)
                            }
                        } else {
                            Text("Week \(w.number)").font(.system(size: 13, weight: .semibold)).frame(width: 70, alignment: .leading)
                            Text(w.phase.name).font(Face.body).foregroundStyle(Ink.ink2).frame(width: 90, alignment: .leading)
                            Text("\(Day.short(model.weekStart(i))) – \(Day.short(Day.add(6, to: model.weekStart(i))))")
                                .font(Face.body).foregroundStyle(Ink.ink2).monospacedDigit().frame(width: 140, alignment: .leading)
                        }
                        if e.reason == .repeated { Tag(text: "repeat") }
                        if e.reason == .recovery { Tag(text: "return week") }
                        Spacer()
                        if i <= cur {
                            Text("\(score.total) pts").font(Face.body).monospacedDigit().foregroundStyle(Ink.ink2)
                            Image(systemName: model.isGreen(week: i) ? "checkmark.circle.fill" : (i < cur ? "circle.dashed" : "circle"))
                                .foregroundStyle(model.isGreen(week: i) ? Ink.green : Ink.ink3)
                        }
                        if i == cur { Circle().fill(Ink.red).frame(width: 6, height: 6) }
                    }
                    .padding(.vertical, 8)
                    .opacity(i > cur ? 0.6 : 1)
                }
            }
            .sheetCard(padding: 18)
        }
    }
}

struct Tag: View {
    var text: String
    var body: some View {
        Text(text).font(Face.tiny).foregroundStyle(Ink.ink2)
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(Ink.sand))
    }
}

/// What you can do with one quest: plant it by hand, take it back if it was
/// planted by mistake, or restore one you took back.
struct QuestActions: View {
    @Environment(AppModel.self) private var model
    var badge: Badge
    var body: some View {
        let planted = model.store.badges[badge.id] != nil
        let revoked = model.store.revokedBadges.contains(badge.id)
        VStack(alignment: .leading, spacing: 6) {
            if planted {
                Button("Take it back") { model.revokeBadge(badge.id) }.buttonStyle(InkButtonStyle(filled: false))
                if !badge.manual {
                    Text("Planted by mistake? It won't plant itself again until you restore it.")
                        .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
            } else if revoked {
                Button("Restore") { model.restoreBadge(badge.id) }.buttonStyle(InkButtonStyle())
                Text("You took this back. Restoring lets your logs plant it again.")
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            } else if badge.manual {
                Button("I did this") { model.restoreBadge(badge.id) }.buttonStyle(InkButtonStyle())
            } else {
                Text("Plants itself when your logs show it.").font(Face.small).foregroundStyle(Ink.ink2)
            }
        }
    }
}
