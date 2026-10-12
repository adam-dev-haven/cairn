import Foundation

// MARK: - Talking to Claude (Mac only)

enum CoachError: LocalizedError {
    case notFound, notSignedIn, failed(String), timedOut, unreadable(String)
    var errorDescription: String? {
        switch self {
        case .notFound: "Cairn couldn't find the `claude` program. Install Claude Code, or set its path in Settings → Progression and coach."
        case .notSignedIn: "Claude isn't signed in. Open Terminal, run `claude`, type /login, then run the check-in again."
        case .failed(let s): "Claude stopped with an error: \(s)"
        case .timedOut: "Claude took too long (over four minutes). Try again, or lower the effort in Settings."
        case .unreadable(let s): "Claude's answer wasn't in the shape Cairn expects. \(s)"
        }
    }
}

enum CoachRunner {
    /// Where the `claude` program lives: the path in Settings, or the usual places.
    static func locate(_ configured: String) -> String? {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        var candidates = [configured, ProcessInfo.processInfo.environment["CAIRN_CLAUDE"] ?? ""]
        candidates += ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude", "\(home)/.claude/local/claude", "\(home)/.bun/bin/claude"]
        return candidates.first { !$0.isEmpty && fm.isExecutableFile(atPath: ($0 as NSString).expandingTildeInPath) }.map { ($0 as NSString).expandingTildeInPath }
    }

    #if os(macOS)
    /// Runs `claude --print` once and returns what it says. No tools, no
    /// settings, no hooks; on the subscription login, never an API key (an
    /// API key in the environment would bill the API instead).
    static func run(prompt: String, system: String, model: String, effort: String, path: String, timeout: TimeInterval = 240) async throws -> String {
        guard let exe = locate(path) else { throw CoachError.notFound }
        let dir = Coach.folder
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var args = ["--print", "--model", model, "--tools", "", "--setting-sources", "", "--system-prompt", system,
                    "--output-format", "text", "--no-session-persistence", "--disable-slash-commands"]
        if ["low", "medium", "high", "xhigh", "max"].contains(effort) { args += ["--effort", effort] }

        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "ANTHROPIC_API_KEY")
        env.removeValue(forKey: "ANTHROPIC_AUTH_TOKEN")
        let home = NSHomeDirectory()
        env["PATH"] = ["\(home)/.local/bin", "/opt/homebrew/bin", "/usr/local/bin", "/usr/bin", "/bin", env["PATH"] ?? ""].joined(separator: ":")
        env["HOME"] = home

        let process = Process()
        process.executableURL = URL(fileURLWithPath: exe)
        process.arguments = args
        process.environment = env
        process.currentDirectoryURL = dir
        let inPipe = Pipe(), outPipe = Pipe(), errPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe

        return try await withCheckedThrowingContinuation { cont in
            final class Box: @unchecked Sendable {
                let lock = NSLock()
                var finished = false, timedOut = false
                var out = Data(), err = Data()
            }
            let box = Box()
            @Sendable func finish(_ r: Result<String, Error>) {
                box.lock.lock(); defer { box.lock.unlock() }
                guard !box.finished else { return }
                box.finished = true
                cont.resume(with: r)
            }
            let group = DispatchGroup()
            group.enter(); group.enter()
            DispatchQueue.global().async { box.out = outPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            DispatchQueue.global().async { box.err = errPipe.fileHandleForReading.readDataToEndOfFile(); group.leave() }
            let timer = DispatchWorkItem { box.timedOut = true; if process.isRunning { process.terminate() } }
            process.terminationHandler = { p in
                timer.cancel()
                group.notify(queue: .global()) {
                    let o = String(data: box.out, encoding: .utf8) ?? ""
                    let e = String(data: box.err, encoding: .utf8) ?? ""
                    let all = o + e
                    if box.timedOut { return finish(.failure(CoachError.timedOut)) }
                    if all.contains("OAuth session expired") || all.contains("Failed to authenticate") || all.contains("Not logged in") || all.contains("Please run /login") {
                        return finish(.failure(CoachError.notSignedIn))
                    }
                    if p.terminationStatus != 0 { return finish(.failure(CoachError.failed(String((e.isEmpty ? o : e).prefix(300))))) }
                    finish(.success(o))
                }
            }
            do { try process.run() } catch { return finish(.failure(CoachError.failed(error.localizedDescription))) }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
            inPipe.fileHandleForWriting.write(Data(prompt.utf8))
            try? inPipe.fileHandleForWriting.close()
        }
    }
    #endif

    // MARK: Reading the answer

    struct Reply {
        var verdict = "keep", headline = "", summary = "", nextWeek = ""
        var wins: [String] = [], concerns: [String] = []
        var questions: [CoachQuestion] = []
        var adjustments: [CoachAdjustment] = []
    }

    /// Pull the JSON object out of whatever came back (a code fence, a line
    /// of preamble) and read it leniently: numbers may arrive as strings.
    static func parse(_ text: String) throws -> Reply {
        guard let a = text.firstIndex(of: "{"), let b = text.lastIndex(of: "}"), a < b,
              let data = String(text[a...b]).data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CoachError.unreadable(String(text.prefix(160)))
        }
        func str(_ v: Any?) -> String { (v as? String) ?? "" }
        func strs(_ v: Any?) -> [String] { (v as? [Any])?.compactMap { $0 as? String } ?? [] }
        func num(_ v: Any?) -> Double? { (v as? Double) ?? (v as? Int).map(Double.init) ?? (v as? String).flatMap { Double($0.replacingOccurrences(of: ",", with: ".")) } }
        var r = Reply()
        let verdict = str(obj["verdict"]).lowercased()
        r.verdict = ["keep", "adjust", "deload"].contains(verdict) ? verdict : "keep"
        r.headline = str(obj["headline"]); r.summary = str(obj["summary"]); r.nextWeek = str(obj["nextWeek"])
        r.wins = strs(obj["wins"]); r.concerns = strs(obj["concerns"])
        for (i, q) in ((obj["questions"] as? [[String: Any]]) ?? []).enumerated() {
            let text = str(q["text"])
            guard !text.isEmpty else { continue }
            let kind = ["choice", "scale", "text"].contains(str(q["kind"])) ? str(q["kind"]) : "text"
            r.questions.append(CoachQuestion(id: str(q["id"]).isEmpty ? "q\(i + 1)" : str(q["id"]), text: text, kind: kind, options: strs(q["options"])))
        }
        let types = ["exercise_load", "exercise_scheme", "schedule_move", "repeat_week", "return_week", "goal", "note"]
        for (i, a) in ((obj["adjustments"] as? [[String: Any]]) ?? []).prefix(6).enumerated() {
            let type = str(a["type"])
            guard types.contains(type) else { continue }
            r.adjustments.append(CoachAdjustment(
                id: str(a["id"]).isEmpty ? "a\(i + 1)" : str(a["id"]), type: type, reason: str(a["reason"]),
                exerciseID: a["exerciseID"] as? String, kg: num(a["kg"]), low: num(a["low"]).map { Int($0) }, high: num(a["high"]).map { Int($0) },
                sets: num(a["sets"]).map { Int($0) }, template: a["template"] as? String, from: a["from"] as? String, to: a["to"] as? String,
                text: a["text"] as? String, byWeek: num(a["byWeek"]).map { Int($0) }))
        }
        return r
    }
}

// MARK: - The check-in, end to end

extension AppModel {
    var coachReports: [CoachReport] { store.coach }

    func report(_ id: UUID) -> CoachReport? { store.coach.first { $0.id == id } }

    func updateReport(_ id: UUID, _ change: (inout CoachReport) -> Void) {
        mutate { s in
            if let i = s.coach.firstIndex(where: { $0.id == id }) { change(&s.coach[i]) }
        }
        if let r = report(id) { writeReportFiles(r) }
    }

    private func insertReport(_ r: CoachReport) {
        mutate { s in
            s.coach.insert(r, at: 0)
            if s.coach.count > 40 { s.coach.removeLast(s.coach.count - 40) }
        }
        writeReportFiles(r)
    }

    /// First pass: read the data, give a first read, and ask the questions.
    /// Falls back to what Cairn can work out alone when Claude can't be reached.
    @discardableResult
    func startCheckIn(scope: CoachScope) async -> UUID {
        coachBusy = "Reading your log…"
        coachProblem = nil
        let snapshot = coachSnapshotJSON(scope: scope)
        writeSnapshot(snapshot, scope: scope)
        let local = coachLocal(scope: scope)
        let s = store.settings
        var report = CoachReport(created: Date(), scope: scope, day: Day.key(now()), weekNumber: currentWeek?.number,
                                 stage: .offline, notes: local.notes, model: s.coachModel, effort: scope == .daily ? "medium" : s.coachEffort)
        #if os(macOS)
        do {
            coachBusy = scope == .daily ? "Claude is looking at today…" : "Claude is reading the week…"
            let text = try await CoachRunner.run(prompt: Coach.prompt(snapshot: snapshot, scope: scope, final: false, answers: [], previous: nil),
                                                 system: Coach.system, model: s.coachModel, effort: report.effort, path: s.claudePath)
            let r = try CoachRunner.parse(text)
            report.stage = .asking
            report.verdict = r.verdict; report.headline = r.headline; report.summary = r.summary; report.nextWeek = r.nextWeek
            report.wins = r.wins; report.concerns = r.concerns
            report.questions = r.questions.isEmpty ? local.questions : r.questions
            report.adjustments = r.adjustments
        } catch {
            report.problem = error.localizedDescription
            report.questions = local.questions
            report.headline = "Cairn's own read"
            report.summary = "Claude wasn't used for this one. These are the things the numbers say on their own."
            coachProblem = error.localizedDescription
        }
        #else
        report.problem = "Claude runs on the Mac. Open Cairn there to run a check-in; it will show up here after the next sync."
        report.questions = local.questions
        #endif
        coachBusy = nil
        insertReport(report)
        return report.id
    }

    /// Second pass: Claude gets your answers and gives the final read.
    func finishCheckIn(_ id: UUID) async {
        guard let first = report(id) else { return }
        #if os(macOS)
        coachBusy = "Claude is putting it together…"
        coachProblem = nil
        let s = store.settings
        let snapshot = coachSnapshotJSON(scope: first.scope)
        do {
            let text = try await CoachRunner.run(prompt: Coach.prompt(snapshot: snapshot, scope: first.scope, final: true, answers: first.questions, previous: first),
                                                 system: Coach.system, model: s.coachModel, effort: first.effort.isEmpty ? s.coachEffort : first.effort, path: s.claudePath)
            let r = try CoachRunner.parse(text)
            updateReport(id) { rep in
                rep.stage = .final
                rep.verdict = r.verdict; rep.headline = r.headline; rep.summary = r.summary; rep.nextWeek = r.nextWeek
                rep.wins = r.wins; rep.concerns = r.concerns
                rep.adjustments = r.adjustments
                rep.problem = nil
            }
        } catch {
            coachProblem = error.localizedDescription
            updateReport(id) { $0.problem = error.localizedDescription }
        }
        coachBusy = nil
        #endif
    }

    func answer(_ reportID: UUID, question: String, _ value: String) {
        updateReport(reportID) { r in
            if let i = r.questions.firstIndex(where: { $0.id == question }) { r.questions[i].answer = value.isEmpty ? nil : value }
        }
    }

    // MARK: Applying what it suggests

    private func weekdayIndex(_ s: String?) -> Int? {
        guard let s = s?.lowercased() else { return nil }
        return Day.weekdayShort.indices.first { s.hasPrefix(Day.weekdayShort[$0].lowercased()) }
    }

    /// Make one adjustment, with a way back. Returns what happened, in words.
    @discardableResult
    func applyAdjustment(_ reportID: UUID, _ adjID: String) -> String {
        guard let r = report(reportID), let a = r.adjustments.first(where: { $0.id == adjID }), a.status != .applied else { return "" }
        var undo: [UndoStep] = []
        var result = ""
        let weekNo = currentWeek?.number ?? 1
        switch a.type {
        case "exercise_load":
            guard let id = a.exerciseID, Library.byID[id] != nil, var kg = a.kg, kg > 0, kg <= 300 else { result = "Not applied: the exercise or the weight didn't check out."; break }
            let info = Library.exercise(id)
            if info.isBand { kg = Bands.rungs[Bands.nearest(kg)].total }
            undo.append(.load(exerciseID: id, previous: store.loadSet[id]))
            setLoad(id, kg: kg, why: "Set from the check-in: \(a.reason)")
            result = "\(info.name) starts at \(info.isBand ? Bands.text(kg) : "\(Overload.kgText(kg)) kg") next session."
        case "exercise_scheme":
            guard let id = a.exerciseID, Library.byID[id] != nil else { result = "Not applied: unknown exercise."; break }
            if let lo = a.low, let hi = a.high, !(1...200).contains(lo) || !(lo...200).contains(hi) { result = "Not applied: that rep range doesn't make sense."; break }
            if let n = a.sets, !(1...8).contains(n) { result = "Not applied: sets must be 1 to 8."; break }
            var touched = 0
            mutate { s in
                for wi in s.plan.workouts.indices {
                    for gym in [false, true] {
                        let list = gym ? (s.plan.workouts[wi].gymExercises ?? []) : s.plan.workouts[wi].exercises
                        for (ei, pe) in list.enumerated() where pe.exerciseID == id {
                            let cur = pe.scheme(forWeek: weekNo)
                            var new = Scheme(fromWeek: weekNo, variant: cur.variant, sets: a.sets ?? cur.sets,
                                             low: a.low ?? cur.low, high: max(a.low ?? cur.low, a.high ?? cur.high), timed: cur.timed, note: cur.note)
                            if new == cur { continue }
                            var schemes = pe.schemes
                            if let k = schemes.firstIndex(where: { $0.fromWeek == weekNo }) { new.variant = schemes[k].variant; schemes[k] = new } else { schemes.append(new) }
                            undo.append(.schemes(workout: s.plan.workouts[wi].id, gym: gym, index: ei, previous: pe.schemes))
                            if gym { s.plan.workouts[wi].gymExercises?[ei].schemes = schemes } else { s.plan.workouts[wi].exercises[ei].schemes = schemes }
                            touched += 1
                        }
                    }
                }
            }
            result = touched == 0 ? "Nothing to change: it's already like that." : "\(Library.exercise(id).name): the new range holds from week \(weekNo) on."
        case "schedule_move":
            guard let f = weekdayIndex(a.from), let t = weekdayIndex(a.to), f != t, let key = a.template?.lowercased() else { result = "Not applied: the days or the session didn't check out."; break }
            let idx = calendarIndex(for: today)
            let fd = days(ofWeek: idx)[f], td = days(ofWeek: idx)[t]
            guard td >= today, let item = plannedItems(for: fd).first(where: { ($0.workoutID?.lowercased() ?? ($0.kind == .climb ? "climb" : "")) == key }) else { result = "Not applied: that session isn't on that day, or the new day has passed."; break }
            undo.append(.change(dayKey: Day.key(fd), previous: store.dayChanges[Day.key(fd)]))
            undo.append(.change(dayKey: Day.key(td), previous: store.dayChanges[Day.key(td)]))
            move(item, from: fd, to: td)
            result = "\(name(of: item)) moved from \(Day.weekdayShort[f]) to \(Day.weekdayShort[t])."
        case "repeat_week":
            repeatCurrentWeek()
            if let e = store.adaptations.first { undo.append(.timeline(e.id)) }
            result = "This week runs again next week."
        case "return_week":
            makeCurrentWeekReturn()
            if let e = store.adaptations.first { undo.append(.timeline(e.id)) }
            result = "This week is an easy return week."
        case "goal":
            guard let text = a.text, !text.isEmpty else { result = "Not applied: no goal text."; break }
            let g = SideGoal(title: text, byWeek: a.byWeek)
            undo.append(.goal(g.id))
            mutate { $0.goals.append(g) }
            result = "Goal added."
        default:
            result = "Noted."
        }
        let ok = !result.hasPrefix("Not applied") && !result.hasPrefix("Nothing")
        updateReport(reportID) { rep in
            if let i = rep.adjustments.firstIndex(where: { $0.id == adjID }) {
                rep.adjustments[i].status = ok ? .applied : .pending
                rep.adjustments[i].result = result
                rep.adjustments[i].undo = undo
            }
        }
        return result
    }

    func dismissAdjustment(_ reportID: UUID, _ adjID: String) {
        updateReport(reportID) { rep in
            if let i = rep.adjustments.firstIndex(where: { $0.id == adjID }) { rep.adjustments[i].status = .dismissed }
        }
    }

    func undoAdjustment(_ reportID: UUID, _ adjID: String) {
        guard let a = report(reportID)?.adjustments.first(where: { $0.id == adjID }), a.status == .applied else { return }
        for step in a.undo.reversed() {
            switch step {
            case .load(let id, let previous):
                mutate { $0.loadSet[id] = previous }
            case .schemes(let w, let gym, let i, let previous):
                mutate { s in
                    guard let wi = s.plan.workouts.firstIndex(where: { $0.id == w }) else { return }
                    if gym { if s.plan.workouts[wi].gymExercises?.indices.contains(i) == true { s.plan.workouts[wi].gymExercises?[i].schemes = previous } }
                    else if s.plan.workouts[wi].exercises.indices.contains(i) { s.plan.workouts[wi].exercises[i].schemes = previous }
                }
            case .goal(let id):
                mutate { $0.goals.removeAll { $0.id == id } }
            case .change(let key, let previous):
                mutate { $0.dayChanges[key] = previous }
            case .timeline(let id):
                if let e = store.adaptations.first(where: { $0.id == id }), !e.undone { undo(e) }
            }
        }
        updateReport(reportID) { rep in
            if let i = rep.adjustments.firstIndex(where: { $0.id == adjID }) {
                rep.adjustments[i].status = .pending
                rep.adjustments[i].result = "Undone."
                rep.adjustments[i].undo = []
            }
        }
    }

    // MARK: Files in the app folder

    private func writeSnapshot(_ json: String, scope: CoachScope) {
        let fm = FileManager.default
        let dir = Coach.folder.appendingPathComponent("snapshots", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        try? json.write(to: dir.appendingPathComponent("\(Day.key(now()))-\(scope.rawValue).json"), atomically: true, encoding: .utf8)
        try? json.write(to: Coach.folder.appendingPathComponent("latest-snapshot.json"), atomically: true, encoding: .utf8)
        let readme = """
        # Cairn coach folder

        - `latest-snapshot.json`: everything the analysis reads, as of the last check-in. Hand it to anyone (or any session) that should look at your training.
        - `snapshots/`: one per check-in, by date and scope.
        - `reports/`: each check-in as a readable `.md` and the full record as `.json`: the read, your answers, what was suggested, what you applied.

        The check-in runs `claude --print` with no tools and no settings, on your Claude sign-in. Nothing leaves the Mac except the snapshot text in that one call.
        """
        try? readme.write(to: Coach.folder.appendingPathComponent("README.md"), atomically: true, encoding: .utf8)
    }

    func writeReportFiles(_ r: CoachReport) {
        let fm = FileManager.default
        let dir = Coach.folder.appendingPathComponent("reports", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let base = "\(r.day)-\(r.scope.rawValue)-\(r.id.uuidString.prefix(6))"
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(r) { try? d.write(to: dir.appendingPathComponent("\(base).json"), options: .atomic) }
        var md = "# \(r.scope.name) · \(r.day)\n\n"
        if !r.headline.isEmpty { md += "**\(r.headline)**" + (r.verdict.isEmpty ? "" : " (\(r.verdict))") + "\n\n" }
        if !r.summary.isEmpty { md += r.summary + "\n\n" }
        if let p = r.problem { md += "> \(p)\n\n" }
        if !r.wins.isEmpty { md += "## Going well\n" + r.wins.map { "- \($0)" }.joined(separator: "\n") + "\n\n" }
        if !r.concerns.isEmpty { md += "## Watch\n" + r.concerns.map { "- \($0)" }.joined(separator: "\n") + "\n\n" }
        if !r.notes.isEmpty { md += "## From the numbers\n" + r.notes.map { "- \($0.text)" }.joined(separator: "\n") + "\n\n" }
        if !r.questions.isEmpty { md += "## Check-in\n" + r.questions.map { "- \($0.text) → \($0.answer ?? "—")" }.joined(separator: "\n") + "\n\n" }
        if !r.adjustments.isEmpty {
            md += "## Suggested changes\n" + r.adjustments.map { "- [\($0.status.rawValue)] \($0.type): \($0.reason)" + ($0.result.map { " — \($0)" } ?? "") }.joined(separator: "\n") + "\n\n"
        }
        if !r.nextWeek.isEmpty { md += "## Next\n\(r.nextWeek)\n" }
        try? md.write(to: dir.appendingPathComponent("\(base).md"), atomically: true, encoding: .utf8)
    }
}
