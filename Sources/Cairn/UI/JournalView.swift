import SwiftUI

struct JournalView: View {
    @Environment(AppModel.self) private var model
    @State private var day: Date?
    @State private var pick = Date()
    @State private var filter: ItemKind?

    var body: some View {
        if let day {
            DayView(date: day, isToday: Day.key(day) == Day.key(model.today), onBack: { withAnimation { self.day = nil } })
        } else {
            list.onAppear { pick = model.today }
        }
    }

    var sessions: [SessionLog] {
        model.store.sessions
            .filter { filter == nil || $0.kind == filter }
            .sorted { $0.day == $1.day ? $0.kind.rawValue < $1.kind.rawValue : $0.day > $1.day }
    }

    var list: some View {
        Page(title: "Journal", subtitle: "Every session you've logged, newest first. Open a day to change it.") {
            HStack(spacing: 10) {
                DatePicker("", selection: $pick, displayedComponents: .date).labelsHidden().fieldDatePicker().frame(width: 110)
                Button("Log that day") { withAnimation { day = Day.start(pick) } }.buttonStyle(InkButtonStyle())
            }
        } content: {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 6) {
                    Button("All") { filter = nil }.buttonStyle(ChipStyle(on: filter == nil))
                    ForEach([ItemKind.climb, .workout, .home, .prehab, .walk]) { k in
                        Button(k.name) { filter = k }.buttonStyle(ChipStyle(on: filter == k))
                    }
                }
                if sessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nothing logged yet.").font(Face.title)
                        Text("Log from Today, or pick a date above. Climbs from your watch show up here on their own.")
                            .font(Face.body).foregroundStyle(Ink.ink2)
                    }
                    .sheetCard()
                } else {
                    let groups = Dictionary(grouping: sessions) { model.calendarIndex(for: $0.date) }
                    ForEach(groups.keys.sorted(by: >), id: \.self) { idx in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .firstTextBaseline) {
                                if let w = model.blockWeek(at: idx) {
                                    Text("Week \(w.number)").font(Face.title)
                                    Text(w.phase.name).font(Face.small).foregroundStyle(Ink.ink2)
                                } else {
                                    Text(idx < 0 ? "Before the block" : "After the block").font(Face.title)
                                }
                                Spacer()
                                if idx >= 0 { Text("\(model.score(week: idx).total) pts").font(Face.small).foregroundStyle(Ink.ink2) }
                            }
                            VStack(spacing: 0) {
                                ForEach(groups[idx]!) { s in
                                    JournalRow(log: s) { withAnimation { day = s.date } }
                                    if s.id != groups[idx]!.last?.id { Rule(seed: s.day.hashValue & 0xff) }
                                }
                            }
                            .sheetCard(padding: 16)
                        }
                    }
                }
            }
        }
    }
}

struct JournalRow: View {
    @Environment(AppModel.self) private var model
    let log: SessionLog
    var open: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: open) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(log.date.formatted(.dateTime.weekday(.abbreviated))).font(Face.small).foregroundStyle(Ink.ink2)
                    Text(log.date.formatted(.dateTime.day())).font(Face.display(20)).monospacedDigit()
                }
                .frame(width: 44, alignment: .leading)
                Image(systemName: log.kind.symbol).font(.system(size: 15)).foregroundStyle(Ink.ink).frame(width: 22).padding(.top, 4)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(title).font(Face.heading)
                        if log.source == .garmin || log.garminID != nil {
                            Image(systemName: "applewatch").font(.system(size: 11)).foregroundStyle(Ink.ink2).help("From your watch")
                        }
                        if log.minimum { Tag(text: "doorway rule") }
                        if let r = log.skip { Tag(text: "skipped: \(r.name.lowercased())") }
                        else if model.inProgress(log) { Tag(text: "not finished") }
                    }
                    Text(summary).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                    if !log.note.isEmpty {
                        Text(log.note).font(Face.body).foregroundStyle(Ink.ink).italic().fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(log.pain) { p in
                        Circle().fill(Ink.pain(p.light)).frame(width: 8, height: 8).help("\(p.area.name) \(p.score)/10")
                    }
                }
                .padding(.top, 6)
                if let e = log.energy {
                    Text(String(repeating: "●", count: e)).font(.system(size: 7)).foregroundStyle(Ink.ink2).padding(.top, 7)
                        .accessibilityLabel("Energy \(e) of 5")
                }
                Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(hover ? Ink.ink : Ink.ink3).padding(.top, 6)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }

    var title: String {
        if let w = model.workout(log.workoutID), log.kind != .climb { return "\(w.id) · \(w.name)" }
        return log.kind.name
    }

    var summary: String {
        var parts: [String] = []
        if let c = log.climb {
            let sends = c.sends
            if !c.problems.isEmpty {
                parts.append("\(sends.count)/\(c.problems.count) sent" + (sends.isEmpty ? "" : ", top \(model.hardestName(c.problems) ?? "–")"))
                let fl = sends.filter(\.flash).count
                if fl > 0 { parts.append("\(fl) first try") }
            }
            if c.falls > 0 { parts.append("\(c.falls) falls") }
            if c.drillBoring { parts.append("drill feels boring") }
        }
        let done = log.exercises.filter { !$0.doneSets.isEmpty }
        if !done.isEmpty {
            parts.append(done.map { e in
                let reps = e.doneSets.map { "\($0.value)" }.joined(separator: "/")
                return "\(Library.exercise(e.exerciseID).name.split(separator: " ").prefix(3).joined(separator: " ")) \(reps)\(e.timed ? "s" : "")\(e.topLoad.map { " @\($0.formatted())kg" } ?? "")"
            }.joined(separator: " · "))
        }
        if let m = log.minutes { parts.append("\(m) min") }
        if let hr = log.avgHr { parts.append("\(hr) bpm") }
        if let sk = log.skills, !sk.isEmpty { parts.append("skills: " + sk.compactMap { Library.skill($0)?.name.lowercased() }.joined(separator: ", ")) }
        if log.skip != nil && parts.isEmpty { return "Didn't happen" }
        return parts.isEmpty ? "No details yet" : parts.joined(separator: " · ")
    }
}
