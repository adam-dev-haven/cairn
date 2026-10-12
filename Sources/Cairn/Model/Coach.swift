import Foundation

// MARK: - What a check-in is

enum CoachScope: String, Codable, CaseIterable, Identifiable {
    case daily, weekly
    var id: String { rawValue }
    var name: String { self == .daily ? "Daily check-in" : "Weekly analysis" }
}

struct CoachNote: Codable, Hashable, Identifiable {
    enum Kind: String, Codable { case win, concern, info }
    var id = UUID()
    var kind: Kind
    var text: String
}

struct CoachQuestion: Codable, Hashable, Identifiable {
    var id: String
    var text: String
    /// "choice", "scale" (1–5) or "text".
    var kind: String
    var options: [String] = []
    var answer: String? = nil
}

enum UndoStep: Codable, Hashable {
    case load(exerciseID: String, previous: LoadSet?)
    case schemes(workout: String, gym: Bool, index: Int, previous: [Scheme])
    case goal(UUID)
    case change(dayKey: String, previous: DayChange?)
    case timeline(UUID)
}

struct CoachAdjustment: Codable, Hashable, Identifiable {
    enum Status: String, Codable { case pending, applied, dismissed }
    var id: String
    /// exercise_load, exercise_scheme, schedule_move, repeat_week, return_week, goal, note
    var type: String
    var reason: String
    var exerciseID: String? = nil
    var kg: Double? = nil
    var low: Int? = nil
    var high: Int? = nil
    var sets: Int? = nil
    var template: String? = nil
    var from: String? = nil
    var to: String? = nil
    var text: String? = nil
    var byWeek: Int? = nil
    var status: Status = .pending
    var result: String? = nil
    var undo: [UndoStep] = []

    var canApply: Bool { type != "note" }
}

struct CoachReport: Codable, Hashable, Identifiable {
    enum Stage: String, Codable {
        /// Claude has read the data and is waiting on your answers.
        case asking
        /// Answers are in; this is the final read.
        case final
        /// No Claude: what Cairn could work out on its own.
        case offline
    }
    var id = UUID()
    var created: Date
    var scope: CoachScope
    var day: String
    var weekNumber: Int?
    var stage: Stage
    var verdict = ""
    var headline = ""
    var summary = ""
    var nextWeek = ""
    var wins: [String] = []
    var concerns: [String] = []
    var questions: [CoachQuestion] = []
    var adjustments: [CoachAdjustment] = []
    var notes: [CoachNote] = []
    var model = ""
    var effort = ""
    /// Why Claude wasn't used, or what went wrong.
    var problem: String? = nil
    var answered: Bool { !questions.isEmpty && questions.allSatisfy { ($0.answer ?? "").isEmpty == false } }
}

// MARK: - Reading the data

enum Coach {
    static let defaultContext = """
    Beginner-to-intermediate climber (V0–V3, 1–4 strict pull-ups). A 14-week "Wall & Bar" block: two hard climbing mornings \
    (Mon, Thu), an optional easy climb on Wednesday, strength on its own days (Push Tue, Aesthetic Wed, Legs Fri, Pull Sat) \
    on resistance bands at home, or dumbbells and the bar at the gym. Pulling stays 48 hours from the hard climbs. Goal: \
    five strict pull-ups by week 14. Never frame a missed day as a failure.
    """

    static var folder: URL {
        AppModel.dataDirectory().appendingPathComponent("coach", isDirectory: true)
    }

    static let system = """
    You are a personal trainer reviewing the training log in the user's app, Cairn. Think the way a good coach does: look for the \
    pattern across sessions, not the single bad day; check that load, volume and recovery move together; protect the elbows and \
    shoulders; progress with double progression (all sets at the top of the rep range at one weight → a small jump, reps back to \
    the bottom); back off after two rough sessions in a row, not one; deload when fatigue shows up in several places at once. \
    Be direct and warm. Short sentences. No therapy language, no guilt about missed days, no hype. Use only the numbers in the \
    data you are given and never invent any; if the data is thin, say what you can't tell. Prefer the smallest change that fixes \
    the problem. Do not suggest anything the equipment doesn't allow (bands, bar and dumbbells at the gym, no machines unless \
    the log shows them). Reply with one JSON object and nothing else: no prose, no code fence.
    """

    static func schema(scope: CoachScope, final: Bool) -> String {
        let q = final
            ? "\"questions\": []   // none, unless one answer is still missing and decisive (max 1)"
            : "\"questions\": [ {\"id\":\"q1\",\"text\":\"...\",\"kind\":\"choice\",\"options\":[\"...\",\"...\"]}, {\"id\":\"q2\",\"text\":\"...\",\"kind\":\"scale\"}, {\"id\":\"q3\",\"text\":\"...\",\"kind\":\"text\"} ]   // 3 to 5 questions a trainer would actually ask this person right now, from what the data shows and what it can't. kind is choice (2–5 options), scale (1 to 5) or text. Short."
        return """
        {
          "verdict": "keep" | "adjust" | "deload",
          "headline": "one line, under 90 characters",
          "summary": "3 to 6 plain sentences: what is working, what isn't, what to do about it",
          "wins": ["specific, with the number"],
          "concerns": ["specific, with the number"],
          \(q),
          "adjustments": [ ... ],
          "nextWeek": "\(scope == .weekly ? "2–4 sentences on the week ahead" : "one sentence on tomorrow")"
        }

        Each adjustment is one object with a unique "id" ("a1", "a2", …), a "type", and a one-sentence "reason". Types:
          {"type":"exercise_load","exerciseID":"<id from the data>","kg":<number>}   set the working load for that exercise's next session
          {"type":"exercise_scheme","exerciseID":"<id>","low":<int>,"high":<int>,"sets":<int>}   change its rep range and/or sets from this week on (omit what stays)
          {"type":"schedule_move","template":"<A|B|C|D|H|P|climb>","from":"<Mon..Sun>","to":"<Mon..Sun>"}   move a session within the current week
          {"type":"repeat_week"}   run this week again next week
          {"type":"return_week"}   make this week an easy half-volume week and run it again
          {"type":"goal","text":"...","byWeek":<int>}   add a goal
          {"type":"note","text":"..."}   advice that is not a change the app can make
        Only propose changes you are sure the data supports. An empty list is a fine answer. Never more than 6.
        """
    }

    static func prompt(snapshot: String, scope: CoachScope, final: Bool, answers: [CoachQuestion], previous: CoachReport?) -> String {
        var s = ""
        s += "Here is the data from the user's training app (JSON). Today is the date in \"today\".\n\n"
        s += snapshot + "\n\n"
        if final {
            s += "They answered your check-in questions:\n"
            for q in answers { s += "- \(q.text) → \((q.answer ?? "").isEmpty ? "(no answer)" : q.answer!)\n" }
            if let p = previous {
                s += "\nYour first read was: \(p.headline) — \(p.summary)\n"
            }
            s += "\nGive the final read, taking the answers into account. Where an answer contradicts the numbers, say so and trust the safer one.\n\n"
        } else {
            s += "Give your first read and the questions you want answered before you recommend changes. Any adjustments you list now are provisional.\n\n"
        }
        s += "Scope: \(scope == .weekly ? "the whole week and the trend over the block so far, and what next week should be" : "today and the last few days only: should today's session go ahead as planned, be lighter, or change?")\n\n"
        s += "Reply with this JSON shape:\n" + schema(scope: scope, final: final)
        return s
    }
}

// MARK: - The snapshot

extension AppModel {
    private func ymd(_ d: Date) -> String { Day.key(d) }

    private func sets(_ s: Overload.Session) -> String {
        s.done.map { "\($0.value)\(s.timed ? "s" : "")" + ($0.kg.map { "@\(Overload.kgText($0))" } ?? "") }.joined(separator: ", ")
    }

    /// Everything the analysis reads, as plain JSON. Also written to the
    /// app folder so a later session can look it up.
    func coachSnapshot(scope: CoachScope) -> [String: Any] {
        let idx = max(0, min(calendarIndex(for: today), plan.timeline.count - 1))
        var snap: [String: Any] = [:]
        snap["today"] = ymd(today) + " (" + Day.weekdayLong[Day.weekday(today) - 1] + ")"
        snap["scope"] = scope.rawValue
        snap["context"] = store.settings.coachContextOrDefault
        if let w = blockWeek(at: idx) {
            snap["block"] = [
                "name": plan.name, "week": w.number, "of": plan.weeks.count, "phase": w.phase.name,
                "effort": w.template.effort, "focus": w.template.focus, "repeatedWeek": w.entry.reason == .repeated,
                "returnWeek": w.entry.reason == .recovery, "grades": ["repeats": w.template.gradeRepeats, "projects": w.template.gradeProjects],
                "summit": ymd(summitDate),
            ] as [String: Any]
        }
        // The last two weeks, day by day.
        var weeks: [[String: Any]] = []
        for i in [idx - 1, idx] where i >= 0 {
            var days: [[String: Any]] = []
            for d in self.days(ofWeek: i) where d <= today || i == idx {
                let items = plannedItems(for: d).filter { $0.kind != .rest }
                var row: [String: Any] = ["date": ymd(d), "day": Day.weekdayShort[Day.weekday(d) - 1]]
                row["planned"] = items.map { name(of: $0) + ($0.from.map { " (moved from \($0))" } ?? "") + ($0.extra == true ? " (extra)" : "") }
                row["done"] = items.filter { isDone($0, on: d) }.map { name(of: $0) }
                let skips = sessions(on: d).compactMap { s in s.skip.map { "\(s.kind.name): \($0.name)" + (s.note.isEmpty ? "" : " (\(s.note))") } }
                if !skips.isEmpty { row["skipped"] = skips }
                let dl = daily(d)
                if let v = dl.steps { row["steps"] = v }
                if let v = dl.proteinG { row["proteinG"] = v }
                if let v = dl.kcal { row["kcal"] = v }
                if let v = dl.weightKg { row["weightKg"] = v }
                if dl.sick { row["sick"] = true }
                if let e = dl.elbow { row["elbowCheckIn"] = e }
                let energy = sessions(on: d).compactMap(\.energy)
                if !energy.isEmpty { row["energy1to5"] = energy }
                let pain = sessions(on: d).flatMap(\.pain).map { "\($0.area.name) \($0.score)/10" }
                if !pain.isEmpty { row["pain"] = pain }
                days.append(row)
            }
            let sc = score(week: i)
            weeks.append(["weekIndex": i, "template": blockWeek(at: i)?.number ?? 0, "points": sc.total, "greenAt": plan.points.greenWeek,
                          "green": isGreen(week: i), "days": days])
        }
        snap["weeks"] = weeks
        snap["stepFloor"] = blockWeek(at: idx)?.template.stepFloor ?? 7000

        // Climbing: the last five sessions.
        let climbs = climbSessions.filter { hasContent($0) }.suffix(5).map { s -> [String: Any] in
            let p = s.climb?.problems ?? []
            var r: [String: Any] = ["date": s.day, "problems": p.count, "sent": p.filter(\.sent).count, "flashed": p.filter(\.flash).count,
                                    "tries": p.reduce(0) { $0 + $1.attempts }, "falls": s.climb?.falls ?? 0]
            if let h = hardestName(p) { r["hardestSend"] = h }
            if s.minimum { r["doorwayRuleOnly"] = true }
            if let e = s.energy { r["energy1to5"] = e }
            if let m = s.minutes { r["minutes"] = m }
            r["perGrade"] = Dictionary(grouping: p, by: { gradeName($0) }).mapValues { g in "\(g.filter(\.sent).count)/\(g.count) sent" }
            return r
        }
        snap["climbing"] = ["recentSessions": climbs, "hardestEver": hardestEverRank.map(rankLabel) ?? "none yet",
                            "goalsNow": climbGoals.map { $0.title }] as [String: Any]

        // Lifts: history, record and what the overload rules say is next.
        snap["lifts"] = liftRows().prefix(24).map { row -> [String: Any] in
            let hist = overloadHistory(row.exerciseID, variant: row.variant).suffix(6)
            let t = row.next.targets
            var r: [String: Any] = [
                "exerciseID": row.exerciseID, "name": row.name, "variant": row.variant,
                "range": "\(row.last.low)–\(row.last.high)\(row.last.timed ? " s" : "")", "plannedSets": row.last.plannedSets,
                "recentSessions": hist.map { "\($0.day): \(sets($0))" + ($0.topped ? " (topped)" : "") },
                "best": ["reps": row.record.bestReps, "atKg": row.record.bestRepsKg as Any, "heaviestKg": row.record.heaviest as Any] as [String: Any],
                "next": ["rule": row.next.kind.rawValue, "reps": t.map(\.reps), "kg": t.first?.kg as Any, "why": row.next.reason] as [String: Any],
            ]
            if row.next.plateau { r["plateau"] = true }
            r["isBand"] = Library.exercise(row.exerciseID).isBand
            return r
        }
        snap["skills"] = focusSkills.map { sk -> [String: Any] in
            let st = sk.steps[skillStep(sk.id)]
            return ["skill": sk.name, "step": st.name, "goal": st.goal]
        }

        // Body and habits, fourteen days.
        var body: [[String: Any]] = []
        for k in 0..<14 {
            let d = Day.add(-k, to: today)
            let dl = daily(d)
            var r: [String: Any] = ["date": ymd(d)]
            if let v = dl.weightKg { r["weightKg"] = v }
            if let v = dl.waistCm { r["waistCm"] = v }
            if let v = dl.steps { r["steps"] = v }
            if let v = dl.proteinG { r["proteinG"] = v }
            if let v = dl.kcal { r["kcal"] = v }
            if r.count > 1 { body.append(r) }
        }
        snap["body"] = body
        snap["targets"] = ["proteinG": plan.proteinTarget, "kcal": plan.kcalTarget]

        // Elbows over the last two weeks.
        var elbows: [String] = []
        for s in store.sessions.sorted(by: { $0.day < $1.day }) where Day.between(s.date, today) <= 14 {
            for p in s.pain where p.area == .elbows || p.area == .shoulders || p.area == .wrists { elbows.append("\(s.day) \(p.area.name) \(p.score)/10") }
        }
        for (k, v) in store.daily.sorted(by: { $0.key < $1.key }) where v.elbow != nil && (Day.date(k).map { Day.between($0, today) <= 14 } ?? false) {
            elbows.append("\(k) elbow check-in \(v.elbow!)/10")
        }
        snap["painAndElbows"] = elbows

        snap["recentAdaptations"] = store.adaptations.prefix(4).map { "\($0.day): \($0.message)" + ($0.undone ? " (undone)" : "") }
        snap["scheduleIssues"] = scheduleIssues(week: idx).map(\.text)
        snap["patterns"] = patternFindings().map(\.text)
        snap["equipment"] = "Resistance bands (4, 9, 13, 18, 22.7 kg, stackable), door anchor, handles; at the gym: dumbbells, a pull-up bar, dip bars. Pull-ups and rows are gym-only."
        let earlier = store.coach.filter { $0.stage != .asking || $0.answered }.prefix(2).map { r -> [String: Any] in
            ["date": r.day, "scope": r.scope.rawValue, "headline": r.headline, "verdict": r.verdict,
             "applied": r.adjustments.filter { $0.status == .applied }.map { $0.type + ": " + $0.reason }]
        }
        if !earlier.isEmpty { snap["earlierCheckIns"] = earlier }
        return snap
    }

    func coachSnapshotJSON(scope: CoachScope) -> String {
        let obj = coachSnapshot(scope: scope)
        let data = (try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    // MARK: What Cairn can say on its own

    /// The deterministic read: what the numbers say without any model, and
    /// the questions worth asking either way.
    func coachLocal(scope: CoachScope) -> (notes: [CoachNote], questions: [CoachQuestion]) {
        var notes: [CoachNote] = []
        let idx = max(0, min(calendarIndex(for: today), plan.timeline.count - 1))

        // This week's plan against what happened.
        var planned = 0, done = 0
        var skippedItems: [String] = []
        for d in days(ofWeek: idx) where d <= today {
            for it in plannedItems(for: d) where [.home, .workout, .climb].contains(it.kind) && !it.isOptional {
                if Day.key(d) == Day.key(today) && !isDone(it, on: d) { continue }
                planned += 1
                if isDone(it, on: d) { done += 1 }
                else if let why = skipped(it, on: d) { skippedItems.append("\(name(of: it)) (\(why.name.lowercased()))") }
            }
        }
        if planned > 0 {
            notes.append(CoachNote(kind: done == planned ? .win : (done * 2 < planned ? .concern : .info),
                                   text: "\(done) of \(planned) planned sessions done so far this week" + (skippedItems.isEmpty ? "." : "; skipped: \(skippedItems.joined(separator: ", ")).")))
        }

        // Lifts.
        for row in liftRows() where Day.between(Day.date(row.last.day) ?? today, today) <= 21 {
            let t = row.next.targets.first
            let load = t?.kg.map { Library.exercise(row.exerciseID).isBand ? Bands.text($0) : "\(Overload.kgText($0)) kg" } ?? ""
            switch row.next.kind {
            case .progress: notes.append(CoachNote(kind: .win, text: "\(row.name): earned a step up. Next: \(load.isEmpty ? "" : load + ", ")\(t?.reps ?? 0) \(row.last.timed ? "s" : "reps")."))
            case .fixLoad: notes.append(CoachNote(kind: .info, text: "\(row.name): reps are there but not at one weight. All sets at \(load) first."))
            case .backOff: notes.append(CoachNote(kind: .concern, text: "\(row.name): two rough sessions running. Backing off\(load.isEmpty ? "" : " to " + load)."))
            default: if row.next.plateau { notes.append(CoachNote(kind: .concern, text: "\(row.name): four sessions at the same load with no gain. Worth changing the range, sets or variation.")) }
            }
        }

        // Climbing.
        let climbs = climbSessions.filter { hasContent($0) && !$0.minimum }
        if let last = climbs.last, climbs.count >= 2 {
            let p = last.climb?.problems ?? []
            let prev = climbs[climbs.count - 2].climb?.problems ?? []
            if let a = hardest(p), let b = hardest(prev), a > b { notes.append(CoachNote(kind: .win, text: "New hardest send last session: \(rankLabel(a))." )) }
            if p.count + 2 < prev.count { notes.append(CoachNote(kind: .info, text: "Fewer problems last session (\(p.count) against \(prev.count)).")) }
        }
        if let gap = daysSinceGym, gap >= store.settings.daysAwayNudge {
            notes.append(CoachNote(kind: .concern, text: "\(gap) days since the last gym session."))
        }

        // Elbows.
        if let r = elbowReading(asOf: today) {
            if r.light == .red { notes.append(CoachNote(kind: .concern, text: "Elbows last read \(r.score)/10 (red) on \(r.day). No pulling or climbing until a check-in comes back green.")) }
            else if r.light == .amber { notes.append(CoachNote(kind: .info, text: "Elbows last read \(r.score)/10 (amber) on \(r.day): technique mode.")) }
        }

        // Energy: the last three rated sessions against the three before.
        let rated = store.sessions.filter { $0.energy != nil && hasContent($0) }.sorted { $0.day < $1.day }
        if rated.count >= 6 {
            let a = rated.suffix(3).compactMap(\.energy), b = rated.suffix(6).prefix(3).compactMap(\.energy)
            let da = Double(a.reduce(0, +)) / 3, db = Double(b.reduce(0, +)) / 3
            if da <= db - 1 { notes.append(CoachNote(kind: .concern, text: String(format: "Energy after sessions is down: %.1f over the last three, against %.1f before.", da, db))) }
        }

        // Sick days and steps.
        let sick = days(ofWeek: idx).filter { daily($0).sick }.count
        if sick > 0 { notes.append(CoachNote(kind: .info, text: "\(sick) sick day\(sick == 1 ? "" : "s") this week.")) }
        let floor = blockWeek(at: idx)?.template.stepFloor ?? 7000
        let under = days(ofWeek: idx).filter { $0 < today && (daily($0).steps ?? 0) < floor && daily($0).steps != nil }.count
        if under >= 3 { notes.append(CoachNote(kind: .info, text: "\(under) days under the \(floor.formatted()) step floor this week.")) }

        for f in patternFindings() { notes.append(CoachNote(kind: .concern, text: f.text)) }
        for i in scheduleIssues(week: idx) { notes.append(CoachNote(kind: .info, text: i.text)) }

        // Questions: the ones worth asking every time.
        var qs: [CoachQuestion] = []
        if scope == .daily {
            qs.append(CoachQuestion(id: "l1", text: "How ready are you for today's session?", kind: "choice", options: ["Ready", "So-so", "Rough"]))
            qs.append(CoachQuestion(id: "l2", text: "Anything sore or tight?", kind: "text"))
        } else {
            qs.append(CoachQuestion(id: "l1", text: "How do the elbows and shoulders feel right now?", kind: "choice", options: ["Fine", "A bit of ache", "Sharp, or getting worse"]))
            qs.append(CoachQuestion(id: "l2", text: "Energy and mood this week?", kind: "scale"))
            if !skippedItems.isEmpty {
                qs.append(CoachQuestion(id: "l3", text: "What got in the way of \(skippedItems[0].components(separatedBy: " (").first ?? "the skipped session")?", kind: "choice",
                                        options: ["Time", "Too tired", "Pain", "Didn't feel like it", "Something else"]))
            }
            qs.append(CoachQuestion(id: "l4", text: "Is there anything in the plan you want to change?", kind: "text"))
        }
        return (notes, qs)
    }
}

// MARK: - Settings

extension Settings {
    var coachContextOrDefault: String { coachContext.isEmpty ? Coach.defaultContext : coachContext }
}
