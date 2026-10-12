import Foundation

/// Profiles: each one is a whole Cairn — its own plan, logs, quests and
/// settings — in its own file. The first profile keeps the original
/// `cairn.json`, so nothing moves for existing data.
struct Profile: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var created: String
}

struct ProfileIndex: Codable, Hashable {
    var active = "main"
    var profiles = [Profile(id: "main", name: ProfileIndex.defaultName, created: Day.key(Date()))]

    static var defaultName: String {
        NSFullUserName().split(separator: " ").first.map(String.init) ?? "Me"
    }

    static func file(for id: String, in dir: URL) -> URL {
        dir.appendingPathComponent(id == "main" ? "cairn.json" : "cairn-\(id).json")
    }

    static func load(from dir: URL) -> ProfileIndex {
        let url = dir.appendingPathComponent("profiles.json")
        if let data = try? Data(contentsOf: url), let index = try? JSONDecoder().decode(ProfileIndex.self, from: data),
           index.profiles.contains(where: { $0.id == index.active }) {
            return index
        }
        return ProfileIndex()
    }

    func save(to dir: URL) {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(self) {
            try? data.write(to: dir.appendingPathComponent("profiles.json"), options: .atomic)
        }
    }

    var activeProfile: Profile { profiles.first { $0.id == active } ?? profiles[0] }
}

enum ResetScope: String, CaseIterable, Identifiable {
    case quests, benchmarks, logs, plan, everything
    var id: String { rawValue }

    var title: String {
        switch self {
        case .quests: "Side quests and missions"
        case .benchmarks: "Benchmarks"
        case .logs: "Sessions and daily logs"
        case .plan: "Plan and timing"
        case .everything: "Everything in this profile"
        }
    }

    var detail: String {
        switch self {
        case .quests: "Unplants every flag and clears missions, mastered drills and your own goals. Quests your logs still show will plant again."
        case .benchmarks: "Empties the week 1 and week 14 columns."
        case .logs: "Removes every session, step count, protein tick, weight and sick day. Watch sessions come back on the next sync."
        case .plan: "Back to the Wall & Bar defaults: the 14 weeks, your week, workouts, points and step floors. Repeats and return weeks are cleared. Logs stay."
        case .everything: "A fresh start for this profile. Sync settings and the data folder are kept."
        }
    }
}

extension AppModel {
    // MARK: Resets

    /// Every reset writes a snapshot first, so it can be undone.
    func reset(_ scope: ResetScope) {
        snapshotBeforeReset()
        mutate { s in
            switch scope {
            case .quests:
                s.badges = [:]; s.revokedBadges = []; s.missions = [:]; s.drillsMastered = [:]; s.goals = []
            case .benchmarks:
                s.benchmarks = [:]
            case .logs:
                s.sessions = []; s.daily = [:]; s.importedGarmin = []
            case .plan:
                s.plan = DefaultPlan.make(start: s.plan.startDate)
                s.evaluatedThrough = -1; s.pending = nil; s.adaptations = []
            case .everything:
                let keep = s.settings, meta = s.meta
                s = Store(plan: DefaultPlan.make(start: s.plan.startDate))
                s.settings = keep
                s.meta = meta
            }
        }
        notice = "\(scope.title) reset. Undo is in Settings → Reset."
    }

    private func snapshotBeforeReset() {
        guard let fileURL, loadError == nil else { return }
        save()
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let snap = fileURL.deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.deletingPathExtension().lastPathComponent).before-reset-\(stamp).json")
        try? FileManager.default.copyItem(at: fileURL, to: snap)
        lastResetSnapshot = snap
    }

    func undoLastReset() {
        guard let snap = lastResetSnapshot, let data = try? Data(contentsOf: snap),
              let restored = try? JSONDecoder().decode(Store.self, from: data) else { return }
        store = restored
        save()
        lastResetSnapshot = nil
        notice = "Reset undone."
    }

    // MARK: Profiles

    func switchProfile(_ id: String) {
        guard id != profiles.active, profiles.profiles.contains(where: { $0.id == id }) else { return }
        save()
        profiles.active = id
        profiles.save(to: Self.dataDirectory())
        lastResetSnapshot = nil
        open(profile: id)
        refreshBadges()
        evaluateAdaptation()
    }

    @discardableResult
    func createProfile(name: String, start: Date) -> String {
        let id = UUID().uuidString.prefix(8).lowercased()
        let clean = name.trimmingCharacters(in: .whitespaces)
        profiles.profiles.append(Profile(id: String(id), name: clean.isEmpty ? "New profile" : clean, created: Day.key(now())))
        // Write the new store before switching, so it starts on the chosen Monday.
        var s = Store(plan: DefaultPlan.make(start: Day.key(Day.monday(of: start))))
        s.settings.garminFolder = store.settings.garminFolder
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? enc.encode(s).write(to: ProfileIndex.file(for: String(id), in: Self.dataDirectory()), options: .atomic)
        profiles.save(to: Self.dataDirectory())
        switchProfile(String(id))
        return String(id)
    }

    func renameProfile(_ id: String, to name: String) {
        guard let i = profiles.profiles.firstIndex(where: { $0.id == id }) else { return }
        let clean = name.trimmingCharacters(in: .whitespaces)
        guard !clean.isEmpty else { return }
        profiles.profiles[i].name = clean
        profiles.save(to: Self.dataDirectory())
    }

    /// Removes a profile from the list. Its file is kept aside, renamed, not deleted.
    func removeProfile(_ id: String) {
        guard id != profiles.active, profiles.profiles.count > 1 else { return }
        let dir = Self.dataDirectory()
        let url = ProfileIndex.file(for: id, in: dir)
        let stamp = Int(Date().timeIntervalSince1970)
        try? FileManager.default.moveItem(at: url, to: url.deletingPathExtension().appendingPathExtension("removed-\(stamp).json"))
        profiles.profiles.removeAll { $0.id == id }
        profiles.save(to: dir)
    }
}
