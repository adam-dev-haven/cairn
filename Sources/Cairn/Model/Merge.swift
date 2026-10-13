import Foundation

/// Change stamps for merging two copies of a store (Mac and iPhone).
///
/// High-traffic records — sessions and days — are stamped one by one, so the
/// phone logging a climb and the Mac importing steps never collide. Everything
/// else is stamped by section, and the newer section wins whole. Deleted
/// sessions leave a tombstone so a delete on one device isn't undone by the
/// other device still having the record.
struct SyncMeta: Codable, Hashable {
    var sections: [String: Date] = [:]
    var sessions: [String: Date] = [:]
    var daily: [String: Date] = [:]
    var deletedSessions: [String: Date] = [:]

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        sections = try c.decodeIfPresent([String: Date].self, forKey: .sections) ?? [:]
        sessions = try c.decodeIfPresent([String: Date].self, forKey: .sessions) ?? [:]
        daily = try c.decodeIfPresent([String: Date].self, forKey: .daily) ?? [:]
        deletedSessions = try c.decodeIfPresent([String: Date].self, forKey: .deletedSessions) ?? [:]
    }
}

/// Settings that belong to the person and travel between devices. The watch
/// folder is about one Mac and stays put.
struct SharedSettings: Hashable {
    var adaptMode: AdaptMode
    var missed: Int
    var sick: Int
    var nudge: Int
    var tips: Bool
    var useCircuits: Bool
    var circuits: [GradeCircuit]
    var scale: GradeScale
    var weightStep: Double
    var schedule: ScheduleRules
    var coachModel: String
    var coachEffort: String

    init(_ s: Settings) {
        adaptMode = s.adaptMode; missed = s.missedGymDaysToRepeat; sick = s.sickDaysForReturnWeek
        nudge = s.daysAwayNudge; tips = s.showTips
        useCircuits = s.useCircuits; circuits = s.circuits; scale = s.gradeScale
        weightStep = s.weightStepKg; schedule = s.schedule; coachModel = s.coachModel; coachEffort = s.coachEffort
    }

    func apply(to s: inout Settings) {
        s.adaptMode = adaptMode; s.missedGymDaysToRepeat = missed; s.sickDaysForReturnWeek = sick
        s.daysAwayNudge = nudge; s.showTips = tips
        s.useCircuits = useCircuits; s.circuits = circuits; s.gradeScale = scale
        s.weightStepKg = weightStep; s.schedule = schedule; s.coachModel = coachModel; s.coachEffort = coachEffort
    }
}

enum Merge {
    // Each section: how to read it for comparison, and how to copy it across.
    private struct Section {
        let key: String
        let same: (Store, Store) -> Bool
        let copy: (Store, inout Store) -> Void
    }

    private static let sections: [Section] = [
        Section(key: "plan",
                same: { $0.plan == $1.plan && $0.adaptations == $1.adaptations && $0.pending == $1.pending && $0.evaluatedThrough == $1.evaluatedThrough },
                copy: { from, to in to.plan = from.plan; to.adaptations = from.adaptations; to.pending = from.pending; to.evaluatedThrough = from.evaluatedThrough }),
        Section(key: "quests",
                same: { $0.badges == $1.badges && $0.revokedBadges == $1.revokedBadges && $0.missions == $1.missions && $0.drillsMastered == $1.drillsMastered && $0.goals == $1.goals && $0.drillChoice == $1.drillChoice },
                copy: { from, to in to.badges = from.badges; to.revokedBadges = from.revokedBadges; to.missions = from.missions; to.drillsMastered = from.drillsMastered; to.goals = from.goals; to.drillChoice = from.drillChoice }),
        Section(key: "benchmarks", same: { $0.benchmarks == $1.benchmarks }, copy: { from, to in to.benchmarks = from.benchmarks }),
        Section(key: "rungs", same: { $0.rungs == $1.rungs && $0.skills == $1.skills && $0.skillsCleared == $1.skillsCleared && $0.skillFocus == $1.skillFocus && $0.skillLadder == $1.skillLadder && $0.bandLadder == $1.bandLadder },
                copy: { from, to in to.rungs = from.rungs; to.skills = from.skills; to.skillsCleared = from.skillsCleared; to.skillFocus = from.skillFocus; to.skillLadder = from.skillLadder; to.bandLadder = from.bandLadder }),
        Section(key: "schedule", same: { $0.dayChanges == $1.dayChanges && $0.loadSet == $1.loadSet && $0.dismissedSchedule == $1.dismissedSchedule },
                copy: { from, to in to.dayChanges = from.dayChanges; to.loadSet = from.loadSet; to.dismissedSchedule = from.dismissedSchedule }),
        Section(key: "coach", same: { $0.coach == $1.coach }, copy: { from, to in to.coach = from.coach }),
        Section(key: "settings", same: { SharedSettings($0.settings) == SharedSettings($1.settings) },
                copy: { from, to in SharedSettings(from.settings).apply(to: &to.settings) }),
    ]

    /// Record what changed between the last write and now.
    static func stamp(from old: Store, to new: inout Store, at now: Date) {
        for s in sections where !s.same(old, new) { new.meta.sections[s.key] = now }

        let before = Dictionary(old.sessions.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        var seen = Set<String>()
        for session in new.sessions {
            let id = session.id.uuidString
            seen.insert(id)
            if before[id] != session { new.meta.sessions[id] = now }
        }
        for id in before.keys where !seen.contains(id) {
            new.meta.deletedSessions[id] = now
            new.meta.sessions[id] = nil
        }

        for key in Set(old.daily.keys).union(new.daily.keys) where old.daily[key] != new.daily[key] {
            new.meta.daily[key] = now
        }
    }

    /// Merge `remote` into `local`. The newer stamp wins; on a tie (or when
    /// neither side stamped it, as with data from before sync existed) the
    /// local copy stays.
    static func merge(local: Store, remote: Store) -> Store {
        var out = local
        func newer(_ r: Date?, than l: Date?) -> Bool { (r ?? .distantPast) > (l ?? .distantPast) }

        for s in sections where newer(remote.meta.sections[s.key], than: local.meta.sections[s.key]) {
            s.copy(remote, &out)
            out.meta.sections[s.key] = remote.meta.sections[s.key]
        }

        // Sessions, record by record, with tombstones.
        var deleted = local.meta.deletedSessions
        for (id, d) in remote.meta.deletedSessions where newer(d, than: deleted[id]) { deleted[id] = d }
        let l = Dictionary(local.sessions.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        let r = Dictionary(remote.sessions.map { ($0.id.uuidString, $0) }, uniquingKeysWith: { a, _ in a })
        var sessions: [SessionLog] = []
        var stamps: [String: Date] = [:]
        for id in Set(l.keys).union(r.keys) {
            let ls = local.meta.sessions[id], rs = remote.meta.sessions[id]
            let pick: SessionLog
            let stamp: Date?
            if let rv = r[id], l[id] == nil || newer(rs, than: ls) { pick = rv; stamp = rs } else { pick = l[id]!; stamp = ls }
            if let d = deleted[id], !newer(stamp, than: d) { continue }   // deleted after its last edit
            sessions.append(pick)
            if let stamp { stamps[id] = stamp }
        }
        out.sessions = sessions.sorted { $0.day == $1.day ? $0.id.uuidString < $1.id.uuidString : $0.day < $1.day }
        out.meta.sessions = stamps
        out.meta.deletedSessions = deleted.filter { stamps[$0.key] == nil || !newer(stamps[$0.key], than: $0.value) }

        // Days, one by one.
        for (key, day) in remote.daily {
            let rs = remote.meta.daily[key], ls = local.meta.daily[key]
            if local.daily[key] == nil || newer(rs, than: ls) {
                out.daily[key] = day
                if let rs { out.meta.daily[key] = rs }
            }
        }

        // Watch imports: a set, so union.
        out.importedGarmin = Array(Set(local.importedGarmin).union(remote.importedGarmin)).sorted()
        return out
    }
}
