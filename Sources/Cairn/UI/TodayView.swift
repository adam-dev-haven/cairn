import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        DayView(date: model.beforeStart ? model.startDate : model.today, isToday: !model.beforeStart)
    }
}

/// One day of the plan: what's on, logged inline, with the week beside it.
struct DayView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    let date: Date
    var isToday = true
    var onBack: (() -> Void)? = nil
    @State private var open: String?

    var items: [PlannedItem] { model.plannedItems(for: date) }

    var body: some View {
        Page(title: title, subtitle: subtitle) {
            HStack(spacing: 10) {
                if let onBack {
                    Button(action: onBack) { Label("Week", systemImage: "chevron.left") }
                        .buttonStyle(InkButtonStyle(filled: false))
                }
                if !model.beforeStart, !model.finished, model.blockWeek(for: date) != nil {
                    Button { nav.show("Change this day", symbol: "calendar.badge.plus") { DayEditor(date: date) } } label: {
                        Label("Change day", systemImage: "calendar.badge.plus")
                    }
                    .buttonStyle(InkButtonStyle(filled: false))
                    .help("Move a session, take one off, or bring another in")
                }
                if compact {
                    PhoneSyncChip()
                } else if isToday && !items.allSatisfy({ $0.kind == .rest }) {
                    Button { openFirst() } label: { Label("Log today", systemImage: "pencil.line") }
                        .buttonStyle(InkButtonStyle())
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("⌘L from anywhere")
                }
            }
        } content: {
            VStack(alignment: .leading, spacing: 18) {
                AdaptationBanners(date: date)
                ScheduleBanners(date: date)
                CoachNudge(date: date)
                if showElbow { ElbowCard(date: date) }
                if model.beforeStart { BeforeStartCard() }
                if model.finished { SummitCard() }
                AdaptiveStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 14) {
                        if items.isEmpty && !model.finished {
                            Text("Nothing planned.").font(Face.body).foregroundStyle(Ink.ink2).sheetCard()
                        }
                        if let next = nextItem, open == nil {
                            NextUpCard(item: next, date: date) {
                                withAnimation(.snappy(duration: 0.28)) { open = key(next) }
                            }
                        }
                        ForEach(items.filter { open != nil || key($0) != nextItem.map(key) }) { item in
                            ItemCard(item: item, date: date, expanded: open == key(item)) {
                                withAnimation(.snappy(duration: 0.28)) { open = open == key(item) ? nil : key(item) }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    VStack(alignment: .leading, spacing: 18) {
                        WeekGlass(date: date)
                        SmallThings(date: date)
                        GoalsCard()
                        TipCard(date: date, kind: items.first?.kind ?? .rest)
                    }
                    .frame(width: compact ? nil : 330)
                    .frame(maxWidth: compact ? .infinity : nil)
                }
            }
        }
        .onChange(of: nav.logRequest) { _, _ in openFirst() }
        .onAppear {
            if nav.logRequest > 0 && isToday && open == nil { openFirst() }
            // Design review: open the Change day sheet straight away.
            if ProcessInfo.processInfo.environment["CAIRN_DAYEDITOR"] != nil { nav.show("Change this day", symbol: "calendar.badge.plus") { DayEditor(date: date) } }
        }
    }

    private func key(_ item: PlannedItem) -> String { "\(item.kind.rawValue)-\(item.workoutID ?? "")" }

    /// The first thing not yet done today — what the screen leads with.
    var nextItem: PlannedItem? {
        guard isToday || model.beforeStart else { return nil }
        let open = items.filter { $0.kind != .rest && $0.kind != .check && !model.isDone($0, on: date) && model.skipped($0, on: date) == nil }
        return open.first { !$0.isOptional } ?? open.first
    }

    /// The elbow check-in belongs on days that load the elbows, and on any day
    /// the last reading wasn't green.
    var showElbow: Bool {
        guard !model.beforeStart, !model.finished else { return false }
        let loads = items.contains { $0.kind == .climb || $0.workoutID == "C" }
        return loads || (model.elbowReading(asOf: date)?.light ?? .green) != .green
    }

    private func openFirst() {
        let first = items.first { !model.isDone($0, on: date) && $0.kind != .rest && model.skipped($0, on: date) == nil } ?? items.first
        withAnimation(.snappy(duration: 0.28)) { open = first.map(key) }
    }

    var title: String {
        if model.beforeStart { return "Base camp" }
        return Day.long(date)
    }

    var subtitle: String {
        if model.beforeStart {
            let d = Day.between(model.today, model.startDate)
            return "The climb starts \(d == 1 ? "tomorrow" : "in \(d) days"), \(Day.long(model.startDate)). Here's the first session."
        }
        guard let w = model.blockWeek(for: date) else { return "" }
        var s = "Week \(w.number) of \(model.plan.weeks.count) · \(w.phase.name)"
        if w.entry.reason == .repeated { s += " (second go)" }
        if w.phase != .holiday && w.phase != .test { s += " · \(w.template.effort)" }
        return s
    }
}

// MARK: - Item card

struct ItemCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    let item: PlannedItem
    let date: Date
    var expanded: Bool
    var toggle: () -> Void
    @State private var hover = false

    var done: Bool { model.isDone(item, on: date) }
    var skipped: SkipReason? { model.skipped(item, on: date) }
    var inProgress: Bool { model.session(on: date, kind: item.kind, workoutID: item.workoutID).map(model.inProgress) ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: toggle) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(done ? Ink.ink : Ink.sand).frame(width: 42, height: 42)
                        Image(systemName: done ? "checkmark" : (skipped?.symbol ?? item.kind.symbol))
                            .font(.system(size: done ? 15 : 18, weight: done ? .bold : .regular))
                            .foregroundStyle(done ? Ink.sheet : (skipped != nil ? Ink.ink3 : Ink.ink))
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.system(size: 16, weight: .semibold).width(.expanded)).foregroundStyle(skipped != nil ? Ink.ink2 : Ink.ink)
                            .strikethrough(skipped != nil, color: Ink.ink3)
                        Text(skipped.map { "Skipped: \($0.name.lowercased())" } ?? detail).font(Face.small).foregroundStyle(Ink.ink2).lineLimit(2)
                        if compact && done && item.kind != .rest {
                            Text(doneSummary).font(Face.small).foregroundStyle(Ink.ink)
                        }
                        if inProgress {
                            Text("In progress · finish to count it").font(Face.small).foregroundStyle(Ink.red)
                        }
                    }
                    Spacer()
                    if item.kind != .rest {
                        if done {
                            if !compact { Text(doneSummary).font(Face.small).foregroundStyle(Ink.ink2) }
                        } else if skipped != nil || inProgress {
                            EmptyView()
                        } else if !expanded, !compact, let label = AppModel.quickLabel(item.kind) {
                            Button(label) { withAnimation(.snappy) { model.quickLog(item, on: date) } }
                                .buttonStyle(InkButtonStyle(filled: false))
                                .help("Log it in one tap. Open the card to change the details.")
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Ink.ink3)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(item.kind == .rest)

            // On the phone the one-tap action gets its own full-width row.
            if compact, !done, !expanded, skipped == nil, !inProgress, item.kind != .rest, let label = AppModel.quickLabel(item.kind) {
                HStack(spacing: 8) {
                    Button { withAnimation(.snappy) { model.quickLog(item, on: date) } } label: {
                        Text(label).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(InkButtonStyle(filled: false))
                    SkipButton(item: item, date: date)
                }
                .padding(.top, 14)
            }

            if expanded {
                VStack(alignment: .leading, spacing: 18) {
                    if item.kind == .climb && skipped == nil { SessionOrder(date: date) }
                    Rule(seed: 3)
                    SessionLogger(item: item, date: date, initial: model.draft(for: item, on: date), onFinish: toggle)
                    ItemMoveRow(item: item, date: date)
                }
                .padding(.top, 18)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .sheetCard(padding: 18)
        .onHover { hover = $0 }
    }

    var title: String {
        switch item.kind {
        case .workout, .home:
            if let w = model.workout(item.workoutID) { return "\(w.id) · \(w.name)" }
            return item.kind.name
        case .climb:
            return item.isOptional ? "Easy climb (optional)" : item.kind.name
        default:
            return item.kind.name
        }
    }

    var detail: String {
        let week = model.blockWeek(for: date)
        switch item.kind {
        case .climb:
            let drill = model.drill(for: date)?.name ?? "—"
            if item.isOptional { return model.grades("Technique only: V0–V2 and the \(drill.lowercased()) drill. Skip it if the elbows say so.") }
            return model.grades("Drill: \(drill) · repeats \(week?.template.gradeRepeats ?? "—")")
        case .workout, .home:
            guard let w = model.workout(item.workoutID) else { return "" }
            let skill = model.focusSkills.first.map { " · skill: \($0.steps[model.skillStep($0.id)].name.lowercased())" } ?? ""
            return "\(w.exercises.count) exercises · \(w.minutes ?? 30) min" + (week?.phase.halvesSets == true ? " · half the sets" : "") + skill
        case .walk:
            return "45–60 min · step floor \((week?.template.stepFloor ?? 7000).formatted())"
        case .prehab:
            return "10 min on the floor: bands, wrists, fingers"
        case .check:
            return "7-day average weight + waist → adjust kcal"
        case .rest:
            return "Easy walk if you feel like it."
        }
    }

    var doneSummary: String {
        let logs = model.sessions(on: date)
        switch item.kind {
        case .climb:
            guard let c = logs.first(where: { $0.kind == .climb }) else { return "" }
            if c.minimum { return "Doorway rule" }
            let sends = c.climb?.sends.count ?? 0
            if sends == 0 { return c.source == .garmin ? "From watch" : "\(c.climb?.problems.count ?? 0) tried" }
            return "\(sends)/\(c.climb?.problems.count ?? sends) sent · top \(model.hardestName(c.climb?.problems ?? []) ?? "–")"
        case .workout, .home, .prehab:
            let s = logs.first { $0.kind == item.kind && ($0.workoutID == item.workoutID || item.workoutID == nil) }
            let n = s?.exercises.reduce(0) { $0 + $1.doneSets.count } ?? 0
            return "\(n) sets"
        case .walk:
            return model.daily(date).steps.map { "\($0.formatted()) steps" } ?? "Done"
        default:
            return "Done"
        }
    }
}

/// The climbing session order from the plan, as one line of steps.
struct SessionOrder: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    let date: Date

    struct Step { let name: String; let short: String; let explain: String }

    var steps: [Step] {
        let week = model.blockWeek(for: date)
        let main = week?.template.mainBlockMinutes ?? 15
        let drill = model.drill(for: date)
        let easiestColour = model.circuits.first?.name.lowercased()
        let start = easiestColour.map { "the easiest \($0) problems" } ?? "V0"
        let working = easiestColour.map { "If \($0) is where you're working right now, the whole ladder is easy \($0)s" }
            ?? "If you're working on V0–V3 right now, the whole ladder is the easy end of V0–V3"
        return [
            Step(name: "Pulse", short: "5 min",
                 explain: "Jumping jacks, skipping on the spot, arm circles. You're done when you're warm and a little out of breath."),
            Step(name: "Shoulders on", short: "5 min",
                 explain: "Band pull-aparts 2 × 15, band external rotations 1 × 12 per side, and scap pull-ups 1 × 8: hang from the bar and pull your shoulders down without bending your arms."),
            Step(name: "Ladder", short: "6–8 easy problems",
                 explain: "The ladder is your fingers' warm-up, not a workout. Climb 6–8 problems that start very easy and get a little harder each time — like going up the rungs of a ladder — and stay well below your limit.\n\nStart on \(start). \(working): that's correct, it should feel easy. Rest a minute between problems.\n\nThe time is a guide, not a target. Six easy problems in eight minutes is a finished ladder."),
            Step(name: "Drill", short: "10–15 min",
                 explain: model.grades("\(drill?.name ?? "This week's drill") on easy problems (V0–V1). \(drill?.done ?? "")\n\nDo it until it feels boring, then use it everywhere.")),
            Step(name: "Main block", short: "\(main) min",
                 explain: model.grades("Your real climbing: repeats \(week?.template.gradeRepeats ?? "—"), projects \(week?.template.gradeProjects ?? "—"). Three tries on anything hard, then it goes on the list for next time. Rest 2–3 minutes between hard attempts.")),
            Step(name: "Downclimb 2", short: "then calisthenics",
                 explain: "Climb two easy problems down instead of dropping off. Free footwork practice, and a cool-down for the fingers. Then straight to the calisthenics."),
        ]
    }

    var body: some View {
        // The order of a session, not a checklist: numbers, no empty boxes.
        // Each step opens an explanation.
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .topLeading), count: compact ? 3 : 6),
                  alignment: .leading, spacing: 10) {
            ForEach(Array(steps.enumerated()), id: \.offset) { i, s in
                Button {
                    nav.show("\(i + 1) · \(s.name)", symbol: "figure.climbing") {
                        Text(s.explain).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
                    }
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(i + 1)").font(.system(size: 11, weight: .semibold)).monospacedDigit().foregroundStyle(Ink.ink2)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(s.name).font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.ink)
                                .underline(true, color: Ink.lineStrong)
                            Text(s.short).font(.system(size: 11)).foregroundStyle(Ink.ink2)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("What this step is")
            }
        }
    }
}

// MARK: - Right column

struct WeekGlass: View {
    @Environment(AppModel.self) private var model
    let date: Date

    var body: some View {
        let idx = model.calendarIndex(for: date)
        let week = model.blockWeek(at: max(0, idx)) ?? model.blockWeek(at: 0)!
        let score = model.score(week: max(0, idx))
        let green = model.plan.points.greenWeek
        PhaseGlass(phase: week.phase) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Week \(week.number)").font(Face.display(30, .regular)).foregroundStyle(Ink.ink)
                    Spacer()
                    Text(week.phase.name).font(.system(size: 13, weight: .semibold)).foregroundStyle(Ink.ink)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(.white.opacity(0.55)))
                }
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(score.total)").font(Face.display(34, .light)).monospacedDigit()
                        .contentTransition(.numericText())
                    Text("/ \(green) points").font(Face.body).foregroundStyle(Ink.ink2)
                }
                .foregroundStyle(Ink.ink)
                .animation(.spring(duration: 0.6), value: score.total)
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.6))
                        Capsule().fill(Ink.ink).frame(width: g.size.width * min(1, CGFloat(score.total) / CGFloat(max(1, green))))
                    }
                }
                .frame(height: 4)
                .animation(.spring(duration: 0.6), value: score.total)
                DayStrip(index: max(0, idx), highlight: date)
                Text(footer(score: score.total, green: green, idx: idx))
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    func footer(score: Int, green: Int, idx: Int) -> String {
        if model.isGreen(week: max(0, idx)) {
            return "Green week. Everything from here is extra." + (model.streak > 1 ? " \(model.streak) in a row." : "")
        }
        // What's still on the calendar this week, from today on.
        let p = model.plan.points
        let ahead = model.days(ofWeek: max(0, idx)).filter { $0 >= model.today }
        let gymLeft = ahead.filter { d in model.plannedItems(for: d).contains { $0.countsAsGym } && !model.gymDone(on: d) }.count
        let homeLeft = ahead.filter { d in model.plannedItems(for: d).contains { $0.kind == .home } && model.session(on: d, kind: .home) == nil }.count
        let reachable = gymLeft * p.gymSession + homeLeft * p.homeSession + ahead.count * (p.stepFloor + p.protein)
        let left = green - score
        if model.week(isDeload: idx) {
            return "Deload: doing the sessions as written makes it green, whatever the points."
        }
        var s = "\(left) to green."
        if gymLeft > 0 { s += " \(gymLeft) climbing morning\(gymLeft == 1 ? "" : "s") left this week (\(gymLeft * p.gymSession) points)." }
        if homeLeft > 0 { s += " \(homeLeft) strength session\(homeLeft == 1 ? "" : "s") left (\(homeLeft * p.homeSession) points)." }
        if reachable < left { s += " Green is out of reach this week — anything you do still counts toward the mountain." }
        return s
    }
}

struct DayStrip: View {
    @Environment(AppModel.self) private var model
    let index: Int
    var highlight: Date

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(model.days(ofWeek: index).enumerated()), id: \.offset) { i, d in
                let items = model.plannedItems(for: d).filter { $0.kind != .rest }
                let done = items.filter { model.isDone($0, on: d) }.count
                let isToday = Day.key(d) == Day.key(model.today)
                VStack(spacing: 6) {
                    Text(Day.weekdayLetter[i]).font(.system(size: 11, weight: .medium)).foregroundStyle(Ink.ink2)
                    ZStack {
                        if model.daily(d).sick {
                            Image(systemName: "bandage").font(.system(size: 11)).foregroundStyle(Ink.ink2)
                        } else if items.isEmpty {
                            Circle().fill(Ink.ink.opacity(0.12)).frame(width: 5, height: 5)
                        } else if done == items.count {
                            Circle().fill(Ink.ink).frame(width: 14, height: 14)
                        } else if done > 0 {
                            Circle().trim(from: 0, to: 0.5).fill(Ink.ink).rotationEffect(.degrees(90)).frame(width: 14, height: 14)
                            Circle().strokeBorder(Ink.ink, lineWidth: 1.2).frame(width: 14, height: 14)
                        } else {
                            Circle().strokeBorder(Ink.ink.opacity(d < model.today ? 0.25 : 0.6), lineWidth: 1.2).frame(width: 14, height: 14)
                        }
                        if isToday {
                            Circle().strokeBorder(Ink.red, lineWidth: 1.5).frame(width: 22, height: 22)
                        }
                    }
                    .frame(height: 22)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Day.weekdayLong[i]): \(done) of \(items.count) done")
            }
        }
    }
}

struct SmallThings: View {
    @Environment(AppModel.self) private var model
    let date: Date
    var body: some View {
        let d = model.daily(date)
        VStack(alignment: .leading, spacing: 14) {
            Text("Small things").font(Face.heading).foregroundStyle(Ink.ink)
            StepsField(date: date)
            Toggle(isOn: Binding(get: { d.protein }, set: { v in model.setDaily(date) { $0.protein = v; $0.typed.insert("protein") } })) {
                HStack(spacing: 6) {
                    Text("\(model.plan.proteinTarget) g protein").font(Face.body)
                    if let g = d.proteinG {
                        Text("· \(g) g logged").font(Face.small).foregroundStyle(Ink.ink2)
                    }
                }
            }.toggleStyle(InkCheck())
            Toggle(isOn: Binding(get: { d.sick }, set: { v in model.setDaily(date) { $0.sick = v } })) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("I'm sick today").font(Face.body)
                    Text("The day turns into rest. \(model.store.settings.sickDaysForReturnWeek)+ sick days in a week adds an easy return week.")
                        .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }.toggleStyle(InkCheck())
        }
        .sheetCard(padding: 18)
    }
}

struct TipCard: View {
    @Environment(AppModel.self) private var model
    let date: Date
    let kind: ItemKind
    var body: some View {
        if model.store.settings.showTips, let w = model.blockWeek(for: date) ?? model.blockWeek(at: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "lightbulb").font(.system(size: 14)).foregroundStyle(Ink.red)
                Text(w.template.tip.title).font(Face.heading).foregroundStyle(Ink.ink)
                Text(w.template.tip.body).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                Rule(seed: 12)
                Text(model.grades(Library.tip(for: kind, on: date))).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
            .sheetCard(padding: 18)
        }
    }
}

// MARK: - Banners

struct AdaptationBanners: View {
    @Environment(AppModel.self) private var model
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let p = model.store.pending {
                NoticeCard(symbol: "arrow.triangle.2.circlepath", text: p.message + " Slide the plan?") {
                    Button("Keep the plan") { model.dismissPending() }.buttonStyle(InkButtonStyle(filled: false))
                    Button("Slide it") { model.acceptPending() }.buttonStyle(InkButtonStyle())
                }
            }
            if let e = model.store.adaptations.first, !e.undone,
               let d = Day.date(e.day), Day.between(d, model.today) <= 6 {
                NoticeCard(symbol: "arrow.triangle.2.circlepath", text: e.message + " Summit is now \(Day.short(model.summitDate)).") {
                    Button("Undo") { model.undo(e) }.buttonStyle(InkButtonStyle(filled: false))
                }
            }
            if Day.key(date) == Day.key(model.today),
               model.plannedItems(for: date).contains(where: { $0.countsAsGym }),
               let gap = model.daysSinceGym, gap >= model.store.settings.daysAwayNudge {
                NoticeCard(symbol: "door.left.hand.open",
                           text: "\(gap) days since the wall. Today only needs the warm-up and the ladder. If you still feel dead after 20 minutes, go home — it counts as a full session.") {
                    EmptyView()
                }
            }
            let ambers = recentAmbers
            if let area = ambers {
                NoticeCard(symbol: "cross.case",
                           text: "Three amber sessions in a row on your \(area.name.lowercased()). That's the plan's line for booking a physio.") { EmptyView() }
            }
        }
    }

    /// The same area amber or worse in the last three logs that rated pain.
    var recentAmbers: BodyArea? {
        let rated = model.store.sessions.filter { !$0.pain.isEmpty }.sorted { $0.day > $1.day }.prefix(3)
        guard rated.count == 3 else { return nil }
        for area in BodyArea.allCases {
            if rated.allSatisfy({ s in s.pain.contains { $0.area == area && $0.score >= 3 } }) { return area }
        }
        return nil
    }
}

/// Today's elbow check-in, with what to do about it. The pain traffic light
/// (green / amber / red) decides: Cairn only advises, it never diagnoses.
struct ElbowCard: View {
    @Environment(AppModel.self) private var model
    let date: Date

    var checkIn: Int? { model.daily(date).elbow }
    var reading: AppModel.ElbowReading? { model.elbowReading(asOf: date) }
    var light: PainLight? { checkIn.map(PainLight.init(score:)) ?? reading?.light }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle().fill(light.map(Ink.pain) ?? Ink.line).frame(width: 12, height: 12)
                Text("Elbows today").font(Face.heading).foregroundStyle(Ink.ink)
                Spacer()
            }
            FlowLayout(spacing: 8) {
                chip("Fine", 1)
                chip("Ache", 3)
                chip("Sharp", 5)
            }
            Text(advice).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
        }
        .sheetCard(padding: 16)
    }

    func chip(_ title: String, _ score: Int) -> some View {
        let on = checkIn == score
        return Button(title) { model.setElbow(date, on ? nil : score) }
            .buttonStyle(ChipStyle(on: on))
            .accessibilityLabel("Elbows \(title.lowercased())")
            .accessibilityAddTraits(on ? .isSelected : [])
    }

    var advice: String {
        let earlier: String
        if checkIn == nil, let r = reading, let d = Day.date(r.day) {
            earlier = "Last logged \(r.score)/10 on \(Day.weekdayShort[Day.weekday(d) - 1]) \(Day.short(d)). "
        } else {
            earlier = ""
        }
        switch light {
        case .none:
            return "Check them in the warm-up, before the first real attempt. Dull ache that fades is fine; sharp pain, or ache that builds, is not."
        case .some(.green):
            return "\(earlier)Green. Climb and pull as planned."
        case .some(.amber):
            return "\(earlier)Amber: technique mode. If you climb, V0–V1, vertical and slab, straight arms, feet drills, about 40 minutes, no hard attempts. On pull day: straight-arm pulldown, face pull and pull-aparts only."
        case .some(.red):
            return "\(earlier)Red: no climbing and no pulling until a check-in comes back green. Push, legs and prehab carry on. If it hasn't settled in two weeks, show a physio. Cairn can't diagnose it."
        }
    }
}

struct NoticeCard<Actions: View>: View {
    var symbol: String
    var text: String
    @ViewBuilder var actions: Actions
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: symbol).font(.system(size: 15)).foregroundStyle(Ink.red).frame(width: 22)
            Text(text).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            actions
        }
        .sheetCard(padding: 16)
    }
}

// MARK: - Before and after

struct BeforeStartCard: View {
    @Environment(AppModel.self) private var model
    let jobs = ["Get a set of resistance bands",
                "Set your calorie and protein targets in Settings",
                "Pack the gym bag tonight: shoes by the door, clothes out"]
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your only job before Monday").font(Face.title).foregroundStyle(Ink.ink)
            ForEach(Array(jobs.enumerated()), id: \.offset) { i, job in
                let key = "prep@\(i)"
                Toggle(isOn: Binding(get: { model.store.missions[key] != nil },
                                     set: { v in model.mutate { $0.missions[key] = v ? Day.key(model.today) : nil } })) {
                    Text(job).font(Face.body)
                }.toggleStyle(InkCheck())
            }
            Text("Monday is the warm-up, the ladder, a falling drill, push-ups and five numbers written down. That's it.")
                .font(Face.small).foregroundStyle(Ink.ink2)
        }
        .sheetCard()
    }
}

struct SummitCard: View {
    @Environment(Navigator.self) private var nav
    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "flag.checkered").font(.system(size: 24)).foregroundStyle(Ink.red)
            VStack(alignment: .leading, spacing: 4) {
                Text("You're on the summit.").font(Face.title)
                Text("Fill in the week-14 benchmarks, then plan the next block in Settings.").font(Face.body).foregroundStyle(Ink.ink2)
            }
            Spacer()
            Button("See the benchmarks") { nav.section = .bar }.buttonStyle(InkButtonStyle())
        }
        .sheetCard()
    }
}

/// The day's next thing, big: what it is, and the two ways to log it.
struct NextUpCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    let item: PlannedItem
    let date: Date
    var start: () -> Void
    @State private var logged = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle().fill(Ink.ink).frame(width: 54, height: 54)
                    Image(systemName: item.kind.symbol).font(.system(size: 24)).foregroundStyle(Ink.sheet)
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text("Next: \(title)").font(Face.display(compact ? 24 : 28, .regular)).foregroundStyle(Ink.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(detail).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
            AdaptiveStack(spacing: 10) {
                Button(action: start) {
                    Label(primaryLabel, systemImage: "pencil.line")
                        .frame(maxWidth: compact ? .infinity : nil)
                        .frame(minHeight: compact ? 30 : nil)
                }
                .buttonStyle(InkButtonStyle())
                HStack(spacing: 10) {
                    if let label = AppModel.quickLabel(item.kind) {
                        Button {
                            withAnimation(.snappy) { model.quickLog(item, on: date) }
                            logged += 1
                        } label: {
                            Text(label)
                                .frame(maxWidth: compact ? .infinity : nil)
                                .frame(minHeight: compact ? 30 : nil)
                        }
                        .buttonStyle(InkButtonStyle(filled: false))
                    }
                    SkipButton(item: item, date: date, tall: compact)
                }
            }
            .sensoryFeedback(.success, trigger: logged)
            if item.kind == .climb {
                Text("Low day? The warm-up and the ladder count as a full session. Go, and leave after 20 minutes if you want.")
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheetCard(padding: compact ? 18 : 24)
    }

    var title: String {
        if let w = model.workout(item.workoutID), item.kind == .workout || item.kind == .home { return "\(w.id) · \(w.name)" }
        return item.isOptional ? "Easy climb (optional)" : item.kind.name
    }

    var primaryLabel: String {
        switch item.kind {
        case .climb: "Log the session"
        case .workout, .home: "Log sets"
        case .walk: "Add minutes and steps"
        default: "Log it"
        }
    }

    var detail: String {
        let week = model.blockWeek(for: date)
        switch item.kind {
        case .climb:
            let drill = model.drill(for: date)?.name ?? "—"
            return model.grades("Drill: \(drill). Repeats \(week?.template.gradeRepeats ?? "—").")
        case .workout, .home:
            guard let w = model.workout(item.workoutID) else { return "" }
            let first = w.exercises.first.map { Library.exercise($0.exerciseID).name } ?? ""
            let skill = model.focusSkills.first.map { " Skill: \($0.steps[model.skillStep($0.id)].name.lowercased())." } ?? ""
            return "\(w.exercises.count) exercises, starting with \(first.lowercased()). \(w.minutes ?? 30) min.\(skill)"
        case .walk: return "45–60 minutes. Floor \((week?.template.stepFloor ?? 7000).formatted()) steps."
        case .prehab: return "Ten minutes on the floor: bands, wrists, fingers."
        default: return ""
        }
    }
}

/// "Not today", with a reason.
struct SkipButton: View {
    @Environment(Navigator.self) private var nav
    let item: PlannedItem
    let date: Date
    var tall = false
    var body: some View {
        Button {
            nav.show("Skip \(item.kind.name.lowercased())", symbol: "forward") { SkipPicker(item: item, date: date) }
        } label: {
            Text("Skip…").frame(minHeight: tall ? 30 : nil)
        }
        .buttonStyle(InkButtonStyle(filled: false))
        .help("Not happening today: sick, no time, tired, pain…")
        .fixedSize()
    }
}

/// Weekly, not daily: on a Sunday or Monday, one quiet card if there's been
/// no weekly analysis this week, or if a check-in is waiting on your answers.
struct CoachNudge: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    let date: Date

    var body: some View {
        if Day.key(date) == Day.key(model.today), !model.beforeStart, !model.finished {
            let weekday = Day.weekday(date)
            let waiting = model.coachReports.first { $0.stage == .asking && !$0.answered && Day.between(Day.date($0.day) ?? date, date) <= 3 }
            let recentWeekly = model.coachReports.contains { $0.scope == .weekly && Day.between(Day.date($0.day) ?? .distantPast, date) < 6 }
            if let w = waiting {
                NoticeCard(symbol: "person.wave.2", text: "Your \(w.scope == .weekly ? "weekly analysis" : "check-in") has questions for you.") {
                    Button("Answer them") { nav.section = .coach }.buttonStyle(InkButtonStyle())
                }
            } else if (weekday == 7 || weekday == 1), !recentWeekly, !compact {
                NoticeCard(symbol: "person.wave.2", text: "Weekly analysis is ready when you are: five minutes, a few questions, and a read on whether to keep going or change something.") {
                    Button("Open Coach") { nav.section = .coach }.buttonStyle(InkButtonStyle(filled: false))
                }
            }
        }
    }
}
