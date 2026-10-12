import Foundation

/// Progressive overload: what to lift next, worked out from what you lifted.
///
/// The rules are plain double progression, one session at a time:
/// - Every set at the top of the rep range, all at the working weight →
///   the weight goes up one step and the reps start again at the bottom
///   (12 × 3 at 22.5 kg → 10–12 × 3 at 25 kg).
/// - Some sets short of the top → stay at that weight and aim every set at
///   the top (12, 12, 10 → 12, 12, 12) until they all get there.
/// - Every set at the top, but some at a lighter weight → fix that first:
///   the lighter set doesn't count (12, 12 at 22.5 then 12 at 20 → all three
///   at 22.5 before going up).
/// - Two rough sessions in a row → back off: a lighter weight, rebuilt from
///   the bottom of the range. One rough session is just a rough session.
///
/// Bands step in rungs, which are big jumps, so the top of the range has to
/// land twice at the same band. Bodyweight work has no load to add: the
/// reps go beyond the range, holds gain five seconds, and a ladder says when
/// the next step is due.
enum Overload {
    enum Kind: String, Codable, Hashable {
        /// Nothing logged yet: start light.
        case new
        /// Earned: more weight, a harder step, or more reps.
        case progress
        /// Not there yet: same load, aim for the top.
        case stay
        /// Reps are there but the load wasn't the same on every set.
        case fixLoad
        /// Two rough sessions running: lighter, rebuild.
        case backOff
    }

    /// One past session of one exercise, boiled down to what the rules read.
    struct Session: Hashable {
        var day: String
        var variant: String
        var done: [SetEntry]
        var plannedSets: Int
        var low: Int
        var high: Int
        var timed: Bool
        /// The heaviest load used, nil for bodyweight work.
        var workKg: Double?
        var atWork: Int
        /// Every planned set done, every one at the top, every one at the working load.
        var topped: Bool
        /// Every set at the top, but not all at the working load.
        var mixed: Bool
        /// Sets under the bottom of the range, counting sets never done.
        var below: Int
        var volume: Double
        /// Best-set strength estimate (Epley), so a lighter weight for more reps compares fairly.
        var strength: Double

        var reps: [Int] { done.map(\.value) }

        /// Half the planned sets (at least two) under the range, or a clear fall in strength.
        func isRough(after prev: Session?) -> Bool {
            let limit = max(2, (plannedSets + 1) / 2)
            if below >= limit { return true }
            guard let prev else { return false }
            // A lighter load on purpose (a back-off) isn't a fall.
            if let a = workKg, let b = prev.workKg, a < b - 0.05 { return false }
            return strength < prev.strength * 0.88
        }
    }

    struct Target: Hashable {
        var reps: Int
        var kg: Double?
    }

    struct Prescription: Hashable {
        var kind: Kind
        var targets: [Target]
        /// One plain sentence for the screen.
        var reason: String
        var kg: Double?
        /// Four sessions at the same load without a gain.
        var plateau = false

        func reps(_ k: Int) -> Int { targets[min(k, max(0, targets.count - 1))].reps }
    }

    // MARK: Summarising

    static func summarise(_ log: ExerciseLog, day: String) -> Session? {
        let done = log.doneSets
        guard !done.isEmpty else { return nil }
        let work = done.compactMap(\.kg).max()
        let atWork = work.map { w in done.filter { ($0.kg ?? w) >= w - 0.05 }.count } ?? done.count
        let planned = max(log.sets.count, done.count)
        let allDone = done.count >= planned
        let allTop = done.allSatisfy { $0.value >= log.high }
        let below = (planned - done.count) + done.filter { $0.value < log.low }.count
        let volume = done.reduce(0.0) { $0 + Double($1.value) * ($1.kg ?? 1) }
        let strength = done.map { s -> Double in
            guard let kg = s.kg, kg > 0 else { return Double(s.value) }
            return kg * (1 + Double(s.value) / 30)
        }.max() ?? 0
        return Session(day: day, variant: log.variant, done: done, plannedSets: planned,
                       low: log.low, high: log.high, timed: log.timed,
                       workKg: work, atWork: atWork,
                       topped: allDone && allTop && atWork == done.count,
                       mixed: allDone && allTop && atWork < done.count,
                       below: below, volume: volume, strength: strength)
    }

    // MARK: Loads

    /// How far one step is for this exercise. Small isolation lifts move in
    /// kilos; everything else in your smallest plate jump.
    static func step(for info: ExerciseInfo, base: Double) -> Double {
        guard let s = info.loadStep else { return base }
        if s.contains("1–2") || s.hasPrefix("+1 kg") { return min(base, 1) }
        return base
    }

    /// "Light — stay light": no load to add, so it progresses like bodyweight.
    static func hasLoad(_ info: ExerciseInfo) -> Bool {
        if info.isBand { return true }
        guard info.usesKg else { return false }
        return !(info.loadStep ?? "").lowercased().contains("stay light")
    }

    static func roundTo(_ x: Double, _ step: Double) -> Double {
        guard step > 0 else { return x }
        return (x / step).rounded() * step
    }

    static func floorTo(_ x: Double, _ step: Double) -> Double {
        guard step > 0 else { return x }
        return (x / step + 1e-9).rounded(.down) * step
    }

    static func kgText(_ x: Double) -> String { x == x.rounded() ? "\(Int(x))" : String(format: "%.1f", x) }

    static func repsText(_ r: [Int], timed: Bool = false) -> String {
        r.map { "\($0)" }.joined(separator: ", ") + (timed ? " s" : "")
    }

    // MARK: The rules

    /// What to do next, from the history of one variation (oldest first).
    static func prescribe(info: ExerciseInfo, low: Int, high: Int, timed: Bool, setCount n: Int,
                          history: [Session], weightStep: Double,
                          override: LoadSet? = nil, ladderNext: String? = nil) -> Prescription {
        let loaded = hasLoad(info)
        let stepKg = step(for: info, base: weightStep)
        func targets(_ reps: Int, _ kg: Double?) -> [Target] { Array(repeating: Target(reps: reps, kg: kg), count: max(1, n)) }
        func load(_ kg: Double?) -> String {
            guard let kg else { return "" }
            return info.isBand ? Bands.text(kg) : "\(kgText(kg)) kg"
        }

        guard let last = history.last else {
            if let o = override, loaded {
                return Prescription(kind: .stay, targets: targets(low, o.kg), reason: o.why, kg: o.kg)
            }
            let start = info.isBand ? info.bandStart : nil
            let how = loaded
                ? "First time: start light and stop 1–3 reps short. Two sessions will find the weight."
                : "First time: stay in the range and stop 1–3 reps short."
            return Prescription(kind: .new, targets: targets(low, start), reason: how, kg: start)
        }

        let prev = history.count >= 2 ? history[history.count - 2] : nil
        let work = last.workKg
        // A load someone set by hand since the last session (the coach, a back-off).
        if let o = override, o.since > last.day, loaded {
            return Prescription(kind: .stay, targets: targets(low, o.kg), reason: o.why, kg: o.kg, plateau: false)
        }

        // Plateau: four sessions at the same load, no better.
        var plateau = false
        if history.count >= 4 {
            let r = history.suffix(4)
            let sameLoad = Set(r.map { $0.workKg ?? 0 }).count == 1
            plateau = sameLoad && r.last!.volume <= r.first!.volume && !r.last!.topped
        }

        let lastReps = repsText(last.reps, timed: timed)
        let loadNow = load(work)
        let at = loadNow.isEmpty ? "" : " at \(loadNow)"

        // Two rough sessions in a row: back off.
        let roughNow = last.isRough(after: prev)
        let roughBefore = prev.map { p in p.isRough(after: history.count >= 3 ? history[history.count - 3] : nil) } ?? false
        if roughNow && roughBefore {
            if info.isBand, let w = work {
                let down = Bands.down(from: w)
                return Prescription(kind: .backOff, targets: targets(low, down),
                                    reason: "Two rough sessions running. Down a rung to \(Bands.text(down)); build back up from \(low).", kg: down, plateau: plateau)
            }
            if loaded, let w = work {
                var down = floorTo(w * 0.9, stepKg)
                if down >= w - 0.05 { down = w - stepKg }
                down = max(stepKg, down)
                return Prescription(kind: .backOff, targets: targets(low, down),
                                    reason: "Two rough sessions running (last: \(lastReps)\(at)). Back to \(kgText(down)) kg and build up from \(low). If it still won't go, drop a set or shorten the range.", kg: down, plateau: plateau)
            }
            return Prescription(kind: .backOff, targets: targets(low, nil),
                                reason: "Two rough sessions running. Back to the bottom of the range, and think about an easier variation or one set fewer.", kg: nil, plateau: plateau)
        }
        if roughNow {
            return Prescription(kind: .stay, targets: targets(low, work),
                                reason: "A rough one (\(lastReps)\(at)). Same load; build from \(low). Another like it and it backs off.", kg: work, plateau: plateau)
        }

        // Every set at the top, every set at the working load: earned.
        if last.topped {
            if info.isBand, let w = work {
                let twice = (prev?.topped ?? false) && abs((prev?.workKg ?? 0) - w) < 0.05
                if twice {
                    let up = Bands.up(from: w)
                    return Prescription(kind: .progress, targets: targets(low, up),
                                        reason: "Top of the range twice at \(Bands.text(w)). Up a rung to \(Bands.text(up)); back to \(low) reps.", kg: up)
                }
                return Prescription(kind: .stay, targets: targets(high, w),
                                    reason: "Top of the range once at \(Bands.text(w)). Once more at this band and it goes up a rung.", kg: w, plateau: false)
            }
            if loaded, let w = work {
                let up = w + stepKg
                return Prescription(kind: .progress, targets: targets(low, up),
                                    reason: "\(lastReps) at \(kgText(w)) kg is the top of the range. Up to \(kgText(up)) kg; \(low)–\(high) again.", kg: up)
            }
            // A fixed prescription (20 reps, a 30 s stretch) or prehab isn't something to push past.
            if low == high || info.group == .prehab {
                return Prescription(kind: .stay, targets: targets(low, nil),
                                    reason: "Same as written, every time.", kg: nil, plateau: false)
            }
            if timed {
                let t = (last.reps.max() ?? high) + 5
                return Prescription(kind: .progress, targets: targets(t, nil),
                                    reason: "Held the top of the range. Add five seconds: \(t) s.", kg: nil)
            }
            if let next = ladderNext {
                return Prescription(kind: .progress, targets: targets(low, nil),
                                    reason: "Top of the range. Next step on the ladder: \(next.lowercased()), starting from \(low).", kg: nil)
            }
            let r = (last.reps.max() ?? high) + 1
            return Prescription(kind: .progress, targets: targets(r, nil),
                                reason: "Top of the range. Go past it: \(r) reps.", kg: nil)
        }

        // Reps at the top, load not the same on every set: fix the load.
        if last.mixed, let w = work {
            return Prescription(kind: .fixLoad, targets: targets(high, w),
                                reason: "All \(last.done.count) sets at \(load(w)) before going up: \(lastReps), but a lighter set doesn't count.", kg: w)
        }

        // Short of the top somewhere: same load, every set to the top.
        let bump = timed ? 5 : 2
        let perSet: [Target] = (0..<max(1, n)).map { k in
            let was = last.done[min(k, last.done.count - 1)].value
            return Target(reps: min(high, max(was + 1, min(high, was + bump))), kg: work)
        }
        let short = last.done.filter { $0.value < high }.count
        let tail = timed ? " Aim for \(high) s on every set." : " Get \(short == 1 ? "the last set" : "every set") to \(high)."
        let hold = loadNow.isEmpty ? "Stay here." : "Stay at \(loadNow)."
        return Prescription(kind: .stay, targets: perSet,
                            reason: "Last time \(lastReps)\(at). \(hold)\(tail)", kg: work, plateau: plateau)
    }

    // MARK: Records

    struct Record: Hashable {
        var bestReps: Int
        var bestRepsKg: Double?
        var heaviest: Double?
        var heaviestReps: Int
        var bestSetCount: Int
        var sessions: Int
    }

    /// The best the exercise has been done: most reps, and the heaviest load.
    static func record(_ sessions: [Session]) -> Record? {
        guard !sessions.isEmpty else { return nil }
        var bestReps = 0
        var bestRepsKg: Double? = nil
        var heaviest: Double? = nil
        var heaviestReps = 0
        var bestSets = 0
        for s in sessions {
            for e in s.done {
                if e.value > bestReps || (e.value == bestReps && (e.kg ?? 0) > (bestRepsKg ?? 0)) { bestReps = e.value; bestRepsKg = e.kg }
                if let kg = e.kg, kg > (heaviest ?? 0) || (kg == heaviest && e.value > heaviestReps) { heaviest = kg; heaviestReps = e.value }
            }
            bestSets = max(bestSets, s.done.count)
        }
        return Record(bestReps: bestReps, bestRepsKg: bestRepsKg, heaviest: heaviest, heaviestReps: heaviestReps,
                      bestSetCount: bestSets, sessions: sessions.count)
    }
}

/// A load set by hand (by you, or by a coach adjustment) that takes over from
/// the history until the next session of that exercise is logged.
struct LoadSet: Codable, Hashable {
    var kg: Double
    var since: String
    var why: String
}

// MARK: - In the model

extension AppModel {
    /// Past sessions of one exercise, one variation, oldest first.
    func overloadHistory(_ exerciseID: String, variant: String?, before date: Date? = nil) -> [Overload.Session] {
        let k = date.map(Day.key)
        return store.sessions
            .filter { k == nil || $0.day < k! }
            .sorted { $0.day < $1.day }
            .flatMap { s in
                s.exercises.compactMap { e -> Overload.Session? in
                    guard e.exerciseID == exerciseID, variant == nil || e.variant == variant else { return nil }
                    return Overload.summarise(e, day: s.day)
                }
            }
    }

    /// What to do next time for an exercise, as of a date.
    func prescription(_ exerciseID: String, variant: String, low: Int, high: Int, timed: Bool, setCount: Int, before date: Date) -> Overload.Prescription {
        let info = Library.exercise(exerciseID)
        let rung = rung(exerciseID)
        return Overload.prescribe(info: info, low: low, high: high, timed: timed, setCount: setCount,
                                  history: overloadHistory(exerciseID, variant: variant, before: date),
                                  weightStep: store.settings.weightStepKg,
                                  override: store.loadSet[exerciseID],
                                  ladderNext: info.ladder[safe: rung + 1])
    }

    /// The same, from the latest session of the exercise (no date, no plan).
    func nextPrescription(_ exerciseID: String) -> Overload.Prescription? {
        let all = store.sessions.sorted { $0.day < $1.day }
        guard let last = all.reversed().lazy.compactMap({ s in s.exercises.last { $0.exerciseID == exerciseID && !$0.doneSets.isEmpty } }).first else { return nil }
        let info = Library.exercise(exerciseID)
        return Overload.prescribe(info: info, low: last.low, high: last.high, timed: last.timed, setCount: last.sets.count,
                                  history: overloadHistory(exerciseID, variant: last.variant),
                                  weightStep: store.settings.weightStepKg,
                                  override: store.loadSet[exerciseID],
                                  ladderNext: info.ladder[safe: rung(exerciseID) + 1])
    }

    /// Set a load by hand; the next session of that exercise starts there.
    func setLoad(_ exerciseID: String, kg: Double, why: String) {
        mutate { $0.loadSet[exerciseID] = LoadSet(kg: kg, since: Day.key(now()), why: why) }
    }

    /// One row per exercise you've logged: last time, best, and what's next.
    struct LiftRow: Identifiable, Hashable {
        var id: String { exerciseID }
        var exerciseID: String
        var name: String
        var variant: String
        var last: Overload.Session
        var record: Overload.Record
        var next: Overload.Prescription
        var sessions: Int
    }

    func liftRows() -> [LiftRow] {
        var seen: [String: String] = [:]
        for s in store.sessions.sorted(by: { $0.day < $1.day }) {
            for e in s.exercises where !e.doneSets.isEmpty { seen[e.exerciseID] = e.variant }
        }
        return seen.keys.sorted().compactMap { id -> LiftRow? in
            guard let variant = seen[id], let rx = nextPrescription(id) else { return nil }
            let hist = overloadHistory(id, variant: variant)
            guard let last = hist.last, let rec = Overload.record(hist) else { return nil }
            return LiftRow(exerciseID: id, name: Library.exercise(id).name, variant: variant, last: last, record: rec, next: rx, sessions: hist.count)
        }
        .sorted { ($0.last.day, $0.name) > ($1.last.day, $1.name) }
    }
}
