import SwiftUI

/// The personal trainer: a daily check-in or a weekly analysis. Claude reads
/// the log, asks you a few questions, and proposes changes you can apply one
/// at a time, and undo.
struct CoachPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @State private var running: CoachScope?

    var body: some View {
        Page(title: "Coach", subtitle: "A trainer's read of your log. It asks, you answer, and you decide which changes to make.") {
            #if os(macOS)
            HStack(spacing: 10) {
                Button { run(.daily) } label: { Label("Daily check-in", systemImage: "sun.max") }
                    .buttonStyle(InkButtonStyle(filled: false)).disabled(model.coachBusy != nil)
                Button { run(.weekly) } label: { Label("Weekly analysis", systemImage: "calendar.badge.checkmark") }
                    .buttonStyle(InkButtonStyle()).disabled(model.coachBusy != nil)
            }
            #endif
        } content: {
            VStack(alignment: .leading, spacing: 22) {
                #if !os(macOS)
                NoticeCard(symbol: "desktopcomputer", text: "Check-ins run on the Mac, where Claude is. Answer a question here and it reaches the Mac on the next sync.") { EmptyView() }
                #endif
                if let busy = model.coachBusy {
                    HStack(spacing: 12) {
                        ProgressView().controlSize(.small)
                        Text(busy).font(Face.body).foregroundStyle(Ink.ink)
                        Spacer()
                    }
                    .sheetCard(padding: 16)
                }
                if let problem = model.coachProblem {
                    NoticeCard(symbol: "exclamationmark.circle", text: problem) {
                        Button("OK") { model.coachProblem = nil }.buttonStyle(InkButtonStyle(filled: false))
                    }
                }
                if let latest = model.coachReports.first {
                    ReportCard(reportID: latest.id, expanded: true)
                } else {
                    Intro()
                }
                Numbers()
                GoalsCard()
                if model.coachReports.count > 1 {
                    SectionTitle(text: "Earlier", detail: "Every check-in is also saved in the app folder.")
                    ForEach(model.coachReports.dropFirst()) { r in ReportCard(reportID: r.id, expanded: false) }
                }
                FilesNote()
            }
        }
    }

    func run(_ scope: CoachScope) {
        Task { await model.startCheckIn(scope: scope) }
    }
}

private struct Intro: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No check-in yet").font(Face.title)
            Text("Press Weekly analysis on a Sunday or Monday, or Daily check-in on a morning you're not sure about. Claude reads your climbs, lifts, skips, elbows, energy, steps and food, asks a few questions, then says whether to keep going as planned or change something, and why. Nothing changes until you press Apply.")
                .font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
        }
        .sheetCard()
    }
}

/// What Cairn's own arithmetic says, with no model: always there.
private struct Numbers: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let local = model.coachLocal(scope: .weekly)
        if !local.notes.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("From the numbers, right now").font(Face.heading)
                ForEach(local.notes) { n in NoteRow(note: n) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheetCard(padding: 18)
        }
    }
}

struct NoteRow: View {
    let note: CoachNote
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle().fill(note.kind == .win ? Ink.green : note.kind == .concern ? Ink.amber : Ink.lineStrong).frame(width: 7, height: 7)
            Text(note.text).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FilesNote: View {
    var body: some View {
        #if os(macOS)
        Text("Check-ins and the data they read are saved as files in \(Coach.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~")), so you can look any of them up.")
            .font(Face.tiny).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
        #else
        EmptyView()
        #endif
    }
}

// MARK: - One check-in

struct ReportCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    let reportID: UUID
    @State var expanded: Bool
    @State private var drafts: [String: String] = [:]
    @State private var notesOpen = false

    init(reportID: UUID, expanded: Bool) {
        self.reportID = reportID
        _expanded = State(initialValue: expanded)
    }

    var body: some View {
        if let r = model.report(reportID) {
            VStack(alignment: .leading, spacing: 16) {
                Button { withAnimation(.snappy(duration: 0.25)) { expanded.toggle() } } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(r.scope.name) · \(Day.date(r.day).map(Day.short) ?? r.day)").font(Face.small).foregroundStyle(Ink.ink2)
                            Text(r.headline.isEmpty ? "Waiting for your answers" : r.headline).font(Face.title).foregroundStyle(Ink.ink)
                                .multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        verdict(r)
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.ink3)
                            .rotationEffect(.degrees(expanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if expanded {
                    if let p = r.problem {
                        Label(p, systemImage: "exclamationmark.circle").font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    if !r.summary.isEmpty {
                        Text(r.summary).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
                    }
                    if !r.wins.isEmpty || !r.concerns.isEmpty {
                        AdaptiveStack(spacing: 24) {
                            if !r.wins.isEmpty { list("Going well", r.wins, .win) }
                            if !r.concerns.isEmpty { list("Watch", r.concerns, .concern) }
                        }
                    }
                    if !r.questions.isEmpty { questions(r) }
                    if !r.adjustments.isEmpty { adjustments(r) }
                    if !r.nextWeek.isEmpty {
                        Rule(seed: 81)
                        Text(r.scope == .weekly ? "The week ahead" : "Tomorrow").font(Face.heading)
                        Text(r.nextWeek).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                    if !r.notes.isEmpty {
                        DisclosureGroup(isExpanded: $notesOpen) {
                            VStack(alignment: .leading, spacing: 8) { ForEach(r.notes) { NoteRow(note: $0) } }.padding(.top, 8)
                        } label: { Text("From the numbers at the time").font(Face.small).foregroundStyle(Ink.ink2) }
                    }
                    if r.stage == .offline {
                        HStack {
                            Text("Claude wasn't used for this one.").font(Face.small).foregroundStyle(Ink.ink2)
                            Spacer()
                            #if os(macOS)
                            Button("Run it again") { Task { await model.startCheckIn(scope: r.scope) } }
                                .buttonStyle(InkButtonStyle(filled: false)).disabled(model.coachBusy != nil)
                            #endif
                        }
                    }
                }
            }
            .sheetCard()
        }
    }

    func verdict(_ r: CoachReport) -> some View {
        let (text, color): (String, Color) = switch r.verdict {
        case "deload": ("Deload", Ink.amber)
        case "adjust": ("Adjust", Ink.red)
        case "keep": ("Keep going", Ink.green)
        default: (r.stage == .asking ? "Questions" : "", Ink.ink2)
        }
        return Group {
            if !text.isEmpty {
                Text(text).font(Face.tiny).foregroundStyle(color)
                    .padding(.horizontal, 9).padding(.vertical, 3).background(Capsule().fill(color.opacity(0.14)))
            }
        }
    }

    func list(_ title: String, _ items: [String], _ kind: CoachNote.Kind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(Face.heading)
            ForEach(items, id: \.self) { NoteRow(note: CoachNote(kind: kind, text: $0)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // The question box

    @ViewBuilder func questions(_ r: CoachReport) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Rule(seed: 82)
            HStack(alignment: .firstTextBaseline) {
                Text(r.stage == .final ? "Your answers" : "Check in").font(Face.heading)
                Text(r.stage == .final ? "" : "Answer what you like. Skip the rest.").font(Face.small).foregroundStyle(Ink.ink2)
            }
            ForEach(r.questions) { q in
                VStack(alignment: .leading, spacing: 8) {
                    Text(q.text).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
                    switch q.kind {
                    case "choice":
                        FlowLayout(spacing: 8) {
                            ForEach(q.options, id: \.self) { o in
                                Button(o) { model.answer(reportID, question: q.id, q.answer == o ? "" : o) }
                                    .buttonStyle(ChipStyle(on: q.answer == o))
                            }
                        }
                    case "scale":
                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { n in
                                Button("\(n)") { model.answer(reportID, question: q.id, q.answer == "\(n)" ? "" : "\(n)") }
                                    .buttonStyle(ChipStyle(on: q.answer == "\(n)"))
                            }
                            Text("1 low, 5 great").font(Face.tiny).foregroundStyle(Ink.ink3)
                        }
                    default:
                        TextField("Type here", text: Binding(get: { drafts[q.id] ?? q.answer ?? "" }, set: { drafts[q.id] = $0 }), axis: .vertical)
                            .textFieldStyle(.plain).font(Face.body)
                            .padding(10).background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.sand))
                            .onSubmit { model.answer(reportID, question: q.id, drafts[q.id] ?? "") }
                            .disabled(r.stage == .final)
                    }
                }
                .disabled(r.stage == .final && q.kind != "text")
            }
            if r.stage != .final {
                #if os(macOS)
                HStack {
                    Button {
                        for (id, v) in drafts { model.answer(reportID, question: id, v) }
                        if r.stage == .asking { Task { await model.finishCheckIn(reportID) } }
                    } label: {
                        Label(r.stage == .asking ? "Send my answers" : "Save my answers", systemImage: "paperplane")
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(model.coachBusy != nil)
                    Text(r.stage == .asking ? "Claude then gives its final read and the changes it recommends." : "These are saved with the check-in.")
                        .font(Face.small).foregroundStyle(Ink.ink2)
                }
                #else
                Text("Answers save as you tap. Press Send on the Mac to get the final read.").font(Face.small).foregroundStyle(Ink.ink2)
                #endif
            }
        }
    }

    // What it suggests

    @ViewBuilder func adjustments(_ r: CoachReport) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Rule(seed: 83)
            Text(r.stage == .asking ? "Provisional changes" : "Suggested changes").font(Face.heading)
            if r.stage == .asking {
                Text("These may change once Claude has your answers.").font(Face.small).foregroundStyle(Ink.ink2)
            }
            ForEach(r.adjustments) { a in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: symbol(a)).font(.system(size: 14)).foregroundStyle(Ink.red).frame(width: 22).padding(.top, 1)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(model.describe(a)).font(Face.body).foregroundStyle(a.status == .dismissed ? Ink.ink3 : Ink.ink)
                                .strikethrough(a.status == .dismissed).fixedSize(horizontal: false, vertical: true)
                            if !a.reason.isEmpty { Text(a.reason).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true) }
                            if let res = a.result { Text(res).font(Face.small).foregroundStyle(a.status == .applied ? Ink.green : Ink.ink2) }
                        }
                    }
                    if a.canApply && r.stage != .asking {
                        HStack(spacing: 8) {
                            switch a.status {
                            case .pending:
                                Button("Not now") { model.dismissAdjustment(reportID, a.id) }.buttonStyle(InkButtonStyle(filled: false))
                                Button("Apply") { model.applyAdjustment(reportID, a.id) }.buttonStyle(InkButtonStyle())
                            case .applied:
                                Button("Undo") { model.undoAdjustment(reportID, a.id) }.buttonStyle(InkButtonStyle(filled: false))
                            case .dismissed:
                                Button("Reconsider") { model.updateReport(reportID) { rep in if let i = rep.adjustments.firstIndex(where: { $0.id == a.id }) { rep.adjustments[i].status = .pending } } }
                                    .buttonStyle(InkButtonStyle(filled: false))
                            }
                        }
                        .padding(.leading, 32)
                    }
                }
            }
        }
    }

    func symbol(_ a: CoachAdjustment) -> String {
        switch a.type {
        case "exercise_load": "scalemass"
        case "exercise_scheme": "slider.horizontal.3"
        case "schedule_move": "calendar.badge.clock"
        case "repeat_week", "return_week": "arrow.triangle.2.circlepath"
        case "goal": "flag"
        default: "text.bubble"
        }
    }
}

extension AppModel {
    /// One adjustment, as a sentence.
    func describe(_ a: CoachAdjustment) -> String {
        let ex = a.exerciseID.map { Library.exercise($0).name } ?? "that exercise"
        switch a.type {
        case "exercise_load":
            let isBand = a.exerciseID.map { Library.exercise($0).isBand } ?? false
            return "\(ex): start at \(a.kg.map { isBand ? Bands.text($0) : "\(Overload.kgText($0)) kg" } ?? "a new weight") next session"
        case "exercise_scheme":
            var parts: [String] = []
            if let lo = a.low, let hi = a.high { parts.append(lo == hi ? "\(lo) reps" : "\(lo)–\(hi) reps") }
            if let s = a.sets { parts.append("\(s) sets") }
            return "\(ex): change to \(parts.joined(separator: ", ")) from this week"
        case "schedule_move":
            let t = a.template.flatMap { id in sessionTemplates.first { ($0.workoutID ?? "climb").lowercased() == id.lowercased() }?.name } ?? a.template ?? "session"
            return "Move \(t) from \(a.from ?? "?") to \(a.to ?? "?") this week"
        case "repeat_week": return "Run this week again next week"
        case "return_week": return "Make this an easy return week, then run it again"
        case "goal": return "New goal: \(a.text ?? "")" + (a.byWeek.map { " (by week \($0))" } ?? "")
        default: return a.text ?? a.reason
        }
    }
}
