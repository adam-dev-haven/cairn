import Foundation

/// The rules behind "if I do this, the app changes that". Each one reads as
/// a sentence in Settings → Smart scheduling.
struct ScheduleRules: Codable, Hashable {
    /// A strength session or hard climb skipped for time or energy moves to
    /// the next free day this week, if the spacing rules allow it.
    var skipCarry: AdaptMode = .ask
    /// Pull sessions stay this many days clear of a hard climb.
    var pullGapDays = 2
    /// Red elbows swap pulling and climbing for prehab.
    var elbow: AdaptMode = .ask
    /// Missing the same session this many weeks running proposes moving it
    /// for good to a weekday that works.
    var patternWeeks = 2
    /// Show spacing warnings when you move things around.
    var warnings = true

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = ScheduleRules()
        skipCarry = try c.decodeIfPresent(AdaptMode.self, forKey: .skipCarry) ?? def.skipCarry
        pullGapDays = try c.decodeIfPresent(Int.self, forKey: .pullGapDays) ?? def.pullGapDays
        elbow = try c.decodeIfPresent(AdaptMode.self, forKey: .elbow) ?? def.elbow
        patternWeeks = try c.decodeIfPresent(Int.self, forKey: .patternWeeks) ?? def.patternWeeks
        warnings = try c.decodeIfPresent(Bool.self, forKey: .warnings) ?? def.warnings
    }
}

/// A kind of session that can go on a day.
struct SessionTemplate: Identifiable, Hashable {
    var id: String
    var name: String
    var symbol: String
    var kind: ItemKind
    var workoutID: String?
    var optional: Bool
    var group: MoveGroup?
    var hard: Bool

    func make(from: String? = nil, extra: Bool = false) -> PlannedItem {
        PlannedItem(kind: kind, workoutID: workoutID, optional: optional ? true : nil, from: from, extra: extra ? true : nil)
    }
}

/// One thing the engine would change, and why.
struct ScheduleSuggestion: Identifiable, Hashable {
    enum Rule: String { case skipCarry, pullGap, elbow, pattern }
    enum Action: Hashable {
        /// Take the session off one day and put it on another, this week.
        case move(PlannedItem, from: String, to: String)
        /// Swap a session for another on the same day.
        case replace(PlannedItem, on: String, with: PlannedItem)
        /// Move a session to another weekday for every week from now on.
        case movePattern(PlannedItem, toWeekday: Int)
    }
    var id: String
    var rule: Rule
    var title: String
    var detail: String
    var actions: [Action]
    var applyLabel: String
}

struct ScheduleIssue: Identifiable, Hashable {
    var id: String
    var weekday: Int
    var text: String
}

enum Schedule {
    /// Distance between two weekdays on a weekly cycle (Sunday sits next to Monday).
    static func cycle(_ a: Int, _ b: Int) -> Int { let d = abs(a - b); return min(d, 7 - d) }

    /// The cost of putting `item` on weekday `day` given what's on the other
    /// days (the item itself already taken off its old day). Lower is better;
    /// nil means it can't go there. Everything that is a hard "no" costs 100,
    /// so a day can still be chosen when nothing else is left, but is flagged.
    static func penalty(_ item: PlannedItem, on day: Int, layout: [[PlannedItem]], gap: Int,
                        group: (PlannedItem) -> MoveGroup?, hard: (PlannedItem) -> Bool) -> Double? {
        if item.kind == .climb && layout[day].contains(where: { $0.kind == .climb }) { return nil }
        var p = 0.0
        for it in layout[day] where it.kind != .rest && it.kind != .check {
            p += (it.isOptional || it.kind == .walk || it.kind == .prehab) ? 0.5 : 1.5
        }
        let isHard = hard(item)
        let g = item.kind == .climb ? nil : group(item)
        let hardDays = (0..<7).filter { d in layout[d].contains(where: hard) }
        let pullDays = (0..<7).filter { d in layout[d].contains { $0.kind != .climb && group($0) == .pull } }
        if isHard {
            if hardDays.contains(where: { cycle($0, day) < 2 }) { p += 100 }
            if pullDays.contains(where: { cycle($0, day) < gap }) { p += 100 }
            if layout[(day + 6) % 7].contains(where: { $0.kind != .climb && group($0) == .legs }) { p += 6 }
        }
        if g == .pull, hardDays.contains(where: { cycle($0, day) < gap }) { p += 100 }
        if let g, g == .push || g == .pull || g == .legs {
            for d in [(day + 6) % 7, day, (day + 1) % 7] where layout[d].contains(where: { $0.kind != .climb && group($0) == g }) {
                p += d == day ? 20 : 8
            }
        }
        if g == .legs, layout[(day + 1) % 7].contains(where: hard) { p += 6 }
        return p
    }

    /// Spacing problems in a week's layout, in words.
    static func issues(layout: [[PlannedItem]], gap: Int, group: (PlannedItem) -> MoveGroup?,
                       hard: (PlannedItem) -> Bool, name: (PlannedItem) -> String) -> [ScheduleIssue] {
        var out: [ScheduleIssue] = []
        let names = Day.weekdayShort
        let hardDays = (0..<7).filter { d in layout[d].contains(where: hard) }
        for (i, a) in hardDays.enumerated() {
            for b in hardDays[(i + 1)...] where cycle(a, b) < 2 {
                out.append(ScheduleIssue(id: "hard-\(a)-\(b)", weekday: b, text: "Hard climbs on \(names[a]) and \(names[b]): your fingers need a day between."))
            }
        }
        for d in 0..<7 {
            for it in layout[d] where it.kind != .climb && group(it) == .pull {
                for h in hardDays where cycle(h, d) < gap {
                    out.append(ScheduleIssue(id: "pull-\(d)-\(h)", weekday: d,
                                             text: "\(name(it)) on \(names[d]) is \(cycle(h, d) == 0 ? "the same day as" : "\(cycle(h, d)) day\(cycle(h, d) == 1 ? "" : "s") from") the hard climb on \(names[h]). Pulling wants \(gap) clear days."))
                }
            }
            if layout[d].contains(where: { $0.kind != .climb && group($0) == .legs }), layout[(d + 1) % 7].contains(where: hard) {
                out.append(ScheduleIssue(id: "legs-\(d)", weekday: d, text: "Legs on \(names[d]), hard climb the next morning: tired legs make the hard grades worse."))
            }
            for g in [MoveGroup.push, .pull, .legs] {
                let here = layout[d].first { $0.kind != .climb && group($0) == g }
                let next = layout[(d + 1) % 7].first { $0.kind != .climb && group($0) == g }
                if let here, let next, d < 6 {
                    out.append(ScheduleIssue(id: "same-\(d)-\(g.rawValue)", weekday: d,
                                             text: "\(g.name) on \(names[d]) and \(names[d + 1]) back to back (\(name(here)), \(name(next)))."))
                }
            }
        }
        return out
    }
}

extension AppModel {
    // MARK: Templates

    /// Everything that can go on a day: the climbs, each strength session,
    /// the walk and prehab.
    var sessionTemplates: [SessionTemplate] {
        var out = [
            SessionTemplate(id: "climb", name: "Boulder", symbol: ItemKind.climb.symbol, kind: .climb, workoutID: nil, optional: false, group: nil, hard: true),
            SessionTemplate(id: "climb-easy", name: "Easy climb (optional)", symbol: ItemKind.climb.symbol, kind: .climb, workoutID: nil, optional: true, group: nil, hard: false),
        ]
        for w in plan.workouts {
            let kind: ItemKind = w.id == "P" ? .prehab : (w.isHome ? .home : .workout)
            out.append(SessionTemplate(id: "w-\(w.id)", name: "\(w.id) · \(w.name)", symbol: kind.symbol, kind: kind,
                                       workoutID: w.id, optional: false, group: majorGroup(of: w), hard: false))
        }
        out.append(SessionTemplate(id: "walk", name: "Walk", symbol: ItemKind.walk.symbol, kind: .walk, workoutID: nil, optional: false, group: nil, hard: false))
        return out
    }

    func template(for item: PlannedItem) -> SessionTemplate? {
        sessionTemplates.first { $0.kind == item.kind && $0.workoutID == item.workoutID && $0.optional == item.isOptional }
            ?? sessionTemplates.first { $0.kind == item.kind && $0.workoutID == item.workoutID }
    }

    /// The movement group a strength session mostly trains.
    func majorGroup(of w: Workout) -> MoveGroup? {
        if w.id == "P" { return .prehab }
        var count: [MoveGroup: Int] = [:]
        for pe in w.exercises { count[Library.exercise(pe.exerciseID).group, default: 0] += 1 }
        let ranked = count.sorted { $0.value > $1.value }
        guard let top = ranked.first else { return nil }
        // A clear majority names the session; a mix (the aesthetic day) names none.
        return Double(top.value) / Double(max(1, w.exercises.count)) >= 0.5 ? top.key : nil
    }

    func group(of item: PlannedItem) -> MoveGroup? {
        guard item.kind == .home || item.kind == .workout, let w = workout(item.workoutID) else { return nil }
        return majorGroup(of: w)
    }

    func isHard(_ item: PlannedItem) -> Bool { item.kind == .climb && !item.isOptional }

    func name(of item: PlannedItem) -> String {
        switch item.kind {
        case .workout, .home:
            if let w = workout(item.workoutID) { return "\(w.id) · \(w.name)" }
            return item.kind.name
        case .prehab: return "Prehab"
        case .climb: return item.isOptional ? "Easy climb (optional)" : "Boulder"
        default: return item.kind.name
        }
    }

    // MARK: Changing a day

    func dayChange(_ date: Date) -> DayChange { store.dayChanges[Day.key(date)] ?? DayChange() }

    private func editChange(_ date: Date, _ f: (inout DayChange) -> Void) {
        let k = Day.key(date)
        mutate { s in
            var c = s.dayChanges[k] ?? DayChange()
            f(&c)
            s.dayChanges[k] = c.isEmpty ? nil : c
        }
    }

    /// Pattern items taken off a date, so they can be put back.
    func takenOff(on date: Date) -> [PlannedItem] {
        let hidden = dayChange(date).hidden
        return plan.days[Day.weekday(date) - 1].items.filter { hidden.contains($0.id) }
    }

    func takeOff(_ item: PlannedItem, on date: Date) {
        editChange(date) { c in
            if c.added.contains(where: { $0.id == item.id }) { c.added.removeAll { $0.id == item.id } }
            else if !c.hidden.contains(item.id) { c.hidden.append(item.id) }
        }
    }

    func putBack(_ item: PlannedItem, on date: Date) {
        editChange(date) { $0.hidden.removeAll { $0 == item.id } }
    }

    func put(_ item: PlannedItem, on date: Date) {
        guard !plannedItems(for: date).contains(where: { $0.kind == item.kind && $0.workoutID == item.workoutID && ($0.kind != .climb) }) else { return }
        guard !(item.kind == .climb && plannedItems(for: date).contains { $0.kind == .climb }) else { return }
        editChange(date) { $0.added.append(item) }
    }

    /// Take a session off one day and put it on another, this week. If it
    /// has a log on the old day (a skip), that log stays where it happened.
    func move(_ item: PlannedItem, from: Date, to: Date) {
        guard Day.key(from) != Day.key(to) else { return }
        let moved = PlannedItem(kind: item.kind, workoutID: item.workoutID, optional: item.optional, from: Day.key(from), extra: nil)
        takeOff(item, on: from)
        put(moved, on: to)
    }

    /// Where this session sits elsewhere in the week, not yet done: the day
    /// a bring-forward would take it from.
    func plannedElsewhere(_ t: SessionTemplate, on date: Date) -> (date: Date, item: PlannedItem)? {
        let idx = calendarIndex(for: date)
        guard blockWeek(at: idx) != nil else { return nil }
        let cands = days(ofWeek: idx).filter { Day.key($0) != Day.key(date) }.compactMap { d -> (Date, PlannedItem)? in
            guard let it = plannedItems(for: d).first(where: { $0.kind == t.kind && $0.workoutID == t.workoutID && $0.isOptional == t.optional }) else { return nil }
            guard !isDone(it, on: d), skipped(it, on: d) == nil else { return nil }
            return (d, it)
        }
        return cands.min { abs(Day.between($0.0, date)) < abs(Day.between($1.0, date)) }.map { (date: $0.0, item: $0.1) }
    }

    /// Put a session on a day. If it's still to do elsewhere this week it
    /// moves here (and is done for the week, off the day it was on);
    /// otherwise it's added again as an extra.
    @discardableResult
    func add(_ t: SessionTemplate, on date: Date) -> String {
        let here = plannedItems(for: date)
        if t.kind == .climb, here.contains(where: { $0.kind == .climb }) { return "There's already a climb on this day." }
        if here.contains(where: { $0.kind == t.kind && $0.workoutID == t.workoutID && t.kind != .climb }) { return "\(t.name) is already on this day." }
        if let from = plannedElsewhere(t, on: date) {
            move(from.item, from: from.date, to: date)
            return "\(t.name) moved here from \(Day.weekdayShort[Day.weekday(from.date) - 1]). It's done for the week there."
        }
        put(t.make(extra: true), on: date)
        return "\(t.name) added again as an extra."
    }

    // MARK: The week as a layout

    func layout(week index: Int) -> [[PlannedItem]] {
        days(ofWeek: index).map { plannedItems(for: $0).filter { $0.kind != .rest } }
    }

    func scheduleIssues(week index: Int) -> [ScheduleIssue] {
        guard store.settings.schedule.warnings else { return [] }
        return Schedule.issues(layout: layout(week: index), gap: store.settings.schedule.pullGapDays,
                               group: group(of:), hard: isHard, name: name(of:))
    }

    /// The best day this week for a session taken off `from`, the cost of
    /// it, and whether it breaks a rule outright.
    func bestSlot(for item: PlannedItem, from: Date, week index: Int) -> (date: Date, cost: Double)? {
        var lay = layout(week: index)
        let src = Day.weekday(from) - 1
        lay[src].removeAll { $0.kind == item.kind && $0.workoutID == item.workoutID }
        var best: (Date, Double)? = nil
        for (i, d) in days(ofWeek: index).enumerated() where i != src && d >= today && !daily(d).sick {
            guard var p = Schedule.penalty(item, on: i, layout: lay, gap: store.settings.schedule.pullGapDays, group: group(of:), hard: isHard) else { continue }
            p += 0.4 * Double(abs(i - src))
            if best == nil || p < best!.1 { best = (d, p) }
        }
        return best.map { (date: $0.0, cost: $0.1) }
    }

    // MARK: Suggestions

    func scheduleSuggestions(week index: Int) -> [ScheduleSuggestion] {
        guard let week = blockWeek(at: index), index == calendarIndex(for: today), !week.phase.isFixed else { return [] }
        let rules = store.settings.schedule
        var out: [ScheduleSuggestion] = []

        // 1. A session skipped for time or energy: the next free day.
        if rules.skipCarry != .off {
            for d in days(ofWeek: index) where d <= today {
                for log in sessions(on: d) {
                    guard let why = log.skip, why == .time || why == .tired || why == .other else { continue }
                    guard let item = plannedItems(for: d).first(where: { $0.kind == log.kind && $0.workoutID == log.workoutID }),
                          !item.isOptional, [.home, .workout, .climb].contains(item.kind) else { continue }
                    guard let t = template(for: item), plannedElsewhere(t, on: d) == nil else { continue }
                    // Already placed again somewhere this week?
                    if days(ofWeek: index).contains(where: { x in x != d && plannedItems(for: x).contains { $0.kind == item.kind && $0.workoutID == item.workoutID && $0.from == Day.key(d) } }) { continue }
                    guard let slot = bestSlot(for: item, from: d, week: index), slot.cost < 100 else { continue }
                    let day = Day.weekdayLong[Day.weekday(slot.date) - 1]
                    out.append(ScheduleSuggestion(
                        id: "skip|\(Day.key(d))|\(t.id)", rule: .skipCarry,
                        title: "\(name(of: item)) wasn't done on \(Day.weekdayShort[Day.weekday(d) - 1]) (\(why.name.lowercased()))",
                        detail: "\(day) has room for it and keeps the spacing right. Move it there, and it's done for the week on \(Day.weekdayShort[Day.weekday(d) - 1]).",
                        actions: [.move(item, from: Day.key(d), to: Day.key(slot.date))],
                        applyLabel: "Move to \(Day.weekdayShort[Day.weekday(slot.date) - 1])"))
                }
            }
        }

        // 2. Red elbows: no pulling or climbing, prehab instead.
        if rules.elbow != .off, let r = elbowReading(asOf: today), r.light == .red {
            var actions: [ScheduleSuggestion.Action] = []
            var names: [String] = []
            for d in days(ofWeek: index) where d >= today {
                let items = plannedItems(for: d)
                for it in items where (it.kind == .climb) || (group(of: it) == .pull && it.kind != .climb) {
                    if isDone(it, on: d) { continue }
                    names.append("\(name(of: it)) \(Day.weekdayShort[Day.weekday(d) - 1])")
                    if items.contains(where: { $0.kind == .prehab }) {
                        actions.append(.replace(it, on: Day.key(d), with: PlannedItem(kind: .walk)))
                    } else {
                        actions.append(.replace(it, on: Day.key(d), with: PlannedItem(kind: .prehab)))
                    }
                }
            }
            if !actions.isEmpty {
                out.append(ScheduleSuggestion(
                    id: "elbow|\(Day.key(today))|\(r.day)", rule: .elbow,
                    title: "Elbows read red (\(r.score)/10)",
                    detail: "No pulling and no climbing until a check-in comes back green: \(names.joined(separator: ", ")) become prehab or a walk. Push, legs and the rest carry on.",
                    actions: actions, applyLabel: "Swap them out"))
            }
        }

        // 3. A pull session too close to a hard climb.
        let gap = rules.pullGapDays
        for issue in scheduleIssues(week: index) where issue.id.hasPrefix("pull-") {
            let d = days(ofWeek: index)[issue.weekday]
            guard d >= today, let it = plannedItems(for: d).first(where: { $0.kind != .climb && group(of: $0) == .pull }), !isDone(it, on: d) else { continue }
            guard let slot = bestSlot(for: it, from: d, week: index), slot.cost < 100 else { continue }
            out.append(ScheduleSuggestion(
                id: "pull|\(Day.key(d))|\(it.workoutID ?? "")", rule: .pullGap,
                title: "\(name(of: it)) is too close to a hard climb",
                detail: "\(issue.text) \(Day.weekdayLong[Day.weekday(slot.date) - 1]) keeps it \(gap)+ days clear.",
                actions: [.move(it, from: Day.key(d), to: Day.key(slot.date))],
                applyLabel: "Move to \(Day.weekdayShort[Day.weekday(slot.date) - 1])"))
        }

        return out.filter { !store.dismissedSchedule.contains($0.id) }
    }

    func apply(_ s: ScheduleSuggestion) {
        for a in s.actions {
            switch a {
            case .move(let item, let from, let to):
                if let f = Day.date(from), let t = Day.date(to) { move(item, from: f, to: t) }
            case .replace(let item, let on, let with):
                if let d = Day.date(on) {
                    takeOff(item, on: d)
                    put(with, on: d)
                }
            case .movePattern(let item, let wd):
                movePattern(item, toWeekday: wd)
            }
        }
        dismissSchedule(s.id)
    }

    func dismissSchedule(_ id: String) {
        mutate { $0.dismissedSchedule.insert(id) }
    }

    /// Apply the rules set to "adjust automatically". Called when something
    /// the rules read has changed (a skip, an elbow check-in, a launch).
    func runScheduleRules() {
        let idx = calendarIndex(for: today)
        for s in scheduleSuggestions(week: idx) {
            let mode: AdaptMode
            switch s.rule {
            case .skipCarry: mode = store.settings.schedule.skipCarry
            case .elbow: mode = store.settings.schedule.elbow
            case .pullGap: mode = store.settings.schedule.skipCarry
            case .pattern: mode = .ask
            }
            if mode == .automatic {
                apply(s)
                notice = s.title + ". " + s.applyLabel + " done."
            }
        }
    }

    // MARK: Patterns

    /// Move one session to another weekday for good (every week from now on).
    func movePattern(_ item: PlannedItem, toWeekday wd: Int) {
        mutate { s in
            for i in s.plan.days.indices {
                if let k = s.plan.days[i].items.firstIndex(where: { $0.id == item.id }) {
                    let moved = s.plan.days[i].items.remove(at: k)
                    s.plan.days[wd].items.append(moved)
                    break
                }
            }
        }
    }

    enum Outcome { case done, missed, sick, notPlanned }

    /// How a pattern item went in one past week.
    func outcome(of item: PlannedItem, weekday wd: Int, week index: Int) -> Outcome {
        let d = days(ofWeek: index)[wd]
        if daily(d).sick { return .sick }
        // Items moved off or brought in belong to the day's plannedItems.
        guard let it = plannedItems(for: d).first(where: { $0.kind == item.kind && $0.workoutID == item.workoutID }) else { return .notPlanned }
        return isDone(it, on: d) ? .done : .missed
    }

    struct PatternFinding: Identifiable, Hashable {
        var id: String
        var item: PlannedItem
        var weekday: Int
        var missedRun: Int
        var better: Int?
        var betterRate: Double
        var text: String
    }

    /// Sessions missed on the same weekday several weeks running, and a
    /// weekday that has actually worked for you.
    func patternFindings() -> [PatternFinding] {
        let cur = calendarIndex(for: today)
        guard cur >= 1 else { return [] }
        let need = max(1, store.settings.schedule.patternWeeks)
        let past = (0..<min(cur, plan.timeline.count)).filter { i in
            guard let w = blockWeek(at: i) else { return false }
            return !w.phase.isFixed && w.entry.reason != .recovery
        }
        guard past.count >= need else { return [] }
        // How each weekday has gone: done / planned over the recent weeks.
        func rate(_ wd: Int) -> (Double, Int) {
            var done = 0, planned = 0
            for i in past.suffix(6) {
                let d = days(ofWeek: i)[wd]
                if daily(d).sick { continue }
                for it in plannedItems(for: d) where [.home, .workout, .climb].contains(it.kind) && !it.isOptional {
                    planned += 1
                    if isDone(it, on: d) { done += 1 }
                }
            }
            return (planned == 0 ? 0 : Double(done) / Double(planned), planned)
        }
        var out: [PatternFinding] = []
        let gap = store.settings.schedule.pullGapDays
        for wd in 0..<7 {
            for item in plan.days[wd].items where [.home, .workout, .climb].contains(item.kind) && !item.isOptional {
                let statuses = past.reversed().map { outcome(of: item, weekday: wd, week: $0) }.filter { $0 != .sick && $0 != .notPlanned }
                var run = 0
                for s in statuses { if s == .missed { run += 1 } else { break } }
                guard run >= need else { continue }
                var lay = (0..<7).map { plan.days[$0].items.filter { $0.kind != .rest } }
                lay[wd].removeAll { $0.id == item.id }
                var best: (Int, Double, Double)? = nil
                for d in 0..<7 where d != wd {
                    guard let p = Schedule.penalty(item, on: d, layout: lay, gap: gap, group: group(of:), hard: isHard), p < 100 else { continue }
                    let r = rate(d)
                    guard r.1 >= 2 else { continue }
                    let score = p - 6 * r.0
                    if best == nil || score < best!.2 { best = (d, r.0, score) }
                }
                let nm = name(of: item)
                if let b = best, b.1 > rate(wd).0 {
                    out.append(PatternFinding(id: "pattern|\(item.id.uuidString)", item: item, weekday: wd, missedRun: run, better: b.0, betterRate: b.1,
                                              text: "\(nm) has been missed \(run) \(run == 1 ? "week" : "weeks") running on \(Day.weekdayLong[wd])s. You do \(Int((b.1 * 100).rounded()))% of what's planned on \(Day.weekdayLong[b.0])s."))
                } else {
                    out.append(PatternFinding(id: "pattern|\(item.id.uuidString)", item: item, weekday: wd, missedRun: run, better: nil, betterRate: 0,
                                              text: "\(nm) has been missed \(run) \(run == 1 ? "week" : "weeks") running on \(Day.weekdayLong[wd])s, and no other day fits it without breaking a spacing rule."))
                }
            }
        }
        return out.filter { !store.dismissedSchedule.contains($0.id) }
    }

    func patternSuggestions() -> [ScheduleSuggestion] {
        patternFindings().compactMap { f in
            guard let b = f.better else { return nil }
            return ScheduleSuggestion(id: f.id, rule: .pattern, title: f.text,
                                      detail: "Move \(name(of: f.item)) to \(Day.weekdayLong[b]) from now on. You can move it back in Settings → Your week.",
                                      actions: [.movePattern(f.item, toWeekday: b)], applyLabel: "Move it to \(Day.weekdayShort[b])")
        }
    }

    // MARK: Ranking for an empty day

    /// What's worth putting on a day: sessions still due this week, cheapest
    /// slot first, nothing that breaks a spacing rule.
    func suggestedForDay(_ date: Date) -> [SessionTemplate] {
        let idx = calendarIndex(for: date)
        guard blockWeek(at: idx) != nil else { return [] }
        let wd = Day.weekday(date) - 1
        var scored: [(SessionTemplate, Double)] = []
        for t in sessionTemplates where t.kind != .walk && t.kind != .prehab && !t.optional {
            guard let from = plannedElsewhere(t, on: date) else { continue }
            var lay = layout(week: idx)
            lay[Day.weekday(from.date) - 1].removeAll { $0.kind == t.kind && $0.workoutID == t.workoutID }
            let item = t.make()
            guard let p = Schedule.penalty(item, on: wd, layout: lay, gap: store.settings.schedule.pullGapDays, group: group(of:), hard: isHard), p < 5 else { continue }
            scored.append((t, p))
        }
        return scored.sorted { $0.1 < $1.1 }.prefix(3).map(\.0)
    }

    /// Spacing problems that adding this to the day would cause (or that exist after).
    func warnings(adding t: SessionTemplate, on date: Date) -> [String] {
        let idx = calendarIndex(for: date)
        guard blockWeek(at: idx) != nil, store.settings.schedule.warnings else { return [] }
        let wd = Day.weekday(date) - 1
        var lay = layout(week: idx)
        if let from = plannedElsewhere(t, on: date) {
            lay[Day.weekday(from.date) - 1].removeAll { $0.kind == t.kind && $0.workoutID == t.workoutID }
        }
        func issues(_ l: [[PlannedItem]]) -> [ScheduleIssue] {
            Schedule.issues(layout: l, gap: store.settings.schedule.pullGapDays, group: group(of:), hard: isHard, name: name(of:))
        }
        let before = Set(issues(lay).map(\.id))
        lay[wd].append(t.make())
        // Only what this addition causes.
        return issues(lay).filter { !before.contains($0.id) }.map(\.text)
    }
}
