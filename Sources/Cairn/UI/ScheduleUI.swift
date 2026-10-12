import SwiftUI

/// "Change this day": what's on it, move things off, bring a session in.
/// A session brought forward is done for the week and comes off the day it
/// was on; you can always add it again.
struct DayEditor: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let date: Date
    @State private var message: String?

    private var week: Int { model.calendarIndex(for: date) }
    private var items: [PlannedItem] { model.plannedItems(for: date).filter { $0.kind != .rest } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let message {
                Label(message, systemImage: "checkmark.circle").font(Face.small).foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if items.isEmpty {
                Text("Nothing on this day.").font(Face.body).foregroundStyle(Ink.ink2)
            }
            ForEach(items) { item in row(item) }

            let off = model.takenOff(on: date)
            if !off.isEmpty {
                Text("Taken off this day").font(Face.tiny).foregroundStyle(Ink.ink3).textCase(.uppercase)
                ForEach(off) { item in
                    HStack {
                        Text(model.name(of: item)).font(Face.body).foregroundStyle(Ink.ink2).strikethrough()
                        Spacer()
                        Button("Put back") { model.putBack(item, on: date); message = "\(model.name(of: item)) is back on this day." }
                            .buttonStyle(InkButtonStyle(filled: false))
                    }
                }
            }

            Rule(seed: 61)
            let fits = model.suggestedForDay(date)
            if !fits.isEmpty {
                Text("Fits here").font(Face.tiny).foregroundStyle(Ink.ink3).textCase(.uppercase)
                ForEach(fits) { t in templateRow(t, highlighted: true) }
            }
            Text("Add a session").font(Face.tiny).foregroundStyle(Ink.ink3).textCase(.uppercase)
            ForEach(model.sessionTemplates.filter { t in !fits.contains(t) }) { t in templateRow(t, highlighted: false) }

            let issues = model.scheduleIssues(week: week)
            if !issues.isEmpty {
                Rule(seed: 62)
                Text("Heads up").font(Face.tiny).foregroundStyle(Ink.ink3).textCase(.uppercase)
                ForEach(issues) { i in
                    Label(i.text, systemImage: "exclamationmark.triangle").font(Face.small).foregroundStyle(Ink.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("Only this date changes. Next week's pattern is as it was; the plan itself lives in Settings → Your week.")
                .font(Face.tiny).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
        }
    }

    func row(_ item: PlannedItem) -> some View {
        let done = model.isDone(item, on: date)
        return HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : item.kind.symbol).foregroundStyle(done ? Ink.ink : Ink.ink2).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(model.name(of: item)).font(Face.body).foregroundStyle(Ink.ink)
                if let from = item.from, let d = Day.date(from) {
                    Text("Moved from \(Day.weekdayShort[Day.weekday(d) - 1])").font(Face.tiny).foregroundStyle(Ink.ink2)
                } else if item.extra == true {
                    Text("Extra").font(Face.tiny).foregroundStyle(Ink.ink2)
                }
            }
            Spacer()
            if !done && item.kind != .check {
                Menu {
                    ForEach(Array(model.days(ofWeek: week).enumerated()), id: \.offset) { i, d in
                        if Day.key(d) != Day.key(date), d >= model.today || model.today <= date {
                            Button {
                                model.move(item, from: date, to: d)
                                message = "\(model.name(of: item)) moved to \(Day.weekdayLong[i])."
                            } label: { Text("\(Day.weekdayLong[i]) \(Day.short(d))") }
                        }
                    }
                } label: { Text("Move") }
                    .menuStyle(.button).buttonStyle(InkButtonStyle(filled: false)).fixedSize()
                Button {
                    model.takeOff(item, on: date)
                    message = "\(model.name(of: item)) is off this day."
                } label: { Image(systemName: "xmark") }
                    .buttonStyle(QuietIconButton()).accessibilityLabel("Take \(model.name(of: item)) off this day")
            }
        }
        .frame(minHeight: 36)
    }

    func templateRow(_ t: SessionTemplate, highlighted: Bool) -> some View {
        let there = model.plannedElsewhere(t, on: date)
        let here = items.contains { $0.kind == t.kind && $0.workoutID == t.workoutID && (t.kind != .climb) }
            || (t.kind == .climb && items.contains { $0.kind == .climb })
        let warn = here ? [] : model.warnings(adding: t, on: date)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(systemName: t.symbol).foregroundStyle(highlighted ? Ink.red : Ink.ink2).frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(t.name).font(Face.body).foregroundStyle(here ? Ink.ink3 : Ink.ink)
                    Text(here ? "Already on this day" : there.map { "Planned \(Day.weekdayShort[Day.weekday($0.date) - 1]): moves here, and is done for the week" } ?? "Adds it again")
                        .font(Face.tiny).foregroundStyle(Ink.ink2)
                }
                Spacer()
                Button(there == nil ? "Add again" : "Bring here") {
                    message = model.add(t, on: date)
                }
                .buttonStyle(InkButtonStyle(filled: highlighted))
                .disabled(here)
            }
            ForEach(warn, id: \.self) { w in
                Label(w, systemImage: "exclamationmark.triangle").font(Face.tiny).foregroundStyle(Ink.red)
                    .fixedSize(horizontal: false, vertical: true).padding(.leading, 32)
            }
        }
        .padding(.vertical, 2)
    }
}

/// The schedule's own suggestions, on Today: a skipped session with a day
/// that fits, red elbows, a pull too close to a hard climb.
struct ScheduleBanners: View {
    @Environment(AppModel.self) private var model
    let date: Date
    var body: some View {
        if Day.key(date) == Day.key(model.today) {
            let list = model.scheduleSuggestions(week: model.calendarIndex(for: date))
            VStack(alignment: .leading, spacing: 10) {
                ForEach(list) { s in
                    NoticeCard(symbol: "calendar.badge.clock", text: s.title + ". " + s.detail) {
                        Button("Not now") { withAnimation { model.dismissSchedule(s.id) } }.buttonStyle(InkButtonStyle(filled: false))
                        Button(s.applyLabel) { withAnimation { model.apply(s) } }.buttonStyle(InkButtonStyle())
                    }
                }
            }
        }
    }
}

/// Under Today's cards of the week: where sessions can move, and what the
/// weekday history says.
struct ScheduleCard: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @Environment(\.compact) private var compact
    let index: Int

    var body: some View {
        let issues = model.scheduleIssues(week: index)
        let sug = model.scheduleSuggestions(week: index) + (index == model.calendarIndex(for: model.today) ? model.patternSuggestions() : [])
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "Smart scheduling", detail: "Spacing is checked every time something moves. Open a day and press Change day to move a session, take one off, or bring another in.")
            if issues.isEmpty {
                Label("No spacing problems this week: hard climbs have a day between, pull is clear of them, nothing stacks.", systemImage: "checkmark.circle")
                    .font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
            ForEach(issues) { i in
                Label(i.text, systemImage: "exclamationmark.triangle").font(Face.body).foregroundStyle(Ink.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(sug) { s in
                Rule(seed: 70)
                VStack(alignment: .leading, spacing: 8) {
                    Text(s.title).font(Face.heading).fixedSize(horizontal: false, vertical: true)
                    Text(s.detail).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Not now") { model.dismissSchedule(s.id) }.buttonStyle(InkButtonStyle(filled: false))
                        Button(s.applyLabel) { model.apply(s) }.buttonStyle(InkButtonStyle())
                    }
                }
            }
        }
        .sheetCard()
    }
}

/// Small links at the foot of an open session card: move it, or take it off.
struct ItemMoveRow: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    let item: PlannedItem
    let date: Date

    var body: some View {
        if item.kind != .rest && item.kind != .check && !model.isDone(item, on: date) {
            HStack(spacing: 14) {
                Button("Change this day…") {
                    nav.show("Change this day", symbol: "calendar.badge.plus") { DayEditor(date: date) }
                }
                .buttonStyle(TextLinkStyle()).font(Face.small).foregroundStyle(Ink.ink2)
                Spacer()
            }
        }
    }
}

// MARK: - Goals

/// What's next, so there's always a next: a harder grade, the next skill
/// step, the lifts that earned a step up.
struct GoalsCard: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        let climb = model.climbGoals.filter { !$0.met(model.store.sessions) }.prefix(2)
        let skills = model.skillGoals().prefix(2)
        let lifts = model.liftGoals()
        if !climb.isEmpty || !skills.isEmpty || !lifts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("What's next").font(Face.heading).foregroundStyle(Ink.ink)
                ForEach(Array(climb), id: \.id) { row($0) }
                ForEach(Array(skills), id: \.id) { row($0) }
                ForEach(lifts, id: \.id) { row($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheetCard(padding: 18)
        }
    }

    func row(_ g: Goal) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: g.symbol).font(.system(size: 13)).foregroundStyle(Ink.red).frame(width: 20).padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(g.title).font(Face.body).foregroundStyle(Ink.ink).fixedSize(horizontal: false, vertical: true)
                Text(g.detail).font(Face.tiny).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Every lift you've logged: last time, best, and what the overload rules say next.
struct LiftsPanel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact

    var body: some View {
        let rows = model.liftRows()
        VStack(alignment: .leading, spacing: 14) {
            SectionTitle(text: "Lifts", detail: "Top of the range on every set at one weight → up a step. Short of it → same weight, aim for the top. Two rough sessions → back off.")
            if rows.isEmpty {
                Text("Log a strength session and each exercise shows up here with its best and what to do next.")
                    .font(Face.body).foregroundStyle(Ink.ink2).sheetCard()
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { i, r in
                        LiftRowView(row: r)
                        if i < rows.count - 1 { Rule(seed: i + 90) }
                    }
                }
                .sheetCard()
            }
        }
    }
}

struct LiftRowView: View {
    let row: AppModel.LiftRow
    @Environment(\.compact) private var compact

    var body: some View {
        let info = Library.exercise(row.exerciseID)
        let t = row.next.targets
        let kg = t.first?.kg
        let load = kg.map { info.isBand ? Bands.text($0) : "\(Overload.kgText($0)) kg" }
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.name).font(Face.heading)
                Spacer()
                kindTag(row.next)
            }
            Text("Last \(Day.short(Day.date(row.last.day) ?? Date())): " + row.last.done.map { "\($0.value)" + ($0.kg.map { "@\(Overload.kgText($0))" } ?? "") }.joined(separator: ", ") + (row.last.timed ? " s" : ""))
                .font(Face.small).foregroundStyle(Ink.ink2)
            HStack(spacing: 14) {
                if let h = row.record.heaviest {
                    Text("Best \(Overload.kgText(h)) kg × \(row.record.heaviestReps)").font(Face.small).foregroundStyle(Ink.ink2)
                } else {
                    Text("Best \(row.record.bestReps)\(row.last.timed ? " s" : "") in a set").font(Face.small).foregroundStyle(Ink.ink2)
                }
                Text("Next: \(load.map { $0 + " · " } ?? "")\(t.map { "\($0.reps)" }.joined(separator: ", "))\(row.last.timed ? " s" : "")")
                    .font(.system(size: 13, weight: .semibold)).monospacedDigit()
            }
            Text(row.next.reason).font(Face.tiny).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder func kindTag(_ rx: Overload.Prescription) -> some View {
        switch rx.kind {
        case .progress: Label("Step up", systemImage: "arrow.up.right").font(Face.tiny).foregroundStyle(Ink.red)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.redSoft))
        case .fixLoad: Label("Same weight", systemImage: "equal").font(Face.tiny).foregroundStyle(Ink.amber)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.amber.opacity(0.14)))
        case .backOff: Label("Back off", systemImage: "arrow.down.right").font(Face.tiny).foregroundStyle(Ink.amber)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.amber.opacity(0.14)))
        case .stay where rx.plateau: Label("Plateau", systemImage: "pause").font(Face.tiny).foregroundStyle(Ink.amber)
                .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Ink.amber.opacity(0.14)))
        default: EmptyView()
        }
    }
}
