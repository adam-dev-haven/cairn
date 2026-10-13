import Foundation

// MARK: - Calisthenics skills

/// What opens a locked skill: another skill's step cleared, or a block week reached.
enum SkillReq: Hashable {
    case step(String, Int)
    case week(Int)
}

/// How to do one step of a skill, at home: what you need, the set-up, the
/// movement, what goes wrong, and photos where the free exercise database has them.
struct StepGuide: Hashable {
    let kit: String
    let setup: String
    let how: [String]
    let mistakes: [String]
    let photos: [String]
    let photoNote: String
}

/// A skill is a ladder of steps, each with a standard that clears it. The
/// ten to learn first live in LibraryBands.swift (generated from the approved
/// training reset); the harder ones below stay locked until their gate is met.
/// Chains follow the r/bodyweightfitness Recommended Routine (move on at
/// 3 × 8 clean reps) and the usual lever, handstand and L-sit progressions,
/// trimmed for a climber: no ring work that loads the biceps tendon, no back lever.
/// Every step is doable at home with the floor, a wall, a chair or sofa, a heavy
/// table, the five bands, the handles and the door anchor. No bar, no dip bars.
struct Skill: Identifiable, Hashable {
    struct Step: Hashable {
        let name: String
        let goal: String
        let cue: String
    }
    let id: String
    let name: String
    let group: MoveGroup
    let why: String
    let watch: String
    let steps: [Step]
    var symbol: String = "figure.strengthtraining.functional"
    /// Where a newcomer to this block starts.
    var start = 0
    /// Photo ids (see Photos).
    var photos: [String] = []
    /// The day it's practised, as a word ("Sat", "Sat (gym bars)").
    var day = ""
    /// 1…10 in the learn-first list; 0 for the locked tier.
    var rank = 0
    /// Empty for the ten to learn first; a locked skill opens when all are met.
    var requires: [SkillReq] = []
    var isLocked: Bool { !requires.isEmpty }
}

extension Library {
    /// The ten first, then the ones that need a gate.
    static let skills: [Skill] = topSkills + laterSkills

    static let laterSkills: [Skill] = [
        Skill(id: "dragon", name: "Dragon flag", group: .core,
              why: "The floor version of the lever: the whole body held straight from the shoulders. Everything on steep ground gets easier as it comes.",
              watch: "Rest on the upper back, never the neck. Needs a heavy sofa or bed to hold, and a mat.",
              steps: [
                .init(name: "Tuck dragon flag", goal: "3 × 5 s", cue: "Knees to the chest, hips and lower back lifted off the floor."),
                .init(name: "One-leg dragon flag", goal: "3 × 5 s per side", cue: "One leg straight, one tucked."),
                .init(name: "Dragon flag negative", goal: "3 × 3, 5 s down", cue: "Start straight at the top, lower as one plank."),
                .init(name: "Dragon flag", goal: "3 × 3", cue: "Straight body, lift and lower without folding at the hips."),
              ], symbol: "figure.core.training", day: "Wed", requires: [.step("legraise", 3), .step("hollow", 2)]),
        Skill(id: "hspu", name: "Handstand push-up", group: .push,
              why: "Overhead strength without a barbell. Continues the wall handstand work.",
              watch: "Any pinch at the front of the shoulder: back to pikes.",
              steps: [
                .init(name: "Pike push-up", goal: "3 × 8", cue: "Head lowers to a spot in front of the hands: a triangle."),
                .init(name: "Feet-elevated pike push-up", goal: "3 × 8", cue: "Feet on a chair seat, hips high over the hands."),
                .init(name: "Wall handstand negative", goal: "3 × 3, 5 s down", cue: "Back to the wall, lower the head to a cushion."),
                .init(name: "Partial wall HSPU", goal: "3 × 5", cue: "Down to a stack of books or a yoga block, press back up."),
                .init(name: "Wall handstand push-up", goal: "3 × 5", cue: "Full range, head touches the floor lightly."),
              ], requires: [.step("handstand", 2)]),
        Skill(id: "nordic", name: "Nordic curl", group: .legs,
              why: "Hamstrings for heel hooks, and the best knee-and-hamstring insurance there is.",
              watch: "Go slow; hamstrings stay sore for days at first.",
              steps: [
                .init(name: "Single-leg Romanian deadlift", goal: "3 × 8 per side", cue: "Hinge on one leg, back flat."),
                .init(name: "Banded Nordic curl", goal: "3 × 5", cue: "Band from above around the chest to take some weight."),
                .init(name: "Nordic negative", goal: "3 × 5", cue: "Heels anchored, lower as slowly as you can, catch with the hands."),
                .init(name: "Nordic curl", goal: "3 × 3", cue: "Down and back up without pushing off the floor."),
              ], symbol: "figure.cross.training", requires: [.week(6)]),
        Skill(id: "planche", name: "Planche", group: .push,
              why: "The long road from the push-up. The crow gives you the wrist and shoulder habits first.",
              watch: "Wrist pain on leans: warm the wrists and use handles.",
              steps: [
                .init(name: "Pseudo planche push-up", goal: "3 × 8", cue: "Hands by the hips, lean forward past them."),
                .init(name: "Planche lean", goal: "3 × 20 s", cue: "Arms straight, shoulders forward of the hands, protract."),
                .init(name: "Tuck planche", goal: "3 × 10 s", cue: "Knees to chest, feet off the floor. A long road; that's normal."),
              ], requires: [.step("crow", 3)]),
    ]

    static func skill(_ id: String) -> Skill? { skills.first { $0.id == id } }

    /// The home guide for one step of a skill.
    static func guide(_ skill: String, _ step: String) -> StepGuide? { stepGuides["\(skill)|\(step)"] }

    /// The drills you can learn, in teaching order. Deload, holiday and test
    /// weeks have their own "drills" that aren't skills to move through.
    static let drillOrder = ["falling", "silent-feet", "straight-arms", "hips-wall", "flagging",
                             "drop-knee", "heel-hook", "reading", "deadpoint", "slab"]
}

// MARK: - Model

extension AppModel {
    /// This date's bouldering drill: the one you picked, from the day you
    /// picked it; otherwise the plan's drill for the week.
    func drill(for date: Date) -> Library.Drill? {
        if let c = store.drillChoice, Day.key(date) >= c.since, let d = Library.drill(c.id) { return d }
        return blockWeek(for: date).flatMap { Library.drill($0.template.drillID) }
    }

    var currentDrill: Library.Drill? { drill(for: today) ?? Library.drill("falling") }

    func drillMastered(_ id: String) -> Bool { store.drillsMastered[id] != nil }

    /// The next drill to learn after this one: the next in teaching order
    /// you haven't cleared, wrapping round.
    func nextDrill(after id: String) -> Library.Drill? {
        let order = Library.drillOrder
        let start = order.firstIndex(of: id) ?? -1
        for k in 1...order.count {
            let cand = order[(start + k + order.count) % order.count]
            if cand != id && !drillMastered(cand) { return Library.drill(cand) }
        }
        return nil
    }

    /// "Got it": the drill is cleared and the next one starts today.
    func clearDrill(_ id: String) {
        let next = nextDrill(after: id)
        mutate { s in
            s.drillsMastered[id] = Day.key(now())
            s.drillChoice = next.map { DrillChoice(id: $0.id, since: Day.key(now())) }
        }
    }

    func chooseDrill(_ id: String) {
        mutate { $0.drillChoice = DrillChoice(id: id, since: Day.key(now())) }
    }

    func followPlanDrill() { mutate { $0.drillChoice = nil } }

    func unclearDrill(_ id: String) { mutate { $0.drillsMastered[id] = nil } }

    // Skills

    func skillStep(_ id: String) -> Int {
        let top = (Library.skill(id)?.steps.count ?? 1) - 1
        return max(0, min(top, store.skills[id] ?? Library.skill(id)?.start ?? 0))
    }

    /// Past the last step: the whole skill is done.
    func skillComplete(_ id: String) -> Bool {
        guard let sk = Library.skill(id) else { return false }
        return store.skillsCleared["\(id)@\(sk.steps.count - 1)"] != nil
    }

    /// The standard is met: mark the step cleared and move to the next.
    func clearSkillStep(_ id: String) {
        guard let sk = Library.skill(id) else { return }
        let step = skillStep(id)
        mutate { s in
            s.skillsCleared["\(id)@\(step)"] = Day.key(now())
            s.skills[id] = min(sk.steps.count - 1, step + 1)
        }
    }

    func setSkillStep(_ id: String, _ step: Int) {
        guard let sk = Library.skill(id) else { return }
        mutate { s in
            let v = max(0, min(sk.steps.count - 1, step))
            s.skills[id] = v
            // Stepping back reopens the steps above.
            for k in v..<sk.steps.count { s.skillsCleared["\(id)@\(k)"] = nil }
        }
    }

    func toggleFocus(_ id: String) {
        if !store.skillFocus.contains(id), let sk = Library.skill(id), !skillUnlocked(sk) { return }
        mutate { s in
            if s.skillFocus.contains(id) { s.skillFocus.removeAll { $0 == id } } else { s.skillFocus.append(id) }
        }
    }

    func requirementMet(_ r: SkillReq) -> Bool {
        switch r {
        case .step(let id, let n): return store.skillsCleared["\(id)@\(n)"] != nil
        case .week(let n): return (blockWeek(for: today)?.number ?? (finished ? 99 : 0)) >= n
        }
    }

    func skillUnlocked(_ s: Skill) -> Bool { s.requires.allSatisfy(requirementMet) }

    func requirementText(_ r: SkillReq) -> String {
        switch r {
        case .step(let id, let n):
            let sk = Library.skill(id)
            return "\(sk?.name ?? id): \(sk?.steps[safe: n]?.name.lowercased() ?? "step \(n + 1)") cleared"
        case .week(let n): return "reach week \(n)"
        }
    }

    var focusSkills: [Skill] { store.skillFocus.compactMap(Library.skill) }
}
