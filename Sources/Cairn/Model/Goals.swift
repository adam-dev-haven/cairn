import Foundation

/// A goal always has a next one. Reach it and the frontier moves: a climbing
/// goal is read off what you've sent, a skill goal off the step you're on,
/// a lift goal off the overload rules. Nothing here is stored; it's all
/// worked out from the logs, so there's nothing to drift.
struct Goal: Identifiable {
    var id: String
    var title: String
    var detail: String
    var symbol: String
    /// Is it already true of these sessions?
    var check: ([SessionLog]) -> Bool

    func met(_ sessions: [SessionLog]) -> Bool { check(sessions) }
}

extension AppModel {
    /// Sent problems per finished climb, in the gym's own ranking.
    private func climbProblems(_ sessions: [SessionLog]) -> [[Problem]] {
        sessions.filter { $0.kind == .climb && hasContent($0) }.map { $0.climb?.problems ?? [] }
    }

    /// The climbing goals around where you are now: a harder grade, three
    /// of the current one in a session, a flash of it.
    func climbGoals(from sessions: [SessionLog]) -> [Goal] {
        let per = climbProblems(sessions)
        let sends = per.flatMap { $0.filter(\.sent) }
        guard let h = sends.map(rank).max() else {
            return [Goal(id: "climb-first", title: "Send your first problem", detail: "Any grade. A send is a top, however many tries.", symbol: "figure.climbing",
                         check: { [unowned self] s in !climbProblems(s).flatMap { $0.filter(\.sent) }.isEmpty })]
        }
        let label = rankLabel(h)
        let top = circuits.isEmpty ? nil : circuits.count - 1
        var out: [Goal] = []
        if top == nil || h < top! {
            let next = rankLabel(h + 1)
            out.append(Goal(id: "climb-up-\(h + 1)", title: "Send a \(next)", detail: "Your hardest so far is \(label). A new hardest is five points.", symbol: "arrow.up.right",
                            check: { [unowned self] s in climbProblems(s).flatMap { $0.filter(\.sent) }.contains { rank($0) >= h + 1 } }))
        }
        out.append(Goal(id: "climb-three-\(h)", title: "Send three \(label) in one session", detail: "Consolidate: the grade stops being a project.", symbol: "3.circle",
                        check: { [unowned self] s in climbProblems(s).contains { $0.filter { $0.sent && rank($0) >= h }.count >= 3 } }))
        out.append(Goal(id: "climb-flash-\(h)", title: "Flash a \(label)", detail: "First try, no beta watched.", symbol: "bolt",
                        check: { [unowned self] s in climbProblems(s).flatMap { $0 }.contains { $0.flash && rank($0) >= h } }))
        return out
    }

    var climbGoals: [Goal] { climbGoals(from: store.sessions) }

    /// What a session just finished moved: goals that were open before it
    /// and are met now, and the goals open now.
    func goalProgress(finishing log: SessionLog) -> (reached: [Goal], next: [Goal]) {
        let before = store.sessions.filter { $0.id != log.id }
        let after = store.sessions
        let open = climbGoals(from: before)
        let reached = open.filter { !$0.met(before) && $0.met(after) }
        return (reached, climbGoals(from: after).filter { !$0.met(after) })
    }

    /// Skills: the step you're on, or the next skill to pick up.
    func skillGoals() -> [Goal] {
        var out: [Goal] = []
        for sk in focusSkills {
            let step = sk.steps[skillStep(sk.id)]
            out.append(Goal(id: "skill-\(sk.id)", title: "\(sk.name): \(step.name)", detail: "Goal \(step.goal). \(step.cue)", symbol: sk.symbol,
                            check: { [unowned self] _ in skillComplete(sk.id) }))
        }
        let done = Library.skills.filter { skillComplete($0.id) }
        if focusSkills.isEmpty || focusSkills.allSatisfy({ skillComplete($0.id) }) {
            if let next = Library.skills.first(where: { !skillComplete($0.id) && skillUnlocked($0) && !store.skillFocus.contains($0.id) }) {
                out.append(Goal(id: "skill-pick-\(next.id)", title: done.isEmpty ? "Pick a skill: \(next.name)" : "Next skill: \(next.name)",
                                detail: "\(next.why) Learn → Calisthenics → Skills.", symbol: next.symbol, check: { _ in false }))
            }
        }
        return out
    }

    /// Lifts that are due a step up at the next session of each exercise.
    func liftGoals() -> [Goal] {
        liftRows().filter { $0.next.kind == .progress || $0.next.kind == .fixLoad }.prefix(4).map { row in
            let t = row.next.targets.first
            let load = t?.kg.map { Library.exercise(row.exerciseID).isBand ? Bands.text($0) : "\(Overload.kgText($0)) kg" }
            return Goal(id: "lift-\(row.exerciseID)", title: "\(row.name): \(load.map { "\($0) × \(t?.reps ?? 0)" } ?? "\(t?.reps ?? 0) reps")",
                        detail: row.next.reason, symbol: row.next.kind == .progress ? "arrow.up.right" : "equal", check: { _ in false })
        }
    }
}
