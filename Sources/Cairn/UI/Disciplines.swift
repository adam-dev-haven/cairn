import Charts
import SwiftUI

// MARK: - Bouldering

struct BoulderPage: View {
    @Environment(AppModel.self) private var model
    @State private var area = "Safety"

    var body: some View {
        Page(title: "Bouldering", subtitle: model.grades("You already have the strength for V0–V3. Technique is what makes V4 possible without wrecking your fingers.")) {
            VStack(alignment: .leading, spacing: 40) {
                DrillHero()
                ClimbStats()
                DrillCurriculum()
                AdaptiveStack(spacing: 24) {
                    WallRules().frame(maxWidth: .infinity)
                    GradeCaps().frame(maxWidth: .infinity)
                }
                TechniqueLibrary(area: $area)
                InjuryRules()
            }
        }
    }
}

struct ClimbStats: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    var body: some View {
        let sessions = model.climbSessions
        let sends = sessions.flatMap { $0.climb?.sends ?? [] }
        let flashes = sends.filter(\.flash).count
        AdaptiveStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 22) {
                LazyVGrid(columns: Array(repeating: GridItem(compact ? .flexible() : .fixed(150), alignment: .leading), count: compact ? 2 : 4),
                          alignment: .leading, spacing: 16) {
                    Stat(value: model.hardestEverRank.map(model.rankLabel) ?? "–", label: "hardest send", size: compact ? 30 : 40)
                    Stat(value: "\(sends.count)", label: "sends this block", size: compact ? 30 : 40)
                    Stat(value: sends.isEmpty ? "–" : "\(Int((Double(flashes) / Double(sends.count) * 100).rounded()))%", label: "first try", size: compact ? 30 : 40)
                    Stat(value: "\(sessions.count)", label: "sessions", size: compact ? 30 : 40)
                }
                HardestChart(sessions: sessions)
                    .frame(height: 180)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheetCard()
            Pyramid()
                .frame(width: compact ? nil : 320)
                .frame(maxWidth: compact ? .infinity : nil, maxHeight: .infinity, alignment: .top)
                .sheetCard()
        }
        .fixedSize(horizontal: false, vertical: !compact)
    }
}

struct HardestChart: View {
    @Environment(AppModel.self) private var model
    var sessions: [SessionLog]
    var body: some View {
        let points = sessions.compactMap { s -> (Date, Int, Int)? in
            guard let h = model.hardest(s.climb?.problems ?? []) else { return nil }
            return (s.date, h, s.climb?.sends.count ?? 0)
        }
        let top = model.circuits.isEmpty ? max(4, (points.map(\.1).max() ?? 0) + 1) : max(1, model.circuits.count - 1)
        if points.isEmpty {
            EmptyChart(text: "Your hardest send per session lands here. Log a climb with the grades you sent.")
        } else {
            Chart {
                ForEach(points, id: \.0) { p in
                    LineMark(x: .value("Day", p.0, unit: .day), y: .value("Grade", p.1))
                        .interpolationMethod(.stepEnd)
                        .foregroundStyle(Ink.ink)
                    PointMark(x: .value("Day", p.0, unit: .day), y: .value("Grade", p.1))
                        .foregroundStyle(Ink.red)
                        .symbolSize(30)
                }
            }
            .chartYScale(domain: 0...top)
            .chartYAxis {
                AxisMarks(values: Array(0...top)) { v in
                    AxisGridLine().foregroundStyle(Ink.line)
                    AxisValueLabel { if let g = v.as(Int.self) { Text(model.rankLabel(g)).font(Face.tiny).foregroundStyle(Ink.ink2) } }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(Face.tiny).foregroundStyle(Ink.ink2)
                }
            }
        }
    }
}

struct EmptyChart: View {
    var text: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Ink.line, style: StrokeStyle(lineWidth: 1, dash: [3, 4]))
            Text(text).font(Face.small).foregroundStyle(Ink.ink2).multilineTextAlignment(.center).padding(24)
        }
    }
}

/// Sends per grade, stacked like a pyramid: wide base, narrow top.
struct Pyramid: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let sends = model.climbSessions.flatMap { $0.climb?.sends ?? [] }
        let counts = Dictionary(grouping: sends, by: model.rank).mapValues(\.count)
        let top = model.circuits.isEmpty ? max(4, (counts.keys.max() ?? 0) + 1) : model.circuits.count - 1
        let most = max(1, counts.values.max() ?? 1)
        let hardest = model.hardestEverRank
        VStack(alignment: .leading, spacing: 12) {
            Text("Pyramid").font(Face.title)
            Text("A wide base is what holds up the top.").font(Face.small).foregroundStyle(Ink.ink2)
            VStack(spacing: 5) {
                ForEach((0...top).reversed(), id: \.self) { g in
                    let n = counts[g] ?? 0
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            if let c = model.rankColor(g) { Circle().fill(c).frame(width: 8, height: 8) }
                            Text(model.rankLabel(g)).font(.system(size: 11, weight: .semibold).width(model.circuits.isEmpty ? .expanded : .standard))
                                .lineLimit(1)
                        }
                        .frame(width: model.circuits.isEmpty ? 26 : 64, alignment: .leading)
                        GeometryReader { geo in
                            let w = n == 0 ? 2 : max(8, geo.size.width * CGFloat(n) / CGFloat(most))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(n == 0 ? Ink.line : (g == hardest ? Ink.red : Ink.ink))
                                .frame(width: w)
                                .frame(maxWidth: .infinity)
                        }
                        .frame(height: 14)
                        Text(n == 0 ? "" : "\(n)").font(Face.tiny).monospacedDigit().foregroundStyle(Ink.ink2).frame(width: 22, alignment: .trailing)
                    }
                }
            }
        }
    }
}

/// Your drill now: the plan's for the week, or the one you moved on to.
/// Clear it when it's boring and the next one starts.
struct DrillHero: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    var body: some View {
        if let drill = model.currentDrill {
            let mastered = model.drillMastered(drill.id)
            let learnable = Library.drillOrder.contains(drill.id)
            AdaptiveStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.store.drillChoice != nil ? "Your drill" : "Drill for week \(model.currentWeek?.number ?? 1)")
                            .font(Face.small).foregroundStyle(Ink.ink2)
                        Spacer()
                        DrillMenu(current: drill.id)
                    }
                    Text(drill.name).font(Face.display(compact ? 26 : 34, .regular)).foregroundStyle(Ink.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.grades(drill.done)).font(.system(size: 15)).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
                    Text(model.grades("Do it on easy problems (V0–V1) until it feels boring. Then clear it and the next one starts — no need to wait for next week."))
                        .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    if learnable && !mastered {
                        Button { model.clearDrill(drill.id) } label: {
                            Label(model.nextDrill(after: drill.id).map { "Got it. Next: \($0.name)" } ?? "Got it", systemImage: "forward.end")
                                .frame(maxWidth: compact ? .infinity : nil)
                        }
                        .buttonStyle(InkButtonStyle())
                    } else if mastered {
                        Label("Cleared \(model.store.drillsMastered[drill.id].flatMap(Day.date).map(Day.short) ?? "")", systemImage: "checkmark.seal")
                            .font(Face.body).foregroundStyle(Ink.ink2)
                    }
                    if model.store.drillChoice != nil {
                        Button("Back to the plan's drill") { model.followPlanDrill() }
                            .buttonStyle(TextLinkStyle()).font(Face.small).foregroundStyle(Ink.ink2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(drill.how.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(i + 1)").font(Face.display(18, .regular)).foregroundStyle(Ink.red).frame(width: 18)
                            Text(step).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .sheetCard(padding: compact ? 18 : 28)
        }
    }
}

struct DrillCurriculum: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "Drill curriculum", detail: "One skill at a time. Tap any drill to work on it now; cleared ones are ticked.")
            let current = model.currentDrill?.id
            let cleared = Library.drillOrder.filter(model.drillMastered).count
            Text("\(cleared) of \(Library.drillOrder.count) cleared").font(Face.small).foregroundStyle(Ink.ink2)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: compact ? 2 : 4), spacing: 12) {
                ForEach(Library.drills) { d in
                    let mastered = model.drillMastered(d.id)
                    let learnable = Library.drillOrder.contains(d.id)
                    let isCurrent = d.id == current
                    Button {
                        if learnable { model.chooseDrill(d.id) }
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(d.name).font(.system(size: 13.5, weight: .semibold)).foregroundStyle(Ink.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                if mastered { Image(systemName: "checkmark.seal.fill").font(.system(size: 12)).foregroundStyle(Ink.ink) }
                                Text("wk \(d.week)").font(Face.tiny).foregroundStyle(isCurrent ? Ink.red : Ink.ink3)
                            }
                            Text(d.done).font(Face.small).foregroundStyle(Ink.ink2).lineLimit(3).multilineTextAlignment(.leading)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(isCurrent ? Ink.sheet : Ink.sheet.opacity(0.55)))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(isCurrent ? Ink.red.opacity(0.6) : Ink.line))
                        .opacity(learnable ? 1 : 0.6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!learnable)
                    .contextMenu {
                        if mastered { Button("Not cleared yet") { model.unclearDrill(d.id) } }
                        else if learnable { Button("Mark cleared") { model.mutate { $0.drillsMastered[d.id] = Day.key(model.today) } } }
                    }
                }
            }
        }
    }
}

struct WallRules: View {
    let rules: [(String, String, String)] = [
        ("3.circle", "Three tries, then move on", "Anything you can't send in three attempts goes on a list for next session. Rest 2–3 minutes between hard attempts."),
        ("hand.raised", "No full crimp", "Thumb wrapped over the fingers on a tiny edge is the classic pulley injury. Open hand or half crimp only."),
        ("arrow.down.to.line", "Land, don't catch", "Fall onto both feet, bend the knees, roll back. Never put an arm out behind you."),
    ]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("The three rules on the wall").font(Face.title)
            ForEach(rules, id: \.1) { r in
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: r.0).font(.system(size: 18)).foregroundStyle(Ink.red).frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(r.1).font(Face.heading)
                        Text(r.2).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .sheetCard()
    }
}

struct GradeCaps: View {
    @Environment(AppModel.self) private var model
    let rows: [(Phase, String, String, String, String)] = [
        (.foundation, "Weeks 1–4", "V0–V2", "Max 2 V3 per session", "Small crimps on overhang, pockets, dynos, campus, hangboard"),
        (.build, "Weeks 6–9", "V0–V3", "Up to 3 projects, 5 tries each", "Dynos, campus, hangboard"),
        (.push, "Weeks 11–12", "V1–V3", "V4 once V3s go in ≤3 tries", "Campus, hangboard"),
    ]
    var body: some View {
        let current = model.currentWeek?.phase
        VStack(alignment: .leading, spacing: 14) {
            Text("Grade caps").font(Face.title)
            ForEach(rows, id: \.0) { r in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Circle().fill(Ink.phaseDot(r.0)).frame(width: 9, height: 9)
                        Text(r.0.name).font(Face.heading).foregroundStyle(current == r.0 ? Ink.red : Ink.ink)
                        Text(r.1).font(Face.small).foregroundStyle(Ink.ink2)
                    }
                    Text(model.grades("Repeats \(r.2) · projects: \(r.3)")).font(Face.body)
                    Text("Off-limits: \(r.4)").font(Face.small).foregroundStyle(Ink.ink2)
                }
                if r.0 != .push { Rule(seed: r.1.count) }
            }
            Text("No hangboard this block. It's the fastest route to a finger injury in your first year.")
                .font(Face.small).foregroundStyle(Ink.red).fixedSize(horizontal: false, vertical: true)
        }
        .sheetCard()
    }
}

struct TechniqueLibrary: View {
    @Environment(AppModel.self) private var model
    @Binding var area: String
    @Environment(\.compact) private var compact
    @State private var open: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AdaptiveStack(spacing: 12) {
                SectionTitle(text: "Technique", detail: "What each skill is, how to learn it, what goes wrong.")
                Picker("", selection: $area) {
                    ForEach(Library.techniqueAreas, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: compact ? nil : 380)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: compact ? 1 : 2), alignment: .leading, spacing: 16) {
                ForEach(Library.techniques.filter { $0.area == area }) { t in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(t.title).font(Face.title)
                        Text(model.grades(t.summary)).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
                        Rule(seed: t.title.count)
                        ForEach(Array(t.steps.enumerated()), id: \.offset) { i, s in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(i + 1)").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.red).frame(width: 12)
                                Text(s).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        ForEach(t.mistakes, id: \.self) { m in
                            Label(m, systemImage: "xmark").font(Face.small).foregroundStyle(Ink.ink2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .sheetCard()
                }
            }
        }
    }
}

struct InjuryRules: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "The pain traffic light", detail: "Rate any pain 0–10 while you move. Log it in the session.")
            AdaptiveStack(spacing: 14) {
                light(.green, "0–2", "Dull, goes away as you warm up.", "Carry on.")
                light(.amber, "3–4", "Or it builds set by set. Still sore 48 h later counts too.", "Stop that exercise or hold type. Finish with easy stuff. Deload the area until it's green.")
                light(.red, "5+", "Sharp, or a pop.", "Session over. A finger pop or sharp pain at the base of a finger = physio before you climb again.")
            }
            Text("Three amber sessions in a row on the same spot = book a physio. None of this is a diagnosis.")
                .font(Face.small).foregroundStyle(Ink.ink2)
        }
    }

    func light(_ l: PainLight, _ range: String, _ what: String, _ action: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(Ink.pain(l)).frame(width: 12, height: 12)
                Text(l.rawValue.capitalized).font(Face.heading)
                Text(range).font(Face.small).foregroundStyle(Ink.ink2)
            }
            Text(what).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            Text(action).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .sheetCard(padding: 16)
    }
}

// MARK: - Calisthenics

struct BarPage: View {
    @Environment(AppModel.self) private var model
    @State private var workoutID = "A"
    @State private var chartExercise: String?

    var body: some View {
        Page(title: "Calisthenics", subtitle: "Built for size, not tricks. Stay at a weight until every set hits the top of the range. Then the weight goes up one step and the reps start again at the bottom.") {
            VStack(alignment: .leading, spacing: 40) {
                SkillsSection()
                LiftsPanel()
                Ladders()
                WorkoutBrowser(workoutID: $workoutID)
                Benchmarks()
            }
        }
    }
}

/// Every calisthenics skill as a ladder of steps with a standard to clear.
/// The ones you pick show up at the end of your sessions.
struct SkillsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "Skills", detail: "Pick up to three to work on; they show up in your sessions. Clear a step when you hit its goal on a fresh day.")
            let focus = model.store.skillFocus
            let open = Library.skills.filter(model.skillUnlocked)
            let ordered = open.sorted { (focus.contains($0.id) ? 0 : 1, $0.rank == 0 ? 99 : $0.rank) < (focus.contains($1.id) ? 0 : 1, $1.rank == 0 ? 99 : $1.rank) }
            let locked = Library.skills.filter { !model.skillUnlocked($0) }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 10 : 12, alignment: .top), count: compact ? 2 : 3), spacing: compact ? 10 : 12) {
                ForEach(ordered) { sk in SkillCard(skill: sk) }
            }
            if !locked.isEmpty {
                Text("Locked until you earn them").font(Face.heading).foregroundStyle(Ink.ink).padding(.top, 8)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 10 : 12, alignment: .top), count: compact ? 2 : 3), spacing: compact ? 10 : 12) {
                    ForEach(locked) { sk in SkillCard(skill: sk) }
                }
            }
        }
    }
}

struct SkillCard: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    let skill: Skill
    var body: some View {
        let step = model.skillStep(skill.id)
        let focused = model.store.skillFocus.contains(skill.id)
        let done = model.skillComplete(skill.id)
        Button { nav.show(skill.name, symbol: skill.symbol) { SkillDetail(skill: skill) } } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    if skill.rank > 0 { Text("\(skill.rank)").font(Face.display(15, .regular)).foregroundStyle(Ink.red) }
                    Text(skill.name).font(Face.heading).foregroundStyle(Ink.ink)
                    Spacer()
                    if !model.skillUnlocked(skill) {
                        Image(systemName: "lock").font(.system(size: 11)).foregroundStyle(Ink.ink3)
                    }
                    if focused {
                        Text("working on").font(Face.tiny).foregroundStyle(Ink.red)
                            .padding(.horizontal, 6).padding(.vertical, 2).background(Capsule().fill(Ink.redSoft))
                    }
                }
                HStack(spacing: 4) {
                    ForEach(0..<skill.steps.count, id: \.self) { i in
                        Capsule().fill(i < step || done ? Ink.ink : (i == step ? Ink.red : Ink.line))
                            .frame(height: 4)
                    }
                }
                if model.skillUnlocked(skill) {
                    Text(done ? "All steps cleared" : skill.steps[step].name).font(Face.body).foregroundStyle(Ink.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(done ? "Keep it with a set now and then." : "Goal: \(skill.steps[step].goal)").font(Face.small).foregroundStyle(Ink.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Needs " + skill.requires.map(model.requirementText).joined(separator: ", ")).font(Face.small).foregroundStyle(Ink.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 120 : nil, alignment: .topLeading)
            .padding(compact ? 13 : 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.sheet))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(focused ? Ink.red.opacity(0.5) : Ink.line))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One skill, every step: where you are, what clears it, and how.
struct SkillDetail: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let skill: Skill
    var body: some View {
        let step = model.skillStep(skill.id)
        let focused = model.store.skillFocus.contains(skill.id)
        let done = model.skillComplete(skill.id)
        VStack(alignment: .leading, spacing: 14) {
            PhotoStrip(ids: skill.photos)
            Text(skill.why).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            if !skill.day.isEmpty {
                Text("Practised \(skill.day).").font(Face.small).foregroundStyle(Ink.ink2)
            }
            if !model.skillUnlocked(skill) {
                Label("Locked. Needs " + skill.requires.map(model.requirementText).joined(separator: ", ") + ".", systemImage: "lock")
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                Button(focused ? "Stop working on it" : "Work on it") { model.toggleFocus(skill.id) }
                    .buttonStyle(InkButtonStyle(filled: false))
                    .disabled(!focused && (model.store.skillFocus.count >= 3 || !model.skillUnlocked(skill)))
                Spacer()
                if !done {
                    Button { model.clearSkillStep(skill.id) } label: {
                        Label(step == skill.steps.count - 1 ? "Cleared the last" : "Cleared", systemImage: "forward.end")
                    }
                    .buttonStyle(InkButtonStyle())
                }
            }
            if !focused && model.store.skillFocus.count >= 3 {
                Text("Three skills at once is the limit. Stop one to start this.").font(Face.tiny).foregroundStyle(Ink.ink2)
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(skill.steps.enumerated()), id: \.offset) { i, st in
                    let cleared = model.store.skillsCleared["\(skill.id)@\(i)"] != nil || i < step
                    Button { model.setSkillStep(skill.id, i) } label: {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle().fill(cleared ? Ink.ink : (i == step ? Ink.red : Ink.sand)).frame(width: 22, height: 22)
                                if cleared { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Ink.sheet) }
                                else { Text("\(i + 1)").font(.system(size: 11, weight: .semibold)).foregroundStyle(i == step ? Ink.sheet : Ink.ink2) }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(st.name).font(i == step ? Face.heading : Face.body).foregroundStyle(Ink.ink)
                                    Spacer()
                                    Text(st.goal).font(Face.small).monospacedDigit().foregroundStyle(Ink.ink2)
                                }
                                if i == step && !done {
                                    Text(st.cue).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(.vertical, 7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Put me on this step")
                }
            }
            Label(skill.watch, systemImage: "exclamationmark.triangle").font(Face.small).foregroundStyle(Ink.red).fixedSize(horizontal: false, vertical: true)
            Text("Tap a step to put yourself on it.").font(Face.tiny).foregroundStyle(Ink.ink2)
        }
    }
}

struct Ladders: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    let ids = ["pullup", "pushup", "pike", "core-front", "bss", "side-plank", "calf-raise", "glute-bridge"]
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "Progression ladders", detail: "Where you stand on each movement. Click a rung when you move up.")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: compact ? 1 : 2), spacing: 16) {
                ForEach(ids, id: \.self) { id in LadderCard(id: id) }
            }
        }
    }
}

struct LadderCard: View {
    @Environment(AppModel.self) private var model
    let id: String
    @Environment(Navigator.self) private var nav

    var body: some View {
        let info = Library.exercise(id)
        let current = model.rung(id)
        let all = model.history(of: id)
        // Chart one variation at a time: seconds of a hold and reps of a
        // push-up don't belong on the same axis.
        let history = all.filter { $0.log.variant == all.last?.log.variant }
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(info.name).font(Face.title)
                Spacer()
                ReadinessTag(readiness: model.readiness(id))
                Button { nav.show(info.name, symbol: info.symbol) { CuesPopover(info: info) } } label: { Image(systemName: "info") }
                    .buttonStyle(QuietIconButton())
                    .accessibilityLabel("How to do \(info.name)")
            }
            // The rungs: a line with nodes, easiest left.
            GeometryReader { geo in
                let n = info.ladder.count
                let step = geo.size.width / CGFloat(max(1, n - 1))
                ZStack(alignment: .leading) {
                    Rectangle().fill(Ink.lineStrong).frame(height: 1).offset(y: -9)
                    Rectangle().fill(Ink.ink).frame(width: step * CGFloat(current), height: 1.6).offset(y: -9)
                    ForEach(0..<n, id: \.self) { i in
                        Button { model.setRung(id, i) } label: {
                            Circle()
                                .fill(i < current ? Ink.ink : (i == current ? Ink.red : Ink.sheet))
                                .overlay(Circle().strokeBorder(i == current ? Ink.red : Ink.ink, lineWidth: 1.2))
                                .frame(width: i == current ? 16 : 11, height: i == current ? 16 : 11)
                                .contentShape(Circle().inset(by: -6))
                        }
                        .buttonStyle(.plain)
                        .help(info.ladder[i])
                        .position(x: CGFloat(i) * step, y: geo.size.height / 2 - 9)
                    }
                }
            }
            .frame(height: 30)
            .padding(.horizontal, 8)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.ladder[safe: current] ?? "").font(Face.heading).foregroundStyle(Ink.ink)
                    if let next = info.ladder[safe: current + 1] {
                        Text("Next: \(next)").font(Face.small).foregroundStyle(Ink.ink2)
                    } else {
                        Text("Top of this ladder.").font(Face.small).foregroundStyle(Ink.ink2)
                    }
                }
                Spacer()
                if let last = history.last {
                    Text("best \(last.log.best)\(last.log.timed ? " s" : "") · \(Day.short(last.date))").font(Face.small).foregroundStyle(Ink.ink2)
                }
            }
            if history.count >= 2 {
                Chart(history.suffix(16), id: \.log.id) { h in
                    BarMark(x: .value("Day", h.date, unit: .day), y: .value("Best", h.log.best))
                        .foregroundStyle(h.log.hitTopOfRange ? Ink.red : Ink.ink)
                        .cornerRadius(2)
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks { _ in AxisValueLabel().font(Face.tiny).foregroundStyle(Ink.ink2) } }
                .frame(height: 70)
            }
        }
        .sheetCard(padding: 18)
    }
}

struct WorkoutBrowser: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    @Binding var workoutID: String
    @State private var atGym = false

    var body: some View {
        let week = model.currentWeek ?? model.blockWeek(at: 0)!
        VStack(alignment: .leading, spacing: 16) {
            AdaptiveStack(spacing: 12) {
                SectionTitle(text: "Sessions", detail: "Week \(week.number): \(week.phase.halvesSets ? "half the sets" : week.template.effort.lowercased()). Rest 90 s – 2 min.")
                if compact {
                    Picker("Session", selection: $workoutID) {
                        ForEach(model.plan.workouts) { w in Text("\(w.id) · \(w.name)").tag(w.id) }
                    }
                    .pickerStyle(.menu)
                } else {
                    Picker("", selection: $workoutID) {
                        ForEach(model.plan.workouts) { w in Text("\(w.id) · \(w.name)").tag(w.id) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 520)
                }
            }
            if let w = model.workout(workoutID) {
                let gym = atGym && w.gymExercises != nil
                let list = gym ? (w.gymExercises ?? w.exercises) : w.exercises
                VStack(alignment: .leading, spacing: 0) {
                    if w.gymExercises != nil {
                        Picker("", selection: $atGym) { Text("Home, bands").tag(false); Text("Gym").tag(true) }
                            .pickerStyle(.segmented).labelsHidden().frame(maxWidth: 260).padding(.bottom, 12)
                    }
                    Text(w.note).font(Face.body).foregroundStyle(Ink.ink2).padding(.bottom, 12)
                    ForEach(Array(list.enumerated()), id: \.element.id) { i, pe in
                        let scheme = pe.scheme(forWeek: week.number)
                        let info = Library.exercise(pe.exerciseID)
                        let sets = model.sets(for: pe, position: i, week: week)
                        Button {
                            if gym {
                                nav.show(info.name, symbol: info.symbol) { CuesPopover(info: info) }
                            } else if let wi = model.plan.workouts.firstIndex(where: { $0.id == w.id }) {
                                nav.show(scheme.variant, symbol: "slider.horizontal.3") { PlanExerciseEditor(wi: wi, ei: i) }
                            }
                        } label: {
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: info.symbol).font(.system(size: 15)).foregroundStyle(Ink.ink2).frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(scheme.variant).font(Face.heading)
                                Text(info.loadStep.map { "Progress: \($0)" } ?? (info.ladder.isEmpty ? info.why : "Ladder: " + info.ladder.joined(separator: " → ")))
                                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                                if !scheme.note.isEmpty { Text(scheme.note).font(Face.small).foregroundStyle(Ink.red) }
                            }
                            Spacer()
                            if !compact {
                                ReadinessTag(readiness: model.readiness(pe.exerciseID))
                            }
                            Text("\(sets) × \(scheme.low == scheme.high ? "\(scheme.low)" : "\(scheme.low)–\(scheme.high)")\(scheme.timed ? " s" : "")\(pe.perSide ? " /side" : "")")
                                .font(.system(size: 14, weight: .semibold)).monospacedDigit()
                                .frame(width: compact ? 78 : 120, alignment: .trailing)
                                .fixedSize(horizontal: false, vertical: true)
                            Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.ink2)
                        }
                        .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(gym ? "How to do it" : "Change reps or sets in the plan")
                        .padding(.vertical, 12)
                        if i < list.count - 1 { Rule(seed: i + 50) }
                    }
                }
                .sheetCard()
            }
        }
    }
}

struct Benchmarks: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "Benchmarks", detail: "Week 1 and week 14. Fresh, after the warm-up, one attempt each. The gap between the columns is the whole point.")
            VStack(spacing: 0) {
                HStack {
                    Text("Test").font(Face.small).foregroundStyle(Ink.ink2)
                    Spacer()
                    Text("Week 1").font(Face.small).foregroundStyle(Ink.ink2).frame(width: 110)
                    Text("Week 14").font(Face.small).foregroundStyle(Ink.ink2).frame(width: 110)
                }
                .padding(.bottom, 8)
                ForEach(Quests.benchmarks) { b in
                    Group {
                    if compact {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(b.name).font(Face.body)
                            HStack { Spacer(); field(b, start: true); field(b, start: false) }
                        }
                    } else {
                        HStack {
                            Text(b.name).font(Face.body)
                            Spacer()
                            field(b, start: true)
                            field(b, start: false)
                        }
                    }
                    }
                    .padding(.vertical, 6)
                    Rule(seed: b.id.count + 60)
                }
            }
            .sheetCard()
            Text("One photo front, side and back in the same spot and light, week 1 and week 14. Don't look at them in between.")
                .font(Face.small).foregroundStyle(Ink.ink2)
        }
    }

    func field(_ b: Quests.Benchmark, start: Bool) -> some View {
        HStack(spacing: 4) {
            TextField(start && b.id == "steps" ? "5,700" : "–", text: Binding(
                get: { start ? model.store.benchmarks[b.id]?.start ?? "" : model.store.benchmarks[b.id]?.end ?? "" },
                set: { v in model.mutate { s in
                    var e = s.benchmarks[b.id] ?? BenchmarkEntry()
                    if start { e.start = v } else { e.end = v }
                    s.benchmarks[b.id] = e
                } }))
                .textFieldStyle(.plain).multilineTextAlignment(.trailing).monospacedDigit()
                .frame(width: 60)
            Text(b.unit).font(Face.tiny).foregroundStyle(Ink.ink2).frame(width: 34, alignment: .leading)
        }
        .padding(.horizontal, 8).frame(width: 110, height: 28)
        .background(Capsule().fill(Ink.sand.opacity(0.7)))
    }
}

/// Change one exercise in the plan: its rep range and whether its sets are
/// pinned. Applies to every future session; past logs stay as they were.
struct PlanExerciseEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let wi: Int
    let ei: Int

    var body: some View {
        if model.plan.workouts.indices.contains(wi), model.plan.workouts[wi].exercises.indices.contains(ei) {
            let pe = model.plan.workouts[wi].exercises[ei]
            let week = model.currentWeek ?? model.blockWeek(at: 0)!
            let si = pe.schemes.lastIndex { $0.fromWeek <= week.number } ?? 0
            let scheme = pe.schemes[si]
            VStack(alignment: .leading, spacing: 14) {
                Text("From week \(scheme.fromWeek)\(pe.schemes.count > 1 ? " (this exercise changes form during the block)" : ""). Changes the plan for every session from now on.")
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Text(scheme.timed ? "Seconds" : "Reps").font(Face.heading).frame(width: 70, alignment: .leading)
                    StepperField(value: bind(si, \.low), range: 1...300, step: scheme.timed ? 5 : 1)
                    Text("to").font(Face.small).foregroundStyle(Ink.ink2)
                    StepperField(value: bind(si, \.high), range: 1...300, step: scheme.timed ? 5 : 1)
                }
                HStack(spacing: 10) {
                    Text("Sets").font(Face.heading).frame(width: 70, alignment: .leading)
                    if let sets = scheme.sets {
                        StepperField(value: Binding(get: { sets }, set: { v in model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si].sets = v } }), range: 1...8)
                        Button("Follow the block") { model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si].sets = nil } }
                            .buttonStyle(TextLinkStyle()).font(Face.small).foregroundStyle(Ink.ink2)
                    } else {
                        Text("\(model.sets(for: pe, position: ei, week: week)) this week, following the block").font(Face.body)
                        Spacer()
                        Button("Set my own") { model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si].sets = model.sets(for: pe, position: ei, week: week) } }
                            .buttonStyle(InkButtonStyle(filled: false))
                    }
                }
                Text("The block's rule: 2 sets in weeks 1–2, 3 from week 3, 4 on the first two exercises in Push, half in deloads.")
                    .font(Face.tiny).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                HStack { Spacer(); Button("Done") { nav.dismissBubble() }.buttonStyle(InkButtonStyle()) }
            }
        }
    }

    func bind(_ si: Int, _ kp: WritableKeyPath<Scheme, Int>) -> Binding<Int> {
        Binding(get: { model.plan.workouts[wi].exercises[ei].schemes[si][keyPath: kp] },
                set: { v in model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si][keyPath: kp] = v } })
    }
}
