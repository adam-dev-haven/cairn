import Foundation

/// The "Wall & Bar — Starter Block", reworked into a split week: two hard
/// climbs, strength on its own days (bands at home, dumbbells and the bar
/// at the gym),
/// and pull kept 48 hours clear of the hard climbs. Everything here is
/// editable in the app afterwards.
enum DefaultPlan {
    static let revision = 2

    static func make(start: String = "2026-09-28") -> Plan {
        var plan = Plan(name: "Wall & Bar",
                        startDate: start,
                        weeks: weeks,
                        timeline: weeks.map { TimelineEntry(template: $0.id) },
                        days: days,
                        workouts: workouts)
        plan.points.greenWeek = 50
        plan.revision = revision
        return plan
    }

    private static func w(_ n: Int, _ phase: Phase, _ effort: String, _ focus: String, _ drill: String,
                          _ tipTitle: String, _ tipBody: String,
                          repeats: String, projects: String, main: Int, floor: Int, goal: Int) -> WeekTemplate {
        WeekTemplate(id: n, phase: phase, effort: effort, focus: focus, drillID: drill,
                     tip: Tip(title: tipTitle, body: tipBody),
                     gradeRepeats: repeats, gradeProjects: projects, mainBlockMinutes: main,
                     stepFloor: floor, stepGoal: goal)
    }

    static let weeks: [WeekTemplate] = [
        w(1, .foundation, "Stop 3 reps short", "Learn movement, easy grades, 2 sets per exercise. Rebuild the habit.", "falling",
          "Five numbers, that's all", "Monday is the warm-up, the ladder, a falling drill and five benchmark numbers written down. Tuesday is the first band push session. Nothing else is required of week one.",
          repeats: "V0–V2", projects: "Max 2 V3 per session", main: 15, floor: 7000, goal: 8000),
        w(2, .foundation, "Stop 3 reps short", "Same shape as week one. Show up; the grades will follow.", "silent-feet",
          "Log food this week too", "Weeks one and two are the only weeks you log everything. Two weeks of real data tells us your true maintenance.",
          repeats: "V0–V2", projects: "Max 2 V3 per session", main: 17, floor: 7000, goal: 8000),
        w(3, .foundation, "Stop 3 reps short", "Three sets per exercise from now on.", "straight-arms",
          "Protein only, from here", "From week three, log protein only — or repeat go-to meals you've already logged. Decisions made once, eaten many times.",
          repeats: "V0–V2", projects: "Max 2 V3 per session", main: 19, floor: 7000, goal: 8000),
        w(4, .foundation, "Stop 3 reps short", "Last Foundation week. Notice what's got easier.", "hips-wall",
          "Never miss twice", "One missed session is life. Two in a row is a pattern — the next thing on the calendar becomes the minimum version.",
          repeats: "V0–V2", projects: "Max 2 V3 per session", main: 21, floor: 7000, goal: 8000),
        w(5, .deload, "Stop 4 short", "Half the sets, same exercises. Climb only what feels easy.", "deload-fav",
          "A deload is not a week off", "You still go, you just do half. If you feel great this week, that's the deload working — not a sign to skip it.",
          repeats: "Easy only", projects: "None", main: 15, floor: 7000, goal: 8000),
        w(6, .build, "Stop 2 short", "3 sets everywhere, harder progressions, V3 projects allowed.", "flagging",
          "Skills step up", "Three sets everywhere, harder rungs on the skill ladders, and the bands go up a rung whenever the top of the range lands twice. Pull-ups go strict on Saturdays at the gym.",
          repeats: "V0–V3", projects: "Up to 3 projects, 5 tries each", main: 25, floor: 8000, goal: 9000),
        w(7, .build, "Stop 2 short", "Keep the numbers climbing, one rep at a time.", "drop-knee",
          "Daylight counts double", "Days get short fast from November. A midday walk puts light on your face, which helps mood.",
          repeats: "V0–V3", projects: "Up to 3 projects, 5 tries each", main: 25, floor: 8000, goal: 9000),
        w(8, .build, "Stop 2 short", "Heel hooks turn the RDLs into climbing.", "heel-hook",
          "Watch the elbows", "Inner-elbow ache is the classic climber complaint. Reverse wrist curls are the insurance: Tuesday, Friday and Sunday in the prehab block.",
          repeats: "V0–V3", projects: "Up to 3 projects, 5 tries each", main: 25, floor: 8000, goal: 9000),
        w(9, .build, "Stop 2 short", "Last Build week. Read before you climb.", "reading",
          "Novelty is fuel", "Ask the gym when they reset walls and treat reset day as an event. Once a month, climb somewhere new or with someone new.",
          repeats: "V0–V3", projects: "Up to 3 projects, 5 tries each", main: 25, floor: 8000, goal: 9000),
        w(10, .deload, "Stop 4 short", "Half the sets. Climb old problems with perfect feet.", "deload-feet",
          "Deloads count as green", "A deload done as written is a green week. Doing half is the whole assignment.",
          repeats: "Old problems", projects: "None", main: 15, floor: 8000, goal: 9000),
        w(11, .push, "Stop 1–2 short", "3–4 sets on the big movers, V4 attempts if V3s are going in fast.", "deadpoint",
          "V4 is allowed now", "Once V3s go in three tries or fewer, V4 attempts are on. Archer push-ups too.",
          repeats: "V1–V3", projects: "V4 once V3s go in ≤3 tries", main: 25, floor: 9000, goal: 10000),
        w(12, .push, "Stop 1–2 short", "Last hard week of the block. Make it count, then let it go.", "slab",
          "Pull-ups: 4 sets of 3", "The strict pull-up target is five clean reps by test week. Stop before the ugly rep, every set.",
          repeats: "V1–V3", projects: "V4 once V3s go in ≤3 tries", main: 25, floor: 9000, goal: 10000),
        w(13, .holiday, "Easy", "Gym likely shut Dec 24–26. Home sessions and long walks.", "holiday",
          "Holiday rules", "Home session, long walks, prehab. The block doesn't stop — it just moves into the living room.",
          repeats: "—", projects: "—", main: 0, floor: 9000, goal: 10000),
        w(14, .test, "—", "Retest every benchmark, then plan block two.", "test",
          "The summit", "Fresh, after the warm-up, one attempt each. Seeing the gap between week one and week fourteen is the biggest hit in the whole plan.",
          repeats: "Flash tests", projects: "—", main: 20, floor: 9000, goal: 10000),
    ]

    static let days: [DayPattern] = [
        // Mon: hard climb. Climb only; nothing that loads the hands afterwards.
        DayPattern(items: [PlannedItem(kind: .climb), PlannedItem(kind: .check)],
                   place: "Gym, morning", length: "60–75 min"),
        // Tue: push at home on the bands.
        DayPattern(items: [PlannedItem(kind: .home, workoutID: "A"), PlannedItem(kind: .prehab)],
                   place: "Home, evening", length: "35 min"),
        // Wed: aesthetic day at home; the morning climb is easy technique and optional.
        DayPattern(items: [PlannedItem(kind: .climb, optional: true), PlannedItem(kind: .home, workoutID: "D")],
                   place: "Easy climb + home", length: "30 min, climb optional"),
        // Thu: hard climb.
        DayPattern(items: [PlannedItem(kind: .climb), PlannedItem(kind: .walk)],
                   place: "Gym, morning", length: "60–75 min"),
        // Fri: legs, home or gym. No grip needed, so tired forearms don't matter.
        DayPattern(items: [PlannedItem(kind: .home, workoutID: "B"), PlannedItem(kind: .prehab)],
                   place: "Home or gym", length: "35 min"),
        // Sat: pull, 48 h after Thursday and 48 h before Monday.
        DayPattern(items: [PlannedItem(kind: .home, workoutID: "C"), PlannedItem(kind: .walk)],
                   place: "Gym or home", length: "40 min + walk"),
        // Sun: rest, with the ten-minute prehab block.
        DayPattern(items: [PlannedItem(kind: .prehab)], place: "Rest day", length: "Easy walk if you feel like it"),
    ]

    private static func pe(_ id: String, _ low: Int, _ high: Int, timed: Bool = false, perSide: Bool = false,
                           sets: Int? = nil, variant: String? = nil, more: [Scheme] = []) -> PlannedExercise {
        let base = Scheme(fromWeek: 1, variant: variant ?? Library.exercise(id).name, sets: sets, low: low, high: high, timed: timed)
        return PlannedExercise(exerciseID: id, schemes: [base] + more, perSide: perSide)
    }

    static let workouts: [Workout] = [
        Workout(id: "A", name: "Push", note: "Chest, shoulders, triceps. Bands on the door anchor. No pulling and no hard gripping today.", exercises: [
            pe("band-floor-press", 10, 15),
            pe("pushup", 8, 15, variant: "Push-up"),
            pe("band-ohp", 8, 12),
            pe("band-low-high-fly", 12, 15),
            pe("band-lateral-raise", 12, 20),
            pe("band-oh-triceps", 12, 15),
        ], isHome: true, minutes: 35),
        Workout(id: "D", name: "Aesthetic", note: "Delts, arms, abs, calves. Light on the hands, so it's safe the day before a hard climb.", exercises: [
            pe("band-rear-fly", 15, 20),
            pe("band-lateral-raise", 15, 25),
            pe("band-pushdown", 12, 20),
            pe("band-hammer-curl", 10, 15, sets: 2),
            pe("band-crunch", 12, 20),
            pe("pallof", 8, 12, perSide: true),
            pe("side-plank", 20, 40, timed: true, perSide: true,
               more: [Scheme(fromWeek: 6, variant: "Side plank, top leg lifted", low: 20, high: 40, timed: true)]),
            pe("band-calf-raise", 15, 25),
        ], isHome: true, minutes: 30),
        Workout(id: "B", name: "Legs", note: "No grip needed. Bands at home, or dumbbells at the gym: the switch is in the session.", exercises: [
            pe("band-squat", 10, 15),
            pe("band-good-morning", 10, 15),
            pe("split-squat", 8, 12, perSide: true),
            pe("glute-bridge", 10, 15, perSide: true, variant: "Single-leg glute bridge"),
            pe("hamstring-slide", 8, 12, perSide: true, sets: 2),
        ], isHome: true, gymExercises: [
            pe("goblet-squat", 8, 15),
            pe("db-rdl", 8, 12),
            pe("bss", 8, 12, perSide: true),
            pe("calf-raise", 12, 20, perSide: true),
            pe("hamstring-slide", 8, 12, perSide: true, sets: 2),
        ], minutes: 35),
        Workout(id: "C", name: "Pull", note: "Kept 48 h clear of the hard climbs and light on the elbows. Elbows amber? Straight-arm pulldown, face pull and pull-aparts only.", exercises: [
            pe("band-lat-pulldown", 10, 15),
            pe("band-row", 10, 15),
            pe("band-one-arm-row", 10, 15, perSide: true, sets: 2),
            pe("band-straight-arm", 12, 15),
            pe("band-face-pull", 15, 20),
            pe("pull-apart", 20, 20, sets: 2),
        ], isHome: true, gymExercises: [
            PlannedExercise(exerciseID: "pullup", schemes: [
                Scheme(fromWeek: 1, variant: "Negative pull-up (5 s down)", sets: 3, low: 3, high: 3),
                Scheme(fromWeek: 6, variant: "Strict pull-up", sets: 5, low: 2, high: 2, note: "4–5 sets of 2. Stop before the ugly rep."),
                Scheme(fromWeek: 11, variant: "Strict pull-up", sets: 4, low: 3, high: 3),
            ]),
            pe("inverted-row", 8, 12),
            pe("db-row", 8, 12, perSide: true),
            pe("band-straight-arm", 12, 15),
            pe("band-face-pull", 15, 20),
            pe("pull-apart", 20, 20, sets: 2),
        ], minutes: 40),
        Workout(id: "H", name: "Home", note: "30 minutes, bands only. Chaos version: push-ups, lunges, pull-aparts.", exercises: [
            PlannedExercise(exerciseID: "pushup", schemes: [Scheme(fromWeek: 1, variant: "Hardest push-up for 8+", sets: 3, low: 8, high: 15)]),
            PlannedExercise(exerciseID: "reverse-lunge", schemes: [Scheme(fromWeek: 1, variant: "Reverse lunge", sets: 3, low: 10, high: 15)], perSide: true),
            PlannedExercise(exerciseID: "glute-bridge", schemes: [Scheme(fromWeek: 1, variant: "Single-leg glute bridge", sets: 3, low: 10, high: 15)], perSide: true),
            PlannedExercise(exerciseID: "pull-apart", schemes: [Scheme(fromWeek: 1, variant: "Band pull-apart", sets: 3, low: 15, high: 20)]),
            PlannedExercise(exerciseID: "external-rotation", schemes: [Scheme(fromWeek: 1, variant: "Band external rotation", sets: 2, low: 15, high: 15)], perSide: true),
            PlannedExercise(exerciseID: "core-front", schemes: [
                Scheme(fromWeek: 1, variant: "Dead bug", sets: 2, low: 8, high: 8),
                Scheme(fromWeek: 6, variant: "Hollow hold", sets: 2, low: 20, high: 40, timed: true),
            ]),
        ], isHome: true, minutes: 30),
        Workout(id: "P", name: "Prehab", note: "Ten minutes on the floor. It doesn't need to feel like training. The wrist curls are the elbow insurance.", exercises: [
            PlannedExercise(exerciseID: "pull-apart", schemes: [Scheme(fromWeek: 1, variant: "Band pull-apart", sets: 2, low: 20, high: 20)]),
            PlannedExercise(exerciseID: "external-rotation", schemes: [Scheme(fromWeek: 1, variant: "Band external rotation", sets: 2, low: 15, high: 15)], perSide: true),
            PlannedExercise(exerciseID: "reverse-wrist", schemes: [Scheme(fromWeek: 1, variant: "Reverse wrist curl", sets: 2, low: 15, high: 20)]),
            PlannedExercise(exerciseID: "ecc-wrist", schemes: [Scheme(fromWeek: 1, variant: "Eccentric wrist curl", sets: 2, low: 10, high: 15)]),
            PlannedExercise(exerciseID: "pronator", schemes: [Scheme(fromWeek: 1, variant: "Pronator twist", sets: 2, low: 15, high: 15)], perSide: true),
            PlannedExercise(exerciseID: "finger-ext", schemes: [Scheme(fromWeek: 1, variant: "Finger extensions", sets: 2, low: 25, high: 25)]),
            PlannedExercise(exerciseID: "wrist-stretch", schemes: [Scheme(fromWeek: 1, variant: "Wrist flexor stretch", sets: 2, low: 30, high: 30, timed: true)], perSide: true),
        ], isHome: true, minutes: 8),
    ]
}

// MARK: - Side quests, missions, benchmarks

enum QuestTrail: String, CaseIterable {
    case wall, bar, body, habit
    var name: String {
        switch self {
        case .wall: "The wall"
        case .bar: "The bar"
        case .body: "Body"
        case .habit: "Habit"
        }
    }
}

struct Badge: Identifiable, Hashable {
    let id: String
    let name: String
    let detail: String
    let trail: QuestTrail
    let symbol: String
    /// The week this quest sits beside on the mountain.
    let nearWeek: Int
    /// Can only be ticked by hand (the app can't observe it).
    var manual = false
}

enum Quests {
    static let badges: [Badge] = [
        Badge(id: "base-camp", name: "Base Camp", detail: "Log your first session.", trail: .habit, symbol: "tent", nearWeek: 1),
        Badge(id: "first-fall", name: "First Fall", detail: "Five controlled falls, feet first.", trail: .wall, symbol: "arrow.down.to.line", nearWeek: 1),
        Badge(id: "silent-feet", name: "Silent Feet", detail: "A whole ladder without a sound from your shoes.", trail: .wall, symbol: "shoeprints.fill", nearWeek: 2, manual: true),
        Badge(id: "skeleton", name: "Skeleton", detail: "A V2 climbed with straight arms the whole way.", trail: .wall, symbol: "figure.stand", nearWeek: 3),
        Badge(id: "twenty-down", name: "Twenty Down", detail: "20 full push-ups, chest to floor.", trail: .bar, symbol: "20.circle", nearWeek: 4),
        Badge(id: "deload-discipline", name: "Half Is Whole", detail: "Finish a deload week as written.", trail: .habit, symbol: "leaf", nearWeek: 5),
        Badge(id: "flag-bearer", name: "Flag Bearer", detail: "A send that needed a flag.", trail: .wall, symbol: "flag", nearWeek: 6),
        Badge(id: "floor-week", name: "Floor Week", detail: "Step floor all seven days of a week.", trail: .body, symbol: "figure.walk", nearWeek: 6),
        Badge(id: "heel-hook", name: "Heel Hook Hero", detail: "A send that needed a heel hook.", trail: .wall, symbol: "shoe", nearWeek: 8),
        Badge(id: "protein-fortnight", name: "Protein Fortnight", detail: "180 g protein for 14 days in a row.", trail: .body, symbol: "fork.knife", nearWeek: 7),
        Badge(id: "four-green", name: "Four Green", detail: "Four green weeks in a row.", trail: .habit, symbol: "square.stack.3d.up", nearWeek: 4),
        Badge(id: "v3-flash", name: "First V3 Flash", detail: "A V3 first try, no beta watched.", trail: .wall, symbol: "bolt", nearWeek: 9),
        Badge(id: "hollow-man", name: "Hollow Man", detail: "60 s hollow hold.", trail: .bar, symbol: "timer", nearWeek: 9),
        Badge(id: "survived-november", name: "Survived November", detail: "Every week in November green.", trail: .habit, symbol: "cloud.rain", nearWeek: 10),
        Badge(id: "five-up", name: "Five Up", detail: "5 strict pull-ups.", trail: .bar, symbol: "5.circle", nearWeek: 12),
        Badge(id: "v4", name: "V4", detail: "Any V4, any number of tries.", trail: .wall, symbol: "mountain.2", nearWeek: 12),
        Badge(id: "new-wall", name: "New Wall", detail: "Climb at a different gym, or with someone new.", trail: .wall, symbol: "person.2", nearWeek: 7, manual: true),
        Badge(id: "summit", name: "Summit", detail: "Log the week-14 retest.", trail: .habit, symbol: "flag.checkered", nearWeek: 14),
    ]
    static let byID = Dictionary(uniqueKeysWithValues: badges.map { ($0.id, $0) })

    struct Mission: Identifiable, Hashable {
        enum Period { case week, month }
        let id: String
        let title: String
        let detail: String
        let period: Period
        let points: Int
        let symbol: String
    }

    static let missions: [Mission] = [
        Mission(id: "drill", title: "Make the drill boring", detail: "Do the drill of the week until it feels automatic, then tick it on a climbing log.", period: .week, points: 5, symbol: "repeat"),
        Mission(id: "never-twice", title: "Never miss twice", detail: "No two planned gym days missed in a row this week.", period: .week, points: 0, symbol: "link"),
        Mission(id: "floor-four", title: "Four floors", detail: "Hit the step floor on four days this week.", period: .week, points: 0, symbol: "figure.walk"),
        Mission(id: "reset-day", title: "Reset day", detail: "Climb on a wall-reset day — new problems, first go at all of them.", period: .month, points: 0, symbol: "sparkles"),
        Mission(id: "new-gym", title: "New wall, new people", detail: "Once a month, climb somewhere new or with someone new.", period: .month, points: 0, symbol: "person.2"),
    ]

    struct Benchmark: Identifiable, Hashable {
        let id: String
        let name: String
        let unit: String
    }

    static let benchmarks: [Benchmark] = [
        Benchmark(id: "pullups", name: "Strict pull-ups (dead hang, chin over bar)", unit: "reps"),
        Benchmark(id: "pushups", name: "Push-ups, chest to floor", unit: "reps"),
        Benchmark(id: "hang", name: "Active dead hang, shoulders down", unit: "s"),
        Benchmark(id: "hollow", name: "Hollow hold", unit: "s"),
        Benchmark(id: "goblet", name: "Goblet squat, reps at heaviest DB", unit: "reps"),
        Benchmark(id: "hardest", name: "Hardest problem sent", unit: "V"),
        Benchmark(id: "v2flash", name: "V2s flashed out of 5 tries", unit: "/5"),
        Benchmark(id: "weight", name: "7-day average weight", unit: "kg"),
        Benchmark(id: "waist", name: "Waist at navel", unit: "cm"),
        Benchmark(id: "steps", name: "Average daily steps, last 14 days", unit: "steps"),
    ]

    static let climbTags = ["Flag", "Heel hook", "Toe hook", "Drop knee", "Straight arms", "Silent feet", "Slab", "Mantle", "Deadpoint", "Overhang"]
}
