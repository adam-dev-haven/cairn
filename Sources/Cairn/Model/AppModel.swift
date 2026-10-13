import Foundation
import Observation

/// Everything the app knows, plus the rules that turn logs into a climb:
/// schedule, adaptation, points, streaks, quests and progression.
@Observable
final class AppModel {
    var store: Store
    /// Set when the saved file exists but could not be read. Cairn then runs
    /// read-only rather than overwrite the user's history with an empty one.
    var loadError: String?
    /// Injectable clock, so the self-test can walk through the block.
    var now: () -> Date = { Date() }
    /// Toast-style message after something happened on its own (Garmin import).
    var notice: String?
    /// The last activity import, and whether one is running now.
    var lastSync: SyncReport?
    var syncing = false
    /// The last Mac ↔ iPhone sync over Wi-Fi, and whether one is running now.
    var lastPeer: PeerReport?
    var peerSyncing = false
    /// Mac side: counts wrong pairing codes and locks the listener briefly.
    var pairingGuard = PairingGuard()
    /// What the coach is doing right now ("Claude is reading the week…"), and the last thing that went wrong.
    var coachBusy: String?
    var coachProblem: String?

    private(set) var fileURL: URL?
    /// The store as last written, so `save()` can stamp what changed.
    private var lastSaved: Store?
    /// Snapshot taken just before the last reset, for "Undo reset".
    var lastResetSnapshot: URL?
    var profiles = ProfileIndex()

    init(store: Store, fileURL: URL? = nil) {
        self.store = store
        self.fileURL = fileURL
        self.lastSaved = store
    }

    // MARK: Persistence

    static func dataDirectory() -> URL {
        if let custom = ProcessInfo.processInfo.environment["CAIRN_DATA_DIR"] {
            return URL(fileURLWithPath: custom)
        }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cairn", isDirectory: true)
    }

    static func load() -> AppModel {
        let model = loadStore()
        // Review hooks: pin the clock, or seed synthetic logs into an empty store.
        if let pinned = ProcessInfo.processInfo.environment["CAIRN_NOW"], let d = Day.date(pinned) {
            model.now = { d.addingTimeInterval(10 * 3600) }
        }
        if ProcessInfo.processInfo.environment["CAIRN_DEMO"] != nil, model.store.sessions.isEmpty {
            Demo.seed(model)
        }
        return model
    }

    private static func loadStore() -> AppModel {
        let dir = dataDirectory()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let index = ProfileIndex.load(from: dir)
        let model = AppModel(store: Store(plan: DefaultPlan.make()), fileURL: nil)
        model.profiles = index
        model.open(profile: index.active)
        return model
    }

    /// Point the model at one profile's file: read it, or create it fresh.
    /// A file that exists but can't be read is never written over.
    func open(profile id: String) {
        let dir = Self.dataDirectory()
        let url = ProfileIndex.file(for: id, in: dir)
        loadError = nil
        lastSync = nil
        guard FileManager.default.fileExists(atPath: url.path) else {
            // A fresh store carries no stamps, so on a first sync it never
            // outranks the other device's real data.
            store = Store(plan: DefaultPlan.make(start: Day.key(Day.monday(of: Day.add(6, to: now())))))
            fileURL = url
            lastSaved = store
            save()
            return
        }
        do {
            store = try JSONDecoder().decode(Store.self, from: Data(contentsOf: url))
            fileURL = url
            lastSaved = store
            let planned = migratePlan()
            let laddered = migrateSkills()
            let banded = migrateBands()
            let geared = addGymVersions()
            if planned || laddered || banded || geared { save() }
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            try? FileManager.default.copyItem(at: url, to: url.deletingPathExtension().appendingPathExtension("unreadable-\(stamp).json"))
            store = Store(plan: DefaultPlan.make())
            fileURL = nil
            loadError = "Cairn couldn't read this profile's saved data (\(error.localizedDescription)). Nothing was changed on disk; a copy is in the data folder. This session won't save."
        }
    }

    func save() {
        guard loadError == nil else { return }
        if let old = lastSaved { Merge.stamp(from: old, to: &store, at: Date()) }
        lastSaved = store
        guard let fileURL else { return }
        let fm = FileManager.default
        // One rolling backup per day, taken before the first write of the day.
        let prefix = fileURL.deletingPathExtension().lastPathComponent
        let backup = fileURL.deletingLastPathComponent().appendingPathComponent("\(prefix).backup-\(Day.key(Date())).json")
        if fm.fileExists(atPath: fileURL.path), !fm.fileExists(atPath: backup.path) {
            try? fm.copyItem(at: fileURL, to: backup)
            pruneBackups(in: fileURL.deletingLastPathComponent(), prefix: prefix)
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(store) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    private func pruneBackups(in dir: URL, prefix: String) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        let backups = files.filter { $0.hasPrefix("\(prefix).backup-") }.sorted()
        for name in backups.dropLast(14) {
            try? FileManager.default.removeItem(at: dir.appendingPathComponent(name))
        }
    }

    /// Take in another device's copy. Its stamps travel with it, so nothing
    /// adopted here is re-stamped as a new local edit.
    func absorb(_ remote: Store) {
        store = Merge.merge(local: store, remote: remote)
        lastSaved = store
        refreshBadges()
        save()
        evaluateAdaptation()
    }

    func mutate(_ change: (inout Store) -> Void) {
        change(&store)
        refreshBadges()
        save()
    }

    // MARK: Calendar of the block

    var plan: Plan { store.plan }
    var startDate: Date { Day.date(plan.startDate) ?? Day.monday(of: now()) }
    var today: Date { Day.start(now()) }

    /// Calendar index into the timeline (can be negative before the block, or
    /// past the end after it).
    func calendarIndex(for date: Date) -> Int {
        let d = Day.between(startDate, date)
        return d >= 0 ? d / 7 : -((-d + 6) / 7)
    }

    func weekStart(_ index: Int) -> Date { Day.add(index * 7, to: startDate) }
    var endDate: Date { Day.add(plan.timeline.count * 7 - 1, to: startDate) }
    var summitDate: Date { weekStart(max(0, plan.timeline.count - 1)) }

    func template(_ number: Int) -> WeekTemplate {
        plan.weeks.first { $0.id == number } ?? plan.weeks.last!
    }

    struct BlockWeek: Hashable {
        let index: Int
        let entry: TimelineEntry
        let template: WeekTemplate
        var phase: Phase { entry.reason == .recovery ? .recovery : template.phase }
        var number: Int { template.id }
    }

    func blockWeek(at index: Int) -> BlockWeek? {
        guard index >= 0, index < plan.timeline.count else { return nil }
        let e = plan.timeline[index]
        return BlockWeek(index: index, entry: e, template: template(e.template))
    }

    func blockWeek(for date: Date) -> BlockWeek? { blockWeek(at: calendarIndex(for: date)) }
    var currentWeek: BlockWeek? { blockWeek(for: today) }
    var beforeStart: Bool { calendarIndex(for: today) < 0 }
    var finished: Bool { calendarIndex(for: today) >= plan.timeline.count }

    func workout(_ id: String?) -> Workout? {
        guard let id else { return nil }
        return plan.workouts.first { $0.id == id }
    }

    /// What's planned for a date after phase rules, sickness and any changes
    /// you made to that day (sessions moved in, or taken off).
    func plannedItems(for date: Date) -> [PlannedItem] {
        guard let week = blockWeek(for: date) else { return [] }
        if daily(date).sick { return [PlannedItem(kind: .rest)] }
        let change = store.dayChanges[Day.key(date)]
        var base = plan.days[Day.weekday(date) - 1].items
        if let c = change, !c.hidden.isEmpty { base.removeAll { c.hidden.contains($0.id) } }
        var out = base
        if week.phase == .holiday {
            out = []
            for item in base {
                switch item.kind {
                case .climb: out.append(PlannedItem(kind: .home, workoutID: "H", optional: item.optional))
                case .workout: out.append(PlannedItem(kind: .walk))
                default: out.append(item)
                }
            }
            var seen = Set<String>()
            out = out.filter { seen.insert("\($0.kind.rawValue)\($0.workoutID ?? "")").inserted }
        }
        if let c = change {
            for a in c.added where !out.contains(where: { $0.kind == a.kind && $0.workoutID == a.workoutID && a.kind != .climb }) {
                if a.kind == .climb && out.contains(where: { $0.kind == .climb }) { continue }
                out.append(a)
            }
        }
        // Everything taken off and nothing brought in: a rest day.
        if out.isEmpty && change != nil { return [PlannedItem(kind: .rest)] }
        return out
    }

    func pattern(for date: Date) -> DayPattern { plan.days[Day.weekday(date) - 1] }

    /// Sets for one planned exercise in a given week, per the plan doc:
    /// 2 in weeks 1–2, 3 from week 3, up to 4 on the first two exercises in
    /// Push weeks, half in deload-shaped weeks.
    func sets(for ex: PlannedExercise, position: Int, week: BlockWeek) -> Int {
        let scheme = ex.scheme(forWeek: week.number)
        var n: Int
        if let fixed = scheme.sets {
            n = fixed
        } else {
            n = week.number <= 2 ? 2 : 3
            if week.phase == .push && position < 2 { n = 4 }
        }
        if week.phase.halvesSets { n = max(1, Int((Double(n) / 2).rounded(.up))) }
        return n
    }

    // MARK: Logs

    func daily(_ date: Date) -> DayLog { store.daily[Day.key(date)] ?? DayLog() }

    func setDaily(_ date: Date, _ change: (inout DayLog) -> Void) {
        mutate { s in
            var d = s.daily[Day.key(date)] ?? DayLog()
            change(&d)
            s.daily[Day.key(date)] = d
        }
    }

    func sessions(on date: Date) -> [SessionLog] {
        let k = Day.key(date)
        return store.sessions.filter { $0.day == k }
    }

    func session(on date: Date, kind: ItemKind, workoutID: String? = nil) -> SessionLog? {
        sessions(on: date).first { $0.kind == kind && (workoutID == nil || $0.workoutID == workoutID) }
    }

    func upsert(_ log: SessionLog) {
        mutate { s in
            if let i = s.sessions.firstIndex(where: { $0.id == log.id }) {
                s.sessions[i] = log
            } else {
                s.sessions.append(log)
            }
        }
    }

    /// One-tap logging from a card: the minimum for a climb (warm-up and
    /// ladder, which counts as a full session), everything as planned for a
    /// workout, done for a walk.
    func quickLog(_ item: PlannedItem, on date: Date) {
        var log = draft(for: item, on: date)
        log.finished = true
        log.skip = nil
        switch item.kind {
        case .climb:
            log.minimum = true
        case .workout, .home, .prehab:
            for i in log.exercises.indices { for k in log.exercises[i].sets.indices { log.exercises[i].sets[k].done = true } }
        case .walk:
            break
        default:
            return
        }
        upsert(log)
    }

    static func quickLabel(_ kind: ItemKind) -> String? {
        switch kind {
        case .climb: "Did the minimum"
        case .workout, .home: "Done as planned"
        case .prehab, .walk: "Done"
        default: nil
        }
    }

    func session(id: UUID) -> SessionLog? { store.sessions.first { $0.id == id } }

    /// Change one saved session in place. Editors in the bottom bubble use
    /// this, so they read and write the same data the screen shows.
    func editSession(_ id: UUID, _ change: (inout SessionLog) -> Void) {
        mutate { s in
            if let i = s.sessions.firstIndex(where: { $0.id == id }) { change(&s.sessions[i]) }
        }
    }

    func delete(_ log: SessionLog) {
        mutate { s in s.sessions.removeAll { $0.id == log.id } }
    }

    /// A fresh log for a planned item, prefilled from the plan and from what
    /// was lifted last time.
    func draft(for item: PlannedItem, on date: Date) -> SessionLog {
        if let existing = session(on: date, kind: item.kind, workoutID: item.workoutID) { return existing }
        var log = SessionLog(day: Day.key(date), kind: item.kind, workoutID: item.workoutID)
        switch item.kind {
        case .climb:
            log.climb = ClimbLog()
        case .workout, .home, .prehab:
            let wid = item.workoutID ?? (item.kind == .prehab ? "P" : item.kind == .home ? "H" : nil)
            log.workoutID = wid
            if let w = workout(wid) {
                log.exercises = exercises(for: w, on: date, atGym: false)
            }
        default:
            break
        }
        return log
    }

    /// The exercises of one strength session on a date, prefilled from the
    /// plan and from what you did last time by the progressive-overload
    /// rules (see Overload.swift): up a step when the top of the range landed
    /// at one weight, the same weight and a higher rep target when it didn't,
    /// lighter after two rough sessions. On bands the load is a band
    /// combination and moves a rung at a time.
    func exercises(for w: Workout, on date: Date, atGym: Bool) -> [ExerciseLog] {
        guard let week = blockWeek(for: date) ?? blockWeek(at: 0) else { return [] }
        let list = atGym ? (w.gymExercises ?? w.exercises) : w.exercises
        return list.enumerated().map { i, pe in
            let scheme = pe.scheme(forWeek: week.number)
            let n = sets(for: pe, position: i, week: week)
            let rx = prescription(pe.exerciseID, variant: scheme.variant, low: scheme.low, high: scheme.high,
                                  timed: scheme.timed, setCount: n, before: date)
            let sets = (0..<n).map { k in SetEntry(value: rx.reps(k), kg: rx.targets[min(k, rx.targets.count - 1)].kg, done: false) }
            return ExerciseLog(exerciseID: pe.exerciseID, variant: scheme.variant, timed: scheme.timed,
                               low: scheme.low, high: scheme.high, sets: sets)
        }
    }

    /// Switch a strength session between its home (bands) and gym versions.
    /// Sets you've already ticked are kept as they are; the switch only
    /// rebuilds the list while nothing has been done.
    func setPlace(_ log: SessionLog, atGym: Bool) -> SessionLog {
        var l = log
        l.atGym = atGym
        if !l.exercises.contains(where: { !$0.doneSets.isEmpty }), let w = workout(l.workoutID) {
            l.exercises = exercises(for: w, on: l.date, atGym: atGym)
        }
        return l
    }

    func lastLog(of exerciseID: String, variant: String? = nil, before date: Date) -> ExerciseLog? {
        let k = Day.key(date)
        return store.sessions
            .filter { $0.day < k }
            .sorted { $0.day > $1.day }
            .lazy
            .compactMap { s in s.exercises.first { $0.exerciseID == exerciseID && (variant == nil || $0.variant == variant) && !$0.doneSets.isEmpty } }
            .first
    }

    func history(of exerciseID: String) -> [(date: Date, log: ExerciseLog)] {
        store.sessions
            .sorted { $0.day < $1.day }
            .flatMap { s in s.exercises.filter { $0.exerciseID == exerciseID && !$0.doneSets.isEmpty }.map { (s.date, $0) } }
    }

    // MARK: Finish and skip

    /// Press Finish: the session counts from now on.
    func finish(_ log: SessionLog) {
        var l = log
        l.finished = true
        l.skip = nil
        upsert(l)
    }

    /// Back to logging. It stops counting until finished again, unless the day is over.
    func reopen(_ log: SessionLog) {
        var l = log
        l.finished = false
        upsert(l)
    }

    /// "Didn't happen, and here's why." Sick also marks the day sick, which
    /// turns it into rest and feeds the return-week rule.
    func skip(_ item: PlannedItem, on date: Date, reason: SkipReason, note: String = "") {
        var log = draft(for: item, on: date)
        log.skip = reason
        log.finished = false
        log.minimum = false
        if !note.isEmpty { log.note = note }
        upsert(log)
        if reason == .sick { setDaily(date) { $0.sick = true } }
        runScheduleRules()
    }

    func unskip(_ item: PlannedItem, on date: Date) {
        guard let log = session(on: date, kind: item.kind, workoutID: item.workoutID), log.skip != nil else { return }
        if log.skip == .sick && daily(date).sick { setDaily(date) { $0.sick = false } }
        delete(log)
    }

    func skipped(_ item: PlannedItem, on date: Date) -> SkipReason? {
        session(on: date, kind: item.kind, workoutID: item.workoutID)?.skip
    }

    // MARK: Completion

    func isDone(_ item: PlannedItem, on date: Date) -> Bool {
        switch item.kind {
        case .rest: return true
        case .walk:
            if let w = session(on: date, kind: .walk) { return hasContent(w) }
            if let steps = daily(date).steps, let w = blockWeek(for: date) { return steps >= w.template.stepFloor }
            return false
        case .check:
            let d = daily(date)
            return d.weightKg != nil || d.waistCm != nil
        case .workout:
            return session(on: date, kind: .workout, workoutID: item.workoutID).map(hasContent) ?? false
        default:
            return session(on: date, kind: item.kind).map(hasContent) ?? false
        }
    }

    /// Does this log count as a session done? A skip never does. A watch
    /// import or the doorway rule always does. Anything you logged by hand
    /// counts once you press Finish — or once the day is over, so a
    /// forgotten Finish doesn't cost the points.
    func hasContent(_ s: SessionLog) -> Bool {
        if s.skip != nil { return false }
        if s.minimum || s.source == .garmin || s.kind == .walk { return true }
        let logged = !(s.climb?.problems.isEmpty ?? true) || s.exercises.contains { !$0.doneSets.isEmpty } || !(s.skills ?? []).isEmpty
        guard logged else { return false }
        return s.isFinished || s.day < Day.key(now())
    }

    /// Logged something, not finished yet.
    func inProgress(_ s: SessionLog) -> Bool {
        s.skip == nil && !s.isFinished && !hasContent(s)
            && (!(s.climb?.problems.isEmpty ?? true) || s.exercises.contains { !$0.doneSets.isEmpty })
    }

    func gymDone(on date: Date) -> Bool {
        sessions(on: date).contains { ($0.kind == .climb || $0.kind == .workout) && hasContent($0) }
    }

    var lastGymDay: Date? {
        store.sessions.filter { ($0.kind == .climb || $0.kind == .workout) && hasContent($0) }.map(\.date).max()
    }

    var daysSinceGym: Int? { lastGymDay.map { Day.between($0, today) } }

    // MARK: Points and streaks

    struct WeekScore: Hashable {
        var gym = 0, home = 0, prehab = 0, steps = 0, protein = 0, sends = 0, drill = 0
        var total: Int { gym + home + prehab + steps + protein + sends + drill }
    }

    func days(ofWeek index: Int) -> [Date] { (0..<7).map { Day.add($0, to: weekStart(index)) } }

    func score(week index: Int) -> WeekScore {
        let p = plan.points
        var s = WeekScore()
        let floor = blockWeek(at: index)?.template.stepFloor ?? 7000
        let goal = blockWeek(at: index)?.template.stepGoal ?? 8000
        var drillCounted = false
        for d in days(ofWeek: index) {
            if gymDone(on: d) { s.gym += p.gymSession }
            if let h = session(on: d, kind: .home), hasContent(h) { s.home += p.homeSession }
            if let pr = session(on: d, kind: .prehab), hasContent(pr) { s.prehab += p.prehab }
            let dl = daily(d)
            if let st = dl.steps {
                if st >= floor { s.steps += p.stepFloor }
                if st >= goal { s.steps += p.stepGoalBonus }
            }
            if dl.protein { s.protein += p.protein }
            for c in sessions(on: d) where c.kind == .climb && hasContent(c) {
                if isNewHardest(c) { s.sends += p.newHardestSend }
                if c.climb?.drillBoring == true && !drillCounted { s.drill += p.drillBoring; drillCounted = true }
            }
        }
        return s
    }

    func isNewHardest(_ log: SessionLog) -> Bool {
        guard let h = log.climb?.hardestSend else { return false }
        let before = store.sessions.filter { $0.kind == .climb && ($0.day < log.day || ($0.day == log.day && $0.id.uuidString < log.id.uuidString)) }
        let prev = before.compactMap { $0.climb?.hardestSend }.max()
        return prev.map { h > $0 } ?? (h >= 1)
    }

    func plannedGymDays(week index: Int) -> [Date] {
        days(ofWeek: index).filter { d in plannedItems(for: d).contains { $0.countsAsGym } }
    }

    func week(isDeload index: Int) -> Bool { blockWeek(at: index)?.phase.halvesSets == true }

    func isGreen(week index: Int) -> Bool {
        guard let w = blockWeek(at: index) else { return false }
        if score(week: index).total >= plan.points.greenWeek { return true }
        if w.phase.halvesSets || w.phase == .holiday {
            let planned = plannedGymDays(week: index)
            let done = planned.filter(gymDone).count
            return !planned.isEmpty ? done >= planned.count : score(week: index).total >= plan.points.greenWeek / 2
        }
        return false
    }

    /// Green weeks in a row, ending at the current week if it's already green,
    /// otherwise at the last finished week.
    var streak: Int {
        let cur = min(calendarIndex(for: today), plan.timeline.count - 1)
        guard cur >= 0 else { return 0 }
        var i = isGreen(week: cur) ? cur : cur - 1
        var n = 0
        while i >= 0, isGreen(week: i) { n += 1; i -= 1 }
        return n
    }

    var totalPoints: Int {
        let cur = min(calendarIndex(for: today), plan.timeline.count - 1)
        guard cur >= 0 else { return 0 }
        return (0...cur).reduce(0) { $0 + score(week: $1).total }
    }

    // MARK: The mountain

    static let baseAltitude = 300.0
    static let summitAltitude = 2400.0

    /// Position on the route in block weeks: 0 at base camp, 14 at the summit.
    /// Inside a week the figure climbs toward the next camp as points land.
    var routeProgress: Double {
        let idx = calendarIndex(for: today)
        if idx < 0 { return 0 }
        if idx >= plan.timeline.count { return Double(plan.weeks.count) }
        let week = blockWeek(at: idx)!
        var best = 0.0
        for i in 0...idx where plan.timeline[i].template == week.number {
            let f = i == idx ? min(1, Double(score(week: i).total) / Double(max(1, plan.points.greenWeek))) : 1
            best = max(best, i < idx ? 0.95 : f * 0.95)
        }
        return Double(week.number - 1) + best
    }

    func altitude(atProgress p: Double) -> Int {
        let a = Self.baseAltitude + (Self.summitAltitude - Self.baseAltitude) * p / Double(max(1, plan.weeks.count))
        return Int(a.rounded())
    }

    var currentAltitude: Int { altitude(atProgress: routeProgress) }

    // MARK: Adaptation

    /// Judge finished weeks. Missed gym days → repeat the week; a sick week →
    /// a half-volume return week, then the week again. Everything after
    /// slides by seven days. ("Don't catch up.")
    func evaluateAdaptation() {
        guard store.settings.adaptMode != .off, store.pending == nil else { return }
        let cur = calendarIndex(for: today)
        guard cur > 0 else { return }
        var timeline = plan.timeline
        var messages: [String] = []
        var repeats: [Int: Int] = [:]      // template → times repeated in this pass
        var idx = max(0, store.evaluatedThrough + 1)
        while idx < min(cur, timeline.count) {
            let entry = timeline[idx]
            let t = template(entry.template)
            defer { idx += 1 }
            if t.phase.isFixed || entry.reason == .recovery { continue }
            let days = self.days(ofWeek: idx)
            let sick = days.filter { daily($0).sick }.count
            let gymDays = days.filter { d in
                !daily(d).sick && plannedItems(for: d).contains { $0.countsAsGym }
            }
            let missed = gymDays.filter { !gymDone(on: $0) }.count
            if sick >= store.settings.sickDaysForReturnWeek {
                timeline.insert(TimelineEntry(template: entry.template, reason: .repeated), at: idx + 1)
                timeline.insert(TimelineEntry(template: entry.template, reason: .recovery), at: idx + 1)
                messages.append("Week \(t.id) had \(sick) sick days. Next up: an easy return week, then week \(t.id) again.")
            } else if missed >= store.settings.missedGymDaysToRepeat {
                timeline.insert(TimelineEntry(template: entry.template, reason: .repeated), at: idx + 1)
                repeats[t.id, default: 0] += 1
                if repeats[t.id] == 1 {
                    messages.append("Week \(t.id) had \(missed) missed gym day\(missed == 1 ? "" : "s"). Repeating it — no catching up.")
                } else if let i = messages.lastIndex(where: { $0.hasPrefix("Week \(t.id) ") }) {
                    messages[i] = "Week \(t.id) didn't happen \(repeats[t.id]!) weeks running. The plan waited for you — it starts again now."
                }
            }
            if store.settings.adaptMode == .ask && !messages.isEmpty {
                store.pending = PendingAdaptation(message: messages.joined(separator: " "), proposed: timeline, evaluatedIndex: idx)
                save()
                return
            }
        }
        let evaluated = min(cur, timeline.count) - 1
        if messages.isEmpty {
            if evaluated != store.evaluatedThrough { store.evaluatedThrough = evaluated; save() }
            return
        }
        applyTimeline(timeline, message: messages.joined(separator: " "), evaluated: evaluated)
    }

    func applyTimeline(_ timeline: [TimelineEntry], message: String, evaluated: Int? = nil) {
        mutate { s in
            s.adaptations.insert(AdaptationEvent(day: Day.key(now()), message: message, previousTimeline: s.plan.timeline), at: 0)
            s.plan.timeline = timeline
            if let evaluated { s.evaluatedThrough = evaluated }
            s.pending = nil
        }
    }

    func acceptPending() {
        guard let p = store.pending else { return }
        applyTimeline(p.proposed, message: p.message, evaluated: p.evaluatedIndex)
        evaluateAdaptation()
    }

    func dismissPending() {
        guard let p = store.pending else { return }
        mutate { s in
            s.pending = nil
            s.evaluatedThrough = p.evaluatedIndex
        }
        evaluateAdaptation()
    }

    func undo(_ event: AdaptationEvent) {
        mutate { s in
            s.plan.timeline = event.previousTimeline
            if let i = s.adaptations.firstIndex(where: { $0.id == event.id }) { s.adaptations[i].undone = true }
        }
    }

    /// Manual: "this week didn't happen, run it again next week".
    func repeatCurrentWeek() {
        let idx = calendarIndex(for: today)
        guard let w = blockWeek(at: idx) else { return }
        var t = plan.timeline
        t.insert(TimelineEntry(template: w.number, reason: .repeated), at: idx + 1)
        applyTimeline(t, message: "You chose to repeat week \(w.number). Everything after moves a week later.", evaluated: store.evaluatedThrough)
    }

    /// Manual: "I'm ill / away — turn this week into an easy return week and
    /// slide the plan". The current template runs again next week.
    func makeCurrentWeekReturn() {
        let idx = calendarIndex(for: today)
        guard let w = blockWeek(at: idx) else { return }
        var t = plan.timeline
        t[idx] = TimelineEntry(template: w.number, reason: .recovery)
        t.insert(TimelineEntry(template: w.number, reason: .repeated), at: idx + 1)
        applyTimeline(t, message: "This week is now an easy return week. Week \(w.number) runs again next week.", evaluated: max(store.evaluatedThrough, idx))
    }

    // MARK: Garmin

    /// Reads `manifest.json` from the activity folder (never writes to it).
    /// Bouldering sessions become climb logs; walks become walk logs.
    @discardableResult
    func importGarmin(announce: Bool = true) -> Int {
        guard let folder = activityFolder else { return 0 }
        let manifest = folder.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifest),
              let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return 0 }
        var added = 0
        var s = store
        for a in items {
            guard let id = a["id"] as? String, !s.importedGarmin.contains(id),
                  let sport = (a["sport"] as? String)?.lowercased(),
                  let local = a["startTimeLocal"] as? String else { continue }
            let kind: ItemKind
            if sport.contains("boulder") || sport.contains("climb") { kind = .climb }
            else if sport.contains("walk") || sport.contains("hik") { kind = .walk }
            else { continue }
            let day = String(local.prefix(10))
            guard let date = Day.date(day), date >= Day.add(-7, to: startDate) else { continue }
            let minutes = (a["durationSec"] as? Double).map { Int(($0 / 60).rounded()) }
            let hr = (a["avgHr"] as? Double).map { Int($0) }
            s.importedGarmin.append(id)
            if let i = s.sessions.firstIndex(where: { $0.day == day && $0.kind == kind }) {
                s.sessions[i].minutes = s.sessions[i].minutes ?? minutes
                s.sessions[i].avgHr = s.sessions[i].avgHr ?? hr
                s.sessions[i].garminID = id
            } else {
                var log = SessionLog(day: day, kind: kind)
                log.source = .garmin
                log.garminID = id
                log.minutes = minutes
                log.avgHr = hr
                if kind == .climb { log.climb = ClimbLog() }
                s.sessions.append(log)
            }
            added += 1
        }
        if added > 0 {
            store = s
            refreshBadges()
            save()
            if announce { notice = "Imported \(added) session\(added == 1 ? "" : "s") from your watch." }
        } else if s.importedGarmin != store.importedGarmin {
            store.importedGarmin = s.importedGarmin
            save()
        }
        return added
    }

    // MARK: Progression

    enum Readiness { case building, stepUp, stalled, new, fixLoad, backOff }

    /// Where an exercise stands, from the overload rules.
    func readiness(_ exerciseID: String) -> Readiness {
        guard let rx = nextPrescription(exerciseID) else { return .new }
        switch rx.kind {
        case .progress: return .stepUp
        case .fixLoad: return .fixLoad
        case .backOff: return .backOff
        case .new: return .new
        case .stay: return rx.plateau ? .stalled : .building
        }
    }

    static let defaultRungs: [String: Int] = [
        "pushup": 1, "pullup": 2, "pike": 0, "core-front": 0, "bss": 0,
        "calf-raise": 1, "side-plank": 1, "glute-bridge": 1, "reverse-lunge": 0,
    ]

    func rung(_ exerciseID: String) -> Int { store.rungs[exerciseID] ?? Self.defaultRungs[exerciseID] ?? 0 }

    func setRung(_ exerciseID: String, _ value: Int) {
        let max = Library.exercise(exerciseID).ladder.count - 1
        mutate { $0.rungs[exerciseID] = Swift.max(0, Swift.min(max, value)) }
    }

    // MARK: Climbing stats

    var climbSessions: [SessionLog] {
        store.sessions.filter { $0.kind == .climb }.sorted { $0.day < $1.day }
    }

    var hardestEver: Int? { climbSessions.compactMap { $0.climb?.hardestSend }.max() }

    /// Sends per grade across the block — the pyramid.
    var pyramid: [Int: Int] {
        var out: [Int: Int] = [:]
        for s in climbSessions { for p in s.climb?.sends ?? [] { out[p.grade, default: 0] += 1 } }
        return out
    }

    // MARK: Quests

    func refreshBadges() {
        let today = Day.key(now())
        var unlocked = store.badges
        func award(_ id: String, _ condition: Bool) {
            if condition, unlocked[id] == nil, !store.revokedBadges.contains(id) { unlocked[id] = today }
        }
        let all = store.sessions
        let problems = all.compactMap(\.climb).flatMap(\.problems)
        let sets = all.flatMap(\.exercises)

        award("base-camp", all.contains { hasContent($0) })
        award("first-fall", all.compactMap(\.climb).contains { $0.falls >= 5 })
        award("skeleton", problems.contains { $0.sent && $0.grade >= 2 && $0.tags.contains("Straight arms") })
        award("flag-bearer", problems.contains { $0.sent && $0.tags.contains("Flag") })
        award("heel-hook", problems.contains { $0.sent && $0.tags.contains("Heel hook") })
        award("v3-flash", problems.contains { $0.flash && $0.grade >= 3 })
        award("v4", problems.contains { $0.sent && $0.grade >= 4 })
        award("five-up", sets.contains { $0.exerciseID == "pullup" && $0.variant.lowercased().contains("strict") && $0.best >= 5 }
              || (Int(store.benchmarks["pullups"]?.end ?? "") ?? 0) >= 5)
        award("twenty-down", sets.contains { $0.exerciseID == "pushup" && $0.best >= 20 }
              || [store.benchmarks["pushups"]?.start, store.benchmarks["pushups"]?.end].contains { (Int($0 ?? "") ?? 0) >= 20 })
        award("hollow-man", sets.contains { $0.exerciseID == "core-front" && $0.timed && $0.best >= 60 }
              || [store.benchmarks["hollow"]?.start, store.benchmarks["hollow"]?.end].contains { (Int($0 ?? "") ?? 0) >= 60 }
              || store.skillsCleared["hollow@3"] != nil)
        award("summit", store.benchmarks.values.contains { !$0.end.isEmpty })

        // Week-shaped quests
        let cur = min(calendarIndex(for: self.now()), plan.timeline.count - 1)
        if cur >= 0 {
            var run = 0
            for i in 0...cur {
                let finishedWeek = i < calendarIndex(for: self.now())
                let green = isGreen(week: i)
                run = green ? run + 1 : (finishedWeek ? 0 : run)
                award("four-green", run >= 4)
                if let w = blockWeek(at: i), w.phase.halvesSets, finishedWeek || green {
                    award("deload-discipline", green)
                }
                let floor = blockWeek(at: i)?.template.stepFloor ?? 7000
                award("floor-week", days(ofWeek: i).allSatisfy { (daily($0).steps ?? 0) >= floor })
            }
            // November: every block week whose Monday falls in November.
            let novWeeks = (0...cur).filter { Day.calendar.component(.month, from: weekStart($0)) == 11 }
            let novOver = Day.calendar.component(.month, from: self.now()) >= 12 || Day.calendar.component(.year, from: self.now()) > Day.calendar.component(.year, from: startDate)
            award("survived-november", novOver && !novWeeks.isEmpty && novWeeks.allSatisfy(isGreen))
        }
        // Protein fortnight
        let proteinDays = store.daily.filter { $0.value.protein }.keys.sorted()
        var streak = 0; var prev: Date?
        for k in proteinDays {
            guard let d = Day.date(k) else { continue }
            streak = (prev.map { Day.between($0, d) == 1 } ?? false) ? streak + 1 : 1
            prev = d
            award("protein-fortnight", streak >= 14)
        }
        if unlocked != store.badges { store.badges = unlocked }
    }

    func toggleManualBadge(_ id: String) {
        if store.badges[id] == nil { restoreBadge(id) } else { revokeBadge(id) }
    }

    /// Take a quest back. An automatic one stays down until you restore it,
    /// even though the log that planted it is still there.
    func revokeBadge(_ id: String) {
        mutate { s in
            s.badges[id] = nil
            if Quests.byID[id]?.manual != true { s.revokedBadges.insert(id) }
        }
    }

    /// Undo a take-back. Manual quests plant now; automatic ones plant again
    /// if your logs still show them.
    func restoreBadge(_ id: String) {
        mutate { s in
            s.revokedBadges.remove(id)
            if Quests.byID[id]?.manual == true { s.badges[id] = Day.key(now()) }
        }
    }

    func missionKey(_ m: Quests.Mission, on date: Date) -> String {
        switch m.period {
        case .week: return "\(m.id)@\(Day.key(Day.monday(of: date)))"
        case .month:
            let c = Day.calendar.dateComponents([.year, .month], from: date)
            return "\(m.id)@\(c.year!)-\(c.month!)"
        }
    }

    func missionDone(_ m: Quests.Mission, on date: Date) -> Bool {
        let idx = calendarIndex(for: date)
        switch m.id {
        case "drill":
            return days(ofWeek: idx).contains { d in sessions(on: d).contains { $0.climb?.drillBoring == true } }
        case "never-twice":
            let planned = plannedGymDays(week: idx).filter { $0 <= today }
            guard planned.count >= 2 else { return false }
            let misses = planned.map { !gymDone(on: $0) && $0 < today }
            return !zip(misses, misses.dropFirst()).contains { $0 && $1 } && idx < calendarIndex(for: today)
        case "floor-four":
            let floor = blockWeek(at: idx)?.template.stepFloor ?? 7000
            return days(ofWeek: idx).filter { (daily($0).steps ?? 0) >= floor }.count >= 4
        default:
            return store.missions[missionKey(m, on: date)] != nil
        }
    }

    func toggleMission(_ m: Quests.Mission, on date: Date) {
        let k = missionKey(m, on: date)
        mutate { s in s.missions[k] = s.missions[k] == nil ? Day.key(now()) : nil }
    }

    // MARK: Plan revisions

    /// Push and Aesthetic gained a gym version (dumbbells) beside the band one,
    /// so every strength day can be logged at home or at the gym. Only workouts
    /// that have none get it, so a gym list you edited yourself is never replaced.
    @discardableResult
    func addGymVersions() -> Bool {
        let fresh = DefaultPlan.make(start: store.plan.startDate).workouts
        var changed = false
        for i in store.plan.workouts.indices where store.plan.workouts[i].gymExercises == nil {
            guard let f = fresh.first(where: { $0.id == store.plan.workouts[i].id }), f.gymExercises != nil else { continue }
            store.plan.workouts[i].gymExercises = f.gymExercises
            if store.plan.name == "Wall & Bar" { store.plan.workouts[i].note = f.note }
            changed = true
        }
        return changed
    }

    /// The bands are 4.5, 9, 13.5, 18 and 22.5 kg (yellow, green, red, blue,
    /// black; the app had 4, 13 and 22.7). Loads logged on a band snap to the
    /// nearest rung of the new ladder, so "53.7 kg" reads as 54 kg
    /// (13.5 + 18 + 22.5). A copy of the file is kept aside first.
    @discardableResult
    func migrateBands() -> Bool {
        guard store.bandLadder < 2 else { return false }
        if let url = fileURL {
            let backup = url.deletingLastPathComponent().appendingPathComponent("\(url.deletingPathExtension().lastPathComponent).backup-before-band-values.json")
            if !FileManager.default.fileExists(atPath: backup.path) { try? FileManager.default.copyItem(at: url, to: backup) }
        }
        func snap(_ kg: Double) -> Double { Bands.rungs[Bands.nearest(kg)].total }
        for s in store.sessions.indices {
            for e in store.sessions[s].exercises.indices where Library.exercise(store.sessions[s].exercises[e].exerciseID).isBand {
                for k in store.sessions[s].exercises[e].sets.indices {
                    if let kg = store.sessions[s].exercises[e].sets[k].kg { store.sessions[s].exercises[e].sets[k].kg = snap(kg) }
                }
            }
        }
        for (id, ls) in store.loadSet where Library.exercise(id).isBand { store.loadSet[id]?.kg = snap(ls.kg) }
        store.bandLadder = 2
        return true
    }

    /// Skill ladders moved to home (ladder 2): pull-up, row, dip and hanging
    /// leg raise became band, table, chair and floor steps, and muscle-up and
    /// front lever (bar only) were replaced by the dragon flag. Step positions
    /// and cleared steps for those skills would point at different steps, so
    /// they start over; every other skill keeps its progress. A copy of the
    /// file is kept aside first.
    @discardableResult
    func migrateSkills() -> Bool {
        guard store.skillLadder < 2 else { return false }
        if let url = fileURL {
            let backup = url.deletingLastPathComponent().appendingPathComponent("\(url.deletingPathExtension().lastPathComponent).backup-before-home-skills.json")
            if !FileManager.default.fileExists(atPath: backup.path) { try? FileManager.default.copyItem(at: url, to: backup) }
        }
        let changed = ["pullup", "row", "dip", "legraise", "muscleup", "frontlever"]
        for id in changed { store.skills[id] = nil }
        for k in store.skillsCleared.keys where changed.contains(where: { k.hasPrefix($0 + "@") }) { store.skillsCleared[k] = nil }
        store.skillFocus.removeAll { Library.skill($0) == nil }
        store.skillLadder = 2
        return true
    }

    /// Bring a saved plan up to the split week (revision 2): two hard climbs,
    /// strength on its own days, pull 48 h clear of the climbs. The week
    /// pattern, the sessions and the week notes are replaced; the timeline,
    /// logs, points, step floors and everything you've logged are kept. The
    /// week in progress isn't judged under the new pattern, so a week lived
    /// under the old one can't be repeated by it. A copy of the file is kept
    /// aside first.
    @discardableResult
    func migratePlan() -> Bool {
        guard store.plan.revision < DefaultPlan.revision, store.plan.name == "Wall & Bar" else { return false }
        if let url = fileURL {
            let backup = url.deletingLastPathComponent().appendingPathComponent("\(url.deletingPathExtension().lastPathComponent).backup-before-split-week.json")
            if !FileManager.default.fileExists(atPath: backup.path) { try? FileManager.default.copyItem(at: url, to: backup) }
        }
        let fresh = DefaultPlan.make(start: store.plan.startDate)
        store.plan.days = fresh.days
        store.plan.workouts = fresh.workouts
        for i in store.plan.weeks.indices {
            if let f = fresh.weeks.first(where: { $0.id == store.plan.weeks[i].id }) {
                store.plan.weeks[i].focus = f.focus
                store.plan.weeks[i].tip = f.tip
            }
        }
        // Five sessions' worth more points are on offer now; keep green about as hard as it was.
        if store.plan.points.greenWeek == 45 { store.plan.points.greenWeek = fresh.points.greenWeek }
        store.plan.revision = DefaultPlan.revision
        let cur = calendarIndex(for: today)
        if cur >= 0 { store.evaluatedThrough = max(store.evaluatedThrough, min(cur, store.plan.timeline.count - 1)) }
        store.pending = nil
        return true
    }

    // MARK: Elbows

    struct ElbowReading: Hashable {
        let score: Int
        let day: String
        var light: PainLight { PainLight(score: score) }
    }

    /// The latest elbow reading in the week before a date: that day's
    /// check-in, or the worst elbow score on a logged session.
    func elbowReading(asOf date: Date) -> ElbowReading? {
        let k = Day.key(date)
        func recent(_ day: String) -> Bool {
            guard day <= k, let d = Day.date(day) else { return false }
            return Day.between(d, date) <= 7
        }
        var byDay: [String: Int] = [:]
        for s in store.sessions where recent(s.day) {
            for p in s.pain where p.area == .elbows { byDay[s.day] = max(byDay[s.day] ?? 0, p.score) }
        }
        for (day, log) in store.daily where recent(day) {
            if let e = log.elbow { byDay[day] = e }
        }
        guard let day = byDay.keys.max(), let score = byDay[day] else { return nil }
        return ElbowReading(score: score, day: day)
    }

    func setElbow(_ date: Date, _ score: Int?) {
        setDaily(date) { $0.elbow = score }
        runScheduleRules()
    }

    // MARK: Reset

    func resetPlan(start: Date) {
        mutate { s in
            let key = Day.key(Day.monday(of: start))
            s.plan = DefaultPlan.make(start: key)
            s.evaluatedThrough = -1
            s.pending = nil
            s.adaptations = []
        }
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
