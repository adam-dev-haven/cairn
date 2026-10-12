#if os(macOS)
import Foundation

/// Checks for progressive overload, smart scheduling, goals and the coach.
extension SelfTest {
    private static func lift(_ m: AppModel, _ day: String, _ sets: [(Int, Double?)], id: String = "floor-press", variant: String = "DB floor press",
                             low: Int = 8, high: Int = 12, timed: Bool = false, planned: Int? = nil) {
        var s = SessionLog(day: day, kind: .home, workoutID: "A")
        var entries = sets.map { SetEntry(value: $0.0, kg: $0.1, done: true) }
        if let planned, planned > entries.count {
            for _ in 0..<(planned - entries.count) { entries.append(SetEntry(value: low, kg: sets.last?.1, done: false)) }
        }
        s.exercises = [ExerciseLog(exerciseID: id, variant: variant, timed: timed, low: low, high: high, sets: entries)]
        s.finished = true
        m.upsert(s)
    }

    private static func next(_ m: AppModel, _ id: String = "floor-press", variant: String = "DB floor press", low: Int = 8, high: Int = 12,
                             timed: Bool = false, sets n: Int = 3, on day: String = "2026-12-01") -> Overload.Prescription {
        m.prescription(id, variant: variant, low: low, high: high, timed: timed, setCount: n, before: d(day))
    }

    static func runOverloadTests() {
        // The worked example: 12 × 3 at 22.5 kg earns 25 kg and the bottom of the range.
        var m = model(at: "2026-12-01")
        lift(m, "2026-11-10", [(12, 22.5), (12, 22.5), (12, 22.5)])
        var rx = next(m)
        check(rx.kind == .progress && rx.kg == 25 && rx.targets.allSatisfy { $0.reps == 8 && $0.kg == 25 }, "12 × 3 at 22.5 → 25 kg, back to 8 reps")
        check(rx.reason.contains("25 kg"), "the reason says where it goes")

        // 12, 12, 10: stay until the last set hits 12.
        m = model(at: "2026-12-01")
        lift(m, "2026-11-10", [(12, 22.5), (12, 22.5), (10, 22.5)])
        rx = next(m)
        check(rx.kind == .stay && rx.kg == 22.5 && rx.targets.map(\.reps) == [12, 12, 12], "12, 12, 10 → stay at 22.5 and aim every set at 12")

        // 12, 12 at 22.5 then 12 at 20: fix the load before going up.
        m = model(at: "2026-12-01")
        lift(m, "2026-11-10", [(12, 22.5), (12, 22.5), (12, 20)])
        rx = next(m)
        check(rx.kind == .fixLoad && rx.kg == 22.5 && rx.targets.allSatisfy { $0.reps == 12 && $0.kg == 22.5 }, "a lighter set doesn't count: all three at 22.5 first")

        // Far from the top: a rep or two at a time, never past the top.
        m = model(at: "2026-12-01")
        lift(m, "2026-11-10", [(8, 20), (8, 20), (8, 20)])
        check(next(m).targets.map(\.reps) == [10, 10, 10], "8s in an 8–12 range aim at 10s")
        // A step up needs every set done: two of three at the top isn't it.
        m = model(at: "2026-12-01")
        lift(m, "2026-11-10", [(12, 22.5), (12, 22.5)], planned: 3)
        check(next(m).kind != .progress, "an unfinished set stops the step up")

        // Rough sessions: one is an off day, two back off.
        m = model(at: "2026-12-01")
        lift(m, "2026-11-03", [(10, 22.5), (10, 22.5), (10, 22.5)])
        lift(m, "2026-11-10", [(4, 22.5), (4, 22.5), (4, 22.5)])
        rx = next(m)
        check(rx.kind == .stay && rx.kg == 22.5 && rx.targets.allSatisfy { $0.reps == 8 }, "one rough session: same load, rebuild from the bottom")
        lift(m, "2026-11-17", [(4, 22.5), (3, 22.5), (3, 22.5)])
        rx = next(m)
        check(rx.kind == .backOff && rx.kg == 20, "two rough sessions: back off to about 90%, on the plate grid")
        // After the back-off the lighter load isn't read as another fall.
        lift(m, "2026-11-24", [(8, 20), (8, 20), (8, 20)])
        check(next(m).kind != .backOff, "a deliberate lighter load isn't a regression")

        // Strength fell without any set below the range: still a rough session.
        m = model(at: "2026-12-01")
        lift(m, "2026-11-03", [(12, 30), (12, 30), (12, 30)], low: 4)
        lift(m, "2026-11-10", [(5, 30), (5, 30), (5, 30)], low: 4)
        check(m.overloadHistory("floor-press", variant: nil).last!.isRough(after: m.overloadHistory("floor-press", variant: nil).first), "a clear fall in strength counts")

        // Plateau: four sessions, same load, no gain.
        m = model(at: "2026-12-01")
        for (i, day) in ["2026-11-03", "2026-11-10", "2026-11-17", "2026-11-24"].enumerated() {
            lift(m, day, [(10 - (i == 3 ? 1 : 0), 20), (9, 20), (9, 20)])
        }
        check(next(m).plateau, "four sessions without a gain is a plateau")

        // Bands: the top of the range has to land twice at the same band.
        m = model(at: "2026-12-01")
        lift(m, "2026-11-10", [(15, 31), (15, 31)], id: "band-floor-press", variant: "Band floor press", low: 10, high: 15)
        let once = next(m, "band-floor-press", variant: "Band floor press", low: 10, high: 15, sets: 2)
        check(once.kind == .stay && once.kg == 31, "a band doesn't move on one clean session")
        lift(m, "2026-11-17", [(15, 31), (15, 31)], id: "band-floor-press", variant: "Band floor press", low: 10, high: 15)
        let twice = next(m, "band-floor-press", variant: "Band floor press", low: 10, high: 15, sets: 2)
        check(twice.kind == .progress && twice.kg == Bands.up(from: 31) && twice.reps(0) == 10, "twice at the same band goes up a rung")

        // Holds gain five seconds; bodyweight goes past the range.
        m = model(at: "2026-12-01")
        lift(m, "2026-11-10", [(40, nil), (40, nil)], id: "side-plank", variant: "Side plank", low: 20, high: 40, timed: true)
        let hold = next(m, "side-plank", variant: "Side plank", low: 20, high: 40, timed: true, sets: 2)
        check(hold.kind == .progress && hold.reps(0) == 45, "a held top adds five seconds")

        // The first time, and a load set by hand.
        m = model(at: "2026-12-01")
        check(next(m).kind == .new && next(m).kg == nil, "nothing logged: start light, no weight guessed")
        m.setLoad("floor-press", kg: 17.5, why: "Set from the check-in.")
        check(next(m).kg == 17.5 && next(m).reps(0) == 8, "a load set by hand is where it starts")
        lift(m, "2026-12-02", [(8, 17.5), (8, 17.5), (8, 17.5)])
        check(next(m, on: "2026-12-09").kg == 17.5 && next(m, on: "2026-12-09").targets.map(\.reps) == [10, 10, 10], "once a session is logged, the history takes over again")

        // It reaches the draft you log into.
        m = model(at: "2026-11-02")
        m.mutate { $0.plan.workouts[0].exercises.append(PlannedExercise(exerciseID: "floor-press", schemes: [Scheme(fromWeek: 1, variant: "DB floor press", sets: 3, low: 10, high: 12)])) }
        lift(m, "2026-10-27", [(12, 22.5), (12, 22.5), (12, 22.5)], low: 10, high: 12)
        let draft = m.draft(for: PlannedItem(kind: .home, workoutID: "A"), on: d("2026-11-03"))
        let fp = draft.exercises.first { $0.exerciseID == "floor-press" }
        check(fp?.sets.count == 3 && fp?.sets.allSatisfy { $0.kg == 25 && $0.value == 10 } == true, "the session opens at 25 kg × 10 after a clean 12 × 3 at 22.5")
        check(m.readiness("floor-press") == .stepUp, "and the tag says step up")
        let rows = m.liftRows()
        check(rows.first { $0.exerciseID == "floor-press" }?.record.heaviest == 22.5, "the record keeps the heaviest load")
        check(Overload.step(for: Library.exercise("lateral-raise"), base: 2.5) == 1 && Overload.step(for: Library.exercise("floor-press"), base: 2.5) == 2.5, "light isolation lifts move in kilos")
    }

    static func runScheduleTests() {
        // A session brought forward is done for the week and comes off its own day.
        var m = model(at: "2026-10-06")
        let push = m.sessionTemplates.first { $0.workoutID == "A" }!
        let msg = m.add(push, on: d("2026-10-05"))
        check(msg.contains("moved here from Tue"), "adding Push to Monday moves it from Tuesday")
        check(m.plannedItems(for: d("2026-10-05")).contains { $0.workoutID == "A" && $0.from == "2026-10-06" }, "Monday has Push, marked as moved")
        check(!m.plannedItems(for: d("2026-10-06")).contains { $0.workoutID == "A" }, "Tuesday no longer has it")
        check(m.plannedItems(for: d("2026-10-13")).contains { $0.workoutID == "A" }, "next Tuesday is untouched")
        check(m.takenOff(on: d("2026-10-06")).count == 1, "the day remembers what was taken off")
        // Done on Monday, it's done for the week. Again, if you want it: as an extra.
        m.quickLog(m.plannedItems(for: d("2026-10-05")).first { $0.workoutID == "A" }!, on: d("2026-10-05"))
        check(m.add(push, on: d("2026-10-09")).contains("again"), "once it's done, adding it again is an extra")
        check(m.plannedItems(for: d("2026-10-09")).contains { $0.workoutID == "A" && $0.extra == true }, "Friday has it as an extra")
        check(m.add(push, on: d("2026-10-09")).contains("already"), "never twice on one day")
        // Put it back.
        m.putBack(m.takenOff(on: d("2026-10-06"))[0], on: d("2026-10-06"))
        check(m.plannedItems(for: d("2026-10-06")).contains { $0.workoutID == "A" }, "a day can take it back")

        // A replaced climb isn't a missed gym day.
        m = model(at: "2026-10-12")
        let climb = m.plannedItems(for: d("2026-10-05")).first { $0.kind == .climb }!
        m.takeOff(climb, on: d("2026-10-05"))
        check(m.plannedGymDays(week: 1).count == 1, "a climb you took off isn't counted as missed")
        check(m.plannedItems(for: d("2026-10-05")).map(\.kind) == [.check], "Monday keeps the check")
        m.takeOff(m.plannedItems(for: d("2026-10-05"))[0], on: d("2026-10-05"))
        check(m.plannedItems(for: d("2026-10-05")).map(\.kind) == [.rest], "a day with everything taken off is a rest day")

        // Spacing math.
        m = model(at: "2026-10-06")
        let pull = m.sessionTemplates.first { $0.workoutID == "C" }!
        check(m.scheduleIssues(week: 1).isEmpty, "the split week has no spacing problems")
        check(m.warnings(adding: pull, on: d("2026-10-09")).contains { $0.contains("hard climb") }, "pull the day after a hard climb is flagged")
        check(m.warnings(adding: pull, on: d("2026-10-10")).isEmpty, "pull where it is in the plan is fine")
        let legs = m.sessionTemplates.first { $0.workoutID == "B" }!
        check(m.warnings(adding: legs, on: d("2026-10-07")).contains { $0.contains("Legs") }, "legs the day before a hard climb is flagged")
        check(Schedule.cycle(6, 0) == 1 && Schedule.cycle(0, 3) == 3, "Sunday sits next to Monday on the weekly cycle")

        // A skipped session finds the cheapest sensible day.
        m = model(at: "2026-10-06")
        let tuePush = m.plannedItems(for: d("2026-10-06")).first { $0.workoutID == "A" }!
        m.skip(tuePush, on: d("2026-10-06"), reason: .tired)
        let sug = m.scheduleSuggestions(week: 1)
        check(sug.count == 1 && sug[0].rule == .skipCarry, "skipping Push for tiredness suggests a new day")
        if case .move(_, let from, let to)? = sug.first?.actions.first { check(from == "2026-10-06" && to == "2026-10-07", "Push goes to Wednesday: room, and clear of every rule") }
        else { check(false, "the suggestion is a move") }
        m.apply(sug[0])
        check(m.plannedItems(for: d("2026-10-07")).contains { $0.workoutID == "A" } && !m.plannedItems(for: d("2026-10-06")).contains { $0.workoutID == "A" }, "applying it moves the session")
        check(m.scheduleSuggestions(week: 1).isEmpty, "and the suggestion doesn't come back")
        m = model(at: "2026-10-06")
        m.skip(m.plannedItems(for: d("2026-10-06")).first { $0.workoutID == "A" }!, on: d("2026-10-06"), reason: .sick)
        check(m.scheduleSuggestions(week: 1).isEmpty, "sick is handled by the return-week rule, not moved")
        // Automatic: it just happens.
        m = model(at: "2026-10-06")
        m.mutate { $0.settings.schedule.skipCarry = .automatic }
        m.skip(m.plannedItems(for: d("2026-10-06")).first { $0.workoutID == "A" }!, on: d("2026-10-06"), reason: .time)
        m.runScheduleRules()
        check(m.plannedItems(for: d("2026-10-07")).contains { $0.workoutID == "A" }, "in automatic mode the skipped session moves by itself")

        // Red elbows swap pulling and climbing for prehab.
        m = model(at: "2026-10-06")
        m.setElbow(d("2026-10-06"), 5)
        let el = m.scheduleSuggestions(week: 1).first { $0.rule == .elbow }
        check(el != nil && el!.actions.count == 3, "red elbows: Wednesday's easy climb, Thursday's climb and Saturday's pull go")
        m.mutate { $0.settings.schedule.elbow = .automatic }
        m.runScheduleRules()
        check(!m.plannedItems(for: d("2026-10-08")).contains { $0.kind == .climb } && !m.plannedItems(for: d("2026-10-10")).contains { $0.workoutID == "C" }, "automatic: no climbing or pulling left this week")
        check(m.plannedItems(for: d("2026-10-10")).contains { $0.kind == .prehab }, "prehab takes the pull's place")

        // Pattern recognition: the same session missed week after week.
        m = model(at: "2026-10-20")
        for day in ["2026-09-30", "2026-10-07", "2026-10-14"] {
            var w = m.draft(for: PlannedItem(kind: .home, workoutID: "D"), on: d(day))
            for i in w.exercises.indices { for k in w.exercises[i].sets.indices { w.exercises[i].sets[k].done = true } }
            w.finished = true
            m.upsert(w)
        }
        let found = m.patternFindings().first { $0.item.workoutID == "A" }
        check(found != nil && found!.missedRun >= 2, "Push missed on Tuesdays week after week is noticed")
        check(found?.better == 2, "Wednesday is the weekday that has worked")
        let ps = m.patternSuggestions().first { $0.actions.contains { if case .movePattern(let i, _) = $0 { return i.workoutID == "A" } else { return false } } }
        check(ps != nil, "and it becomes a suggestion")
        if let ps { m.apply(ps) }
        check(m.plan.days[2].items.contains { $0.workoutID == "A" } && !m.plan.days[1].items.contains { $0.workoutID == "A" }, "applying it moves Push to Wednesday in the plan itself")

        // Day changes survive a save and travel between devices.
        m = model(at: "2026-10-06")
        _ = m.add(m.sessionTemplates.first { $0.workoutID == "A" }!, on: d("2026-10-05"))
        let data = try! JSONEncoder().encode(m.store)
        let back = try! JSONDecoder().decode(Store.self, from: data)
        check(back.dayChanges == m.store.dayChanges && !back.dayChanges.isEmpty, "day changes are saved")
        let other = AppModel(store: Store(plan: DefaultPlan.make()))
        other.save()
        let merged = Merge.merge(local: other.store, remote: m.store)
        check(merged.dayChanges == m.store.dayChanges, "and sync to the other device")
    }

    static func runCoachTests() {
        // Goals: a harder grade, three of the current one, a flash.
        var m = model(at: "2026-10-20")
        check(m.climbGoals.first?.title == "Send your first problem", "no sends yet: the first goal is the first send")
        var c = SessionLog(day: "2026-10-19", kind: .climb)
        c.climb = ClimbLog(problems: [Problem(grade: 1, attempts: 2)])
        c.finished = true
        m.upsert(c)
        check(m.climbGoals.map(\.title) == ["Send a V2", "Send three V1 in one session", "Flash a V1"], "one V1 sent: V2, three V1s, a V1 flash")
        var c2 = SessionLog(day: "2026-10-20", kind: .climb)
        c2.climb = ClimbLog(problems: [Problem(grade: 2), Problem(grade: 1), Problem(grade: 1), Problem(grade: 1)])
        c2.finished = true
        m.upsert(c2)
        let progress = m.goalProgress(finishing: c2)
        check(progress.reached.count == 3, "that session reached all three goals")
        check(progress.next.first?.title == "Send a V3", "and the next one is a V3")

        // The check-in prompt and snapshot.
        m = model(at: "2026-10-20")
        lift(m, "2026-10-13", [(12, 22.5), (12, 22.5), (12, 22.5)])
        let snap = m.coachSnapshotJSON(scope: .weekly)
        let obj = try? JSONSerialization.jsonObject(with: Data(snap.utf8)) as? [String: Any]
        check(obj != nil && obj!["lifts"] != nil && obj!["weeks"] != nil && obj!["block"] != nil, "the snapshot is JSON with the block, the weeks and the lifts")
        check(snap.contains("floor-press") && snap.contains("progress"), "it carries what the overload rules say is next")
        let local = m.coachLocal(scope: .weekly)
        check(local.notes.contains { $0.kind == .win && $0.text.contains("step up") } && local.questions.count >= 3, "Cairn's own read finds the step up and has questions")
        let prompt = Coach.prompt(snapshot: snap, scope: .weekly, final: true, answers: [CoachQuestion(id: "q1", text: "Elbows?", kind: "choice", answer: "Fine")], previous: nil)
        check(prompt.contains("Elbows? → Fine") && prompt.contains("exercise_load"), "the second pass carries your answers and the adjustment types")

        // Reading what comes back, leniently.
        let raw = """
        Sure. ```json
        {"verdict":"adjust","headline":"Push is going well","summary":"Good week.","wins":["Floor press up"],"concerns":[],
         "questions":[{"id":"q1","text":"How are the elbows?","kind":"choice","options":["Fine","Ache"]},{"text":"Energy?","kind":"scale"}],
         "adjustments":[{"id":"a1","type":"exercise_load","exerciseID":"floor-press","kg":"25","reason":"Earned it."},
                        {"id":"a2","type":"exercise_scheme","exerciseID":"floor-press","low":6,"high":10,"sets":4,"reason":"Heavier."},
                        {"id":"a3","type":"schedule_move","template":"C","from":"Sat","to":"Sun","reason":"x"},
                        {"id":"a4","type":"goal","text":"Five strict pull-ups","byWeek":12,"reason":"x"},
                        {"id":"a5","type":"launch_rocket","reason":"x"},
                        {"id":"a6","type":"note","text":"Sleep more","reason":"x"}]} ```
        """
        let reply = try? CoachRunner.parse(raw)
        check(reply?.verdict == "adjust" && reply?.questions.count == 2 && reply?.questions[1].id == "q2", "a fenced answer with preamble is read; missing ids are filled")
        check(reply?.adjustments.count == 5 && reply?.adjustments.first?.kg == 25, "string numbers are read; unknown adjustment types are dropped")
        check((try? CoachRunner.parse("no json here")) == nil, "an answer without JSON is refused")

        // Applying, and undoing.
        m = model(at: "2026-10-20")
        m.mutate { $0.plan.workouts[0].exercises.append(PlannedExercise(exerciseID: "floor-press", schemes: [Scheme(fromWeek: 1, variant: "DB floor press", sets: 3, low: 8, high: 12)])) }
        var rep = CoachReport(created: Date(), scope: .weekly, day: "2026-10-20", weekNumber: 4, stage: .final)
        rep.adjustments = reply!.adjustments
        m.mutate { $0.coach = [rep] }
        let rid = rep.id
        check(m.applyAdjustment(rid, "a1").contains("25 kg"), "load adjustment applies")
        check(m.next(for: "floor-press") == 25, "the next session starts there")
        m.undoAdjustment(rid, "a1")
        check(m.store.loadSet["floor-press"] == nil && m.report(rid)!.adjustments[0].status == .pending, "undo puts the load back")
        m.applyAdjustment(rid, "a1")
        let before = m.plan.workouts[0].exercises.last!.schemes
        _ = m.applyAdjustment(rid, "a2")
        let after = m.plan.workouts[0].exercises.last!.scheme(forWeek: m.currentWeek!.number)
        check(after.low == 6 && after.high == 10 && after.sets == 4 && after.variant == "DB floor press", "scheme adjustment changes the range and sets from this week")
        m.undoAdjustment(rid, "a2")
        check(m.plan.workouts[0].exercises.last!.schemes == before, "undo restores the scheme")
        m.applyAdjustment(rid, "a3")
        check(m.plannedItems(for: d("2026-10-25")).contains { $0.workoutID == "C" } && !m.plannedItems(for: d("2026-10-24")).contains { $0.workoutID == "C" }, "schedule adjustment moves Pull from Saturday to Sunday")
        m.undoAdjustment(rid, "a3")
        check(m.plannedItems(for: d("2026-10-24")).contains { $0.workoutID == "C" }, "undo puts it back")
        m.applyAdjustment(rid, "a4")
        check(m.store.goals.contains { $0.title == "Five strict pull-ups" }, "goal adjustment adds a goal")
        m.undoAdjustment(rid, "a4")
        check(m.store.goals.isEmpty, "undo removes it")
        var bad = rep; bad.adjustments = [CoachAdjustment(id: "x", type: "exercise_load", reason: "", exerciseID: "no-such-lift", kg: 20)]
        m.mutate { $0.coach = [bad] }
        check(m.applyAdjustment(rid, "x").hasPrefix("Not applied") && m.report(rid)!.adjustments[0].status == .pending, "a made-up exercise isn't applied")

        // Round trip through a stand-in `claude` that answers from a script.
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cairn-coach-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        setenv("CAIRN_DATA_DIR", tmp.path, 1)
        defer { unsetenv("CAIRN_DATA_DIR") }
        let script = tmp.appendingPathComponent("fake-claude.sh")
        let first = #"{"verdict":"keep","headline":"First read","summary":"Fine.","wins":["a"],"concerns":[],"questions":[{"id":"q1","text":"Elbows?","kind":"choice","options":["Fine","Ache"]}],"adjustments":[]}"#
        let final = #"{"verdict":"adjust","headline":"Final read","summary":"Raise it.","wins":[],"concerns":[],"questions":[],"adjustments":[{"id":"a1","type":"exercise_load","exerciseID":"floor-press","kg":27.5,"reason":"Earned."}],"nextWeek":"Same again."}"#
        try? """
        #!/bin/bash
        input=$(cat)
        echo "$@" > "\(tmp.path)/args.txt"
        if echo "$input" | grep -q "They answered"; then echo '\(final)'; else echo '\(first)'; fi
        """.write(to: script, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        m = model(at: "2026-10-20")
        m.store.settings.claudePath = script.path
        var rid2: UUID?
        let sem = DispatchSemaphore(value: 0)
        Task { rid2 = await m.startCheckIn(scope: .weekly); sem.signal() }
        _ = sem.wait(timeout: .now() + 30)
        let r1 = rid2.flatMap { m.report($0) }
        check(r1?.stage == .asking && r1?.headline == "First read" && r1?.questions.first?.text == "Elbows?", "the first pass asks its question")
        let args = (try? String(contentsOf: tmp.appendingPathComponent("args.txt"))) ?? ""
        check(args.contains("--print") && args.contains("--model claude-sonnet-5-5") && args.contains("--effort high") && args.contains("--tools"), "it runs claude --print with the chosen model and effort, no tools")
        check(args.contains("--setting-sources") && !args.contains("--bare"), "no settings or hooks, and never --bare")
        if let id = rid2 {
            m.answer(id, question: "q1", "Ache")
            check(m.report(id)?.answered == true, "an answered question is recorded")
            let sem2 = DispatchSemaphore(value: 0)
            Task { await m.finishCheckIn(id); sem2.signal() }
            _ = sem2.wait(timeout: .now() + 30)
            let r2 = m.report(id)
            check(r2?.stage == .final && r2?.headline == "Final read" && r2?.adjustments.first?.exerciseID == "floor-press", "the second pass gives the final read and a change")
            m.applyAdjustment(id, "a1")
            check(m.store.loadSet["floor-press"]?.kg == 27.5, "which applies")
        }
        let files = (try? FileManager.default.contentsOfDirectory(atPath: tmp.appendingPathComponent("coach/reports").path)) ?? []
        check(files.contains { $0.hasSuffix(".md") } && files.contains { $0.hasSuffix(".json") }, "reports are written to the app folder")
        check(FileManager.default.fileExists(atPath: tmp.appendingPathComponent("coach/latest-snapshot.json").path), "so is the snapshot")
        check(m.store.coach.count == 1, "one report in the store")
        let merged = Merge.merge(local: AppModel(store: Store(plan: DefaultPlan.make())).store, remote: { var s = m.store; s.meta.sections["coach"] = Date(); return s }())
        check(merged.coach.count == 1, "check-ins sync to the phone")

        // No claude: an honest offline read.
        let off = model(at: "2026-10-20")
        off.store.settings.claudePath = "/nonexistent/claude"
        let savedPath = ProcessInfo.processInfo.environment["PATH"]
        _ = savedPath
        var rid3: UUID?
        let sem3 = DispatchSemaphore(value: 0)
        Task { rid3 = await off.startCheckIn(scope: .daily); sem3.signal() }
        _ = sem3.wait(timeout: .now() + 30)
        let r3 = rid3.flatMap { off.report($0) }
        // (If a real claude is installed in a usual place it may answer; either way a report exists.)
        check(r3 != nil && !(r3?.questions.isEmpty ?? true), "a check-in always produces a report with questions")
        check(CoachError.notSignedIn.errorDescription!.contains("/login"), "the sign-in error says what to do")

        // The colour wheel: a colour round-trips through hex.
        check(Hex.value(Hex.color(0x2BB5C9)) == 0x2BB5C9, "a colour chosen on the wheel keeps its hex")
        check(GradeCircuit.palette.contains { $0.0 == "Cyan" }, "Cyan is in the palette")
    }
}

extension AppModel {
    /// The kg the next session of an exercise starts at (tests).
    func next(for exerciseID: String) -> Double? {
        let rx = prescription(exerciseID, variant: "DB floor press", low: 8, high: 12, timed: false, setCount: 3, before: Day.add(1, to: today))
        return rx.kg
    }
}
#endif
