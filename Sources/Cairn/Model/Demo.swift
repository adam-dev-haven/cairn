import Foundation

/// Synthetic logs for design review only (CAIRN_DEMO=1 with an empty store).
/// Never runs against real data: the store must have no sessions.
enum Demo {
    static func seed(_ m: AppModel) {
        var rng = SeededRandom(seed: 42)
        let end = m.today
        var day = m.startDate
        while day < end {
            let items = m.plannedItems(for: day)
            let skip = rng.next() < 0.12
            for item in items where !skip {
                switch item.kind {
                case .climb:
                    let w = m.blockWeek(for: day)?.number ?? 1
                    var log = SessionLog(day: Day.key(day), kind: .climb)
                    let top = min(4, 1 + w / 3)
                    var c = ClimbLog()
                    for _ in 0..<Int(rng.next(6, 11)) {
                        let g = Int(rng.next(0, Double(top) + 0.99))
                        let tries = g >= top - 1 ? Int(rng.next(1, 4)) : 1
                        var tags: [String] = []
                        if rng.next() < 0.15 { tags.append(Quests.climbTags[Int(rng.next(0, 6))]) }
                        c.problems.append(Problem(grade: g, attempts: tries, sent: rng.next() > 0.15, tags: tags))
                    }
                    if w == 1 { c.falls = 5 }
                    c.drillBoring = rng.next() < 0.4
                    log.climb = c
                    log.energy = Int(rng.next(2, 5.9))
                    m.store.sessions.append(log)
                case .workout, .home, .prehab:
                    var log = m.draft(for: item, on: day)
                    for i in log.exercises.indices {
                        for k in log.exercises[i].sets.indices {
                            let ex = log.exercises[i]
                            log.exercises[i].sets[k].value = min(ex.high, ex.sets[k].value + (rng.next() < 0.5 ? 1 : 0))
                            if Library.exercise(ex.exerciseID).usesKg && log.exercises[i].sets[k].kg == nil {
                                log.exercises[i].sets[k].kg = [8, 10, 12, 14][Int(rng.next(0, 3.99))]
                            }
                            log.exercises[i].sets[k].done = true
                        }
                    }
                    m.store.sessions.append(log)
                case .walk:
                    let w = m.blockWeek(for: day)?.template.stepFloor ?? 7000
                    m.store.daily[Day.key(day), default: DayLog()].steps = Int(rng.next(Double(w) - 2500, Double(w) + 3500))
                default: break
                }
            }
            m.store.daily[Day.key(day), default: DayLog()].protein = rng.next() < 0.7
            if m.store.daily[Day.key(day)]?.steps == nil {
                m.store.daily[Day.key(day), default: DayLog()].steps = Int(rng.next(3000, 11000))
            }
            day = Day.add(1, to: day)
        }
        m.store.goals = [SideGoal(title: "Send the purple V3 in the cave", byWeek: 9),
                         SideGoal(title: "Climb once with a friend", byWeek: 6, done: Day.key(Day.add(20, to: m.startDate)))]
        m.store.benchmarks["pullups"] = BenchmarkEntry(start: "3")
        m.store.benchmarks["pushups"] = BenchmarkEntry(start: "14")
        m.refreshBadges()
        m.save()
    }
}
