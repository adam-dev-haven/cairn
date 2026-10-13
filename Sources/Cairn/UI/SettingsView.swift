#if os(macOS)
import AppKit
#endif
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case profiles, grades, block, adapting, scheduling, progression, week, sessions, points, steps, sync, reset, about, privacy, legal, credits
    var id: String { rawValue }
    var title: String {
        switch self {
        case .profiles: "Profiles"
        case .grades: "Grades"
        case .block: "The block"
        case .adapting: "Adapting the plan"
        case .scheduling: "Smart scheduling"
        case .progression: "Progression and coach"
        case .week: "Your week"
        case .sessions: "Sessions"
        case .points: "Points and targets"
        case .steps: "Steps"
        case .sync: "Sync"
        case .reset: "Reset"
        case .about: "About"
        case .privacy: "Privacy policy"
        case .legal: "Legal"
        case .credits: "Credits and licenses"
        }
    }
    var detail: String {
        switch self {
        case .profiles: "Switch, add, rename"
        case .grades: "V or Font, and your gym's colours"
        case .block: "Name, start date, summit, tips"
        case .adapting: "What happens when a week goes sideways"
        case .scheduling: "If I do this, the app changes that"
        case .progression: "Weight jumps, overload rules, the Claude check-in"
        case .week: "What each day holds"
        case .sessions: "Exercises, reps and sets"
        case .points: "Green week, points, protein, calories"
        case .steps: "Floor and goal per week"
        case .sync: "Your iPhone and your watch folder"
        case .reset: "Quests, logs, plan, all undoable"
        case .about: "What Cairn is and who made it"
        case .privacy: "What is stored and where it goes"
        case .legal: "Not medical advice, liability, terms"
        case .credits: "Code license, photos, sources"
        }
    }
    var symbol: String {
        switch self {
        case .profiles: "person.2"
        case .grades: "paintpalette"
        case .block: "mountain.2"
        case .adapting: "arrow.triangle.2.circlepath"
        case .scheduling: "calendar.badge.clock"
        case .progression: "chart.line.uptrend.xyaxis"
        case .week: "calendar"
        case .sessions: "figure.strengthtraining.functional"
        case .points: "star"
        case .steps: "figure.walk"
        case .sync: "arrow.triangle.2.circlepath.circle"
        case .reset: "arrow.uturn.backward"
        case .about: "info.circle"
        case .privacy: "hand.raised"
        case .legal: "doc.text"
        case .credits: "books.vertical"
        }
    }
}

/// On a paged settings screen the page already names the section.
private struct PagedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var settingsPaged: Bool {
        get { self[PagedKey.self] }
        set { self[PagedKey.self] = newValue }
    }
}

struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @State private var workoutID = "A"
    @State private var confirmReset = false
    @State private var newStart = Date()
    @State private var page: SettingsPage?
    /// Phone: leave Settings entirely (back to More).
    var onExit: (() -> Void)? = nil

    var body: some View {
        if compact { phone } else { mac }
    }

    var mac: some View {
        Page(title: "Settings", subtitle: "Everything in the plan is yours to change. Changes save as you make them.") {
            VStack(alignment: .leading, spacing: 36) {
                ForEach(SettingsPage.allCases) { section($0) }
            }
        }
    }

    /// Phone: an index of sections, each opening on its own page.
    @ViewBuilder var phone: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    if page != nil { withAnimation(.snappy) { page = nil } } else { onExit?() }
                } label: { Label(page == nil ? "More" : "Settings", systemImage: "chevron.left") }
                    .buttonStyle(InkButtonStyle(filled: false))
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 8)
            if let page {
                Page(title: page.title) {
                    section(page).environment(\.settingsPaged, true)
                }
            } else {
                Page(title: "Settings", subtitle: "Changes save as you make them.") {
                    VStack(spacing: 10) {
                        ForEach(SettingsPage.allCases) { p in
                            Button { withAnimation(.snappy) { page = p } } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: p.symbol).font(.system(size: 16)).frame(width: 26).foregroundStyle(Ink.ink)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(p.title).font(Face.heading).foregroundStyle(Ink.ink)
                                        Text(p.detail).font(Face.small).foregroundStyle(Ink.ink2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.ink2)
                                }
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Ink.sheet))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Ink.line))
                        }
                    }
                }
            }
        }
        .background(Ink.paper)
    }

    @ViewBuilder func section(_ p: SettingsPage) -> some View {
        switch p {
        case .profiles: ProfilesSection()
        case .grades: GradesSection()
        case .block: block
        case .adapting: adapting
        case .scheduling: SchedulingSection()
        case .progression: ProgressionSection()
        case .week: weekPattern
        case .sessions: workouts
        case .points: points
        case .steps: floors
        case .sync: data
        case .reset: ResetSection()
        case .about: DocSection(title: "About", parts: AboutDocs.about, showsVersion: true)
        case .privacy: DocSection(title: "Privacy policy", parts: AboutDocs.privacy)
        case .legal: DocSection(title: "Legal", parts: AboutDocs.legal)
        case .credits: DocSection(title: "Credits and licenses", parts: AboutDocs.credits)
        }
    }

    // MARK: Block

    var block: some View {
        SettingsSection(title: "The block", detail: "\(model.plan.weeks.count) weeks on the plan, \(model.plan.timeline.count) on the calendar after repeats.") {
            SettingRow("Name") {
                TextField("", text: Binding(get: { model.plan.name }, set: { v in model.mutate { $0.plan.name = v } }))
                    .textFieldStyle(.roundedBorder).frame(width: compact ? 180 : 240)
            }
            SettingRow("Starts", detail: "Always a Monday. Moving it moves the whole climb.") {
                DatePicker("", selection: Binding(get: { model.startDate },
                                                  set: { v in model.mutate { $0.plan.startDate = Day.key(Day.monday(of: v)); $0.evaluatedThrough = -1 } }),
                           displayedComponents: .date)
                    .labelsHidden().fieldDatePicker().frame(width: 120)
            }
            SettingRow("Summit", detail: "Test week, after any repeats.") {
                Text(Day.long(model.summitDate)).font(Face.body)
            }
            SettingRow("Start a fresh block", detail: "Resets the fourteen weeks and their timing. Your logs, quests and benchmarks stay.") {
                HStack {
                    DatePicker("", selection: $newStart, displayedComponents: .date).labelsHidden().fieldDatePicker().frame(width: 120)
                    Button("Start fresh…") { confirmReset = true }.buttonStyle(InkButtonStyle(filled: false))
                }
            }
            SettingRow("Tips", detail: "Weekly tip and a daily one beside Today.") {
                Toggle("", isOn: Binding(get: { model.store.settings.showTips }, set: { v in model.mutate { $0.settings.showTips = v } }))
                    .toggleStyle(.switch).labelsHidden()
            }
        }
        .confirmationDialog("Start a fresh block from \(Day.short(Day.monday(of: newStart)))?", isPresented: $confirmReset) {
            Button("Start fresh", role: .destructive) { model.resetPlan(start: newStart) }
        } message: {
            Text("The plan goes back to the Wall & Bar defaults, including workouts and your week. Logs stay.")
        }
    }

    // MARK: Adapting

    var adapting: some View {
        SettingsSection(title: "Adapting the plan", detail: "Checked each time Cairn opens and each Monday.") {
            SettingRow("When a week goes sideways") {
                Picker("", selection: Binding(get: { model.store.settings.adaptMode }, set: { v in model.mutate { $0.settings.adaptMode = v } })) {
                    ForEach(AdaptMode.allCases) { Text($0.name).tag($0) }
                }.labelsHidden().frame(width: 220)
            }
            SettingRow("Repeat a week after", detail: "Missed gym mornings in one week. Sick days don't count as missed.") {
                StepperField(value: Binding(get: { model.store.settings.missedGymDaysToRepeat },
                                            set: { v in model.mutate { $0.settings.missedGymDaysToRepeat = v } }), range: 1...7, suffix: " missed")
            }
            SettingRow("Add a return week after", detail: "Sick days in one week. The return week is half the sets on easy grades.") {
                StepperField(value: Binding(get: { model.store.settings.sickDaysForReturnWeek },
                                            set: { v in model.mutate { $0.settings.sickDaysForReturnWeek = v } }), range: 1...7, suffix: " sick")
            }
            SettingRow("Doorway nudge after", detail: "Days without the wall before Today suggests the minimum session.") {
                StepperField(value: Binding(get: { model.store.settings.daysAwayNudge },
                                            set: { v in model.mutate { $0.settings.daysAwayNudge = v } }), range: 2...21, suffix: " days")
            }
        }
    }

    // MARK: Week pattern

    var weekPattern: some View {
        SettingsSection(title: "Your week", detail: "What each day holds. Climbs are the gym days the week is judged on; an optional climb never counts as missed. Holiday weeks swap climbs for home sessions on their own.") {
            ForEach(0..<7, id: \.self) { i in
                AdaptiveStack(spacing: 14) {
                    Text(Day.weekdayLong[i]).font(Face.heading).frame(width: compact ? nil : 90, alignment: .leading)
                    FlowLayout(spacing: 6) {
                        ForEach(options, id: \.label) { o in
                            let on = has(i, o)
                            Button(o.label) { toggle(i, o) }.buttonStyle(ChipStyle(on: on))
                        }
                    }
                    if !compact { Spacer() }
                    TextField("Place", text: Binding(get: { model.plan.days[i].place }, set: { v in model.mutate { $0.plan.days[i].place = v } }))
                        .textFieldStyle(.roundedBorder).frame(width: 130)
                }
                .padding(.vertical, 6)
            }
        }
    }

    struct Option { let label: String; let kind: ItemKind; let workoutID: String?; var optional = false }
    var options: [Option] {
        [Option(label: "Boulder", kind: .climb, workoutID: nil),
         Option(label: "Easy climb (optional)", kind: .climb, workoutID: nil, optional: true)]
            + model.plan.workouts.filter { !$0.isHome }.map { Option(label: "\($0.id) · \($0.name)", kind: .workout, workoutID: $0.id) }
            + model.plan.workouts.filter { $0.isHome && $0.id != "P" }.map { Option(label: "\($0.id) · \($0.name)", kind: .home, workoutID: $0.id) }
            + [Option(label: "Walk", kind: .walk, workoutID: nil),
               Option(label: "Prehab", kind: .prehab, workoutID: nil),
               Option(label: "Monday check", kind: .check, workoutID: nil),
               Option(label: "Rest", kind: .rest, workoutID: nil)]
    }

    func has(_ day: Int, _ o: Option) -> Bool {
        model.plan.days[day].items.contains { $0.kind == o.kind && $0.workoutID == o.workoutID && $0.isOptional == o.optional }
    }

    func toggle(_ day: Int, _ o: Option) {
        model.mutate { s in
            var items = s.plan.days[day].items
            if let i = items.firstIndex(where: { $0.kind == o.kind && $0.workoutID == o.workoutID && $0.isOptional == o.optional }) {
                items.remove(at: i)
            } else {
                if o.kind == .rest { items = [] } else { items.removeAll { $0.kind == .rest } }
                items.append(PlannedItem(kind: o.kind, workoutID: o.workoutID, optional: o.optional ? true : nil))
                let order: [ItemKind] = [.climb, .workout, .home, .walk, .prehab, .check, .rest]
                items.sort { order.firstIndex(of: $0.kind)! < order.firstIndex(of: $1.kind)! }
            }
            if items.isEmpty { items = [PlannedItem(kind: .rest)] }
            s.plan.days[day].items = items
        }
    }

    // MARK: Workouts

    var workouts: some View {
        SettingsSection(title: "Sessions", detail: "Exercises and rep ranges. Sets follow the block (2 → 3 → 4, halved on deloads) unless you pin them.") {
            if compact {
                Picker("Session", selection: $workoutID) {
                    ForEach(model.plan.workouts) { Text("\($0.id) · \($0.name)").tag($0.id) }
                }.pickerStyle(.menu)
            } else {
                Picker("", selection: $workoutID) {
                    ForEach(model.plan.workouts) { Text("\($0.id) · \($0.name)").tag($0.id) }
                }.pickerStyle(.segmented).labelsHidden()
            }
            if let wi = model.plan.workouts.firstIndex(where: { $0.id == workoutID }) {
                SettingRow("Name") {
                    TextField("", text: Binding(get: { model.plan.workouts[wi].name }, set: { v in model.mutate { $0.plan.workouts[wi].name = v } }))
                        .textFieldStyle(.roundedBorder).frame(width: compact ? nil : 240)
                }
                SettingRow("Note") {
                    TextField("", text: Binding(get: { model.plan.workouts[wi].note }, set: { v in model.mutate { $0.plan.workouts[wi].note = v } }))
                        .textFieldStyle(.roundedBorder).frame(width: compact ? nil : 420)
                }
                ForEach(Array(model.plan.workouts[wi].exercises.enumerated()), id: \.element.id) { ei, pe in
                    ExerciseEditRow(wi: wi, ei: ei, count: model.plan.workouts[wi].exercises.count)
                }
                HStack {
                    Menu("Add exercise") {
                        ForEach(MoveGroup.allCases) { g in
                            Section(g.name) {
                                ForEach(Library.exercises.filter { $0.group == g }) { ex in
                                    Button(ex.name) {
                                        model.mutate { s in
                                            s.plan.workouts[wi].exercises.append(PlannedExercise(exerciseID: ex.id, schemes: [
                                                Scheme(fromWeek: 1, variant: ex.name, low: 8, high: 12)]))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
    }

    // MARK: Points

    var points: some View {
        SettingsSection(title: "Points and targets", detail: "A green week is the only thing the streak counts. Days never break it.") {
            pointRow("Green week at", \.greenWeek, 10...150)
            pointRow("Gym morning", \.gymSession, 0...30)
            pointRow("Home session", \.homeSession, 0...30)
            pointRow("Prehab", \.prehab, 0...10)
            pointRow("Step floor, per day", \.stepFloor, 0...10)
            pointRow("Step goal bonus, per day", \.stepGoalBonus, 0...10)
            pointRow("Protein day", \.protein, 0...10)
            pointRow("New hardest send", \.newHardestSend, 0...20)
            pointRow("Drill got boring", \.drillBoring, 0...20)
            SettingRow("Protein target") {
                StepperField(value: Binding(get: { model.plan.proteinTarget }, set: { v in model.mutate { $0.plan.proteinTarget = v } }), range: 60...300, step: 5, suffix: " g")
            }
            SettingRow("Calories") {
                StepperField(value: Binding(get: { model.plan.kcalTarget }, set: { v in model.mutate { $0.plan.kcalTarget = v } }), range: 1200...4000, step: 50, suffix: " kcal")
            }
        }
    }

    func pointRow(_ label: String, _ kp: WritableKeyPath<PointsTable, Int>, _ range: ClosedRange<Int>) -> some View {
        SettingRow(label) {
            StepperField(value: Binding(get: { model.plan.points[keyPath: kp] }, set: { v in model.mutate { $0.plan.points[keyPath: kp] = v } }), range: range)
        }
    }

    // MARK: Step floors

    var floors: some View {
        SettingsSection(title: "Steps", detail: "Floor counts for points and the streak; the goal is a bonus. Set your watch to the floor, not the goal.") {
            Grid(alignment: .leading, horizontalSpacing: compact ? 10 : 20, verticalSpacing: 8) {
                GridRow {
                    Text("Week").font(Face.small).foregroundStyle(Ink.ink2)
                    if !compact { Text("Phase").font(Face.small).foregroundStyle(Ink.ink2) }
                    Text("Floor").font(Face.small).foregroundStyle(Ink.ink2)
                    Text("Goal").font(Face.small).foregroundStyle(Ink.ink2)
                }
                ForEach(Array(model.plan.weeks.enumerated()), id: \.element.id) { i, w in
                    GridRow {
                        Text("\(w.id)").font(Face.body).monospacedDigit()
                        if !compact { Text(w.phase.name).font(Face.body).foregroundStyle(Ink.ink2) }
                        StepperField(value: Binding(get: { model.plan.weeks[i].stepFloor }, set: { v in model.mutate { $0.plan.weeks[i].stepFloor = v } }), range: 0...30000, step: 500)
                        StepperField(value: Binding(get: { model.plan.weeks[i].stepGoal }, set: { v in model.mutate { $0.plan.weeks[i].stepGoal = v } }), range: 0...30000, step: 500)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

#if os(macOS)
    // MARK: Data

    var data: some View {
        SettingsSection(title: "Sync", detail: "Optional. Cairn can read bouldering and walking sessions your watch exported to a folder (format in docs/ACTIVITY-IMPORT.md). It never signs in to Garmin and never writes to the folder.") {
            SettingRow("Watch activity folder", detail: model.importAvailable ? model.store.settings.garminFolder : "Not connected") {
                HStack {
                    Button(model.importAvailable ? "Change…" : "Choose…") { chooseFolder() }.buttonStyle(InkButtonStyle(filled: false))
                    if model.importAvailable {
                        Button("Disconnect") { model.mutate { $0.settings.garminFolder = "" }; model.lastSync = nil }
                            .buttonStyle(InkButtonStyle(filled: false))
                    }
                }
            }
            SettingRow("Import automatically", detail: "On launch, when you come back to the app, and hourly. Needs a folder.") {
                Toggle("", isOn: Binding(get: { model.store.settings.autoSync }, set: { v in model.mutate { $0.settings.autoSync = v } }))
                    .toggleStyle(.switch).labelsHidden().disabled(!model.importAvailable)
            }
            SettingRow("Last import", detail: model.lastSync?.summary ?? (model.importAvailable ? "Not yet this session" : "Nothing connected")) {
                Button(model.syncing ? "Importing…" : "Import now") { Task { await model.syncNow() } }
                    .buttonStyle(InkButtonStyle()).disabled(model.syncing || !model.importAvailable)
            }
            MacPeerSettings()
            SettingRow("Your data", detail: AppModel.dataDirectory().path) {
                HStack {
                    Button("Show in Finder") { NSWorkspace.shared.open(AppModel.dataDirectory()) }.buttonStyle(InkButtonStyle(filled: false))
                    Button("Export…") { export() }.buttonStyle(InkButtonStyle(filled: false))
                }
            }
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if let folder = model.activityFolder { panel.directoryURL = folder }
        panel.message = "Pick the folder that holds your watch activities (it needs a manifest.json)"
        if panel.runModal() == .OK, let url = panel.url {
            model.mutate { $0.settings.garminFolder = url.path }
            Task { await model.syncNow() }
        }
    }

    func export() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "cairn-\(Day.key(Date())).json"
        if panel.runModal() == .OK, let url = panel.url {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            if let data = try? enc.encode(model.store) { try? data.write(to: url) }
        }
    }
#else
    var data: some View {
        SettingsSection(title: "Sync", detail: "Your Mac keeps the other copy of your log.") {
            PhoneSyncSettings(embedded: true)
        }
    }
#endif
}

struct ExerciseEditRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    let wi: Int
    let ei: Int
    let count: Int

    var body: some View {
        if compact { phone } else { mac }
    }

    /// Two lines on the phone: the exercise, then its numbers.
    var phone: some View {
        let pe = model.plan.workouts[wi].exercises[ei]
        let si = pe.schemes.count - 1
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                VStack(spacing: 6) {
                    Button { move(-1) } label: { Image(systemName: "chevron.up").frame(width: 28, height: 20) }.buttonStyle(.plain).disabled(ei == 0)
                    Button { move(1) } label: { Image(systemName: "chevron.down").frame(width: 28, height: 20) }.buttonStyle(.plain).disabled(ei == count - 1)
                }
                .font(.system(size: 11, weight: .bold)).foregroundStyle(Ink.ink2)
                TextField("", text: bind(\.variant, si)).textFieldStyle(.plain).font(Face.heading)
                Button { model.mutate { $0.plan.workouts[wi].exercises.remove(at: ei) } } label: { Image(systemName: "trash") }
                    .buttonStyle(QuietIconButton()).accessibilityLabel("Remove \(pe.schemes[si].variant)")
            }
            HStack(spacing: 8) {
                StepperField(value: bind(\.low, si), range: 1...200)
                Text("to").font(Face.small).foregroundStyle(Ink.ink2)
                StepperField(value: bind(\.high, si), range: 1...200, suffix: pe.schemes[si].timed ? " s" : "")
                Spacer(minLength: 0)
                Toggle("Pin sets", isOn: Binding(get: { pe.schemes[si].sets != nil },
                                                  set: { v in model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si].sets = v ? 3 : nil } }))
                    .toggleStyle(InkCheck()).font(Face.small)
            }
            if pe.schemes[si].sets != nil {
                StepperField(value: Binding(get: { pe.schemes[si].sets ?? 3 },
                                            set: { v in model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si].sets = v } }), range: 1...8, suffix: " sets")
            }
        }
        .padding(.vertical, 8)
    }

    var mac: some View {
        let pe = model.plan.workouts[wi].exercises[ei]
        let si = pe.schemes.count - 1
        return HStack(spacing: 12) {
            VStack(spacing: 2) {
                Button { move(-1) } label: { Image(systemName: "chevron.up") }.buttonStyle(.plain).disabled(ei == 0)
                Button { move(1) } label: { Image(systemName: "chevron.down") }.buttonStyle(.plain).disabled(ei == count - 1)
            }
            .font(.system(size: 9, weight: .bold)).foregroundStyle(Ink.ink2)
            VStack(alignment: .leading, spacing: 2) {
                TextField("", text: bind(\.variant, si)).textFieldStyle(.plain).font(Face.heading)
                Text(pe.schemes.count > 1 ? "Latest stage, from week \(pe.schemes[si].fromWeek)" : Library.exercise(pe.exerciseID).group.name)
                    .font(Face.small).foregroundStyle(Ink.ink2)
            }
            Spacer()
            StepperField(value: bind(\.low, si), range: 1...200)
            Text("to").font(Face.small).foregroundStyle(Ink.ink2)
            StepperField(value: bind(\.high, si), range: 1...200, suffix: pe.schemes[si].timed ? " s" : "")
            Toggle("Pin sets", isOn: Binding(get: { pe.schemes[si].sets != nil },
                                              set: { v in model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si].sets = v ? 3 : nil } }))
                .toggleStyle(InkCheck()).font(Face.small)
            if pe.schemes[si].sets != nil {
                StepperField(value: Binding(get: { pe.schemes[si].sets ?? 3 },
                                            set: { v in model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si].sets = v } }), range: 1...8, suffix: " sets")
            }
            Button { model.mutate { $0.plan.workouts[wi].exercises.remove(at: ei) } } label: { Image(systemName: "trash") }
                .buttonStyle(QuietIconButton()).help("Remove from this session")
        }
        .padding(.vertical, 6)
    }

    func bind<T>(_ kp: WritableKeyPath<Scheme, T>, _ si: Int) -> Binding<T> {
        Binding(get: { model.plan.workouts[wi].exercises[ei].schemes[si][keyPath: kp] },
                set: { v in model.mutate { $0.plan.workouts[wi].exercises[ei].schemes[si][keyPath: kp] = v } })
    }

    func move(_ d: Int) {
        model.mutate { s in
            let j = ei + d
            guard s.plan.workouts[wi].exercises.indices.contains(j) else { return }
            s.plan.workouts[wi].exercises.swapAt(ei, j)
        }
    }
}

struct SettingsSection<Content: View>: View {
    var title: String
    var detail: String
    @ViewBuilder var content: Content
    @Environment(\.settingsPaged) private var paged
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if paged {
                Text(detail).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            } else {
                SectionTitle(text: title, detail: detail)
            }
            VStack(alignment: .leading, spacing: 10) { content }
                .sheetCard()
        }
    }
}

struct SettingRow<Control: View>: View {
    var label: String
    var detail: String?
    @ViewBuilder var control: Control
    init(_ label: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.label = label
        self.detail = detail
        self.control = control()
    }
    @Environment(\.compact) private var compact

    var labels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(Face.body).foregroundStyle(Ink.ink)
            if let detail {
                Text(detail).font(Face.small).foregroundStyle(Ink.ink2)
                    .lineLimit(compact ? nil : 2).truncationMode(.middle)
                    .fixedSize(horizontal: false, vertical: compact)
            }
        }
    }

    var body: some View {
        Group {
            if compact {
                // Label and control side by side when they fit; the control
                // drops below when the words need the width.
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 12) {
                        // An ideal width, not the text's one-line width, so a
                        // short control stays beside a label that wraps.
                        labels.frame(minWidth: 120, idealWidth: 150, maxWidth: .infinity, alignment: .leading)
                        control.fixedSize()
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        labels
                        control
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 20) {
                    labels
                    Spacer(minLength: 20)
                    control
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct ProfilesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @State private var newName = ""
    @State private var newStart = Date()
    @State private var editing: String?
    @State private var draft = ""
    @State private var removing: Profile?

    var body: some View {
        SettingsSection(title: "Profiles", detail: "Each profile is a whole Cairn: its own mountain, logs, quests and settings.") {
            ForEach(model.profiles.profiles) { p in
                let active = p.id == model.profiles.active
                let nameRow = HStack(spacing: 12) {
                    Circle().fill(active ? Ink.red : Ink.sand).frame(width: 8, height: 8)
                    if editing == p.id {
                        TextField("Name", text: $draft).textFieldStyle(.roundedBorder).frame(width: compact ? nil : 200)
                            .onSubmit { model.renameProfile(p.id, to: draft); editing = nil }
                    } else {
                        Text(p.name).font(Face.heading).foregroundStyle(Ink.ink)
                        if active { Text("in use").font(Face.small).foregroundStyle(Ink.ink2) }
                    }
                }
                let buttons = HStack(spacing: 8) {
                    if editing == p.id {
                        Button("Save") { model.renameProfile(p.id, to: draft); editing = nil }.buttonStyle(InkButtonStyle())
                    } else {
                        Button("Rename") { draft = p.name; editing = p.id }.buttonStyle(InkButtonStyle(filled: false))
                    }
                    if !active {
                        Button("Switch to") { model.switchProfile(p.id) }.buttonStyle(InkButtonStyle())
                        Button { removing = p } label: { Image(systemName: "trash") }
                            .buttonStyle(QuietIconButton()).help("Remove \(p.name)")
                            .accessibilityLabel("Remove \(p.name)")
                    }
                }
                Group {
                    if compact {
                        VStack(alignment: .leading, spacing: 10) { nameRow; buttons }
                    } else {
                        HStack(spacing: 12) { nameRow; Spacer(); buttons }
                    }
                }
                .padding(.vertical, 4)
            }
            Rule(seed: 70)
            if compact {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("New profile name", text: $newName).textFieldStyle(.roundedBorder)
                    HStack(spacing: 12) {
                        Text("Starts").font(Face.small).foregroundStyle(Ink.ink2)
                        DatePicker("", selection: $newStart, displayedComponents: .date).labelsHidden().fieldDatePicker()
                        Spacer(minLength: 0)
                    }
                    Button("Create and switch") {
                        model.createProfile(name: newName, start: newStart)
                        newName = ""
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } else {
                HStack(spacing: 12) {
                    TextField("New profile name", text: $newName).textFieldStyle(.roundedBorder).frame(width: 200)
                    Text("starts").font(Face.small).foregroundStyle(Ink.ink2)
                    DatePicker("", selection: $newStart, displayedComponents: .date).labelsHidden().fieldDatePicker().frame(width: 110)
                    Spacer()
                    Button("Create and switch") {
                        model.createProfile(name: newName, start: newStart)
                        newName = ""
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .confirmationDialog("Remove \(removing?.name ?? "")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } })) {
            Button("Remove", role: .destructive) { if let r = removing { model.removeProfile(r.id) }; removing = nil }
        } message: {
            Text("It leaves the list. Its file stays in the data folder, renamed, so nothing is deleted.")
        }
    }
}

struct ResetSection: View {
    @Environment(AppModel.self) private var model
    @State private var pending: ResetScope?

    var body: some View {
        SettingsSection(title: "Reset", detail: "Every reset saves a snapshot first, so each one can be undone. To take back a single quest, right-click it on the mountain.") {
            if model.lastResetSnapshot != nil {
                SettingRow("Undo the last reset", detail: "Puts this profile back exactly as it was before.") {
                    Button("Undo reset") { model.undoLastReset() }.buttonStyle(InkButtonStyle())
                }
                Rule(seed: 71)
            }
            ForEach(ResetScope.allCases) { scope in
                SettingRow(scope.title, detail: scope.detail) {
                    Button("Reset…") { pending = scope }
                        .buttonStyle(InkButtonStyle(filled: false, red: scope == .everything))
                }
            }
        }
        .confirmationDialog("Reset \(pending?.title.lowercased() ?? "")?", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } })) {
            Button("Reset", role: .destructive) { if let p = pending { model.reset(p) }; pending = nil }
        } message: {
            Text((pending?.detail ?? "") + " You can undo it from here.")
        }
    }
}

#if os(macOS)
/// The iPhone pairs with this Mac using the code shown here.
struct MacPeerSettings: View {
    @Environment(AppModel.self) private var model
    @State private var enabled = PeerHost.shared.enabled
    @State private var code = PeerSync.hostCode

    var body: some View {
        Rule(seed: 72)
        SettingRow("iPhone sync", detail: "Off by default. When on, Cairn on your iPhone syncs with this Mac over Wi-Fi while Cairn is open here. The link is not encrypted, so use it on a network you trust.") {
            Toggle("", isOn: $enabled).toggleStyle(.switch).labelsHidden()
                .onChange(of: enabled) { _, on in
                    PeerHost.shared.enabled = on
                    if on { PeerHost.shared.start(model) } else { PeerHost.shared.stop() }
                }
        }
        if enabled {
            SettingRow("Pairing code", detail: "Type this into Cairn on the iPhone once. New code = every phone has to pair again.") {
                HStack(spacing: 12) {
                    Text(code.map { String($0) }.joined(separator: " "))
                        .font(.system(size: 20, weight: .semibold, design: .monospaced)).foregroundStyle(Ink.ink)
                        .textSelection(.enabled)
                    Button("New code") { PeerSync.hostCode = PeerSync.newCode(); code = PeerSync.hostCode }
                        .buttonStyle(InkButtonStyle(filled: false))
                }
            }
            SettingRow("Last phone sync", detail: model.lastPeer.map { "\($0.at.formatted(date: .omitted, time: .shortened)) · \($0.detail)" } ?? "None since Cairn opened") {
                EmptyView()
            }
        }
    }
}
#endif

/// V grades, or the gym's colour circuits (green = V0–V3, blue = V3–V4…).
struct GradesSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact

    var body: some View {
        SettingsSection(title: "Grades", detail: "Pick the scale you think in, and your gym's colours if it grades by colour. Cairn converts the plan's grades into whatever you choose.") {
            SettingRow("Scale", detail: "V (Hueco) or Font (Fontainebleau). Font is finer: 6A and 6A+ are both V3. Old logs convert.") {
                Picker("", selection: Binding(get: { model.store.settings.gradeScale }, set: { v in model.mutate { $0.settings.gradeScale = v } })) {
                    Text("V scale").tag(GradeScale.v)
                    Text("Font").tag(GradeScale.font)
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 180)
            }
            SettingRow("My gym grades by colour", detail: "Switches the logger, the pyramid and the plan's wording to your colours.") {
                Toggle("", isOn: Binding(get: { model.store.settings.useCircuits }, set: { on in
                    model.mutate { s in
                        s.settings.useCircuits = on
                        if on && s.settings.circuits.isEmpty { s.settings.circuits = GradeCircuit.starter }
                    }
                }))
                .toggleStyle(.switch).labelsHidden()
            }
            if model.store.settings.useCircuits {
                Rule(seed: 90)
                ForEach(model.circuits) { c in CircuitRow(circuit: c) }
                HStack {
                    Button {
                        model.mutate { s in
                            let used = Set(s.settings.circuits.map(\.name))
                            let pick = GradeCircuit.palette.first { !used.contains($0.0) } ?? ("New colour", 0x888888)
                            var c = GradeCircuit(name: pick.0, hex: pick.1, low: 0, high: 0)
                            if s.settings.gradeScale == .font {
                                let top = s.settings.circuits.map(\.fontRange.upperBound).max() ?? 0
                                c.setFont(low: min(top + 1, GradeScale.fontNames.count - 1), high: min(top + 2, GradeScale.fontNames.count - 1))
                            } else {
                                let top = s.settings.circuits.map(\.high).max() ?? 0
                                c.setV(low: top, high: top + 1)
                            }
                            s.settings.circuits.append(c)
                        }
                    } label: { Label("Add a colour", systemImage: "plus") }
                        .buttonStyle(InkButtonStyle(filled: false))
                    Spacer()
                }
                Text(model.scale == .font
                     ? "Put each colour in with the Font range your gym gives it. Each colour counts as its easiest grade for the plan's caps and quests, so a green 4–5+ never counts as a 5+."
                     : "Each colour counts as its easiest grade for the plan's caps and quests, so a green V0–V3 never counts as a V3. Put the colours in with the range your gym gives them — a sign by the wall or the front desk usually has it.")
                    .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CircuitRow: View {
    @Environment(AppModel.self) private var model
    let circuit: GradeCircuit

    var index: Int? { model.store.settings.circuits.firstIndex { $0.id == circuit.id } }

    var body: some View {
        if let i = index {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    // The wheel: any colour your gym uses. The menu beside it has the usual ones.
                    ColorPicker("", selection: Binding(get: { circuit.color },
                                                       set: { c in model.mutate { $0.settings.circuits[i].hex = Hex.value(c) } }),
                                supportsOpacity: false)
                        .labelsHidden()
                        .frame(width: 34, height: 28)
                        .accessibilityLabel("Colour wheel for \(circuit.name)")
                    Menu {
                        ForEach(GradeCircuit.palette, id: \.0) { p in
                            Button {
                                model.mutate { $0.settings.circuits[i].hex = p.1; if $0.settings.circuits[i].name == "New colour" { $0.settings.circuits[i].name = p.0 } }
                            } label: { Label(p.0, systemImage: circuit.hex == p.1 ? "checkmark.circle.fill" : "circle.fill") }
                        }
                    } label: {
                        Image(systemName: "swatchpalette").font(.system(size: 13)).foregroundStyle(Ink.ink2)
                    }
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help("Usual colours: white, yellow, orange, green, blue, cyan, teal, purple, pink, red, brown, grey, black")
                    .accessibilityLabel("Usual colours for \(circuit.name)")
                    TextField("Name", text: Binding(get: { circuit.name }, set: { v in model.mutate { $0.settings.circuits[i].name = v } }))
                        .textFieldStyle(.plain).font(Face.heading)
                    Button { model.mutate { $0.settings.circuits.remove(at: i) } } label: { Image(systemName: "trash") }
                        .buttonStyle(QuietIconButton()).accessibilityLabel("Remove \(circuit.name)")
                }
                if model.scale == .font {
                    HStack(spacing: 8) {
                        StepperField(value: Binding(get: { circuit.fontRange.lowerBound },
                                                    set: { v in model.mutate { let hi = $0.settings.circuits[i].fontRange.upperBound; $0.settings.circuits[i].setFont(low: min(v, hi), high: hi) } }),
                                     range: 0...(GradeScale.fontNames.count - 1), label: GradeScale.fontName)
                        Text("to").font(Face.small).foregroundStyle(Ink.ink2)
                        StepperField(value: Binding(get: { circuit.fontRange.upperBound },
                                                    set: { v in model.mutate { let lo = $0.settings.circuits[i].fontRange.lowerBound; $0.settings.circuits[i].setFont(low: lo, high: max(v, lo)) } }),
                                     range: 0...(GradeScale.fontNames.count - 1), label: GradeScale.fontName)
                    }
                    .padding(.leading, 36)
                    Text("≈ \(circuit.range(in: .v)) on the V scale").font(Face.small).foregroundStyle(Ink.ink2).padding(.leading, 36)
                } else {
                    HStack(spacing: 8) {
                        Text("V").font(Face.small).foregroundStyle(Ink.ink2)
                        StepperField(value: Binding(get: { circuit.low }, set: { v in model.mutate { $0.settings.circuits[i].setV(low: min(v, $0.settings.circuits[i].high), high: $0.settings.circuits[i].high) } }), range: 0...17)
                        Text("to V").font(Face.small).foregroundStyle(Ink.ink2)
                        StepperField(value: Binding(get: { circuit.high }, set: { v in model.mutate { $0.settings.circuits[i].setV(low: $0.settings.circuits[i].low, high: max(v, $0.settings.circuits[i].low)) } }), range: 0...17)
                    }
                    .padding(.leading, 36)
                    Text("≈ \(circuit.range(in: .font)) in Font").font(Face.small).foregroundStyle(Ink.ink2).padding(.leading, 36)
                }
            }
            .padding(.vertical, 6)
        }
    }
}


// MARK: - Smart scheduling

/// The scheduling rules, written as sentences: if I do this, the app changes that.
struct SchedulingSection: View {
    @Environment(AppModel.self) private var model

    private func rules(_ change: @escaping (inout ScheduleRules) -> Void) { model.mutate { change(&$0.settings.schedule) } }
    private var r: ScheduleRules { model.store.settings.schedule }

    private func modePicker(_ get: AdaptMode, _ set: @escaping (inout ScheduleRules, AdaptMode) -> Void) -> some View {
        Picker("", selection: Binding(get: { get }, set: { v in rules { set(&$0, v) } })) {
            ForEach(AdaptMode.allCases) { Text($0.name).tag($0) }
        }
        .pickerStyle(.menu).labelsHidden().fixedSize()
    }

    var body: some View {
        SettingsSection(title: "Smart scheduling", detail: "Rules the schedule follows on its own. Each one is written as what you do, and what the app changes because of it.") {
            SettingRow("If I bring a session forward", detail: "It's done for the week and comes off the day it was on. You can always add it again from Change day. This one is always on.") {
                Text("Always").font(Face.small).foregroundStyle(Ink.ink2)
            }
            Rule(seed: 95)
            SettingRow("If I skip a session for time or energy", detail: "it moves to the next free day this week where the spacing still works. Sick days are handled by the return-week rule instead.") {
                modePicker(r.skipCarry) { $0.skipCarry = $1 }
            }
            SettingRow("If my elbows read red", detail: "pulling and climbing are swapped for prehab until a check-in comes back green.") {
                modePicker(r.elbow) { $0.elbow = $1 }
            }
            SettingRow("Pull stays clear of hard climbs", detail: "Days between a pull session and a hard climb. If it's closer, it's flagged and a better day is offered.") {
                StepperField(value: Binding(get: { r.pullGapDays }, set: { v in rules { $0.pullGapDays = v } }), range: 1...3, suffix: " days")
            }
            SettingRow("If I miss the same session this many weeks running", detail: "Cairn looks at which weekday you actually train and offers to move it there for good.") {
                StepperField(value: Binding(get: { r.patternWeeks }, set: { v in rules { $0.patternWeeks = v } }), range: 2...6, suffix: " weeks")
            }
            SettingRow("Warn me when I move things", detail: "Back-to-back push, legs the day before a hard climb, hard climbs on consecutive days.") {
                Toggle("", isOn: Binding(get: { r.warnings }, set: { v in rules { $0.warnings = v } })).toggleStyle(.switch).labelsHidden()
            }
            Text("\"Adjust automatically\" does it and tells you; \"Ask me first\" shows a card on Today; \"Never adjust\" leaves it alone.")
                .font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Progression and the coach

struct ProgressionSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    private var s: Settings { model.store.settings }

    var body: some View {
        SettingsSection(title: "Progression and coach", detail: "How lifts move up and down, and how the check-in with Claude works.") {
            SettingRow("Smallest weight jump", detail: "When every set is at the top of the range at one weight, the weight goes up this much (22.5 → 25). Small lifts like lateral raises move 1 kg.") {
                StepperField(value: Binding(get: { Int((s.weightStepKg * 2).rounded()) }, set: { v in model.mutate { $0.settings.weightStepKg = Double(v) / 2 } }),
                             range: 1...20, label: { Overload.kgText(Double($0) / 2) + " kg" })
            }
            Text("""
            The rules: all sets at the top of the range, all at one weight → up one step, reps back to the bottom. Short of the top → same weight, aim every set at the top. Reps there but a lighter set in the mix → all sets at one weight first. Two rough sessions in a row → lighter, rebuilt from the bottom; one is just an off day. Bands move in rungs, so the top has to land twice. Holds gain five seconds.
            """).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            Rule(seed: 96)
            SettingRow("Coach model", detail: "The check-in runs the claude program on your Mac with this model. Sonnet 5.5 is the default.") {
                TextField("", text: Binding(get: { s.coachModel }, set: { v in model.mutate { $0.settings.coachModel = v } }))
                    .textFieldStyle(.roundedBorder).frame(width: compact ? 170 : 220)
            }
            SettingRow("Weekly analysis thinks", detail: "The daily check-in always uses medium.") {
                Picker("", selection: Binding(get: { s.coachEffort }, set: { v in model.mutate { $0.settings.coachEffort = v } })) {
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 160)
            }
            #if os(macOS)
            SettingRow("Claude program", detail: claudeDetail) {
                TextField("auto", text: Binding(get: { s.claudePath }, set: { v in model.mutate { $0.settings.claudePath = v } }))
                    .textFieldStyle(.roundedBorder).frame(width: 220)
            }
            #endif
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("What the coach is told about you").font(Face.body)
                    Spacer()
                    if !s.coachContext.isEmpty {
                        Button("Use the built-in text") { model.mutate { $0.settings.coachContext = "" } }.buttonStyle(TextLinkStyle()).font(Face.small)
                    }
                }
                TextEditor(text: Binding(get: { s.coachContext.isEmpty ? Coach.defaultContext : s.coachContext },
                                         set: { v in model.mutate { $0.settings.coachContext = v == Coach.defaultContext ? "" : v } }))
                    .font(Face.small).scrollContentBackground(.hidden)
                    .frame(height: 130).padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Ink.sand))
                Text("This goes to Claude with your training data, and nothing else about you does.").font(Face.tiny).foregroundStyle(Ink.ink2)
            }
        }
    }

    #if os(macOS)
    var claudeDetail: String {
        if let p = CoachRunner.locate(s.claudePath) { return "Found at \(p.replacingOccurrences(of: NSHomeDirectory(), with: "~")). It must be signed in: run claude in Terminal and use /login if a check-in says it isn't." }
        return "Not found. Install Claude Code, or type its path here."
    }
    #endif
}
