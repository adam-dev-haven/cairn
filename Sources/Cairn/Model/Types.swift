import Foundation

// MARK: - Calendar helpers

/// Every day in Cairn is a local calendar day, keyed "yyyy-MM-dd". Times of
/// day never matter here, and string keys survive time-zone travel.
enum Day {
    static var calendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        c.firstWeekday = 2
        return c
    }()

    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .iso8601)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func key(_ date: Date) -> String { keyFormatter.string(from: date) }
    static func date(_ key: String) -> Date? { keyFormatter.date(from: key) }
    static func start(_ date: Date) -> Date { calendar.startOfDay(for: date) }
    static func add(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: start(date))!
    }
    static func between(_ a: Date, _ b: Date) -> Int {
        calendar.dateComponents([.day], from: start(a), to: start(b)).day ?? 0
    }
    /// 1 = Monday … 7 = Sunday.
    static func weekday(_ date: Date) -> Int {
        let w = calendar.component(.weekday, from: date) // 1 = Sunday
        return w == 1 ? 7 : w - 1
    }
    static func monday(of date: Date) -> Date { add(-(weekday(date) - 1), to: date) }

    static let weekdayShort = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let weekdayLetter = ["M", "T", "W", "T", "F", "S", "S"]
    static let weekdayLong = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
    static func long(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

// MARK: - Plan

enum Phase: String, Codable, CaseIterable, Identifiable {
    case foundation, deload, build, push, holiday, test, recovery
    var id: String { rawValue }

    var name: String {
        switch self {
        case .foundation: "Foundation"
        case .deload: "Deload"
        case .build: "Build"
        case .push: "Push"
        case .holiday: "Holiday"
        case .test: "Test"
        case .recovery: "Return"
        }
    }

    /// Deload-shaped weeks halve the sets.
    var halvesSets: Bool { self == .deload || self == .recovery }
    /// Weeks the adaptation engine never repeats.
    var isFixed: Bool { self == .holiday || self == .test }
}

enum ItemKind: String, Codable, CaseIterable, Identifiable {
    case climb, workout, home, walk, prehab, check, rest
    var id: String { rawValue }

    var name: String {
        switch self {
        case .climb: "Boulder"
        case .workout: "Calisthenics"
        case .home: "Strength session"
        case .walk: "Walk"
        case .prehab: "Prehab"
        case .check: "Monday check"
        case .rest: "Rest"
        }
    }

    var symbol: String {
        switch self {
        case .climb: "figure.climbing"
        case .workout: "figure.strengthtraining.functional"
        case .home: "figure.core.training"
        case .walk: "figure.walk"
        case .prehab: "hand.raised"
        case .check: "scalemass"
        case .rest: "moon.zzz"
        }
    }

    /// Items that need the gym. These are what "missed a gym day" counts.
    var isGym: Bool { self == .climb || self == .workout }
}

struct PlannedItem: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: ItemKind
    var workoutID: String? = nil
    /// Nice to have, never missed: an optional climb doesn't count toward
    /// "missed gym days" and never leads the day.
    var optional: Bool? = nil
    /// Brought here from another day of this week (day key), so the day can say so.
    var from: String? = nil
    /// An extra: the same session added again after it was already done this week.
    var extra: Bool? = nil

    var isOptional: Bool { optional ?? false }
    /// The same kind of session, whichever day it sits on.
    var templateKey: String { "\(kind.rawValue)-\(workoutID ?? "")-\(isOptional ? "o" : "h")" }
    /// A gym session the week is judged on.
    var countsAsGym: Bool { kind.isGym && !isOptional }
}

struct DayPattern: Codable, Hashable {
    var items: [PlannedItem]
    var place: String
    var length: String
}

/// What was changed on one calendar day, on top of the week's pattern: a
/// session brought in from another day, or taken off. Only that date is
/// touched; next week's pattern is as it was.
struct DayChange: Codable, Hashable {
    var added: [PlannedItem] = []
    /// Ids of pattern items taken off this day.
    var hidden: [UUID] = []
    var isEmpty: Bool { added.isEmpty && hidden.isEmpty }
}

struct Tip: Codable, Hashable {
    var title: String
    var body: String
}

struct WeekTemplate: Codable, Hashable, Identifiable {
    var id: Int                 // block week 1…14
    var phase: Phase
    var effort: String          // reps in reserve, in words
    var focus: String
    var drillID: String
    var tip: Tip
    var gradeRepeats: String
    var gradeProjects: String
    var mainBlockMinutes: Int
    var stepFloor: Int
    var stepGoal: Int
}

/// One calendar week of the actual climb. The plan's fourteen templates are
/// laid out here in order; when a week repeats or a return week is inserted,
/// the timeline grows and everything after it slides seven days.
struct TimelineEntry: Codable, Hashable, Identifiable {
    enum Reason: String, Codable { case planned, repeated, recovery, pushedBack }
    var id = UUID()
    var template: Int
    var reason: Reason = .planned
}

/// "From block week N, this exercise is done this way." Lets a slot change
/// variation across the block (pike hold → pike push-up, negatives → strict).
struct Scheme: Codable, Hashable {
    var fromWeek: Int
    var variant: String
    var sets: Int?          // nil → the block's default set count
    var low: Int
    var high: Int
    var timed: Bool = false
    var note: String = ""
}

struct PlannedExercise: Codable, Hashable, Identifiable {
    var id = UUID()
    var exerciseID: String
    var schemes: [Scheme]
    var perSide: Bool = false

    func scheme(forWeek week: Int) -> Scheme {
        schemes.filter { $0.fromWeek <= week }.max { $0.fromWeek < $1.fromWeek } ?? schemes[0]
    }
}

struct Workout: Codable, Hashable, Identifiable {
    var id: String          // "A", "B", "C", "H"
    var name: String
    var note: String
    var exercises: [PlannedExercise]
    var isHome: Bool = false
    /// The same session with dumbbells and the bar, for days at the gym.
    /// nil means there is only one version.
    var gymExercises: [PlannedExercise]? = nil
    var minutes: Int? = nil
}

struct PointsTable: Codable, Hashable {
    var gymSession = 10
    var homeSession = 6
    var prehab = 2
    var stepFloor = 2
    var stepGoalBonus = 1
    var protein = 1
    var newHardestSend = 5
    var drillBoring = 5
    var greenWeek = 45
}

struct Plan: Codable, Hashable {
    var name: String
    var startDate: String       // Monday of block week 1
    var weeks: [WeekTemplate]
    var timeline: [TimelineEntry]
    var days: [DayPattern]      // Mon…Sun
    var workouts: [Workout]
    var points = PointsTable()
    var proteinTarget = 180
    var kcalTarget = 2400
    /// 1 = the original Wall & Bar week (climb + calisthenics the same day);
    /// 2 = the split week (see AppModel.migratePlan).
    var revision = 1

    init(name: String, startDate: String, weeks: [WeekTemplate], timeline: [TimelineEntry],
         days: [DayPattern], workouts: [Workout]) {
        self.name = name; self.startDate = startDate; self.weeks = weeks
        self.timeline = timeline; self.days = days; self.workouts = workouts
    }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        startDate = try c.decode(String.self, forKey: .startDate)
        weeks = try c.decode([WeekTemplate].self, forKey: .weeks)
        timeline = try c.decode([TimelineEntry].self, forKey: .timeline)
        days = try c.decode([DayPattern].self, forKey: .days)
        workouts = try c.decode([Workout].self, forKey: .workouts)
        points = try c.decodeIfPresent(PointsTable.self, forKey: .points) ?? PointsTable()
        proteinTarget = try c.decodeIfPresent(Int.self, forKey: .proteinTarget) ?? 180
        kcalTarget = try c.decodeIfPresent(Int.self, forKey: .kcalTarget) ?? 2400
        revision = try c.decodeIfPresent(Int.self, forKey: .revision) ?? 1
    }
}

// MARK: - Logs

enum Source: String, Codable { case manual, garmin }

struct Problem: Codable, Hashable, Identifiable {
    var id = UUID()
    /// V grade. With colour circuits this is the circuit's lowest V, so caps
    /// and quests stay conservative (a green V0–V3 never counts as a V3).
    var grade: Int
    var attempts: Int = 1
    var sent: Bool = true
    var tags: [String] = []
    /// The gym colour it was logged as, when the gym grades by colour.
    var circuit: String? = nil
    /// The exact Font grade (index into GradeScale.fontNames) when logged in
    /// Font; `grade` then holds its V conversion.
    var font: Int? = nil

    var flash: Bool { sent && attempts == 1 }
}

struct ClimbLog: Codable, Hashable {
    var problems: [Problem] = []
    var falls: Int = 0
    var drillBoring = false
    var wallNote = ""

    var sends: [Problem] { problems.filter(\.sent) }
    var hardestSend: Int? { sends.map(\.grade).max() }
}

struct SetEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var value: Int          // reps, or seconds when timed
    var kg: Double? = nil
    var done: Bool = false
}

struct ExerciseLog: Codable, Hashable, Identifiable {
    var id = UUID()
    var exerciseID: String
    var variant: String
    var timed: Bool
    var low: Int
    var high: Int
    var sets: [SetEntry]

    var doneSets: [SetEntry] { sets.filter(\.done) }
    var best: Int { doneSets.map(\.value).max() ?? 0 }
    var topLoad: Double? { doneSets.compactMap(\.kg).max() }
    var hitTopOfRange: Bool { !doneSets.isEmpty && doneSets.count == sets.count && doneSets.allSatisfy { $0.value >= high } }
}

enum BodyArea: String, Codable, CaseIterable, Identifiable {
    case fingers, wrists, elbows, shoulders, skin, other
    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

struct PainEntry: Codable, Hashable, Identifiable {
    var id = UUID()
    var area: BodyArea
    var score: Int

    var light: PainLight { PainLight(score: score) }
}

enum PainLight: String {
    case green, amber, red
    init(score: Int) { self = score >= 5 ? .red : score >= 3 ? .amber : .green }
}

/// Why a planned session didn't happen.
enum SkipReason: String, Codable, CaseIterable, Identifiable {
    case sick, time, tired, pain, other
    var id: String { rawValue }
    var name: String {
        switch self {
        case .sick: "Sick"
        case .time: "No time"
        case .tired: "Too tired"
        case .pain: "Pain or injury"
        case .other: "Something else"
        }
    }
    var symbol: String {
        switch self {
        case .sick: "bandage"
        case .time: "clock"
        case .tired: "battery.25percent"
        case .pain: "cross.case"
        case .other: "ellipsis"
        }
    }
}

struct SessionLog: Codable, Hashable, Identifiable {
    var id = UUID()
    var day: String
    var kind: ItemKind
    var workoutID: String? = nil
    var climb: ClimbLog? = nil
    var exercises: [ExerciseLog] = []
    var pain: [PainEntry] = []
    var energy: Int? = nil          // 1…5
    var note = ""
    var minimum = false             // the doorway rule: warm-up + ladder only
    var minutes: Int? = nil
    var avgHr: Int? = nil
    var source: Source = .manual
    var garminID: String? = nil
    /// false while you're still logging, true once you press Finish. nil on
    /// logs from before Finish existed, which count as finished.
    var finished: Bool? = false
    /// Set when the session didn't happen, with the reason.
    var skip: SkipReason? = nil
    /// Calisthenics skills practised in this session.
    var skills: [String]? = nil
    /// Strength sessions: done with the gym version of the exercises.
    var atGym: Bool? = nil

    var date: Date { Day.date(day) ?? .distantPast }
    var isFinished: Bool { finished ?? true }
}

struct DayLog: Codable, Hashable {
    var steps: Int? = nil
    var protein = false
    var sick = false
    var weightKg: Double? = nil
    var waistCm: Double? = nil
    /// What was actually eaten, when the day's food was logged.
    var proteinG: Int? = nil
    var kcal: Int? = nil
    /// Today's elbow check-in: 1 fine, 3 ache, 5 sharp (the pain traffic light).
    var elbow: Int? = nil
    /// Fields you set by hand ("steps", "protein", "weight"). An import never
    /// overwrites these: typed wins.
    var typed: Set<String> = []

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        steps = try c.decodeIfPresent(Int.self, forKey: .steps)
        protein = try c.decodeIfPresent(Bool.self, forKey: .protein) ?? false
        sick = try c.decodeIfPresent(Bool.self, forKey: .sick) ?? false
        weightKg = try c.decodeIfPresent(Double.self, forKey: .weightKg)
        waistCm = try c.decodeIfPresent(Double.self, forKey: .waistCm)
        proteinG = try c.decodeIfPresent(Int.self, forKey: .proteinG)
        kcal = try c.decodeIfPresent(Int.self, forKey: .kcal)
        elbow = try c.decodeIfPresent(Int.self, forKey: .elbow)
        typed = try c.decodeIfPresent(Set<String>.self, forKey: .typed) ?? []
    }
}

// MARK: - Progress state

struct AdaptationEvent: Codable, Hashable, Identifiable {
    var id = UUID()
    var day: String
    var message: String
    var previousTimeline: [TimelineEntry]
    var undone = false
}

struct PendingAdaptation: Codable, Hashable {
    var message: String
    var proposed: [TimelineEntry]
    var evaluatedIndex: Int
}

struct SideGoal: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var byWeek: Int?
    var done: String? = nil         // day key
}

struct BenchmarkEntry: Codable, Hashable {
    var start: String = ""
    var end: String = ""
}

enum AdaptMode: String, Codable, CaseIterable, Identifiable {
    case automatic, ask, off
    var id: String { rawValue }
    var name: String {
        switch self {
        case .automatic: "Adjust automatically"
        case .ask: "Ask me first"
        case .off: "Never adjust"
        }
    }
}

struct Settings: Codable, Hashable {
    var adaptMode: AdaptMode = .automatic
    var missedGymDaysToRepeat = 2
    var sickDaysForReturnWeek = 3
    var daysAwayNudge = 5
    /// Folder holding an exported `manifest.json` of watch activities. Empty = not connected.
    var garminFolder = ""
    var gymName = ""
    var showTips = true
    var weightUnitKg = true
    var autoSync = true
    /// The gym grades by colour circuits instead of V grades.
    var useCircuits = false
    var circuits: [GradeCircuit] = []
    /// V or Font: how grades are shown and logged when not using colours,
    /// and how colour ranges are written.
    var gradeScale: GradeScale = .v
    /// The smallest jump when a lift goes up, in kg (22.5 → 25).
    var weightStepKg = 2.5
    var schedule = ScheduleRules()
    /// The check-in with Claude: which model, how hard it thinks, and where
    /// the `claude` program lives (blank = look for it).
    var coachModel = "claude-sonnet-5-5"
    var coachEffort = "high"
    var claudePath = ""
    /// What the coach is told about you. Blank = the built-in description.
    var coachContext = ""

    /// Settings that name something on one machine: a program to run and a
    /// folder to read. They are never taken from another device, so a paired
    /// phone cannot choose which program the Mac runs. List new ones here.
    mutating func clearMachineLocal() {
        garminFolder = ""
        claudePath = ""
    }

    init() {}
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        let def = Settings()
        weightStepKg = try c.decodeIfPresent(Double.self, forKey: .weightStepKg) ?? def.weightStepKg
        schedule = try c.decodeIfPresent(ScheduleRules.self, forKey: .schedule) ?? def.schedule
        coachModel = try c.decodeIfPresent(String.self, forKey: .coachModel) ?? def.coachModel
        coachEffort = try c.decodeIfPresent(String.self, forKey: .coachEffort) ?? def.coachEffort
        claudePath = try c.decodeIfPresent(String.self, forKey: .claudePath) ?? def.claudePath
        coachContext = try c.decodeIfPresent(String.self, forKey: .coachContext) ?? def.coachContext
        adaptMode = try c.decodeIfPresent(AdaptMode.self, forKey: .adaptMode) ?? def.adaptMode
        missedGymDaysToRepeat = try c.decodeIfPresent(Int.self, forKey: .missedGymDaysToRepeat) ?? def.missedGymDaysToRepeat
        sickDaysForReturnWeek = try c.decodeIfPresent(Int.self, forKey: .sickDaysForReturnWeek) ?? def.sickDaysForReturnWeek
        daysAwayNudge = try c.decodeIfPresent(Int.self, forKey: .daysAwayNudge) ?? def.daysAwayNudge
        garminFolder = try c.decodeIfPresent(String.self, forKey: .garminFolder) ?? def.garminFolder
        gymName = try c.decodeIfPresent(String.self, forKey: .gymName) ?? def.gymName
        showTips = try c.decodeIfPresent(Bool.self, forKey: .showTips) ?? def.showTips
        weightUnitKg = try c.decodeIfPresent(Bool.self, forKey: .weightUnitKg) ?? def.weightUnitKg
        autoSync = try c.decodeIfPresent(Bool.self, forKey: .autoSync) ?? def.autoSync
        useCircuits = try c.decodeIfPresent(Bool.self, forKey: .useCircuits) ?? def.useCircuits
        circuits = try c.decodeIfPresent([GradeCircuit].self, forKey: .circuits) ?? def.circuits
        gradeScale = try c.decodeIfPresent(GradeScale.self, forKey: .gradeScale) ?? def.gradeScale
    }
}

struct DrillChoice: Codable, Hashable {
    var id: String
    var since: String       // day key
}

struct Store: Codable {
    var version = 1
    var plan: Plan
    var sessions: [SessionLog] = []
    var daily: [String: DayLog] = [:]
    var rungs: [String: Int] = [:]          // exerciseID → current ladder rung
    var badges: [String: String] = [:]      // badge id → day unlocked
    var missions: [String: String] = [:]    // "mission@period" → day done
    var drillsMastered: [String: String] = [:]
    var goals: [SideGoal] = []
    var benchmarks: [String: BenchmarkEntry] = [:]
    var adaptations: [AdaptationEvent] = []
    var pending: PendingAdaptation? = nil
    var evaluatedThrough = -1               // last timeline index the engine judged
    var importedGarmin: [String] = []
    var settings = Settings()
    /// Quests you took back that would otherwise plant themselves again from
    /// your logs (a mistaken send, a test entry). Restoring removes it here.
    var revokedBadges: Set<String> = []
    /// The bouldering drill you picked instead of the plan's, from a day on.
    var drillChoice: DrillChoice? = nil
    /// Calisthenics skills: skill id → the step you're on.
    var skills: [String: Int] = [:]
    /// Skill steps cleared: "skill@step" → day.
    var skillsCleared: [String: String] = [:]
    /// The skills you're working on now; they show up in the sessions.
    var skillFocus: [String] = []
    /// 2 = every skill step doable at home (see AppModel.migrateSkills).
    var skillLadder = 2
    /// 2 = the bands are 4.5, 9, 13.5, 18 and 22.5 kg (see AppModel.migrateBands).
    var bandLadder = 2
    /// Sessions moved, added or taken off a single day: date key → change.
    var dayChanges: [String: DayChange] = [:]
    /// Loads set by hand or by a coach adjustment: exercise id → load.
    var loadSet: [String: LoadSet] = [:]
    /// Schedule suggestions you turned down or that were applied, so they don't come back.
    var dismissedSchedule: Set<String> = []
    /// Check-ins with Claude, newest first.
    var coach: [CoachReport] = []
    /// When each part last changed, so two devices can merge (see Merge.swift).
    var meta = SyncMeta()

    init(plan: Plan) { self.plan = plan }
    init(from d: Decoder) throws {
        let c = try d.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        plan = try c.decode(Plan.self, forKey: .plan)
        sessions = try c.decodeIfPresent([SessionLog].self, forKey: .sessions) ?? []
        daily = try c.decodeIfPresent([String: DayLog].self, forKey: .daily) ?? [:]
        rungs = try c.decodeIfPresent([String: Int].self, forKey: .rungs) ?? [:]
        badges = try c.decodeIfPresent([String: String].self, forKey: .badges) ?? [:]
        missions = try c.decodeIfPresent([String: String].self, forKey: .missions) ?? [:]
        drillsMastered = try c.decodeIfPresent([String: String].self, forKey: .drillsMastered) ?? [:]
        goals = try c.decodeIfPresent([SideGoal].self, forKey: .goals) ?? []
        benchmarks = try c.decodeIfPresent([String: BenchmarkEntry].self, forKey: .benchmarks) ?? [:]
        adaptations = try c.decodeIfPresent([AdaptationEvent].self, forKey: .adaptations) ?? []
        pending = try c.decodeIfPresent(PendingAdaptation.self, forKey: .pending)
        evaluatedThrough = try c.decodeIfPresent(Int.self, forKey: .evaluatedThrough) ?? -1
        importedGarmin = try c.decodeIfPresent([String].self, forKey: .importedGarmin) ?? []
        settings = try c.decodeIfPresent(Settings.self, forKey: .settings) ?? Settings()
        revokedBadges = try c.decodeIfPresent(Set<String>.self, forKey: .revokedBadges) ?? []
        drillChoice = try c.decodeIfPresent(DrillChoice.self, forKey: .drillChoice)
        skills = try c.decodeIfPresent([String: Int].self, forKey: .skills) ?? [:]
        skillsCleared = try c.decodeIfPresent([String: String].self, forKey: .skillsCleared) ?? [:]
        skillFocus = try c.decodeIfPresent([String].self, forKey: .skillFocus) ?? []
        skillLadder = try c.decodeIfPresent(Int.self, forKey: .skillLadder) ?? 1
        bandLadder = try c.decodeIfPresent(Int.self, forKey: .bandLadder) ?? 1
        dayChanges = try c.decodeIfPresent([String: DayChange].self, forKey: .dayChanges) ?? [:]
        loadSet = try c.decodeIfPresent([String: LoadSet].self, forKey: .loadSet) ?? [:]
        dismissedSchedule = try c.decodeIfPresent(Set<String>.self, forKey: .dismissedSchedule) ?? []
        coach = try c.decodeIfPresent([CoachReport].self, forKey: .coach) ?? []
        meta = try c.decodeIfPresent(SyncMeta.self, forKey: .meta) ?? SyncMeta()
    }
}
