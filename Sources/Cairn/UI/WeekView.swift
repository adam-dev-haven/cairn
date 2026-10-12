import SwiftUI

struct WeekView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    @State private var index: Int?
    @State private var day: Date?

    var body: some View {
        let idx = index ?? max(0, min(model.calendarIndex(for: model.today), model.plan.timeline.count - 1))
        if let day {
            DayView(date: day, isToday: Day.key(day) == Day.key(model.today), onBack: { withAnimation { self.day = nil } })
        } else if let week = model.blockWeek(at: idx) {
            content(idx: idx, week: week)
        }
    }

    @ViewBuilder
    func content(idx: Int, week: AppModel.BlockWeek) -> some View {
        let start = model.weekStart(idx)
        Page(title: "Week \(week.number) of \(model.plan.weeks.count)",
             subtitle: "\(week.phase.name) · \(Day.short(start)) – \(Day.short(Day.add(6, to: start)))" + (week.entry.reason == .repeated ? " · second go" : week.entry.reason == .recovery ? " · return week" : "")) {
            HStack(spacing: 8) {
                Button { index = idx - 1 } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(QuietIconButton()).disabled(idx == 0).keyboardShortcut("[", modifiers: .command)
                Button("This week") { index = nil }.buttonStyle(InkButtonStyle(filled: false))
                    .disabled(index == nil)
                Button { index = idx + 1 } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(QuietIconButton()).disabled(idx >= model.plan.timeline.count - 1).keyboardShortcut("]", modifiers: .command)
            }
        } content: {
            VStack(alignment: .leading, spacing: 32) {
                AdaptationBanners(date: model.today)
                if compact {
                    VStack(spacing: 0) {
                        ForEach(Array(model.days(ofWeek: idx).enumerated()), id: \.offset) { i, d in
                            DayRow(date: d, weekday: i) { withAnimation { day = d } }
                            if i < 6 { Rule(seed: i + 80) }
                        }
                    }
                    .sheetCard(padding: 14)
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(Array(model.days(ofWeek: idx).enumerated()), id: \.offset) { i, d in
                            DayColumn(date: d, weekday: i) { withAnimation { day = d } }
                        }
                    }
                }

                AdaptiveStack(spacing: 24) {
                    ScoreCard(index: idx)
                        .frame(maxWidth: .infinity)
                    WeekBrief(week: week)
                        .frame(maxWidth: .infinity)
                }

                ScheduleCard(index: idx)
                AdaptCard(isCurrent: idx == model.calendarIndex(for: model.today))
            }
        }
    }
}

struct DayColumn: View {
    @Environment(AppModel.self) private var model
    let date: Date
    let weekday: Int
    var open: () -> Void
    @State private var hover = false

    var body: some View {
        let items = model.plannedItems(for: date)
        let isToday = Day.key(date) == Day.key(model.today)
        let sick = model.daily(date).sick
        Button(action: open) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text(Day.weekdayShort[weekday]).font(.system(size: 13, weight: .semibold)).foregroundStyle(isToday ? Ink.red : Ink.ink)
                    Spacer()
                    Text(date.formatted(.dateTime.day())).font(Face.display(20)).monospacedDigit().foregroundStyle(Ink.ink)
                }
                Text(model.pattern(for: date).place).font(Face.tiny).foregroundStyle(Ink.ink2)
                Rule(seed: weekday + 20)
                if sick {
                    Label("Sick", systemImage: "bandage").font(Face.small).foregroundStyle(Ink.ink2)
                }
                ForEach(items.filter { $0.kind != .rest || items.count == 1 }) { item in
                    let done = model.isDone(item, on: date)
                    HStack(spacing: 7) {
                        Image(systemName: done && item.kind != .rest ? "checkmark.circle.fill" : item.kind.symbol)
                            .font(.system(size: 12))
                            .foregroundStyle(done && item.kind != .rest ? Ink.ink : Ink.ink2)
                            .frame(width: 16)
                        Text(label(item)).font(.system(size: 12)).foregroundStyle(Ink.ink).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                if let steps = model.daily(date).steps {
                    Text("\(steps.formatted()) steps").font(Face.tiny).foregroundStyle(Ink.ink2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 196, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isToday ? Ink.sheet : (hover ? Ink.sheet : Ink.sheet.opacity(0.6)))
                    .shadow(color: Ink.ink.opacity(isToday ? 0.07 : 0), radius: 14, y: 8)
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(isToday ? Ink.red.opacity(0.6) : Ink.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Open \(Day.long(date))")
    }

    func label(_ item: PlannedItem) -> String {
        if let w = model.workout(item.workoutID), item.kind == .workout || item.kind == .home { return "\(w.id) · \(w.name)" }
        return item.kind.name
    }
}

struct ScoreCard: View {
    @Environment(AppModel.self) private var model
    let index: Int
    var body: some View {
        let s = model.score(week: index)
        let p = model.plan.points
        let rows: [(String, Int, String)] = [
            ("Gym mornings", s.gym, "\(p.gymSession) each"),
            ("Home session", s.home, "\(p.homeSession)"),
            ("Prehab", s.prehab, "\(p.prehab) each"),
            ("Step floors and goals", s.steps, "\(p.stepFloor) / +\(p.stepGoalBonus) a day"),
            ("Protein days", s.protein, "\(p.protein) a day"),
            ("New hardest send", s.sends, "\(p.newHardestSend)"),
            ("Drill got boring", s.drill, "\(p.drillBoring)"),
        ]
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Points").font(Face.title)
                Spacer()
                Text("\(s.total)").font(Face.display(34)).monospacedDigit()
                Text("/ \(p.greenWeek)").font(Face.body).foregroundStyle(Ink.ink2)
            }
            ForEach(rows, id: \.0) { r in
                HStack {
                    Text(r.0).font(Face.body).foregroundStyle(Ink.ink)
                    Text(r.2).font(Face.small).foregroundStyle(Ink.ink3)
                    Spacer()
                    Text(r.1 == 0 ? "–" : "+\(r.1)").font(.system(size: 13, weight: .medium)).monospacedDigit()
                        .foregroundStyle(r.1 == 0 ? Ink.ink3 : Ink.ink)
                }
            }
            Rule(seed: 31)
            Text(model.isGreen(week: index) ? "Green week." : "Green at \(p.greenWeek). A full week is around 70. Nothing here punishes a single bad day.")
                .font(Face.small).foregroundStyle(model.isGreen(week: index) ? Ink.green : Ink.ink2)
        }
        .sheetCard()
    }
}

struct WeekBrief: View {
    @Environment(AppModel.self) private var model
    let week: AppModel.BlockWeek
    var body: some View {
        let monday = model.weekStart(week.index)
        let drill = model.drill(for: model.today >= monday && model.today < Day.add(7, to: monday) ? model.today : monday)
        VStack(alignment: .leading, spacing: 14) {
            Text(week.template.focus).font(Face.title).fixedSize(horizontal: false, vertical: true)
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    Text("Effort").font(Face.small).foregroundStyle(Ink.ink2)
                    Text(week.phase == .recovery ? "Stop 4 short, half the sets" : week.template.effort).font(Face.body)
                }
                GridRow {
                    Text("Drill").font(Face.small).foregroundStyle(Ink.ink2)
                    Text(drill?.name ?? "—").font(Face.body)
                }
                GridRow {
                    Text("Repeats").font(Face.small).foregroundStyle(Ink.ink2)
                    Text(model.grades(week.template.gradeRepeats)).font(Face.body)
                }
                GridRow {
                    Text("Projects").font(Face.small).foregroundStyle(Ink.ink2)
                    Text(model.grades(week.template.gradeProjects)).font(Face.body)
                }
                GridRow {
                    Text("Steps").font(Face.small).foregroundStyle(Ink.ink2)
                    Text("floor \(week.template.stepFloor.formatted()) · goal \(week.template.stepGoal.formatted())").font(Face.body)
                }
            }
            Rule(seed: 32)
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb").foregroundStyle(Ink.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text(week.template.tip.title).font(Face.heading)
                    Text(week.template.tip.body).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .sheetCard()
    }
}

struct AdaptCard: View {
    @Environment(AppModel.self) private var model
    @Environment(\.compact) private var compact
    var isCurrent: Bool
    @State private var confirmRepeat = false
    @State private var confirmReturn = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle(text: "When life happens", detail: "Don't catch up. Repeat the week and slide everything by seven days.")
            AdaptiveStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(rule).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    Picker("", selection: Binding(get: { model.store.settings.adaptMode },
                                                  set: { v in model.mutate { $0.settings.adaptMode = v } })) {
                        ForEach(AdaptMode.allCases) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(maxWidth: compact ? nil : 420)
                    Text("Summit now: \(Day.long(model.summitDate))").font(Face.small).foregroundStyle(Ink.ink2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if isCurrent {
                    VStack(alignment: .trailing, spacing: 10) {
                        Button("Repeat this week next week") { confirmRepeat = true }
                            .buttonStyle(InkButtonStyle(filled: false))
                        Button("Make this an easy return week") { confirmReturn = true }
                            .buttonStyle(InkButtonStyle(filled: false))
                    }
                }
            }
            if !model.store.adaptations.isEmpty {
                Rule(seed: 40)
                ForEach(model.store.adaptations.prefix(6)) { e in
                    HStack(spacing: 12) {
                        Text(Day.date(e.day).map(Day.short) ?? e.day).font(Face.small).foregroundStyle(Ink.ink2).frame(width: 60, alignment: .leading)
                        Text(e.message).font(Face.body).foregroundStyle(e.undone ? Ink.ink3 : Ink.ink).strikethrough(e.undone)
                        Spacer()
                        if !e.undone && e.id == model.store.adaptations.first?.id {
                            Button("Undo") { model.undo(e) }.buttonStyle(InkButtonStyle(filled: false))
                        }
                    }
                }
            }
        }
        .sheetCard()
        .confirmationDialog("Repeat this week?", isPresented: $confirmRepeat) {
            Button("Repeat it") { model.repeatCurrentWeek() }
        } message: {
            Text("Next week runs this week's plan again. Everything after moves seven days later.")
        }
        .confirmationDialog("Make this a return week?", isPresented: $confirmReturn) {
            Button("Make it easy") { model.makeCurrentWeekReturn() }
        } message: {
            Text("This week becomes half the sets on easy grades. This week's plan runs again next week.")
        }
    }

    var rule: String {
        let s = model.store.settings
        return "Miss \(s.missedGymDaysToRepeat) or more gym mornings in a week and that week repeats. \(s.sickDaysForReturnWeek)+ sick days adds an easy return week first. Holiday and test weeks never move."
    }
}

/// One day as a row, for the phone's week.
struct DayRow: View {
    @Environment(AppModel.self) private var model
    let date: Date
    let weekday: Int
    var open: () -> Void

    var body: some View {
        let items = model.plannedItems(for: date).filter { $0.kind != .rest && $0.kind != .check }
        let isToday = Day.key(date) == Day.key(model.today)
        Button(action: open) {
            HStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text(Day.weekdayShort[weekday]).font(.system(size: 11, weight: .semibold)).foregroundStyle(isToday ? Ink.red : Ink.ink2)
                    Text(date.formatted(.dateTime.day())).font(Face.display(20)).monospacedDigit().foregroundStyle(Ink.ink)
                }
                .frame(width: 40)
                VStack(alignment: .leading, spacing: 5) {
                    if model.daily(date).sick {
                        Label("Sick", systemImage: "bandage").font(Face.small).foregroundStyle(Ink.ink2)
                    } else if items.isEmpty {
                        Text("Rest").font(Face.small).foregroundStyle(Ink.ink2)
                    } else {
                        FlowLayout(spacing: 6) {
                            ForEach(items) { item in
                                let done = model.isDone(item, on: date)
                                HStack(spacing: 4) {
                                    Image(systemName: done ? "checkmark.circle.fill" : item.kind.symbol).font(.system(size: 11))
                                    Text(label(item)).font(.system(size: 12))
                                }
                                .foregroundStyle(done ? Ink.ink : Ink.ink2)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Capsule().fill(done ? Ink.sand : Ink.sand.opacity(0.45)))
                            }
                        }
                    }
                    if let steps = model.daily(date).steps {
                        Text("\(steps.formatted()) steps").font(Face.tiny).foregroundStyle(Ink.ink2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(Ink.ink2)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Day.weekdayLong[weekday]) \(date.formatted(.dateTime.day().month()))")
    }

    func label(_ item: PlannedItem) -> String {
        if let w = model.workout(item.workoutID), item.kind == .workout || item.kind == .home { return "\(w.id) · \(w.name)" }
        return item.kind.name
    }
}
