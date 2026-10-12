import SwiftUI

/// Edits one session log in place. Every change saves; there is no Save
/// button. A gym session counts once you press Finish.
struct SessionLogger: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let item: PlannedItem
    let date: Date
    var onFinish: (() -> Void)? = nil
    /// The log before its first change is saved. After that the model holds
    /// it, and everything — including editors in the bottom bubble — reads
    /// and writes the model, so they never drift apart.
    @State private var draft: SessionLog
    @State private var finishedTick = 0

    init(item: PlannedItem, date: Date, initial: SessionLog, onFinish: (() -> Void)? = nil) {
        self.item = item
        self.date = date
        self.onFinish = onFinish
        _draft = State(initialValue: initial)
    }

    private var log: SessionLog { model.store.sessions.first { $0.id == draft.id } ?? draft }

    private var binding: Binding<SessionLog> {
        Binding(get: { log }, set: { new in if new != log { model.upsert(new) } })
    }

    private func update(_ change: (inout SessionLog) -> Void) {
        var l = log
        change(&l)
        model.upsert(l)
    }

    var finishable: Bool { [.climb, .workout, .home, .prehab].contains(item.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            if let reason = log.skip {
                SkippedRow(reason: reason, note: log.note) {
                    model.unskip(item, on: date)
                    draft = model.draft(for: item, on: date)
                }
            } else {
                switch item.kind {
                case .climb:
                    ClimbLogger(log: binding, date: date)
                case .workout, .home, .prehab:
                    ExerciseLogger(log: binding, date: date)
                case .walk:
                    WalkLogger(log: binding, date: date)
                case .check:
                    CheckLogger(date: date)
                case .rest:
                    EmptyView()
                }
                if item.kind.isGym || item.kind == .home {
                    Rule(seed: 9)
                    DetailsDisclosure(log: binding)
                }
                if finishable { finishBar }
                if model.session(on: date, kind: log.kind, workoutID: log.workoutID) != nil && item.kind != .check {
                    HStack {
                        if log.source == .garmin || log.garminID != nil {
                            Label("From your watch\(log.minutes.map { " · \($0) min" } ?? "")\(log.avgHr.map { " · \($0) bpm" } ?? "")",
                                  systemImage: "applewatch").font(Face.small).foregroundStyle(Ink.ink2)
                        }
                        Spacer()
                        Button("Clear this log", role: .destructive) {
                            model.delete(log)
                            draft = model.draft(for: item, on: date)
                        }
                        .buttonStyle(TextLinkStyle()).font(Face.small).foregroundStyle(Ink.ink2)
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: finishedTick)
    }

    var logged: Bool {
        log.minimum || !(log.climb?.problems.isEmpty ?? true) || log.exercises.contains { !$0.doneSets.isEmpty } || !(log.skills ?? []).isEmpty
    }

    @ViewBuilder var finishBar: some View {
        if log.isFinished && logged {
            HStack(spacing: 12) {
                Label("Finished", systemImage: "checkmark.seal.fill").font(Face.heading).foregroundStyle(Ink.ink)
                Button("See the stats") { showSummary() }.buttonStyle(TextLinkStyle()).font(Face.body)
                Spacer()
                Button("Keep logging") { update { $0.finished = false } }.buttonStyle(InkButtonStyle(filled: false))
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    update { $0.finished = true; $0.skip = nil }
                    finishedTick += 1
                    showSummary()
                    onFinish?()
                } label: {
                    Label("Finish session", systemImage: "flag.checkered").frame(maxWidth: .infinity).frame(minHeight: 30)
                }
                .buttonStyle(InkButtonStyle())
                .disabled(!logged)
                HStack {
                    Text(logged ? "It counts once you finish. Forgot? It counts at midnight anyway."
                                : "Log what you did, then finish. Or skip it if it isn't happening.")
                        .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if !logged {
                        Button("Skip…") { nav.show("Skip \(item.kind.name.lowercased())", symbol: "forward") { SkipPicker(item: item, date: date) } }
                            .buttonStyle(InkButtonStyle(filled: false))
                    }
                }
            }
        }
    }

    func showSummary() {
        let snapshot = log
        nav.show(item.kind == .climb ? "Session done" : "Sets done", symbol: "checkmark.seal") {
            SessionSummary(log: snapshot)
        }
    }
}

/// A skipped session: the reason, and a way back.
struct SkippedRow: View {
    var reason: SkipReason
    var note: String
    var undo: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reason.symbol).font(.system(size: 15)).foregroundStyle(Ink.ink2).frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("Skipped: \(reason.name.lowercased())").font(Face.heading)
                if !note.isEmpty { Text(note).font(Face.small).foregroundStyle(Ink.ink2) }
            }
            Spacer()
            Button("Undo skip", action: undo).buttonStyle(InkButtonStyle(filled: false))
        }
    }
}

/// Why it isn't happening. Sick turns the day into rest.
struct SkipPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let item: PlannedItem
    let date: Date
    @State private var reason: SkipReason?
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(SkipReason.allCases) { r in
                    Button { reason = r } label: {
                        Label(r.name, systemImage: r.symbol)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .foregroundStyle(reason == r ? Ink.sheet : Ink.ink)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(reason == r ? Ink.ink : Ink.sand))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            Text(explain).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            TextField("A note, if you want", text: $note)
                .textFieldStyle(.plain).font(Face.body)
                .padding(10).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.sand.opacity(0.6)))
            HStack {
                Spacer()
                Button("Skip it") {
                    if let reason { model.skip(item, on: date, reason: reason, note: note) }
                    nav.dismissBubble()
                }
                .buttonStyle(InkButtonStyle())
                .disabled(reason == nil)
            }
        }
    }

    var explain: String {
        switch reason {
        case .sick: "The whole day turns into rest. \(model.store.settings.sickDaysForReturnWeek)+ sick days in a week adds an easy return week."
        case .pain: "Good call. Log where it hurts next session; three amber sessions on one spot means a physio."
        case .none: "Pick a reason. Missed gym days still count toward repeating the week — no catching up, the plan waits."
        default: "Noted. \(model.store.settings.missedGymDaysToRepeat)+ missed gym days in a week repeats the week, so nothing is lost."
        }
    }
}

/// What a finished session added up to.
struct SessionSummary: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let log: SessionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let c = log.climb, !log.minimum {
                climb(c)
            } else if log.minimum {
                Text("Doorway rule: warm-up and ladder. That's a full session.").font(Face.body)
            } else {
                sets
            }
            Rule(seed: 31)
            let idx = model.calendarIndex(for: log.date)
            let score = model.score(week: max(0, idx))
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(score.total)").font(Face.display(26, .light)).monospacedDigit()
                Text("/ \(model.plan.points.greenWeek) points this week").font(Face.body).foregroundStyle(Ink.ink2)
                Spacer()
                if model.isGreen(week: max(0, idx)) {
                    Text("Green").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.sheet)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.ink))
                }
            }
            HStack { Spacer(); Button("Done") { nav.dismissBubble() }.buttonStyle(InkButtonStyle()) }
        }
    }

    @ViewBuilder func climb(_ c: ClimbLog) -> some View {
        let tried = c.problems.count
        let sent = c.sends.count
        let flashes = c.sends.filter(\.flash).count
        let tries = c.problems.reduce(0) { $0 + $1.attempts }
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 4), spacing: 12) {
            Stat(value: "\(tried)", label: "problems", size: 26)
            Stat(value: "\(sent)", label: "sent", size: 26)
            Stat(value: "\(flashes)", label: "flashed", size: 26)
            Stat(value: "\(tries)", label: "tries", size: 26)
        }
        let goals = model.goalProgress(finishing: log)
        if !goals.reached.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(goals.reached) { g in
                    Label("Goal reached: \(g.title)", systemImage: "flag.checkered").font(Face.heading).foregroundStyle(Ink.red)
                }
                if let n = goals.next.first {
                    Text("Next: \(n.title). \(n.detail)").font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        if let top = model.hardestName(c.problems) {
            HStack(spacing: 8) {
                Text("Hardest send: \(top)").font(Face.heading)
                if model.isNewHardest(log) {
                    Text("new best +\(model.plan.points.newHardestSend)").font(Face.tiny).foregroundStyle(Ink.red)
                        .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Ink.redSoft))
                }
            }
        }
        // Per grade: sent of tried.
        let rows = model.gradeOptions.compactMap { o -> (AppModel.GradeOption, Int, Int)? in
            let ps = c.problems.filter(o.matches)
            return ps.isEmpty ? nil : (o, ps.filter(\.sent).count, ps.count)
        }
        if !rows.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(rows, id: \.0.id) { r in
                    HStack(spacing: 5) {
                        if let col = r.0.color { Circle().fill(col).frame(width: 9, height: 9) }
                        Text("\(r.0.label) \(r.1)/\(r.2)").font(.system(size: 13, weight: .medium)).monospacedDigit()
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(Ink.sand))
                }
            }
        }
        if tried > 0 {
            Text("Sent \(Int((Double(sent) / Double(tried) * 100).rounded()))% of what you tried, \(String(format: "%.1f", Double(tries) / Double(tried))) tries a problem.")
                .font(Face.small).foregroundStyle(Ink.ink2)
        }
    }

    @ViewBuilder var sets: some View {
        let planned = log.exercises.reduce(0) { $0 + $1.sets.count }
        let done = log.exercises.reduce(0) { $0 + $1.doneSets.count }
        let reps = log.exercises.filter { !$0.timed }.reduce(0) { $0 + $1.doneSets.reduce(0) { $0 + $1.value } }
        let top = log.exercises.filter(\.hitTopOfRange)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: 3), spacing: 12) {
            Stat(value: "\(done)/\(planned)", label: "sets", size: 26)
            Stat(value: "\(reps)", label: "reps", size: 26)
            Stat(value: "\(top.count)", label: "at the top", size: 26)
        }
        // Next time, for every exercise with a set done: where it goes from here.
        let next = log.exercises.filter { !$0.doneSets.isEmpty }.compactMap { e -> (ExerciseLog, Overload.Prescription)? in
            model.nextPrescription(e.exerciseID).map { (e, $0) }
        }
        if !next.isEmpty {
            Text("Next time").font(Face.heading)
            ForEach(next, id: \.0.id) { e, rx in
                let info = Library.exercise(e.exerciseID)
                let t = rx.targets
                let load = t.first?.kg.map { info.isBand ? Bands.text($0) : "\(Overload.kgText($0)) kg" }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(e.variant).font(Face.body)
                        Spacer()
                        Text("\(load.map { $0 + " · " } ?? "")\(t.map { "\($0.reps)" }.joined(separator: ", "))\(e.timed ? " s" : "")")
                            .font(.system(size: 13, weight: .semibold)).monospacedDigit()
                    }
                    Text(rx.reason).font(Face.tiny).foregroundStyle(rx.kind == .progress ? Ink.red : Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        if let sk = log.skills, !sk.isEmpty {
            Text("Skills practised: \(sk.compactMap { Library.skill($0)?.name }.joined(separator: ", ")).").font(Face.small).foregroundStyle(Ink.ink2)
        }
    }
}

// MARK: - Climbing

struct ClimbLogger: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    @Binding var log: SessionLog
    let date: Date
    @State private var tapped = 0

    private var climb: Binding<ClimbLog> {
        Binding(get: { log.climb ?? ClimbLog() }, set: { log.climb = $0 })
    }

    var body: some View {
        let week = model.blockWeek(for: date)
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.circuits.isEmpty ? "Tap a grade for every problem you try" : "Tap a colour for every problem you try")
                        .font(Face.heading).foregroundStyle(Ink.ink)
                    Spacer()
                    if let week, !compact {
                        Text(model.grades("Repeats \(week.template.gradeRepeats) · \(week.template.gradeProjects)"))
                            .font(Face.small).foregroundStyle(Ink.ink2)
                    }
                }
                if let week, compact {
                    Text(model.grades("Repeats \(week.template.gradeRepeats) · \(week.template.gradeProjects)"))
                        .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
                let options = model.gradeOptions
                let wide = options.count <= 4
                LazyVGrid(columns: Array(repeating: GridItem(compact || wide ? .flexible() : .fixed(52), spacing: 8),
                                         count: compact ? min(4, max(2, options.count)) : (wide ? options.count : 8)),
                          alignment: .leading, spacing: 8) {
                    ForEach(options) { o in
                        let mine = climb.wrappedValue.problems.filter(o.matches)
                        let sent = mine.filter(\.sent).count
                        let over = o.v >= capGrade
                        Button {
                            let p = o.problem()
                            climb.wrappedValue.problems.append(p)
                            tapped += 1
                            edit(p.id)
                        } label: {
                            VStack(spacing: 2) {
                                HStack(spacing: 6) {
                                    if let c = o.color { Circle().fill(c).frame(width: 12, height: 12).overlay(Circle().strokeBorder(Ink.ink.opacity(0.15))) }
                                    Text(o.label).font(.system(size: compact ? 17 : 15, weight: .semibold).width(o.circuit == nil && o.font == nil ? .expanded : .standard))
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                                Text(mine.isEmpty ? (o.detail ?? " ") : "\(sent)/\(mine.count) sent")
                                    .font(.system(size: 11)).monospacedDigit().foregroundStyle(Ink.ink2)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: compact ? 64 : 50)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(over ? Ink.sand.opacity(0.45) : Ink.sand))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(over ? Ink.lineStrong : .clear, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Ink.ink)
                        .help(over ? "Above this phase's grade cap" : "Add a \(o.label) problem")
                        .accessibilityLabel("\(o.label), \(sent) of \(mine.count) sent\(over ? ", above this phase's cap" : ""). Add a problem.")
                    }
                }
                .sensoryFeedback(.impact(weight: .light), trigger: tapped)
                if let warning = capWarning {
                    Label(warning, systemImage: "exclamationmark.triangle").font(Face.small).foregroundStyle(Ink.amber)
                }
            }

            if !climb.wrappedValue.problems.isEmpty {
                VStack(spacing: 0) {
                    ForEach(climb.wrappedValue.problems) { p in
                        ProblemRow(problem: p, edit: { edit(p.id) },
                                   remove: { climb.wrappedValue.problems.removeAll { $0.id == p.id } })
                        if p.id != climb.wrappedValue.problems.last?.id { Divider().overlay(Ink.line) }
                    }
                }
                .padding(.horizontal, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.paper.opacity(0.6)))
            }

            AdaptiveStack(spacing: 26) {
                if let drill = model.drill(for: date) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Drill: \(drill.name)").font(Face.heading).foregroundStyle(Ink.ink)
                            Spacer()
                            DrillMenu(current: drill.id)
                        }
                        if drill.id == "falling" {
                            HStack(spacing: 10) {
                                Text("Controlled falls").font(Face.body).foregroundStyle(Ink.ink2)
                                StepperField(value: climb.falls, range: 0...30)
                            }
                        }
                        if Library.drillOrder.contains(drill.id) {
                            Button {
                                climb.wrappedValue.drillBoring = true
                                model.clearDrill(drill.id)
                            } label: {
                                Label("Got it, it's boring. Next drill (+\(model.plan.points.drillBoring))", systemImage: "forward.end")
                            }
                            .buttonStyle(InkButtonStyle(filled: false))
                        } else {
                            Toggle(isOn: climb.drillBoring) {
                                Text("It feels boring now (+\(model.plan.points.drillBoring))").font(Face.body)
                            }
                            .toggleStyle(InkCheck())
                        }
                        if climb.wrappedValue.drillBoring, let next = model.drill(for: date), next.id != drill.id {
                            Text("Cleared. Next: \(next.name).").font(Face.small).foregroundStyle(Ink.ink2)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Doorway rule").font(Face.heading).foregroundStyle(Ink.ink)
                    Toggle(isOn: $log.minimum) {
                        Text("Warm-up and ladder only — still a full session").font(Face.body)
                    }
                    .toggleStyle(InkCheck())
                }
            }
        }
    }

    /// Open one problem in the bottom bubble: how it went, not an assumption.
    func edit(_ id: UUID) {
        if model.session(id: log.id) == nil { model.upsert(log) }
        let label = log.climb?.problems.first { $0.id == id }.map(model.gradeName) ?? "Problem"
        nav.show(label, symbol: "figure.climbing") {
            ProblemEditor(sessionID: log.id, problemID: id)
        }
    }

    /// First grade that's off-limits for repeats in this phase.
    private var capGrade: Int {
        switch model.blockWeek(for: date)?.phase {
        case .foundation: 3
        case .deload, .recovery: 3
        case .build: 4
        case .push: 5
        default: 8
        }
    }

    private var capWarning: String? {
        guard let phase = model.blockWeek(for: date)?.phase else { return nil }
        let p = climb.wrappedValue.problems
        if phase == .foundation && p.filter({ $0.grade == 3 }).count > 2 {
            return model.grades("That's more than two V3s. Foundation caps V3 at two per session — save the rest for next time.")
        }
        if phase != .push && p.contains(where: { $0.grade >= 4 }) {
            return model.grades("V4 attempts open in the Push phase (weeks 11–12).")
        }
        return nil
    }
}

/// Pick a different drill, or go back to the plan's.
struct DrillMenu: View {
    @Environment(AppModel.self) private var model
    let current: String
    var body: some View {
        Menu {
            ForEach(Library.drillOrder, id: \.self) { id in
                if let d = Library.drill(id) {
                    Button { model.chooseDrill(id) } label: {
                        if id == current { Label(d.name, systemImage: "checkmark") }
                        else if model.drillMastered(id) { Label(d.name, systemImage: "checkmark.seal") }
                        else { Text(d.name) }
                    }
                }
            }
            if model.store.drillChoice != nil {
                Divider()
                Button("Back to the plan's drill") { model.followPlanDrill() }
            }
        } label: {
            Text("Change").font(Face.small)
        }
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

struct ProblemRow: View {
    @Environment(AppModel.self) private var model
    let problem: Problem
    var edit: () -> Void
    var remove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: edit) {
                HStack(spacing: 12) {
                    HStack(spacing: 5) {
                        if let c = model.circuit(problem.circuit) { Circle().fill(c.color).frame(width: 10, height: 10) }
                        Text(model.gradeName(problem)).font(.system(size: 14, weight: .semibold).width(problem.circuit == nil && model.scale == .v ? .expanded : .standard))
                            .lineLimit(1)
                    }
                    .frame(minWidth: 34, alignment: .leading)
                    Text(summary).font(Face.body).foregroundStyle(problem.sent ? Ink.ink : Ink.ink2)
                    if problem.flash {
                        Text("flash").font(Face.tiny).foregroundStyle(Ink.red)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(Ink.redSoft))
                    }
                    Spacer()
                    Image(systemName: "slider.horizontal.3").font(.system(size: 12)).foregroundStyle(Ink.ink2)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Tries, sent, technique")
            Button(action: remove) { Image(systemName: "xmark") }.buttonStyle(QuietIconButton()).help("Remove")
        }
        .padding(.vertical, 9)
    }

    var summary: String {
        var parts: [String] = []
        parts.append(problem.sent ? (problem.attempts == 1 ? "flash" : "sent in \(problem.attempts)") : "\(problem.attempts) \(problem.attempts == 1 ? "try" : "tries"), not sent")
        if problem.flash { parts = [] ; parts.append("first try") }
        if !problem.tags.isEmpty { parts.append(problem.tags.joined(separator: ", ").lowercased()) }
        return parts.joined(separator: " · ")
    }
}

/// One problem: how it went. Opens as soon as you tap a grade, so nothing
/// is assumed — a flash is one tap, a fight is a few.
struct ProblemEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let sessionID: UUID
    let problemID: UUID

    enum Outcome { case flash, sent, notYet }
    var outcome: Outcome { !problem.sent ? .notYet : (problem.attempts == 1 ? .flash : .sent) }

    private var stored: Problem? { model.session(id: sessionID)?.climb?.problems.first { $0.id == problemID } }

    /// Reads and writes the saved problem, so the bubble always shows what's stored.
    private var problem: Problem {
        get { stored ?? Problem(grade: 0, sent: false) }
        nonmutating set {
            model.editSession(sessionID) { s in
                if let i = s.climb?.problems.firstIndex(where: { $0.id == problemID }) { s.climb?.problems[i] = newValue }
            }
        }
    }

    func remove() {
        model.editSession(sessionID) { s in s.climb?.problems.removeAll { $0.id == problemID } }
        nav.dismissBubble()
    }

    var body: some View {
        if stored == nil {
            Text("This problem was removed.").font(Face.body).foregroundStyle(Ink.ink2)
        } else {
            editor
        }
    }

    var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                outcomeButton("Flash", "bolt", .flash) { var p = problem; p.sent = true; p.attempts = 1; problem = p; nav.dismissBubble() }
                outcomeButton("Sent", "checkmark", .sent) { var p = problem; p.sent = true; p.attempts = max(2, p.attempts); problem = p }
                outcomeButton("Not sent", "xmark", .notYet) { var p = problem; p.sent = false; problem = p }
            }
            HStack(spacing: 12) {
                Text("Tries").font(Face.heading)
                StepperField(value: Binding(get: { problem.attempts }, set: { v in problem.attempts = v }), range: 1...40)
                Spacer()
                Picker("Grade", selection: Binding(
                    get: { model.option(for: problem)?.id ?? "" },
                    set: { id in
                        if let o = model.gradeOptions.first(where: { $0.id == id }) {
                            var p = problem
                            p.grade = o.v; p.circuit = o.circuit; p.font = o.font
                            problem = p
                        }
                    })) {
                    ForEach(model.gradeOptions) { Text($0.label).tag($0.id) }
                }
                .labelsHidden().fixedSize()
            }
            Text(line).font(Face.small).foregroundStyle(Ink.ink2)
            FlowLayout(spacing: 6) {
                ForEach(Quests.climbTags, id: \.self) { tag in
                    let on = problem.tags.contains(tag)
                    Button(tag) {
                        var p = problem
                        if on { p.tags.removeAll { $0 == tag } } else { p.tags.append(tag) }
                        problem = p
                    }.buttonStyle(ChipStyle(on: on))
                }
            }
            HStack {
                Button("Remove", role: .destructive, action: remove).buttonStyle(TextLinkStyle()).font(Face.small).foregroundStyle(Ink.ink2)
                Spacer()
                Button("Done") { nav.dismissBubble() }.buttonStyle(InkButtonStyle())
            }
        }
    }

    var line: String {
        switch outcome {
        case .flash: "First try. The best kind."
        case .sent: "Sent on try \(problem.attempts)."
        case .notYet: problem.attempts >= 3 ? "Three tries and not yet: on the list for next time." : "\(problem.attempts) \(problem.attempts == 1 ? "try" : "tries"), not sent yet. Add tries as you go."
        }
    }

    func outcomeButton(_ title: String, _ symbol: String, _ o: Outcome, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(outcome == o ? Ink.sheet : Ink.ink)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(outcome == o ? Ink.ink : Ink.sand))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Sets

struct ExerciseLogger: View {
    @Environment(AppModel.self) private var model
    @Binding var log: SessionLog
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let w = model.workout(log.workoutID), w.gymExercises != nil {
                HStack(spacing: 12) {
                    Text("Where").font(Face.heading)
                    Picker("", selection: Binding(get: { log.atGym ?? false }, set: { log = model.setPlace(log, atGym: $0) })) {
                        Text("Home, bands").tag(false)
                        Text("Gym").tag(true)
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 260)
                    Spacer()
                }
                .padding(.bottom, 8)
            }
            HStack {
                if let w = model.workout(log.workoutID) {
                    Text(w.note).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Button {
                    for i in log.exercises.indices { for k in log.exercises[i].sets.indices { log.exercises[i].sets[k].done = true } }
                } label: {
                    Label("Done as planned", systemImage: "checkmark")
                }
                .buttonStyle(InkButtonStyle(filled: false))
                .help("Tick every set at the numbers shown")
            }
            .padding(.bottom, 8)
            ForEach($log.exercises) { $ex in
                ExerciseRow(ex: $ex, date: date, sessionID: log.id, persist: { if model.session(id: log.id) == nil { model.upsert(log) } })
                if ex.id != log.exercises.last?.id { Rule(seed: ex.exerciseID.count) }
            }
            if log.kind == .workout || log.kind == .home {
                SkillPractice(log: $log)
            }
        }
    }
}

/// The skills you're working on, at the end of a session: practised today,
/// and cleared when the standard is met.
struct SkillPractice: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Binding var log: SessionLog

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rule(seed: 77)
            HStack(alignment: .firstTextBaseline) {
                Text("Skill practice").font(Face.heading)
                Spacer()
                Text(model.focusSkills.isEmpty ? "" : "5–10 min, fresh, before the last exercise").font(Face.small).foregroundStyle(Ink.ink2)
            }
            if model.focusSkills.isEmpty {
                Text("No skills picked. Learn → Calisthenics → Skills: pick up to three and they show up here.")
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(model.focusSkills) { sk in
                let step = sk.steps[model.skillStep(sk.id)]
                let practised = (log.skills ?? []).contains(sk.id)
                HStack(spacing: 12) {
                    Button {
                        var list = log.skills ?? []
                        if practised { list.removeAll { $0 == sk.id } } else { list.append(sk.id) }
                        log.skills = list
                    } label: {
                        Image(systemName: practised ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22)).foregroundStyle(practised ? Ink.ink : Ink.ink3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(sk.name) practised")
                    Button {
                        nav.show(sk.name, symbol: sk.symbol) { SkillDetail(skill: sk) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.name).font(Face.body).foregroundStyle(Ink.ink)
                            Text("\(sk.name) · goal \(step.goal)").font(Face.small).foregroundStyle(Ink.ink2)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button("Cleared") { model.clearSkillStep(sk.id); if !practised { log.skills = (log.skills ?? []) + [sk.id] } }
                        .buttonStyle(InkButtonStyle(filled: false))
                        .disabled(model.skillComplete(sk.id))
                        .help("You hit the goal: move to the next step")
                }
            }
        }
    }
}

struct ExerciseRow: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    @Binding var ex: ExerciseLog
    let date: Date
    var sessionID: UUID
    var persist: () -> Void = {}

    var info: ExerciseInfo { Library.exercise(ex.exerciseID) }

    /// What the overload rules said for this session, from what came before.
    var rx: Overload.Prescription? {
        guard model.lastLog(of: ex.exerciseID, variant: ex.variant, before: date) != nil || model.store.loadSet[ex.exerciseID] != nil else { return nil }
        return model.prescription(ex.exerciseID, variant: ex.variant, low: ex.low, high: ex.high, timed: ex.timed, setCount: ex.sets.count, before: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ex.variant).font(Face.heading).foregroundStyle(Ink.ink)
                    Text(targetLine).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    if let why = rx?.reason, rx?.kind != .new {
                        Text(why).font(Face.tiny).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                if !compact { ReadinessTag(readiness: model.readiness(ex.exerciseID)) }
                Button {
                    persist()
                    nav.show(ex.variant, symbol: "slider.horizontal.3") { SetEditor(sessionID: sessionID, exerciseID: ex.id) }
                } label: { Image(systemName: "pencil") }
                    .buttonStyle(QuietIconButton())
                    .help("Change reps, weight or the number of sets")
                    .accessibilityLabel("Edit sets for \(ex.variant)")
                Button {
                    nav.show(info.name, symbol: info.symbol) { CuesPopover(info: info) }
                } label: { Image(systemName: "info") }
                    .buttonStyle(QuietIconButton())
                    .help("How to do it")
                    .accessibilityLabel("How to do \(info.name)")
            }
            if compact { ReadinessTag(readiness: model.readiness(ex.exerciseID)) }
            FlowLayout(spacing: 8) {
                ForEach($ex.sets) { $set in
                    SetBubble(set: $set, timed: ex.timed, target: ex.high, low: ex.low)
                }
                if info.isBand {
                    BandField(kg: Binding(
                        get: { ex.sets.first?.kg },
                        set: { v in for i in ex.sets.indices { ex.sets[i].kg = v } }))
                } else if info.usesKg && !compact {
                    KgField(kg: Binding(
                        get: { ex.sets.first?.kg },
                        set: { v in for i in ex.sets.indices { ex.sets[i].kg = v } }))
                }
            }
        }
        .padding(.vertical, 12)
    }

    var targetLine: String {
        let unit = ex.timed ? " s" : ""
        let range = ex.low == ex.high ? "\(ex.low)\(unit)" : "\(ex.low)–\(ex.high)\(unit)"
        var s = "\(ex.sets.count) × \(range)"
        func load(_ kg: Double) -> String { info.isBand ? Bands.describe(kg) : "\(kg.formatted()) kg" }
        if compact, !info.isBand, let kg = ex.sets.first?.kg { s += " @ \(load(kg))" }
        if let last = model.lastLog(of: ex.exerciseID, variant: ex.variant, before: date) {
            s += " · last: " + last.doneSets.map { "\($0.value)" }.joined(separator: ", ")
            if let kg = last.topLoad { s += " @ \(load(kg))" }
        }
        return s
    }
}

struct SetBubble: View {
    @Binding var set: SetEntry
    var timed: Bool
    var target: Int
    var low: Int = 1
    @State private var hover = false
    @Environment(\.compact) private var compact

    /// Values offered on long-press / right-click: around the rep range.
    var choices: [Int] {
        let step = timed ? 5 : 1
        let lo = max(step, (min(low, set.value) - 3 * step) / step * step)
        let hi = max(target, set.value) + 3 * step
        return Array(stride(from: lo, through: hi, by: step))
    }

    var body: some View {
        HStack(spacing: 0) {
            if hover && !set.done {
                Button { set.value = max(0, set.value - (timed ? 5 : 1)) } label: {
                    Image(systemName: "minus").font(.system(size: 9, weight: .bold)).frame(width: 18, height: 34)
                }.buttonStyle(.plain)
            }
            Button { set.done.toggle() } label: {
                HStack(spacing: 5) {
                    if set.done { Image(systemName: "checkmark").font(.system(size: compact ? 12 : 10, weight: .bold)) }
                    Text("\(set.value)\(timed ? "s" : "")").font(.system(size: compact ? 17 : 14, weight: .semibold)).monospacedDigit()
                }
                .frame(minWidth: compact ? 56 : 40, minHeight: compact ? 46 : 34)
                .padding(.horizontal, 6)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .contextMenu {
                ForEach(choices, id: \.self) { v in
                    Button {
                        set.value = v
                        set.done = true
                    } label: {
                        if v == set.value { Label("\(v)\(timed ? " s" : "")", systemImage: "checkmark") } else { Text("\(v)\(timed ? " s" : "")") }
                    }
                }
            }
            if hover && !set.done {
                Button { set.value += (timed ? 5 : 1) } label: {
                    Image(systemName: "plus").font(.system(size: 9, weight: .bold)).frame(width: 18, height: 34)
                }.buttonStyle(.plain)
            }
        }
        .foregroundStyle(set.done ? Ink.sheet : Ink.ink)
        .background(Capsule().fill(set.done ? Ink.ink : Ink.sand))
        .overlay(Capsule().strokeBorder(set.done && set.value >= target ? Ink.red : .clear, lineWidth: 1.5))
        .onHover { h in if !compact { withAnimation(.easeOut(duration: 0.12)) { hover = h } } }
        .help(set.done ? "Click to undo" : "Click to tick · hover for − / + · right-click to pick a number")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(set.value) \(timed ? "seconds" : "reps"), \(set.done ? "done" : "not done")")
    }
}

struct KgField: View {
    @Binding var kg: Double?
    var body: some View {
        HStack(spacing: 4) {
            TextField("–", value: $kg, format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.plain)
                .multilineTextAlignment(.trailing)
                .frame(width: 38)
                .font(.system(size: 13, weight: .medium)).monospacedDigit()
            Text("kg").font(Face.small).foregroundStyle(Ink.ink2)
        }
        .padding(.horizontal, 10).frame(height: 30)
        .background(Capsule().fill(Ink.sand))
    }
}

/// Band load: steps through every combination of your five bands, lightest to heaviest.
struct BandField: View {
    @Binding var kg: Double?
    var body: some View {
        HStack(spacing: 2) {
            Button { kg = Bands.down(from: kg ?? Bands.rungs[0].total) } label: {
                Image(systemName: "minus").font(.system(size: 10, weight: .bold)).frame(width: 26, height: 30)
            }
            .buttonStyle(.plain).disabled(kg == nil)
            .accessibilityLabel("Lighter band")
            VStack(spacing: 0) {
                Text(kg.map(Bands.text) ?? "pick a band").font(.system(size: 13, weight: .semibold)).monospacedDigit()
                if let kg, let r = Bands.rungs[safe: Bands.nearest(kg)], r.bands.count > 1 {
                    Text(r.combo).font(.system(size: 10)).foregroundStyle(Ink.ink2).monospacedDigit()
                }
            }
            .frame(minWidth: 62)
            Button { kg = Bands.up(from: kg ?? 0) } label: {
                Image(systemName: "plus").font(.system(size: 10, weight: .bold)).frame(width: 26, height: 30)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Heavier band")
        }
        .foregroundStyle(Ink.ink)
        .padding(.horizontal, 4)
        .background(Capsule().fill(Ink.sand))
        .help("Band combination, by the kg printed on the bands. Tap − or + to move one rung.")
    }
}

struct ReadinessTag: View {
    var readiness: AppModel.Readiness
    var body: some View {
        switch readiness {
        case .stepUp:
            Label("Step up", systemImage: "arrow.up.right").font(Face.tiny).foregroundStyle(Ink.red)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.redSoft))
                .help("Top of the range on every set, all at one weight. Go up one step and start at the bottom of the range.")
        case .stalled:
            Label("Plateau", systemImage: "pause").font(Face.tiny).foregroundStyle(Ink.amber)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.amber.opacity(0.14)))
                .help("Four sessions at the same load without a gain. Check the technique, or change the range, the sets or the variation.")
        case .fixLoad:
            Label("Same weight", systemImage: "equal").font(Face.tiny).foregroundStyle(Ink.amber)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.amber.opacity(0.14)))
                .help("Every rep was there but not every set at the same weight. Do them all at one weight before going up.")
        case .backOff:
            Label("Back off", systemImage: "arrow.down.right").font(Face.tiny).foregroundStyle(Ink.amber)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.amber.opacity(0.14)))
                .help("Two rough sessions in a row. Lighter, and build up from the bottom of the range.")
        default:
            EmptyView()
        }
    }
}

/// How to do an exercise. Shown in the bottom bubble, which carries the name.
struct CuesPopover: View {
    var info: ExerciseInfo
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(info.photos, id: \.self) { PhotoPair(id: $0) }
            if !info.photoNote.isEmpty {
                Text(info.photoNote).font(Face.tiny).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
            if info.muscles.isEmpty {
                Text(info.why).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(info.muscles, id: \.self) { m in
                        Text(m).font(Face.tiny).padding(.horizontal, 9).padding(.vertical, 3)
                            .foregroundStyle(Ink.sheet).background(Capsule().fill(Ink.ink))
                    }
                    ForEach(info.alsoMuscles, id: \.self) { m in
                        Text(m).font(Face.tiny).padding(.horizontal, 9).padding(.vertical, 3)
                            .foregroundStyle(Ink.ink2).background(Capsule().fill(Ink.sand))
                    }
                }
            }
            if info.isBand, let start = info.bandStart {
                Text("Start around \(Bands.describe(start)). It's a guess: stay in the rep range, stop 1–3 reps short, and two sessions will correct it.")
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
            if !info.setup.isEmpty {
                Text("Set-up").font(Face.tiny).foregroundStyle(Ink.ink3).textCase(.uppercase)
                Text(info.setup).font(Face.body).fixedSize(horizontal: false, vertical: true)
            }
            if !info.cues.isEmpty {
                Text("How").font(Face.tiny).foregroundStyle(Ink.ink3).textCase(.uppercase)
            }
            ForEach(Array(info.cues.enumerated()), id: \.offset) { i, c in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(i + 1)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.red).frame(width: 14, alignment: .leading).padding(.top, 2)
                    Text(c).font(Face.body).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !info.mistakes.isEmpty {
                Text("Common mistakes").font(Face.tiny).foregroundStyle(Ink.ink3).textCase(.uppercase)
                ForEach(info.mistakes, id: \.self) { m in
                    Label(m, systemImage: "xmark").font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !info.elbowNote.isEmpty {
                Label(info.elbowNote, systemImage: "cross.case").font(Face.small).foregroundStyle(Ink.red).fixedSize(horizontal: false, vertical: true)
            }
            if !info.watch.isEmpty, info.mistakes.isEmpty {
                Label(info.watch, systemImage: "exclamationmark.triangle")
                    .font(Face.small).foregroundStyle(Ink.red).fixedSize(horizontal: false, vertical: true)
            }
            if !info.gymSwap.isEmpty {
                Text("Gym swap: \(info.gymSwap)").font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
            if !info.ladder.isEmpty {
                Text("Steps: " + info.ladder.joined(separator: " → "))
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            } else if let step = info.loadStep {
                Text("Next step: \(step)").font(Face.small).foregroundStyle(Ink.ink2)
            }
        }
    }
}

/// Today's sets for one exercise, every number editable, sets added or
/// removed. Changes this log only; the plan lives in Settings → Sessions.
struct SetEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let sessionID: UUID
    let exerciseID: UUID

    private var stored: ExerciseLog? { model.session(id: sessionID)?.exercises.first { $0.id == exerciseID } }

    /// Reads and writes the saved exercise, so the bubble always shows what's stored.
    private var ex: ExerciseLog {
        get { stored ?? ExerciseLog(exerciseID: "", variant: "", timed: false, low: 0, high: 0, sets: []) }
        nonmutating set {
            model.editSession(sessionID) { s in
                if let i = s.exercises.firstIndex(where: { $0.id == exerciseID }) { s.exercises[i] = newValue }
            }
        }
    }

    var usesKg: Bool { Library.exercise(ex.exerciseID).usesKg }
    var isBand: Bool { Library.exercise(ex.exerciseID).isBand }
    var step: Int { ex.timed ? 5 : 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Target \(ex.low == ex.high ? "\(ex.low)" : "\(ex.low)–\(ex.high)")\(ex.timed ? " s" : " reps"). Tick a set when it's done.")
                .font(Face.small).foregroundStyle(Ink.ink2)
            ForEach(Array(ex.sets.enumerated()), id: \.element.id) { i, set in
                HStack(spacing: 10) {
                    Text("Set \(i + 1)").font(Face.heading).frame(width: 48, alignment: .leading)
                    StepperField(value: bind(set.id, \.value), range: 0...500, step: step, suffix: ex.timed ? " s" : "")
                    if usesKg {
                        if isBand {
                            BandField(kg: Binding(get: { ex.sets.first { $0.id == set.id }?.kg },
                                                  set: { v in update(set.id) { $0.kg = v } }))
                        } else {
                            StepperField(value: Binding(get: { Int(ex.sets.first { $0.id == set.id }?.kg ?? 0) },
                                                        set: { v in update(set.id) { $0.kg = v == 0 ? nil : Double(v) } }),
                                         range: 0...200, step: 1, suffix: " kg")
                        }
                    }
                    Spacer(minLength: 0)
                    Toggle("", isOn: bind(set.id, \.done)).toggleStyle(InkCheck()).labelsHidden()
                        .accessibilityLabel("Set \(i + 1) done")
                    if ex.sets.count > 1 {
                        Button { var e = ex; e.sets.removeAll { $0.id == set.id }; ex = e } label: { Image(systemName: "minus") }
                            .buttonStyle(QuietIconButton()).accessibilityLabel("Remove set \(i + 1)")
                    }
                }
            }
            HStack {
                Button {
                    var e = ex
                    var next = e.sets.last ?? SetEntry(value: e.low)
                    next.id = UUID(); next.done = false
                    e.sets.append(next)
                    ex = e
                } label: { Label("Add a set", systemImage: "plus") }
                    .buttonStyle(InkButtonStyle(filled: false))
                Spacer()
                Button("Done") { nav.dismissBubble() }.buttonStyle(InkButtonStyle())
            }
            Text("This changes today's log. To change the plan itself: Settings → Sessions.")
                .font(Face.tiny).foregroundStyle(Ink.ink2)
        }
    }

    func update(_ id: UUID, _ change: (inout SetEntry) -> Void) {
        var e = ex
        guard let i = e.sets.firstIndex(where: { $0.id == id }) else { return }
        change(&e.sets[i])
        ex = e
    }

    func bind<T>(_ id: UUID, _ kp: WritableKeyPath<SetEntry, T>) -> Binding<T> {
        Binding(get: { (ex.sets.first { $0.id == id } ?? SetEntry(value: 0))[keyPath: kp] },
                set: { v in update(id) { $0[keyPath: kp] = v } })
    }
}

// MARK: - Walk, check, pain, energy

struct WalkLogger: View {
    @Environment(AppModel.self) private var model
    @Binding var log: SessionLog
    let date: Date
    var body: some View {
        HStack(spacing: 24) {
            HStack(spacing: 8) {
                Text("Minutes").font(Face.body).foregroundStyle(Ink.ink2)
                StepperField(value: Binding(get: { log.minutes ?? 0 }, set: { log.minutes = $0 }), range: 0...300, step: 5)
            }
            StepsField(date: date)
        }
    }
}

struct StepsField: View {
    @Environment(AppModel.self) private var model
    let date: Date
    var body: some View {
        let floor = model.blockWeek(for: date)?.template.stepFloor ?? 7000
        HStack(spacing: 8) {
            Text("Steps").font(Face.body).foregroundStyle(Ink.ink2)
            TextField("0", value: Binding(get: { model.daily(date).steps }, set: { v in model.setDaily(date) { $0.steps = v; if v == nil { $0.typed.remove("steps") } else { $0.typed.insert("steps") } } }),
                      format: .number)
                .textFieldStyle(.plain).monospacedDigit()
                .frame(width: 64)
                .padding(.horizontal, 10).frame(height: 28)
                .background(Capsule().fill(Ink.sand))
            Text("floor \(floor.formatted())").font(Face.small).foregroundStyle(Ink.ink2)
        }
    }
}

struct CheckLogger: View {
    @Environment(AppModel.self) private var model
    let date: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weigh after the toilet, before food. Waist at the navel. Compare the 7-day average, not today's number.")
                .font(Face.small).foregroundStyle(Ink.ink2)
            HStack(spacing: 24) {
                MeasureField(label: "Weight", unit: "kg", value: Binding(get: { model.daily(date).weightKg }, set: { v in model.setDaily(date) { $0.weightKg = v; if v == nil { $0.typed.remove("weight") } else { $0.typed.insert("weight") } } }))
                MeasureField(label: "Waist", unit: "cm", value: Binding(get: { model.daily(date).waistCm }, set: { v in model.setDaily(date) { $0.waistCm = v } }))
            }
        }
    }
}

struct MeasureField: View {
    var label: String
    var unit: String
    @Binding var value: Double?
    var body: some View {
        HStack(spacing: 8) {
            Text(label).font(Face.body).foregroundStyle(Ink.ink2)
            TextField("–", value: $value, format: .number.precision(.fractionLength(0...1)))
                .textFieldStyle(.plain).monospacedDigit().frame(width: 52)
                .padding(.horizontal, 10).frame(height: 28)
                .background(Capsule().fill(Ink.sand))
            Text(unit).font(Face.small).foregroundStyle(Ink.ink2)
        }
    }
}

struct PainCheck: View {
    @Binding var pain: [PainEntry]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Anything niggling?").font(Face.heading).foregroundStyle(Ink.ink)
            FlowLayout(spacing: 6) {
                ForEach(BodyArea.allCases) { area in
                    let on = pain.contains { $0.area == area }
                    Button(area.name) {
                        if on { pain.removeAll { $0.area == area } } else { pain.append(PainEntry(area: area, score: 2)) }
                    }.buttonStyle(ChipStyle(on: on))
                }
            }
            ForEach($pain) { $p in
                HStack(spacing: 14) {
                    Text(p.area.name).font(Face.body).frame(width: 76, alignment: .leading)
                    Slider(value: Binding(get: { Double(p.score) }, set: { p.score = Int($0.rounded()) }), in: 0...10, step: 1)
                        .tint(Ink.pain(p.light))
                        .frame(maxWidth: 220)
                    Text("\(p.score)").monospacedDigit().font(.system(size: 13, weight: .semibold)).frame(width: 20)
                    Circle().fill(Ink.pain(p.light)).frame(width: 8, height: 8)
                    Text(rule(p)).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    func rule(_ p: PainEntry) -> String {
        switch p.light {
        case .green: "Green — carry on."
        case .amber: "Amber — stop that exercise or hold type, finish with easy stuff."
        case .red: p.area == .fingers ? "Red — session over. A finger pop or sharp pain = physio before climbing again." : "Red — session over."
        }
    }
}

struct EnergyAndNote: View {
    @Binding var log: SessionLog
    var body: some View {
        AdaptiveStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Energy").font(Face.heading).foregroundStyle(Ink.ink)
                HStack(spacing: 2) {
                    ForEach(1...5, id: \.self) { n in
                        let word = ["Empty", "Low", "OK", "Good", "Flying"][n - 1]
                        Button { log.energy = log.energy == n ? nil : n } label: {
                            Circle()
                                .fill((log.energy ?? 0) >= n ? Ink.ink : Ink.sand)
                                .frame(width: 18, height: 18)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(word)
                        .accessibilityLabel("Energy \(n) of 5, \(word)")
                        .accessibilityAddTraits(log.energy == n ? .isSelected : [])
                    }
                    if let e = log.energy {
                        Text(["Empty", "Low", "OK", "Good", "Flying"][e - 1]).font(Face.small).foregroundStyle(Ink.ink2).padding(.leading, 6)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Note").font(Face.heading).foregroundStyle(Ink.ink)
                TextField("The problem to come back to, how the elbow felt…", text: $log.note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(Face.body)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.sand.opacity(0.6)))
            }
        }
    }
}

/// Wrapping row layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
            widest = max(widest, x)
        }
        return CGSize(width: min(widest, maxW), height: y + rowH)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > bounds.maxX, x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
    }
}

/// Pain, energy and a note: useful, never required, so folded away until asked for.
struct DetailsDisclosure: View {
    @Binding var log: SessionLog
    @State private var open = false

    var hasAny: Bool { !log.pain.isEmpty || log.energy != nil || !log.note.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                withAnimation(.snappy(duration: 0.25)) { open.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: open || hasAny ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .bold))
                    Text(hasAny && !open ? "Details: \(summary)" : "Add details — anything niggling, energy, a note")
                        .font(Face.body)
                    Spacer(minLength: 0)
                }
                .foregroundStyle(Ink.ink2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if open {
                PainCheck(pain: $log.pain)
                EnergyAndNote(log: $log)
            }
        }
    }

    var summary: String {
        var parts: [String] = []
        if !log.pain.isEmpty { parts.append(log.pain.map { "\($0.area.name.lowercased()) \($0.score)" }.joined(separator: ", ")) }
        if let e = log.energy { parts.append("energy \(e)/5") }
        if !log.note.isEmpty { parts.append("note") }
        return parts.joined(separator: " · ")
    }
}
