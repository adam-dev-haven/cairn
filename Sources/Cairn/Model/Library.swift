import Foundation

// MARK: - Exercises

enum MoveGroup: String, Codable, CaseIterable, Identifiable {
    case push, pull, legs, core, prehab
    var id: String { rawValue }
    var name: String {
        switch self {
        case .push: "Push"
        case .pull: "Pull"
        case .legs: "Legs"
        case .core: "Core"
        case .prehab: "Prehab"
        }
    }
}

struct ExerciseInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let group: MoveGroup
    /// Bodyweight progressions, easiest first. Empty for load-based moves.
    var ladder: [String] = []
    /// How a load-based move steps up.
    var loadStep: String? = nil
    var cues: [String]
    var watch: String
    var why: String
    var symbol: String = "figure.strengthtraining.functional"
    /// Photo ids (see Photos): a start frame and a finish frame each.
    var photos: [String] = []
    /// Said when the photo shows the cable or dumbbell version of a band move.
    var photoNote = ""
    var muscles: [String] = []
    var alsoMuscles: [String] = []
    var setup = ""
    var mistakes: [String] = []
    var elbowNote = ""
    var gymSwap = ""
    /// Done on your resistance bands: the load is a band combination, not a weight.
    var isBand = false
    /// Where the first session starts, in band label kg. A guess that two sessions correct.
    var bandStart: Double? = nil

    /// Loaded with weights you can write down in kilograms, or with a band combination.
    var usesKg: Bool { isBand || (loadStep.map { $0.contains("kg") || $0.contains("plate") } ?? false) }
}

enum Library {
    /// What the split-week reset adds to an exercise the library already had.
    struct Overlay {
        var photos: [String]
        var photoNote: String
        var muscles: [String]
        var alsoMuscles: [String]
        var setup: String
        var cues: [String]
        var mistakes: [String]
        var elbowNote: String
        var gymSwap: String
    }

    static func applyOverlay(_ e: ExerciseInfo) -> ExerciseInfo {
        guard let o = overlays[e.id] else { return e }
        var x = e
        x.photos = o.photos; x.photoNote = o.photoNote; x.muscles = o.muscles; x.alsoMuscles = o.alsoMuscles
        x.setup = o.setup; x.mistakes = o.mistakes; x.elbowNote = o.elbowNote; x.gymSwap = o.gymSwap
        if !o.cues.isEmpty { x.cues = o.cues }
        return x
    }

    /// Every exercise: the originals plus the band and gym moves of the split week.
    static let exercises: [ExerciseInfo] = (baseExercises + bandExercises).map(applyOverlay)

    static let baseExercises: [ExerciseInfo] = [
        // Push
        ExerciseInfo(id: "pushup", name: "Push-up", group: .push,
                     ladder: ["Hands on bench", "Floor, on DB handles", "Feet on bench", "3-second lowering", "Archer push-up", "One-arm negative"],
                     cues: ["Squeeze glutes, ribs down — one plank from heel to head.",
                            "Elbows about 45° from the body, not flared out to a T.",
                            "Chest touches the handles; lock out and push the floor away at the top."],
                     watch: "Hips sagging first means the set is over.",
                     why: "The main chest and triceps builder, and the base of every harder press.",
                     symbol: "figure.strengthtraining.functional"),
        ExerciseInfo(id: "shoulder-press", name: "Seated DB shoulder press", group: .push,
                     loadStep: "+2 kg dumbbells",
                     cues: ["Palms facing in (neutral grip) — kinder on climbers' shoulders.",
                            "Back against the pad, press straight up, biceps by the ears at the top.",
                            "Lower to chin height, not below."],
                     watch: "Arching the lower back to finish a rep. Drop the weight instead.",
                     why: "Front and side delts: the top of the V."),
        ExerciseInfo(id: "floor-press", name: "DB floor press", group: .push,
                     loadStep: "+2 kg dumbbells",
                     cues: ["Upper arms touch the floor softly, pause, press.",
                            "Neutral or slightly angled grip.",
                            "Use a bench press instead if there's a free bench."],
                     watch: "Bouncing the elbows off the floor.",
                     why: "Chest volume with a built-in safe range for the shoulder."),
        ExerciseInfo(id: "lateral-raise", name: "DB lateral raise", group: .push,
                     loadStep: "+1–2 kg",
                     cues: ["Lead with the elbows, slight bend in the arm.",
                            "Stop at shoulder height; thumbs level, not up.",
                            "Two seconds down. Light weight, strict reps."],
                     watch: "Swinging with the hips. That's momentum, not delts.",
                     why: "The move that builds width — the V in V-taper."),
        ExerciseInfo(id: "pike", name: "Pike hold → pike push-up", group: .push,
                     ladder: ["Pike hold (20–30 s)", "Pike push-up", "Feet-elevated pike", "Wall handstand hold", "Wall handstand negative"],
                     cues: ["Hips high, head between the arms, weight into the hands.",
                            "Lower the crown of the head toward a spot in front of the hands — a triangle.",
                            "Only move to push-ups when the shoulders are quiet."],
                     watch: "Any pinch at the front of the shoulder: back to the hold.",
                     why: "Overhead strength without a barbell, and the road to handstands."),
        ExerciseInfo(id: "oh-triceps", name: "DB overhead triceps extension", group: .push,
                     loadStep: "+1–2 kg",
                     cues: ["One DB, two hands, elbows pointing forward.",
                            "Lower behind the head slowly, full stretch.",
                            "Light. This is volume, not a max."],
                     watch: "Stop if the elbow complains. Climbers' elbows come first.",
                     why: "Long head of the triceps — arm size where climbing doesn't reach."),

        // Pull
        ExerciseInfo(id: "pullup", name: "Pull-up", group: .pull,
                     ladder: ["Dead hang", "Scap pull-up", "Negative (5 s down)", "Strict singles", "Strict sets of 3", "5 strict", "Weighted"],
                     cues: ["Start from a dead hang with shoulders pulled down, away from the ears.",
                            "Chest to the bar, chin over. Lower all the way under control.",
                            "Stop before the ugly rep — kipping trains nothing you need."],
                     watch: "Pain on the inside of the elbow: skip to lat pulldowns for the day.",
                     why: "Goal for the block: 5 clean strict pull-ups by test week.",
                     symbol: "figure.play"),
        ExerciseInfo(id: "lat-pulldown", name: "Lat pulldown", group: .pull,
                     loadStep: "+1 plate",
                     cues: ["Shoulder-width grip. Lean back a touch.",
                            "Drive the elbows down into the back pockets.",
                            "Let it rise all the way — stretch the lats at the top."],
                     watch: "Yanking with the lower back.",
                     why: "The main lat builder while pull-ups are still low-rep."),
        ExerciseInfo(id: "db-row", name: "One-arm DB row", group: .pull,
                     loadStep: "+2 kg dumbbells",
                     cues: ["Knee and hand on a bench, back flat.",
                            "Row the elbow toward the hip, not the shoulder.",
                            "Pause at the top, two seconds down."],
                     watch: "Twisting the torso to cheat the weight up.",
                     why: "Mid-back thickness that balances all the pulling from the wall."),
        ExerciseInfo(id: "rear-delt", name: "DB rear delt fly", group: .pull,
                     loadStep: "+1 kg",
                     cues: ["Hinge to near horizontal, soft elbows.",
                            "Open the arms wide like a bird, pinkies leading.",
                            "Slow down. Light is right."],
                     watch: "Shrugging. Keep the neck long.",
                     why: "Shoulder health and width from behind."),
        ExerciseInfo(id: "hammer-curl", name: "DB hammer curl", group: .pull,
                     loadStep: "+2 kg",
                     cues: ["Thumbs up, elbows pinned to the sides.",
                            "No swing. Two seconds down."],
                     watch: "Inner-elbow ache — drop a size.",
                     why: "Kinder to climbers' elbows than palms-up curls."),
        ExerciseInfo(id: "reverse-wrist", name: "Reverse wrist curl", group: .prehab,
                     loadStep: "Light — stay light",
                     cues: ["Forearm on the thigh, palm down.",
                            "Lift the back of the hand, three seconds down."],
                     watch: "Never heavy. This is insurance, not training.",
                     why: "The elbow insurance policy. Don't skip it.",
                     symbol: "hand.raised"),

        // Legs
        ExerciseInfo(id: "goblet-squat", name: "Goblet squat", group: .legs,
                     loadStep: "+2 kg; pause at the bottom once the DBs run out",
                     cues: ["DB at the chest, elbows inside the knees at the bottom.",
                            "Sit between the heels, chest tall.",
                            "Drive the floor away."],
                     watch: "Heels lifting. Widen the stance or put small plates under them.",
                     why: "Quads and a strong bottom position for high steps on the wall.",
                     symbol: "figure.cross.training"),
        ExerciseInfo(id: "bss", name: "Bulgarian split squat", group: .legs,
                     ladder: ["Bodyweight", "DBs in hand", "Heavier DBs", "Front-foot elevated"],
                     cues: ["Back foot laces-down on the bench.",
                            "Drop straight down; front shin roughly vertical.",
                            "Front heel drives you up."],
                     watch: "Wobble is normal the first two weeks. Hold a rack with one hand.",
                     why: "Single-leg strength — every rock-over on the wall is one of these.",
                     symbol: "figure.cross.training"),
        ExerciseInfo(id: "db-rdl", name: "DB Romanian deadlift", group: .legs,
                     loadStep: "+2 kg dumbbells",
                     cues: ["Soft knees, push the hips back to the wall behind you.",
                            "DBs slide down the thighs; stop when the hamstrings pull.",
                            "Squeeze glutes to stand."],
                     watch: "Rounding the lower back to reach further.",
                     why: "Hamstrings and glutes for heel hooks and a strong hinge.",
                     symbol: "figure.cross.training"),
        ExerciseInfo(id: "calf-raise", name: "Single-leg calf raise", group: .legs,
                     ladder: ["Two legs on a step", "Single leg", "Single leg + DB"],
                     cues: ["Full stretch at the bottom, pause at the top.",
                            "Slow. Calves love tempo."],
                     watch: "Bouncing through the bottom.",
                     why: "Ankle strength for standing on small feet.",
                     symbol: "figure.step.training"),
        ExerciseInfo(id: "reverse-lunge", name: "Reverse lunge", group: .legs,
                     ladder: ["Bodyweight", "Band overhead", "Deficit (front foot raised)"],
                     cues: ["Step back long, back knee kisses the floor.",
                            "Drive through the front foot."],
                     watch: "Front knee caving in.",
                     why: "Home leg work with zero equipment."),
        ExerciseInfo(id: "glute-bridge", name: "Single-leg glute bridge", group: .legs,
                     ladder: ["Two-leg bridge", "Single-leg bridge", "Single-leg, shoulders on sofa"],
                     cues: ["Heel close to the bum, push through it.",
                            "Ribs down; squeeze at the top for one second."],
                     watch: "Arching the back instead of lifting with the glutes.",
                     why: "Glutes for high feet and heel hooks."),

        // Core
        ExerciseInfo(id: "core-front", name: "Dead bug → hollow hold", group: .core,
                     ladder: ["Dead bug (8 per side)", "Tuck hollow", "Hollow hold", "Hollow rock", "Tuck L-sit"],
                     cues: ["Lower back glued to the floor — that's the whole exercise.",
                            "Breathe out as the arm and leg reach away.",
                            "Hollow: arms by the ears, legs low, banana shape."],
                     watch: "The moment the back lifts, bend the knees or shorten the hold.",
                     why: "Keeping feet on the wall on steep ground is a core job.",
                     symbol: "figure.core.training"),
        ExerciseInfo(id: "side-plank", name: "Side plank", group: .core,
                     ladder: ["From the knees", "Full side plank", "Top leg lifted"],
                     cues: ["Elbow under the shoulder, hips high.",
                            "Body in one line, look forward."],
                     watch: "Hips sinking toward the floor.",
                     why: "Obliques for flagging and hips-to-wall positions.",
                     symbol: "figure.core.training"),

        // Prehab
        ExerciseInfo(id: "pull-apart", name: "Band pull-apart", group: .prehab,
                     loadStep: "Heavier band",
                     cues: ["Arms straight at shoulder height, pull the band to the chest.",
                            "Squeeze shoulder blades, slow return."],
                     watch: "Shrugging up to the ears.",
                     why: "Shoulder balance against all the pulling.",
                     symbol: "hand.raised"),
        ExerciseInfo(id: "external-rotation", name: "Band external rotation", group: .prehab,
                     loadStep: "Heavier band",
                     cues: ["Elbow pinned to the side (a rolled towel helps).",
                            "Rotate the forearm out, slow back."],
                     watch: "Letting the elbow drift away from the body.",
                     why: "Rotator cuff — the part climbers tear.",
                     symbol: "hand.raised"),
        ExerciseInfo(id: "finger-ext", name: "Finger extensions (rubber band)", group: .prehab,
                     cues: ["Band around fingertips and thumb; open the hand wide.",
                            "Controlled, 25 reps."],
                     watch: "Nothing to watch. It's the easiest win of the day.",
                     why: "Balances the grip muscles and protects the pulleys.",
                     symbol: "hand.raised"),
        ExerciseInfo(id: "wrist-stretch", name: "Wrist flexor stretch", group: .prehab,
                     cues: ["Palm flat on a wall, fingers down, gently lean.",
                            "30 seconds each side, breathe."],
                     watch: "No bouncing.",
                     why: "Forearms that climb three times a week need length.",
                     symbol: "hand.raised"),
    ]

    static let byID: [String: ExerciseInfo] = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0) })
    static func exercise(_ id: String) -> ExerciseInfo {
        byID[id] ?? ExerciseInfo(id: id, name: id, group: .core, cues: [], watch: "", why: "")
    }

    // MARK: - Drills

    struct Drill: Identifiable, Hashable {
        let id: String
        let week: Int
        let name: String
        let done: String
        let how: [String]
        var symbol: String = "figure.climbing"
    }

    static let drills: [Drill] = [
        Drill(id: "falling", week: 1, name: "Falling and downclimbing",
              done: "Five controlled falls from mid-height. Downclimb every warm-up problem.",
              how: ["Start from a metre up, then mid-height. Let go on purpose.",
                    "Land on both feet, knees bent, sit and roll back. Arms stay in.",
                    "Downclimb the ladder problems instead of jumping off."]),
        Drill(id: "silent-feet", week: 2, name: "Silent feet",
              done: "Every foot placed without a sound. Watch it until it's on the hold.",
              how: ["Eyes stay on the foothold until the toe is on it.",
                    "Place, don't slap. If you hear it, climb it again.",
                    "Use the big toe edge, not the middle of the shoe."]),
        Drill(id: "straight-arms", week: 3, name: "Straight arms",
              done: "Hang off your skeleton, move with your legs. Arms bend only to reach.",
              how: ["Between moves, arms straight like ropes.",
                    "Push up with the legs, then reach.",
                    "Feel the difference in your forearms after five problems."]),
        Drill(id: "hips-wall", week: 4, name: "Hips to the wall",
              done: "Turn side-on to reach. Feel how much less your arms work.",
              how: ["Reaching with the right hand? Turn the right hip into the wall.",
                    "Stand on the outside edge of the shoe.",
                    "Twist, reach, untwist."]),
        Drill(id: "deload-fav", week: 5, name: "Deload: favourite drill",
              done: "Your favourite drill so far, on problems you've already sent.",
              how: ["Pick the drill that felt best.", "Only problems you've sent before.", "Leave with energy left."]),
        Drill(id: "flagging", week: 6, name: "Flagging",
              done: "Use a leg as a counterweight instead of a foothold.",
              how: ["When you'd swing open (barn-door), stick the free leg out to the side on the wall.",
                    "Back flag: free leg crosses behind the standing leg.",
                    "Try each easy problem once with a flag on purpose."]),
        Drill(id: "drop-knee", week: 7, name: "Drop knee",
              done: "Turn the knee in and down on steep terrain.",
              how: ["Two opposing footholds; turn one knee down toward the floor.",
                    "Hip comes into the wall, reach gets longer.",
                    "Go gentle on the knee — it's a twist, not a crank."]),
        Drill(id: "heel-hook", week: 8, name: "Heel hooks",
              done: "Pull with your heel on a hold at hip height or above.",
              how: ["Place the heel, then pull the heel toward your bum.",
                    "Use it to take weight off the arms on an overhang.",
                    "Hamstrings on. The RDLs are paying off here."]),
        Drill(id: "reading", week: 9, name: "Toe hooks + reading",
              done: "Plan every move for 30 seconds before touching the wall.",
              how: ["Stand back. Name every hand, then every foot.",
                    "Mime the sequence with your hands.",
                    "Toe hook: pull the top of the shoe against a hold to stop a swing."]),
        Drill(id: "deload-feet", week: 10, name: "Deload: perfect feet",
              done: "Old problems, perfect feet only.",
              how: ["Only sent problems.", "Silent feet, every placement.", "Leave fresh."]),
        Drill(id: "deadpoint", week: 11, name: "Small deadpoints",
              done: "Controlled little jumps to a hold you catch at the dead point.",
              how: ["Load the legs, float up, catch the hold at the top of the float.",
                    "Hips drive into the wall, not away from it.",
                    "Not full dynos. Small, accurate, repeatable."]),
        Drill(id: "slab", week: 12, name: "Slab and mantles",
              done: "Balance on bad feet. Press out over a top edge.",
              how: ["Slab: hips out from the wall, weight straight down through the feet.",
                    "Trust the rubber — smear, don't hunt for footholds.",
                    "Mantle: hands under the chest, press down like getting out of a pool."]),
        Drill(id: "holiday", week: 13, name: "Holiday: no wall",
              done: "Home sessions and long walks. Rest the fingers.",
              how: ["Prehab counts.", "Long walks count.", "Rest is part of the plan."]),
        Drill(id: "test", week: 14, name: "Test day: flash",
              done: "Flash attempts: how many V2 and V3 go first try.",
              how: ["Read each problem for 30 seconds.", "One attempt each. No watching beta.", "Write the count down."]),
    ]
    static func drill(_ id: String) -> Drill? { drills.first { $0.id == id } }

    // MARK: - Technique

    struct Technique: Identifiable, Hashable {
        let id: String
        let title: String
        let area: String
        let summary: String
        let steps: [String]
        let mistakes: [String]
    }

    static let techniqueAreas = ["Safety", "Feet", "Body", "Movement", "Reading"]

    static let techniques: [Technique] = [
        Technique(id: "grips", title: "Open hand and half crimp", area: "Safety",
                  summary: "The only two grips this block. The full crimp — thumb wrapped over the fingers — is the classic pulley injury.",
                  steps: ["Open hand: fingers drape over the hold, knuckles barely bent.",
                          "Half crimp: fingers bent to about 90°, thumb off.",
                          "On a tiny edge, choose a different hold before you choose a full crimp."],
                  mistakes: ["Wrapping the thumb over on hard moves.", "Crimping small edges on overhangs in Foundation."]),
        Technique(id: "falling", title: "Landing", area: "Safety",
                  summary: "Land, don't catch. Most bouldering injuries happen on the mat, not the wall.",
                  steps: ["Look down before you let go.", "Both feet, knees bent, sit and roll back.", "Arms in, hands on your chest."],
                  mistakes: ["Putting an arm out behind you.", "Landing stiff-legged."]),
        Technique(id: "warmup", title: "The warm-up ladder", area: "Safety",
                  summary: "Fingers warm up on the ladder, never on the first hard problem.",
                  steps: ["Pulse, 5 min: jumping jacks, skipping, arm circles.",
                          "Shoulders on, 5 min: pull-aparts 2×15, external rotations 1×12/side, scap pull-ups 1×8.",
                          "Ladder: 6–8 easy problems, each a little harder than the last, all well below your limit. It's a warm-up for the fingers, not a test."],
                  mistakes: ["Skipping the ladder when you're short on time. Shorten the main block instead.",
                             "Climbing the ladder at your limit. If you're working on V0–V3, the whole ladder is the easy end of V0–V3."]),
        Technique(id: "footwork", title: "Precise feet", area: "Feet",
                  summary: "Good climbers climb with their feet. The hands just keep you on.",
                  steps: ["Watch the foot all the way onto the hold.", "Use the inside edge by the big toe.", "Once placed, don't shuffle it."],
                  mistakes: ["Looking at the next handhold while the foot is still moving."]),
        Technique(id: "smearing", title: "Smearing", area: "Feet",
                  summary: "No foothold? Press the rubber straight into the wall.",
                  steps: ["Heel low, ball of the foot on the wall.", "Hips out so the weight goes into the foot.", "Commit. Hesitation slips."],
                  mistakes: ["Hugging the wall on slab — it pushes the feet off."]),
        Technique(id: "heel-toe", title: "Heel and toe hooks", area: "Feet",
                  summary: "Feet can pull, not only push.",
                  steps: ["Heel: place, then curl it toward your bum.", "Toe: top of the shoe pulls against a hold to stop a swing."],
                  mistakes: ["Placing the heel and then not pulling with it."]),
        Technique(id: "straight-arms", title: "Straight arms", area: "Body",
                  summary: "Bent arms burn out; straight arms rest on the skeleton.",
                  steps: ["Hang long between moves.", "Push with the legs to move up.", "Bend only to reach."],
                  mistakes: ["Pulling up with the arms like a pull-up."]),
        Technique(id: "hips", title: "Hips to the wall and flagging", area: "Body",
                  summary: "Where the hips go, the weight goes.",
                  steps: ["Turn side-on to reach further.", "Flag the free leg to stop the barn-door swing.", "Drop knee on steep ground."],
                  mistakes: ["Square to the wall on every move."]),
        Technique(id: "deadpoint", title: "Deadpoints", area: "Movement",
                  summary: "A small, accurate float to a hold — the precursor to dynamic climbing.",
                  steps: ["Legs generate, arms guide.", "Catch at the top of the float.", "From week 11 only. No full dynos this block."],
                  mistakes: ["Throwing with the arms.", "Hips moving away from the wall."]),
        Technique(id: "mantle", title: "Mantles and top-outs", area: "Movement",
                  summary: "Getting over the top is its own skill.",
                  steps: ["Hands under the chest, elbows up.", "Press down, bring a foot up high.", "Stand up slowly."],
                  mistakes: ["Belly-flopping over the top."]),
        Technique(id: "reading", title: "Reading a problem", area: "Reading",
                  summary: "Thirty seconds on the mat saves three attempts on the wall.",
                  steps: ["Find the start and the top.", "Name each hand, then each foot.", "Mime the crux, then go."],
                  mistakes: ["Starting before you know where your feet go."]),
        Technique(id: "three-tries", title: "Three tries, then move on", area: "Reading",
                  summary: "Can't send it in three? It goes on the list for next time.",
                  steps: ["Rest 2–3 minutes between hard attempts.", "Write the problem down.", "Come back fresh next session."],
                  mistakes: ["Ten attempts on one problem at the end of a session. That's how fingers go."]),
    ]

    // MARK: - Tips

    /// Rotating short tips for the day's session kind, picked by date so
    /// they change daily but stay stable within a day.
    static let dayTips: [ItemKind: [String]] = [
        .climb: [
            "Three tries, then move on. Rest 2–3 minutes between hard attempts.",
            "No full crimp. Open hand or half crimp only.",
            "Land, don't catch. Both feet, knees bent, roll back.",
            "Fingers warm up on the ladder, not on the first hard problem.",
            "Downclimb two easy problems at the end. It's free technique.",
            "Watch every foot onto its hold. Silent feet are precise feet.",
            "Straight arms between moves. Push with the legs.",
            "Check the elbows in the warm-up, before the first real attempt. Ache that builds means technique mode.",
            "Open hand beats crimp. Your elbows will tell you which one you used.",
        ],
        .workout: [
            "Stay at a weight until you hit the top of the range on every set, two sessions running.",
            "Rest 90 seconds to 2 minutes. Set a timer; don't guess.",
            "Stop before the ugly rep. Form breaks are where elbows hurt.",
            "Log the numbers now. Next week's you needs them.",
        ],
        .home: [
            "Stop every set one to three reps short. On bands the last rep should still be clean.",
            "Easy top of the range? Step back from the door a pace before you change band.",
            "Slow on the way back. Three seconds lowering is where bands do their work.",
            "Chaos day? Push-ups, a band row and a squat. That still counts.",
            "Finish with 5 minutes of mobility: hip flexors, thoracic opener, wrist circles.",
        ],
        .walk: [
            "Only listen to the good podcast while walking. Temptation bundling works.",
            "Daylight counts double. A midday walk helps the mood more than an evening one.",
            "Rain jacket by the door. Weather is not a reason, it's a costume.",
            "Walk menu: a new café, a call with a friend, a loop of your nearest park.",
        ],
        .prehab: [
            "Prehab on the floor while something plays on the TV. It doesn't need to feel like training.",
            "Reverse wrist curls are the elbow insurance. Ten minutes, done.",
        ],
        .rest: [
            "Rest is when the tendons catch up with the muscles.",
            "Night before a gym morning: bag packed, shoes by the door, clothes out.",
        ],
    ]

    static func tip(for kind: ItemKind, on date: Date) -> String {
        let pool = dayTips[kind] ?? dayTips[.rest]!
        let n = Day.calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[n % pool.count]
    }
}
