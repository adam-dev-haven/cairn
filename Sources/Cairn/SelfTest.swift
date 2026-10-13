#if os(macOS)
import Foundation

/// `Cairn --selftest` — headless checks of the plan, the schedule engine,
/// adaptation, scoring, quests, activity import and persistence.
enum SelfTest {
    static var passed = 0
    static var failed = 0

    static func check(_ ok: Bool, _ what: String, line: Int = #line) {
        if ok { passed += 1 } else { failed += 1; print("FAIL (line \(line)): \(what)") }
    }

    static func model(at day: String) -> AppModel {
        let m = AppModel(store: Store(plan: DefaultPlan.make()))
        m.now = { Day.date(day)!.addingTimeInterval(9 * 3600) }
        return m
    }

    static func d(_ k: String) -> Date { Day.date(k)! }

    static func logGym(_ m: AppModel, _ day: String, climb grades: [Int] = [1, 2], workout: String? = nil) {
        var c = SessionLog(day: day, kind: .climb)
        c.climb = ClimbLog(problems: grades.map { Problem(grade: $0) })
        m.upsert(c)
        if let workout {
            var w = m.draft(for: PlannedItem(kind: .home, workoutID: workout), on: d(day))
            for i in w.exercises.indices { for k in w.exercises[i].sets.indices { w.exercises[i].sets[k].done = true } }
            m.upsert(w)
        }
    }

    static func run() -> Bool {
        // Plan shape
        let p = DefaultPlan.make()
        check(p.weeks.count == 14, "14 weeks")
        check(p.timeline.count == 14, "timeline of 14")
        check(p.days.count == 7, "7 day patterns")
        check(Set(p.workouts.map(\.id)) == ["A", "B", "C", "D", "H", "P"], "workouts A B C D H P")
        check(["A", "B", "C", "D"].allSatisfy { id in p.workouts.first { $0.id == id }?.gymExercises?.isEmpty == false }, "Push, Legs, Pull and Aesthetic each have a gym version")
        check(Bands.kg == [4.5, 9, 13.5, 18, 22.5] && Bands.rungs.last?.total == 67.5, "the five bands are yellow 4.5, green 9, red 13.5, blue 18 and black 22.5 kg")
        check(p.revision == DefaultPlan.revision && p.points.greenWeek == 50, "the plan is the split week, green at 50")
        check(p.weeks.map(\.phase) == [.foundation, .foundation, .foundation, .foundation, .deload, .build, .build, .build, .build, .deload, .push, .push, .holiday, .test], "phase order from the doc")
        check(p.weeks.allSatisfy { Library.drill($0.drillID) != nil }, "every week has a drill")
        check(p.workouts.flatMap { $0.exercises + ($0.gymExercises ?? []) }.allSatisfy { Library.byID[$0.exerciseID] != nil }, "every exercise is in the library")
        check(Library.exercises.count == Set(Library.exercises.map(\.id)).count, "exercise ids unique")
        check(Library.exercises.filter(\.isBand).allSatisfy { $0.bandStart != nil && $0.photos.count <= 1 }, "band exercises start on a band")
        if Photos.available {
            let ids = Library.exercises.flatMap(\.photos) + Library.skills.flatMap(\.photos)
            check(!ids.isEmpty && ids.allSatisfy { !Photos.frames($0).isEmpty }, "every photo the app mentions ships with it")
            check(Library.exercises.filter { !$0.photos.isEmpty && !$0.isBand && $0.id == "pushup" }.allSatisfy { Photos.frames($0.photos[0]).count == 2 }, "exercise photos come as start and finish")
        }
        // The split week: climb days climb, pull sits 48 h clear of the hard ones
        let hard = p.days.indices.filter { i in p.days[i].items.contains { $0.countsAsGym } }
        let pullDays = p.days.indices.filter { i in p.days[i].items.contains { $0.workoutID == "C" } }
        check(hard == [0, 3] && pullDays == [5], "two hard climbs (Mon, Thu), pull on Saturday")
        check(pullDays.allSatisfy { c in hard.allSatisfy { g in min((c - g + 7) % 7, (g - c + 7) % 7) >= 2 } }, "pull is 48 h from both hard climbs")
        check(p.days.flatMap(\.items).filter { $0.kind == .climb && $0.isOptional }.count == 1, "one optional easy climb")
        check(!p.days.flatMap(\.items).contains { ($0.kind == .home || $0.kind == .workout) && $0.countsAsGym }, "nothing on a climbing day loads the hands afterwards")
        check(p.days[0].items.allSatisfy { $0.kind != .home && $0.kind != .workout } && p.days[3].items.allSatisfy { $0.kind != .home && $0.kind != .workout }, "climb days have no strength session")
        // The band ladder
        check(Bands.rungs.first?.total == 4.5 && Bands.rungs.last?.total == 67.5, "ladder runs 4.5 to 67.5 kg")
        check(Bands.rungs.map(\.total) == Bands.rungs.map(\.total).sorted() && Set(Bands.rungs.map(\.total)).count == Bands.rungs.count, "ladder is sorted, one rung per total")
        check(Bands.up(from: 31.5) > 31.5 && Bands.down(from: 31.5) < 31.5 && Bands.up(from: 100) == 67.5 && Bands.down(from: 0) == 4.5, "stepping the ladder stops at both ends")
        check(Bands.describe(31.5) == "31.5 kg (13.5 + 18)" && Bands.describe(13.5) == "13.5 kg", "a band combination reads as its parts")
        check(Quests.badges.count == Set(Quests.badges.map(\.id)).count, "badge ids unique")
        check(Library.exercises.filter { !$0.ladder.isEmpty }.allSatisfy { (AppModel.defaultRungs[$0.id] ?? 0) < $0.ladder.count }, "default rungs inside ladders")

        // Calendar
        var m = model(at: "2026-09-28")
        check(Day.weekday(d("2026-09-28")) == 1, "Sep 28 2026 is a Monday")
        check(m.calendarIndex(for: d("2026-09-28")) == 0, "index 0 on start")
        check(m.calendarIndex(for: d("2026-10-04")) == 0, "Sunday still week 1")
        check(m.calendarIndex(for: d("2026-10-05")) == 1, "next Monday week 2")
        check(m.calendarIndex(for: d("2026-09-27")) == -1, "day before is -1")
        check(Day.key(m.summitDate) == "2026-12-28", "summit week starts Dec 28")
        check(Day.key(m.endDate) == "2027-01-03", "block ends the Sunday after")
        let beforeStart = model(at: "2026-09-27")
        check(beforeStart.beforeStart, "Sep 27 is before start")

        // Planned items
        let mon = m.plannedItems(for: d("2026-09-28"))
        check(mon.map(\.kind) == [.climb, .check], "Monday: boulder, check")
        let tue = m.plannedItems(for: d("2026-09-29"))
        check(tue.map(\.kind) == [.home, .prehab] && tue[0].workoutID == "A", "Tuesday: push at home, prehab")
        let wed = m.plannedItems(for: d("2026-09-30"))
        check(wed.map(\.kind) == [.climb, .home] && wed[0].isOptional && wed[1].workoutID == "D", "Wednesday: optional easy climb, aesthetic")
        check(m.plannedItems(for: d("2026-10-01")).map(\.kind) == [.climb, .walk], "Thursday: boulder, walk")
        check(m.plannedItems(for: d("2026-10-02")).first?.workoutID == "B", "Friday: legs")
        check(m.plannedItems(for: d("2026-10-03")).first?.workoutID == "C", "Saturday: pull")
        check(m.plannedItems(for: d("2026-10-04")).map(\.kind) == [.prehab], "Sunday: prehab")
        check(m.plannedGymDays(week: 0).count == 2, "the optional climb isn't a gym day")
        let holidayMon = d("2026-12-21")
        check(m.blockWeek(for: holidayMon)?.phase == .holiday, "Dec 21 is holiday week")
        check(!m.plannedItems(for: holidayMon).contains { $0.kind.isGym }, "holiday has no gym items")
        check(m.plannedItems(for: holidayMon).contains { $0.kind == .home && $0.workoutID == "H" }, "holiday has a home session")
        check(m.plannedItems(for: d("2026-12-23")).contains { $0.kind == .home && $0.workoutID == "H" && $0.isOptional }, "an optional climb stays optional at home")

        // Sets per the doc
        let a = p.workouts.first { $0.id == "A" }!
        let w1 = m.blockWeek(at: 0)!, w3 = m.blockWeek(at: 2)!, w5 = m.blockWeek(at: 4)!, w11 = m.blockWeek(at: 10)!
        check(m.sets(for: a.exercises[0], position: 0, week: w1) == 2, "2 sets in week 1")
        check(m.sets(for: a.exercises[0], position: 0, week: w3) == 3, "3 sets from week 3")
        check(m.sets(for: a.exercises[0], position: 0, week: w11) == 4, "4 sets on first exercise in Push")
        check(m.sets(for: a.exercises[2], position: 2, week: w11) == 3, "3 sets on later exercises in Push")
        check(m.sets(for: a.exercises[0], position: 0, week: w5) == 2, "deload halves 3 → 2")
        let pull = p.workouts.first { $0.id == "C" }!.gymExercises![0]
        check(pull.scheme(forWeek: 1).variant.contains("Negative"), "pull-ups start as negatives")
        check(pull.scheme(forWeek: 7).variant == "Strict pull-up" && pull.scheme(forWeek: 7).high == 2, "week 7: strict 2s")
        check(pull.scheme(forWeek: 12).high == 3 && m.sets(for: pull, position: 0, week: w11) == 4, "Push: 4 × 3")
        let aesthetic = p.workouts.first { $0.id == "D" }!
        let plank = aesthetic.exercises.first { $0.exerciseID == "side-plank" }!
        check(!plank.scheme(forWeek: 5).variant.contains("top leg") && plank.scheme(forWeek: 6).variant.contains("top leg"), "side plank lifts a leg at week 6")

        // Draft prefill uses last time's numbers
        logGym(m, "2026-09-28", workout: "A")
        let draft = m.draft(for: PlannedItem(kind: .home, workoutID: "A"), on: d("2026-10-05"))
        check(draft.exercises.first?.sets.first?.value == 12, "short of the top, the target is two reps past last time")
        check(draft.exercises.first?.sets.allSatisfy { !$0.done } == true, "a new draft has nothing ticked")
        check(draft.exercises.first?.sets.first?.kg == 31.5, "a band exercise starts on its guess")

        // Bands: the load climbs a rung when the top of the range lands twice
        do {
            let b = model(at: "2026-10-20")
            for day in ["2026-10-06", "2026-10-13"] {
                var w = SessionLog(day: day, kind: .home, workoutID: "A")
                w.exercises = [ExerciseLog(exerciseID: "band-floor-press", variant: "Band floor press", timed: false, low: 10, high: 15,
                                           sets: [SetEntry(value: 15, kg: 31, done: true), SetEntry(value: 15, kg: 31, done: true)])]
                b.upsert(w)
            }
            check(b.readiness("band-floor-press") == .stepUp, "top of the range twice on bands")
            let next = b.draft(for: PlannedItem(kind: .home, workoutID: "A"), on: d("2026-10-20"))
            check(next.exercises.first?.sets.first?.kg == Bands.up(from: 31) && next.exercises.first?.sets.first?.value == 10, "the band goes up a rung and reps start over")
            var lowDay = SessionLog(day: "2026-10-14", kind: .home, workoutID: "A")
            lowDay.exercises = [ExerciseLog(exerciseID: "band-floor-press", variant: "Band floor press", timed: false, low: 10, high: 15,
                                            sets: [SetEntry(value: 11, kg: 36, done: true)])]
            b.upsert(lowDay)
            check(b.draft(for: PlannedItem(kind: .home, workoutID: "A"), on: d("2026-10-20")).exercises.first?.sets.first?.kg == 36, "short of the top, the band stays")
        }

        // Pull and legs have a gym version
        do {
            let g = model(at: "2026-10-03")
            let cItem = PlannedItem(kind: .home, workoutID: "C")
            let home = g.draft(for: cItem, on: d("2026-10-03"))
            check(home.exercises.first?.exerciseID == "band-lat-pulldown" && home.atGym == nil, "pull starts at home on bands")
            let gym = g.setPlace(home, atGym: true)
            check(gym.atGym == true && gym.exercises.first?.exerciseID == "pullup", "the gym version leads with the pull-up ladder")
            var started = g.setPlace(home, atGym: false)
            started.exercises[0].sets[0].done = true
            check(g.setPlace(started, atGym: true).exercises.first?.exerciseID == "band-lat-pulldown", "switching after ticking a set keeps the log")
            check(g.plan.workouts.filter { $0.gymExercises != nil }.map(\.id).sorted() == ["A", "B", "C", "D"], "push, legs, pull and aesthetic have gym versions")
        }

        // Elbows
        do {
            let e = model(at: "2026-10-03")
            check(e.elbowReading(asOf: e.today) == nil, "no elbow reading yet")
            var c = SessionLog(day: "2026-09-30", kind: .climb)
            c.pain = [PainEntry(area: .elbows, score: 6)]
            e.upsert(c)
            check(e.elbowReading(asOf: e.today)?.light == .red && e.elbowReading(asOf: e.today)?.day == "2026-09-30", "a red session pain shows as the reading")
            e.setElbow(e.today, 1)
            check(e.elbowReading(asOf: e.today)?.light == .green, "today's check-in outranks last week")
            e.setElbow(e.today, nil)
            check(e.elbowReading(asOf: e.today)?.light == .red, "clearing the check-in brings the old reading back")
            check(e.elbowReading(asOf: d("2026-10-12")) == nil, "a reading older than a week fades")
            let reopened = try? JSONDecoder().decode(DayLog.self, from: Data(#"{"steps":5000}"#.utf8))
            check(reopened?.elbow == nil && reopened?.steps == 5000, "old day logs still decode")
        }

        // Moving a saved plan to the split week
        do {
            var old = Store(plan: DefaultPlan.make())
            old.plan.revision = 1
            old.plan.days[0] = DayPattern(items: [PlannedItem(kind: .climb), PlannedItem(kind: .workout, workoutID: "A"), PlannedItem(kind: .check)], place: "Gym", length: "70–80 min")
            old.plan.workouts = old.plan.workouts.filter { $0.id != "D" }
            old.plan.points.greenWeek = 45
            var oldLog = SessionLog(day: "2026-09-28", kind: .workout, workoutID: "A")
            oldLog.exercises = [ExerciseLog(exerciseID: "floor-press", variant: "DB floor press", timed: false, low: 8, high: 12, sets: [SetEntry(value: 8, kg: 12, done: true)])]
            old.sessions = [oldLog]
            let mm = AppModel(store: old)
            mm.now = { Day.date("2026-10-03")!.addingTimeInterval(9 * 3600) }
            check(mm.migratePlan(), "an old plan migrates")
            check(mm.plan.revision == DefaultPlan.revision && mm.plan.workouts.contains { $0.id == "D" } && mm.plan.days[0].items.count == 2, "it gets the split week")
            check(mm.plan.points.greenWeek == 50, "green moves with it")
            check(mm.store.sessions.count == 1 && mm.store.sessions[0].exercises.first?.exerciseID == "floor-press", "logs are untouched")
            check(Library.exercise("floor-press").name == "DB floor press", "old exercises still read")
            check(mm.store.evaluatedThrough == 0, "the week lived under the old pattern isn't judged by the new one")
            check(!mm.migratePlan(), "migrating twice does nothing")
            var tweaked = Store(plan: DefaultPlan.make()); tweaked.plan.revision = 1; tweaked.plan.points.greenWeek = 60
            let tm = AppModel(store: tweaked); tm.migratePlan()
            check(tm.plan.points.greenWeek == 60, "a green score you changed yourself stays")
        }

        // Points
        m = model(at: "2026-10-04")
        logGym(m, "2026-09-28", workout: "A")
        check(m.score(week: 0).gym == 10, "gym morning = 10")
        check(m.score(week: 0).sends == 5, "first hardest send = 5")
        logGym(m, "2026-09-30", climb: [2], workout: "B")
        check(m.score(week: 0).sends == 5, "same grade isn't a new hardest")
        logGym(m, "2026-10-02", climb: [3], workout: "C")
        check(m.score(week: 0).sends == 10, "V3 is a new hardest")
        for day in ["2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01"] {
            m.setDaily(d(day)) { $0.steps = 8200; $0.protein = true }
        }
        check(m.score(week: 0).steps == 12, "4 floors + 4 goals")
        check(m.score(week: 0).total == 30 + 18 + 10 + 12 + 4, "total adds up")
        check(m.isGreen(week: 0), "that's a green week")
        check(m.streak == 1, "streak 1")
        check(m.store.badges["base-camp"] != nil, "Base Camp unlocked")
        check(m.routeProgress > 0.9 && m.routeProgress < 1.0, "figure near camp 1 after a green week")

        // Adaptation: both hard climbs missed repeats the week
        m = model(at: "2026-10-05")
        m.evaluateAdaptation()
        check(m.plan.timeline.count == 15, "missed week inserts a repeat")
        check(m.plan.timeline[safe: 1]?.template == 1 && m.plan.timeline[safe: 1]?.reason == .repeated, "week 1 again")
        check(m.currentWeek?.number == 1, "this calendar week is week 1 again")
        check(Day.key(m.summitDate) == "2027-01-04", "summit slides a week")
        check(m.store.adaptations.count == 1, "event recorded")
        m.evaluateAdaptation()
        check(m.plan.timeline.count == 15, "evaluation is idempotent")
        if let e = m.store.adaptations.first { m.undo(e) }
        check(m.plan.timeline.count == 14 && !m.store.adaptations.isEmpty, "undo restores")

        // Sickness → return week + repeat
        m = model(at: "2026-10-05")
        for day in ["2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02"] { m.setDaily(d(day)) { $0.sick = true } }
        logGym(m, "2026-09-28")
        m.evaluateAdaptation()
        check(m.plan.timeline.count == 16, "sick week adds return + repeat")
        check(m.currentWeek?.phase == .recovery, "this week is a return week")
        check(m.currentWeek.map { m.sets(for: a.exercises[0], position: 0, week: $0) } == 1, "return week halves")
        check(m.plannedItems(for: d("2026-09-30")).map(\.kind) == [.rest], "a sick day is rest")

        // All three gym days done → nothing moves
        m = model(at: "2026-10-05")
        for day in ["2026-09-28", "2026-10-01"] { logGym(m, day) }
        m.evaluateAdaptation()
        check(m.plan.timeline.count == 14, "a done week doesn't move the plan")
        m = model(at: "2026-10-05")
        logGym(m, "2026-09-28")
        m.evaluateAdaptation()
        check(m.plan.timeline.count == 14, "one of two climbs missed doesn't repeat the week")
        check(m.store.evaluatedThrough == 0, "week 1 judged")

        // Ask mode
        m = model(at: "2026-10-05")
        m.store.settings.adaptMode = .ask
        m.evaluateAdaptation()
        check(m.store.pending != nil && m.plan.timeline.count == 14, "ask mode proposes, doesn't apply")
        m.acceptPending()
        check(m.plan.timeline.count == 15 && m.store.pending == nil, "accept applies")

        // Holiday weeks never repeat
        m = model(at: "2026-12-28")
        m.store.evaluatedThrough = 11
        m.evaluateAdaptation()
        check(m.plan.timeline.count == 14, "holiday week isn't repeated")

        // Manual controls
        m = model(at: "2026-10-07")
        m.repeatCurrentWeek()
        check(m.plan.timeline.count == 15 && m.plan.timeline[safe: 2]?.template == 2, "manual repeat")
        m = model(at: "2026-10-07")
        m.makeCurrentWeekReturn()
        check(m.currentWeek?.phase == .recovery && m.plan.timeline[safe: 2]?.template == 2, "manual return week")

        // Quests
        m = model(at: "2026-12-10")
        var c = SessionLog(day: "2026-12-09", kind: .climb)
        c.climb = ClimbLog(problems: [Problem(grade: 4, attempts: 3), Problem(grade: 3, attempts: 1),
                                      Problem(grade: 2, tags: ["Flag", "Straight arms"]), Problem(grade: 1, tags: ["Heel hook"])], falls: 5)
        m.upsert(c)
        for id in ["v4", "v3-flash", "flag-bearer", "heel-hook", "skeleton", "first-fall"] {
            check(m.store.badges[id] != nil, "badge \(id)")
        }
        check(m.store.badges["silent-feet"] == nil, "manual badge stays manual")
        m.toggleManualBadge("silent-feet")
        check(m.store.badges["silent-feet"] != nil, "manual badge ticks")
        m.mutate { $0.benchmarks["pullups"] = BenchmarkEntry(start: "2", end: "5") }
        check(m.store.badges["five-up"] != nil && m.store.badges["summit"] != nil, "five up + summit from benchmarks")
        m = model(at: "2026-10-20")
        for i in 0..<14 { m.setDaily(Day.add(i, to: d("2026-10-01"))) { $0.protein = true } }
        check(m.store.badges["protein-fortnight"] != nil, "protein fortnight")

        // Progression readiness
        m = model(at: "2026-10-20")
        for day in ["2026-10-01", "2026-10-08"] {
            var w = SessionLog(day: day, kind: .home, workoutID: "A")
            w.exercises = [ExerciseLog(exerciseID: "lateral-raise", variant: "DB lateral raise", timed: false, low: 12, high: 20,
                                       sets: [SetEntry(value: 20, done: true), SetEntry(value: 20, done: true)])]
            m.upsert(w)
        }
        check(m.readiness("lateral-raise") == .stepUp, "top of range twice → step up")
        check(m.readiness("floor-press") == .new, "unlogged is new")

        // Garmin import
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cairn-selftest-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        let manifest = """
        [{"id":"g1","sport":"bouldering","startTimeLocal":"2026-09-30T07:10:00","durationSec":3600,"avgHr":131.0},
         {"id":"g2","sport":"running","startTimeLocal":"2026-09-30T18:00:00","durationSec":1800},
         {"id":"g3","sport":"walking","startTimeLocal":"2026-10-01T12:00:00","durationSec":2700}]
        """
        try? manifest.data(using: .utf8)!.write(to: tmp.appendingPathComponent("manifest.json"))
        m = model(at: "2026-10-02")
        m.store.settings.garminFolder = tmp.path
        check(m.importGarmin() == 2, "imports climb + walk, skips running")
        check(m.isDone(PlannedItem(kind: .climb), on: d("2026-09-30")), "watch climb ticks the day")
        check(m.session(on: d("2026-09-30"), kind: .climb)?.minutes == 60, "minutes carried")
        check(m.importGarmin() == 0, "import is idempotent")

        // Not connected: an empty folder setting must stay inert, never fall back to the working directory.
        m.store.settings.garminFolder = ""
        check(!m.importAvailable && m.importGarmin() == 0, "no folder, no import")
        m.store.settings.garminFolder = tmp.path
        check(m.importAvailable, "a chosen folder connects the import")

        // Pairing: five wrong codes lock the listener, a right one resets the count, odd profile ids are refused
        var pairing = PairingGuard()
        let t0 = Date()
        for _ in 0..<4 { _ = pairing.check("000000", against: "123456", now: t0) }
        check(pairing.check("123456", against: "123456", now: t0) == .accepted, "a right code after four misses still works")
        for _ in 0..<5 { _ = pairing.check("000000", against: "123456", now: t0) }
        check(pairing.check("123456", against: "123456", now: t0.addingTimeInterval(10)) == .locked(seconds: 50), "five misses lock the listener, even for the right code")
        check(pairing.check("123456", against: "123456", now: t0.addingTimeInterval(61)) == .accepted, "the lock lifts after a minute")
        check(PeerSync.codesMatch("123456", "123456") && !PeerSync.codesMatch("123456", "123457") && !PeerSync.codesMatch("12345", "123456"), "codes compare exactly")
        check(PeerSync.isValidProfileID("main") && PeerSync.isValidProfileID("3fa85f64"), "Cairn's own profile ids pass")
        check(!PeerSync.isValidProfileID("../x") && !PeerSync.isValidProfileID("a/b") && !PeerSync.isValidProfileID("") && !PeerSync.isValidProfileID(String(repeating: "a", count: 33)), "path-like profile ids are refused")

        let oldDay = try? JSONDecoder().decode(DayLog.self, from: Data(#"{"steps":5000,"protein":true}"#.utf8))
        check(oldDay?.steps == 5000 && oldDay?.typed.isEmpty == true, "days saved before sync still decode")

        // Persistence: tolerant decode, and an unreadable file is never overwritten
        let enc = try? JSONEncoder().encode(m.store)
        check(enc.flatMap { try? JSONDecoder().decode(Store.self, from: $0) } != nil, "round-trips")
        let minimal = try? JSONEncoder().encode(["plan": DefaultPlan.make()])
        let partial = minimal.flatMap { try? JSONDecoder().decode(Store.self, from: $0) }
        check(partial != nil && partial?.settings.adaptMode == .automatic, "missing keys decode to defaults")
        setenv("CAIRN_DATA_DIR", tmp.path, 1)
        let garbage = Data("{ not json".utf8)
        try? garbage.write(to: tmp.appendingPathComponent("cairn.json"))
        let loaded = AppModel.load()
        loaded.save()
        check(loaded.loadError != nil, "bad file reports an error")
        check((try? Data(contentsOf: tmp.appendingPathComponent("cairn.json"))) == garbage, "bad file left untouched")
        try? FileManager.default.removeItem(at: tmp.appendingPathComponent("cairn.json"))
        let fresh = AppModel.load()
        check(fresh.loadError == nil && FileManager.default.fileExists(atPath: tmp.appendingPathComponent("cairn.json").path), "fresh store saves")
        unsetenv("CAIRN_DATA_DIR")
        try? FileManager.default.removeItem(at: tmp)

        // Take-backs, resets, profiles — against a scratch data folder
        let pdir = FileManager.default.temporaryDirectory.appendingPathComponent("cairn-profiles-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: pdir, withIntermediateDirectories: true)
        setenv("CAIRN_DATA_DIR", pdir.path, 1)
        let pm = AppModel.load()
        pm.now = { Day.date("2026-10-01")!.addingTimeInterval(9 * 3600) }
        check(pm.profiles.active == "main" && pm.fileURL?.lastPathComponent == "cairn.json", "first profile keeps cairn.json")
        var v4 = SessionLog(day: "2026-09-30", kind: .climb)
        v4.climb = ClimbLog(problems: [Problem(grade: 4)])
        pm.upsert(v4)
        check(pm.store.badges["v4"] != nil, "mistaken V4 plants the flag")
        pm.revokeBadge("v4")
        pm.refreshBadges()
        check(pm.store.badges["v4"] == nil, "taken-back quest stays down though the log remains")
        pm.restoreBadge("v4")
        check(pm.store.badges["v4"] != nil, "restore lets the log plant it again")
        pm.revokeBadge("silent-feet")
        check(!pm.store.revokedBadges.contains("silent-feet"), "manual quests don't need revoking")

        pm.mutate { $0.benchmarks["pullups"] = BenchmarkEntry(start: "3") }
        pm.reset(.logs)
        check(pm.store.sessions.isEmpty && pm.store.benchmarks["pullups"]?.start == "3", "logs reset keeps benchmarks")
        check(pm.lastResetSnapshot.map { FileManager.default.fileExists(atPath: $0.path) } == true, "snapshot written before reset")
        pm.undoLastReset()
        check(pm.store.sessions.count == 1, "undo reset restores the logs")
        pm.reset(.quests)
        check(pm.store.badges.isEmpty || pm.store.badges["v4"] != nil, "quests reset, logs replant")
        pm.reset(.everything)
        check(pm.store.sessions.isEmpty && pm.store.settings.garminFolder == Settings().garminFolder, "everything reset keeps settings")
        pm.undoLastReset()

        let second = pm.createProfile(name: "Sam", start: d("2026-10-05"))
        check(pm.profiles.active == second && pm.store.sessions.isEmpty, "new profile is empty and active")
        check(pm.plan.startDate == "2026-10-05", "new profile starts on its Monday")
        pm.switchProfile("main")
        check(pm.store.sessions.count == 1, "switching back finds the first profile's logs")
        let reloaded = AppModel.load()
        check(reloaded.profiles.profiles.count == 2 && reloaded.profiles.active == "main", "profile list persists")
        pm.removeProfile(second)
        check(pm.profiles.profiles.count == 1, "profile removed from the list")
        let kept = (try? FileManager.default.contentsOfDirectory(atPath: pdir.path))?.contains { $0.contains("removed-") } ?? false
        check(kept, "removed profile's file is kept aside, not deleted")
        pm.removeProfile("main")
        check(pm.profiles.profiles.count == 1, "can't remove the profile in use")
        unsetenv("CAIRN_DATA_DIR")
        try? FileManager.default.removeItem(at: pdir)

        // Merge: Mac and phone editing at the same time
        do {
            let base = model(at: "2026-10-01")
            var old = SessionLog(day: "2026-09-28", kind: .climb)
            old.climb = ClimbLog(problems: [Problem(grade: 1)])
            base.upsert(old)
            let mac = AppModel(store: base.store); mac.now = base.now
            let phone = AppModel(store: base.store); phone.now = base.now
            var climb = SessionLog(day: "2026-09-30", kind: .climb)
            climb.climb = ClimbLog(problems: [Problem(grade: 2)])
            phone.upsert(climb)                                        // phone logs at the gym
            mac.setDaily(d("2026-09-30")) { $0.steps = 8123 }          // Mac takes steps from the mail
            mac.store.sessions.removeAll()                             // Mac deletes the old session
            mac.save()
            phone.revokeBadge("base-camp")                             // phone takes a quest back
            let merged = Merge.merge(local: mac.store, remote: phone.store)
            check(merged.sessions.contains { $0.id == climb.id }, "phone's new session reaches the Mac")
            check(!merged.sessions.contains { $0.id == old.id }, "Mac's delete survives the merge")
            check(merged.daily["2026-09-30"]?.steps == 8123, "Mac's steps survive the merge")
            check(merged.revokedBadges.contains("base-camp"), "phone's quest take-back wins (newer)")
            let back = Merge.merge(local: phone.store, remote: merged)
            check(back.sessions.map(\.id) == merged.sessions.map(\.id) && back.daily == merged.daily, "phone converges on the Mac's result")

            // Same session edited on both: the later edit wins.
            let a1 = AppModel(store: merged), b1 = AppModel(store: merged)
            var e1 = merged.sessions.first { $0.id == climb.id }!
            e1.note = "from mac"; a1.upsert(e1)
            Thread.sleep(forTimeInterval: 0.01)
            e1.note = "from phone"; b1.upsert(e1)
            check(Merge.merge(local: a1.store, remote: b1.store).sessions.first { $0.id == climb.id }?.note == "from phone", "later edit of one session wins")

            // A brand-new phone never overwrites the Mac's plan.
            let freshPhone = AppModel(store: Store(plan: DefaultPlan.make(start: "2026-10-05")))
            mac.mutate { $0.plan.name = "Wall & Bar (Mac)" }
            let first = Merge.merge(local: mac.store, remote: freshPhone.store)
            check(first.plan.name == "Wall & Bar (Mac)" && first.plan.startDate == "2026-09-28", "fresh phone adopts the Mac's plan")
        }

        // The real network path: a server and a client in this process, over Bonjour.
        do {
            let host = model(at: "2026-10-01")
            var s1 = SessionLog(day: "2026-09-28", kind: .climb)
            s1.climb = ClimbLog(problems: [Problem(grade: 3)])
            host.upsert(s1)
            let savedCode = PeerSync.pairingCode, savedHost = PeerSync.hostCode
            PeerSync.pairingCode = "424242"
            PeerSync.hostCode = "424242"
            // Cairn may be open on this Mac too: aim the client at the test server.
            let testMac = "Selftest-\(UUID().uuidString.prefix(4))"
            let savedPreferred = PeerClient.preferredMac
            PeerClient.preferredMac = testMac
            defer { PeerClient.preferredMac = savedPreferred }
            let server = PeerServer { req in host.answerPeer(req, macName: testMac) }
            server.start(name: "Cairn on \(testMac)")
            let client = model(at: "2026-10-01")
            var s2 = SessionLog(day: "2026-09-30", kind: .home, workoutID: "B")
            s2.minimum = true
            client.upsert(s2)
            var finished = false
            Task { @MainActor in
                await client.syncWithMac(device: "selftest")
                finished = true
            }
            let deadline = Date().addingTimeInterval(20)
            while !finished && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            check(finished && client.lastPeer?.ok == true, "phone syncs with the Mac over the network (\(client.lastPeer?.detail ?? "no result"))")
            check(client.store.sessions.contains { $0.id == s1.id } && host.store.sessions.contains { $0.id == s2.id }, "both sides end up with both sessions")
            PeerSync.pairingCode = "000000"
            finished = false
            Task { @MainActor in await client.syncWithMac(device: "selftest"); finished = true }
            let d2 = Date().addingTimeInterval(20)
            while !finished && Date() < d2 { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
            check(client.lastPeer?.ok == false, "a wrong pairing code is refused")
            server.stop()
            PeerSync.pairingCode = savedCode
            PeerSync.hostCode = savedHost
        }

        // A phone must not be able to choose what the Mac runs or reads: a profile it creates arrives with per-machine settings stripped.
        do {
            let host = model(at: "2026-10-01")
            var evil = Store(plan: DefaultPlan.make())
            evil.settings.claudePath = "/tmp/not-claude"
            evil.settings.garminFolder = "/tmp/elsewhere"
            evil.settings.gymName = "Kept"
            let id = "feedbeef"
            let url = ProfileIndex.file(for: id, in: AppModel.dataDirectory())
            try? FileManager.default.removeItem(at: url)
            let savedHost = PeerSync.hostCode
            PeerSync.hostCode = "424242"
            let request = PeerRequest(key: "424242", profileID: id, profileName: "Guest", device: "selftest", store: evil)
            let reply = MainActor.assumeIsolated { host.answerPeer(request, macName: "selftest") }
            let written = (try? Data(contentsOf: url)).flatMap { try? JSONDecoder().decode(Store.self, from: $0) }
            check(reply.ok && written != nil, "a new profile from a paired phone is created")
            check(written?.settings.claudePath == "" && written?.settings.garminFolder == "", "its claude path and watch folder are stripped")
            check(written?.settings.gymName == "Kept", "ordinary settings still arrive")
            check(reply.store?.settings.claudePath == "", "and the reply does not echo them back")
            try? FileManager.default.removeItem(at: url)
            PeerSync.hostCode = savedHost

            // A relative claude path must never resolve against the working directory.
            let fm = FileManager.default
            let cwd = fm.currentDirectoryPath
            let scratch = fm.temporaryDirectory.appendingPathComponent("cairn-cwd-\(UUID().uuidString)")
            try? fm.createDirectory(at: scratch, withIntermediateDirectories: true)
            let planted = scratch.appendingPathComponent("planted-claude")
            try? "#!/bin/sh\n".write(to: planted, atomically: true, encoding: .utf8)
            try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: planted.path)
            fm.changeCurrentDirectoryPath(scratch.path)
            let found = CoachRunner.locate("planted-claude")
            fm.changeCurrentDirectoryPath(cwd)
            try? fm.removeItem(at: scratch)
            check(found != "planted-claude" && found != planted.path, "a relative claude path is not picked up from the working directory")

            // A paired phone can't create profiles without limit, nor pile up merge backups.
            let many = model(at: "2026-10-01")
            PeerSync.hostCode = "424242"
            var refused = 0
            for i in 0..<(PeerSync.maxProfiles + 3) {
                let pid = String(format: "cafe%04d", i)
                let r = MainActor.assumeIsolated { many.answerPeer(PeerRequest(key: "424242", profileID: pid, profileName: "P\(i)", device: "selftest", store: evil), macName: "selftest") }
                if !r.ok { refused += 1 }
            }
            check(many.profiles.profiles.count == PeerSync.maxProfiles && refused >= 3, "profiles created by a phone are capped (\(many.profiles.profiles.count), refused \(refused))")
            let pid0 = "cafe0001"
            for round in 0..<3 {
                for k in 0..<4 { try? "x".write(to: ProfileIndex.file(for: pid0, in: AppModel.dataDirectory()).deletingPathExtension().appendingPathExtension("before-peer-\(1000 + round * 10 + k).json"), atomically: true, encoding: .utf8) }
                _ = MainActor.assumeIsolated { many.answerPeer(PeerRequest(key: "424242", profileID: pid0, profileName: "P1", device: "selftest", store: evil), macName: "selftest") }
            }
            let kept = ((try? fm.contentsOfDirectory(atPath: AppModel.dataDirectory().path)) ?? []).filter { $0.hasPrefix("cairn-\(pid0).before-peer-") }.count
            check(kept <= PeerSync.peerBackupsKept, "peer merge backups are pruned (\(kept) kept)")
            for i in 0..<(PeerSync.maxProfiles + 3) { try? fm.removeItem(at: ProfileIndex.file(for: String(format: "cafe%04d", i), in: AppModel.dataDirectory())) }
            for n in ((try? fm.contentsOfDirectory(atPath: AppModel.dataDirectory().path)) ?? []) where n.contains(".before-peer-") { try? fm.removeItem(at: AppModel.dataDirectory().appendingPathComponent(n)) }
            try? fm.removeItem(at: ProfileIndex.file(for: id, in: AppModel.dataDirectory()))
        }

        // Colour circuits: the gym's grades, translated both ways
        do {
            let g = model(at: "2026-10-01")
            check(g.grades("Repeats V0–V2") == "Repeats V0–V2", "V scale: text unchanged")
            g.mutate { $0.settings.useCircuits = true; $0.settings.circuits = GradeCircuit.starter }
            check(g.grades("Repeats V0–V2") == "Repeats green", "V0–V2 reads as green")
            check(g.grades("V4 once V3s go in") == "blue once greens or blues go in" || g.grades("V4 once V3s go in").hasPrefix("blue"), "V4 reads as blue")
            check(g.grades("Max 2 V3 per session") == "Max 2 blue per session", "a single V3 reads as the colour that starts there")
            check(g.grades("Repeats V0–V3") == "Repeats green or blue", "a range spanning two colours names both")
            check(g.grades("V9 dreams") == "V9 dreams", "grades outside every colour stay V")
            let blue = g.gradeOptions.last!
            var c = SessionLog(day: "2026-09-30", kind: .climb)
            c.climb = ClimbLog(problems: [Problem(grade: blue.v, attempts: 1, circuit: blue.circuit), Problem(grade: 0, circuit: g.gradeOptions[0].circuit)])
            g.upsert(c)
            check(g.hardestName(c.climb!.problems) == "Blue", "hardest send by colour")
            check(g.store.badges["v3-flash"] != nil, "a blue (V3–V4) flash counts as a V3 flash")
            check(g.store.badges["v4"] == nil, "a blue send doesn't count as a V4 (its easiest grade is V3)")
            check(g.rank(Problem(grade: 2)) == 0, "an old V2 log sits on green")
        }

        // Font grades: conversion both ways, colours in Font, logging in Font
        do {
            check(GradeScale.fontName(GradeScale.font(v: 3)) == "6A", "V3 is 6A at its easiest")
            check(GradeScale.fontName(GradeScale.fontTop(v: 3)) == "6A+", "and 6A+ at its hardest")
            check(GradeScale.v(font: GradeScale.fontNames.firstIndex(of: "5+")!) == 2, "5+ is V2")
            check(GradeScale.v(font: GradeScale.fontNames.firstIndex(of: "7A")!) == 6, "7A is V6")
            let g = model(at: "2026-10-01")
            g.mutate { $0.settings.gradeScale = .font }
            check(g.grades("Repeats V0–V2") == "Repeats 4–5+", "plan text converts to Font")
            check(g.grades("Max 2 V3 per session") == "Max 2 6A per session", "a single V grade converts to its easiest Font")
            check(g.gradeOptions.first?.label == "4" && g.gradeOptions.contains { $0.label == "6A+" }, "the logger offers Font grades")
            let sixAPlus = g.gradeOptions.first { $0.label == "6A+" }!
            check(sixAPlus.v == 3 && sixAPlus.problem().sent == false, "a new 6A+ problem is V3 and not assumed sent")
            var p = sixAPlus.problem(); p.sent = true
            check(g.gradeName(p) == "6A+" && g.rankLabel(g.rank(p)) == "6A+", "a Font-logged problem keeps its exact grade")
            check(g.gradeName(Problem(grade: 4)) == "6B", "an old V4 log reads as 6B")
            var green = GradeCircuit(name: "Green", hex: 0, low: 0, high: 0)
            green.setFont(low: GradeScale.fontNames.firstIndex(of: "4")!, high: GradeScale.fontNames.firstIndex(of: "5+")!)
            check(green.low == 0 && green.high == 2 && green.range(in: .font) == "4–5+" && green.range(in: .v) == "V0–V2", "a colour set in Font converts to V")
            g.mutate { $0.settings.useCircuits = true; $0.settings.circuits = [green] }
            check(g.gradeOptions.first?.detail == "4–5+", "colour ranges read in Font")
            check(g.grades("Repeats V0–V2") == "Repeats green", "and the plan still speaks in colours")
            let old = GradeCircuit.starter[0]
            check(old.range(in: .font) == "4–6A+", "a colour set in V shows its Font range")
        }

        // Finish, skip, and old logs
        do {
            let f = model(at: "2026-09-28")
            let climb = PlannedItem(kind: .climb)
            var log = f.draft(for: climb, on: d("2026-09-28"))
            log.climb?.problems.append(Problem(grade: 1, attempts: 2, sent: true))
            f.upsert(log)
            check(!f.isDone(climb, on: d("2026-09-28")), "a climb in progress doesn't count yet")
            check(f.score(week: 0).total == 0, "and earns no points yet")
            check(f.inProgress(f.session(on: d("2026-09-28"), kind: .climb)!), "it reads as in progress")
            f.finish(f.session(on: d("2026-09-28"), kind: .climb)!)
            check(f.isDone(climb, on: d("2026-09-28")), "Finish makes it count")
            check(f.score(week: 0).gym == f.plan.points.gymSession, "and it scores")
            f.reopen(f.session(on: d("2026-09-28"), kind: .climb)!)
            check(!f.isDone(climb, on: d("2026-09-28")), "reopening takes it back out")
            f.now = { Day.date("2026-09-29")!.addingTimeInterval(9 * 3600) }
            check(f.isDone(climb, on: d("2026-09-28")), "an unfinished log counts once the day is over")

            let tue = (1...6).map { Day.add($0, to: d("2026-09-28")) }.first { day in f.plannedItems(for: day).contains { $0.countsAsGym } }!
            let gym = f.plannedItems(for: tue).first { $0.countsAsGym }!
            f.skip(gym, on: tue, reason: .tired, note: "slept badly")
            check(f.skipped(gym, on: tue) == .tired && !f.isDone(gym, on: tue) && !f.gymDone(on: tue), "a skip is recorded and doesn't count")
            check(f.session(on: tue, kind: gym.kind, workoutID: gym.workoutID)?.note == "slept badly", "the skip keeps its note")
            f.unskip(gym, on: tue)
            check(f.skipped(gym, on: tue) == nil, "undo skip")
            f.skip(gym, on: tue, reason: .sick)
            check(f.daily(tue).sick, "skipping sick marks the day sick")
            f.unskip(gym, on: tue)
            check(!f.daily(tue).sick, "and undoing it clears that")

            let legacy = #"{"id":"6E1D3A3B-6B0C-4C1F-9A55-1B0C6D3E2A10","day":"2026-09-28","kind":"climb","exercises":[],"pain":[],"note":"","minimum":false,"source":"manual","climb":{"problems":[{"id":"7E1D3A3B-6B0C-4C1F-9A55-1B0C6D3E2A10","grade":2,"attempts":1,"sent":true,"tags":[]}],"falls":0,"drillBoring":false,"wallNote":""}}"#
            let old = try? JSONDecoder().decode(SessionLog.self, from: Data(legacy.utf8))
            check(old?.isFinished == true && old?.skip == nil && old?.climb?.problems.first?.font == nil, "logs from before Finish still count and decode")
        }

        // Drills you move through, and skills
        do {
            let r = model(at: "2026-09-30")
            check(r.drill(for: r.today)?.id == "falling", "week 1 drill is falling")
            r.clearDrill("falling")
            check(r.drillMastered("falling") && r.drill(for: r.today)?.id == "silent-feet", "clearing moves to the next drill today")
            check(r.drill(for: d("2026-09-29"))?.id == "falling", "days before the switch keep the old drill")
            r.clearDrill("silent-feet")
            check(r.drill(for: r.today)?.id == "straight-arms", "and on")
            r.chooseDrill("heel-hook")
            check(r.drill(for: d("2026-10-20"))?.id == "heel-hook", "a picked drill holds in later weeks")
            r.followPlanDrill()
            check(r.drill(for: d("2026-10-20"))?.id == Library.drill(r.blockWeek(for: d("2026-10-20"))!.template.drillID)?.id, "back to the plan's drill")
            check(r.nextDrill(after: "slab")?.id == "straight-arms", "next wraps round past cleared drills")
            check(Library.drillOrder.allSatisfy { Library.drill($0) != nil }, "every drill in the order exists")

            check(Library.skills.count == Set(Library.skills.map(\.id)).count, "skill ids unique")
            check(Library.skills.allSatisfy { $0.start < $0.steps.count && $0.steps.count >= 3 }, "skills have steps and start inside them")
            check(Library.topSkills.count == 10 && Library.topSkills.map(\.rank) == Array(1...10) && Library.topSkills.allSatisfy { !$0.isLocked }, "ten skills to learn first, in order")
            check(Library.laterSkills.allSatisfy { $0.isLocked }, "the rest are locked")
            check(Library.skills.flatMap(\.requires).allSatisfy { req in
                if case .step(let id, let n) = req { return (Library.skill(id)?.steps.count ?? 0) > n } else { return true }
            }, "every lock points at a real step")
            check(r.skillStep("pullup") == 0, "vertical pull starts at the first band pulldown")
            r.clearSkillStep("pullup")
            check(r.skillStep("pullup") == 1 && r.store.skillsCleared["pullup@0"] != nil, "clearing a step moves up")
            r.setSkillStep("pullup", 0)
            check(r.skillStep("pullup") == 0 && r.store.skillsCleared["pullup@0"] == nil, "stepping back reopens the steps above")
            let hollow = Library.skill("hollow")!
            for _ in hollow.steps { r.clearSkillStep("hollow") }
            check(r.skillComplete("hollow"), "clearing the last step completes the skill")
            check(r.store.badges["hollow-man"] != nil, "a 60 s hollow hold from the ladder earns the quest")
            let flag = Library.skill("dragon")!
            check(!r.skillUnlocked(flag), "the dragon flag starts locked")
            r.toggleFocus("dragon")
            check(r.focusSkills.isEmpty, "a locked skill can't be picked")
            for _ in 0...3 { r.clearSkillStep("legraise") }
            check(r.skillUnlocked(flag), "a clean slow leg raise and a 30 s hollow hold open it")
            r.toggleFocus("dragon")
            check(r.focusSkills.map(\.id) == ["dragon"], "focus a skill")
            check(!r.skillUnlocked(Library.skill("nordic")!) && model(at: "2026-11-09").skillUnlocked(Library.skill("nordic")!), "the Nordic curl opens in the Build phase")
            let five = model(at: "2026-10-20")
            for _ in Library.skill("pullup")!.steps { five.clearSkillStep("pullup") }
            check(five.store.badges["five-up"] == nil, "band pulldowns don't earn Five Up; only real pull-ups do")

            // Home: every step of every skill has a guide, nothing needs a bar, and its photos ship.
            let all = Library.skills.flatMap { sk in sk.steps.map { (sk.id, $0.name) } }
            check(all.allSatisfy { Library.guide($0.0, $0.1) != nil }, "every skill step has a home guide")
            check(Library.stepGuides.keys.allSatisfy { k in all.contains { "\($0.0)|\($0.1)" == k } }, "every guide belongs to a real step")
            check(Library.stepGuides.values.allSatisfy { !$0.kit.isEmpty && !$0.setup.isEmpty && $0.how.count >= 3 && !$0.mistakes.isEmpty }, "guides have kit, set-up, steps and mistakes")
            check(Library.stepGuides.values.allSatisfy { g in !["pull-up bar", "dip bar", "rings", "parallette", "dumbbell"].contains { g.kit.lowercased().contains($0) } }, "no guide needs gym kit")
            if Photos.available {
                check(Library.stepGuides.values.flatMap(\.photos).allSatisfy { !Photos.frames($0).isEmpty }, "every guide photo ships with the app")
            }

            // Old ladders: the changed skills start over, the rest keep their place, bar-only skills drop out of focus.
            let old = model(at: "2026-10-20")
            old.mutate { s in
                s.skillLadder = 1; s.skills = ["pullup": 3, "lsit": 2]
                s.skillsCleared = ["pullup@2": "2026-10-10", "lsit@0": "2026-10-11", "lsit@1": "2026-10-12"]
                s.skillFocus = ["frontlever", "lsit"]
            }
            check(old.migrateSkills() && !old.migrateSkills(), "the ladder migration runs once")
            check(old.store.skills["pullup"] == nil && old.store.skillsCleared["pullup@2"] == nil, "changed skills start over")
            check(old.store.skills["lsit"] == 2 && old.store.skillsCleared.count == 2 && old.store.skillFocus == ["lsit"], "other skills keep their place")

            // Bands: logged loads snap to the new rungs, once; gym versions are added only where missing.
            let bm = model(at: "2026-10-20")
            var bs = SessionLog(day: "2026-10-13", kind: .home)
            bs.exercises = [ExerciseLog(exerciseID: "band-lat-pulldown", variant: "x", timed: false, low: 10, high: 15, sets: [SetEntry(value: 10, kg: 53.7, done: true)]),
                            ExerciseLog(exerciseID: "goblet-squat", variant: "x", timed: false, low: 8, high: 15, sets: [SetEntry(value: 10, kg: 20, done: true)])]
            bm.store.sessions = [bs]
            bm.store.loadSet["band-lat-pulldown"] = LoadSet(kg: 53.7, since: "2026-10-13", why: "x")
            bm.store.bandLadder = 1
            check(bm.migrateBands() && !bm.migrateBands(), "the band migration runs once")
            check(bm.store.sessions[0].exercises[0].sets[0].kg == 54 && bm.store.loadSet["band-lat-pulldown"]?.kg == 54, "a band load snaps to the nearest rung (13.5 + 18 + 22.5)")
            check(bm.store.sessions[0].exercises[1].sets[0].kg == 20, "dumbbell loads are left alone")
            bm.store.plan.workouts[0].gymExercises = nil
            bm.store.plan.workouts[3].gymExercises = nil
            check(bm.addGymVersions() && !bm.addGymVersions() && bm.plan.workouts[0].gymExercises?.isEmpty == false && bm.plan.workouts[3].gymExercises?.isEmpty == false, "Push and Aesthetic get their gym versions back, once")

            // All of it travels between devices
            let other = AppModel(store: r.store)
            other.mutate { $0.settings.gradeScale = .font; $0.skills["lsit"] = 2; $0.drillChoice = DrillChoice(id: "slab", since: "2026-09-30") }
            let merged = Merge.merge(local: r.store, remote: other.store)
            check(merged.settings.gradeScale == .font && merged.skills["lsit"] == 2 && merged.drillChoice?.id == "slab", "scale, skills and drill choice sync")
        }

        runOverloadTests()
        runScheduleTests()
        runCoachTests()

        // Icon renders
        check((Icon.render(px: 64)?.count ?? 0) > 500, "icon renders")

        print("selftest: \(passed) passed, \(failed) failed")
        return failed == 0
    }
}

#endif
