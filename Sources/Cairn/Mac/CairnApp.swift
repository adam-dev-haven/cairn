#if os(macOS)
import AppKit
import SwiftUI

enum MacMain {
    static func run() {
        // build.sh asks the binary to draw its own icon; that's a build step,
        // not a launch, so it must not bounce in the Dock.
        if let i = CommandLine.arguments.firstIndex(of: "--iconset"), CommandLine.arguments.count > i + 1 {
            NSApplication.shared.setActivationPolicy(.prohibited)
            Icon.writeIconset(to: CommandLine.arguments[i + 1])
            return
        }
        if let i = CommandLine.arguments.firstIndex(of: "--ios-icon"), CommandLine.arguments.count > i + 1 {
            NSApplication.shared.setActivationPolicy(.prohibited)
            Icon.writeIOSIcon(to: CommandLine.arguments[i + 1])
            return
        }
        if CommandLine.arguments.contains("--selftest") {
            NSApplication.shared.setActivationPolicy(.prohibited)
            exit(SelfTest.run() ? 0 : 1)
        }
        CairnApp.main()
    }
}

/// Owns the Wi-Fi listener the iPhone syncs with.
@MainActor
final class PeerHost {
    static let shared = PeerHost()
    private var server: PeerServer?
    /// Off until the user turns on iPhone sync in Settings → Sync: a fresh
    /// install opens no port and advertises nothing on the network.
    var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "peer.enabled") as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: "peer.enabled") }
    }
    var macName: String { Host.current().localizedName ?? "your Mac" }

    func start(_ model: AppModel) {
        guard enabled, server == nil else { return }
        let name = macName
        let s = PeerServer { req in model.answerPeer(req, macName: name) }
        s.start(name: "Cairn on \(name)")
        server = s
    }

    func stop() { server?.stop(); server = nil }
}

struct CairnApp: App {
    @State private var model = AppModel.load()
    @State private var nav = Navigator()

    var body: some Scene {
        Window("Cairn", id: "main") {
            Group {
                if ProcessInfo.processInfo.environment["CAIRN_PHONE"] != nil {
                    // Design review: the iPhone layout in a phone-sized window.
                    PhoneRoot().frame(width: 393, height: 852)
                } else {
                    RootView()
                }
            }
                .environment(model)
                .environment(nav)
                .preferredColorScheme(.light)
                .frame(minWidth: ProcessInfo.processInfo.environment["CAIRN_PHONE"] != nil ? 393 : 1000,
                       minHeight: ProcessInfo.processInfo.environment["CAIRN_PHONE"] != nil ? 852 : 680)
                .onAppear {
                    model.refreshBadges()
                    model.evaluateAdaptation()
                    model.runScheduleRules()
                }
                .task {
                    PeerHost.shared.start(model)
                    // Launch: import now, then hourly while the window is open.
                    await model.syncIfStale(minutes: 0)
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(3600))
                        await model.syncIfStale(minutes: 55)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    Task { await model.syncIfStale() }
                    model.evaluateAdaptation()
                    model.runScheduleRules()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1280, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Go") {
                ForEach(NavSection.allCases.filter { $0 != .settings }) { s in
                    Button(s.name) { nav.section = s }.keyboardShortcut(s.key, modifiers: .command)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") { nav.section = .settings }.keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Session") {
                Button("Log today") { nav.section = .today; nav.logRequest += 1 }
                    .keyboardShortcut("l", modifiers: .command)
                Button("Import watch activities") { Task { await model.syncNow() } }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                    .disabled(model.syncing || !model.importAvailable)
            }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav

    var body: some View {
        HStack(spacing: 0) {
            Sidebar()
                .frame(width: 228)
            Rectangle().fill(Ink.line).frame(width: 1)
            ZStack(alignment: .top) {
                Ink.paper.ignoresSafeArea()
                Group {
                    switch nav.section {
                    case .today: TodayView()
                    case .week: WeekView()
                    case .mountain: MountainPage()
                    case .boulder: BoulderPage()
                    case .bar: BarPage()
                    case .coach: CoachPage()
                    case .journal: JournalView()
                    case .settings: SettingsView()
                    }
                }
                .id(nav.section)
                .transition(.opacity)
                VStack(spacing: 10) {
                    if let err = model.loadError {
                        Banner(text: err, tone: .red, action: nil)
                    }
                    if let notice = model.notice {
                        Banner(text: notice, tone: .quiet, action: ("OK", { model.notice = nil }))
                            .task(id: notice) {
                                try? await Task.sleep(for: .seconds(6))
                                if model.notice == notice { model.notice = nil }
                            }
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 40)
                BubbleHost()
            }
            .animation(.easeOut(duration: 0.18), value: nav.section)
            .onChange(of: nav.section) { _, _ in nav.dismissBubble() }
        }
        .background(Ink.paper)
        .ignoresSafeArea()
    }
}

struct Sidebar: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                CairnMark().frame(width: 22, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Cairn").font(.system(size: 17, weight: .semibold).width(.expanded)).foregroundStyle(Ink.ink)
                    if model.profiles.profiles.count > 1 {
                        Menu {
                            ForEach(model.profiles.profiles) { p in
                                Button { model.switchProfile(p.id) } label: {
                                    if p.id == model.profiles.active { Label(p.name, systemImage: "checkmark") } else { Text(p.name) }
                                }
                            }
                            Divider()
                            Button("Manage profiles…") { nav.section = .settings }
                        } label: {
                            Text(model.profiles.activeProfile.name).font(Face.small).foregroundStyle(Ink.ink2)
                        }
                        .menuStyle(.borderlessButton)
                        .menuIndicator(.visible)
                        .fixedSize()
                        .help("Switch profile")
                    }
                }
            }
            .padding(.top, 50)
            .padding(.horizontal, 22)
            .padding(.bottom, 22)

            VStack(spacing: 2) {
                ForEach(NavSection.allCases.filter { $0 != .settings }) { s in
                    SidebarRow(section: s, selected: nav.section == s) { nav.section = s }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            SidebarAltitude()
                .padding(.horizontal, 22)
                .padding(.bottom, 16)

            SyncRow()
                .padding(.horizontal, 22)
                .padding(.bottom, 12)
            Rule(seed: 4).padding(.horizontal, 18)
            SidebarRow(section: .settings, selected: nav.section == .settings) { nav.section = .settings }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Ink.paper)
    }
}

struct SidebarRow: View {
    var section: NavSection
    var selected: Bool
    var action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: section.symbol)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 20)
                    .foregroundStyle(selected ? Ink.ink : Ink.ink2)
                Text(section.name)
                    .font(.system(size: 13.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? Ink.ink : Ink.ink2)
                Spacer()
                if selected {
                    Circle().fill(Ink.red).frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(selected ? Ink.sand : (hover ? Ink.sand.opacity(0.5) : .clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("\(section.name)  ⌘\(String(section.key.character))")
    }
}

/// Where you are, always visible: altitude, week, streak.
struct SidebarAltitude: View {
    @Environment(AppModel.self) private var model
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MiniRoute(progress: model.routeProgress / Double(model.plan.weeks.count))
                .frame(height: 64)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(model.currentAltitude.formatted()).font(Face.display(22)).monospacedDigit()
                    .contentTransition(.numericText())
                Text("m").font(Face.small).foregroundStyle(Ink.ink2)
            }
            .foregroundStyle(Ink.ink)
            Text(statusLine).font(Face.small).foregroundStyle(Ink.ink2)
        }
        .animation(.spring(duration: 0.8), value: model.currentAltitude)
    }

    var statusLine: String {
        if model.beforeStart { return "Base camp opens \(Day.short(model.startDate))" }
        if model.finished { return "Summit reached" }
        guard let w = model.currentWeek else { return "" }
        let streak = model.streak
        return "Week \(w.number) · \(w.phase.name)" + (streak > 0 ? " · \(streak) green" : "")
    }
}

/// A tiny ink ridge with the route and a red dot — the sidebar's reminder.
struct SyncRow: View {
    @Environment(AppModel.self) private var model
    @State private var spin = false

    var body: some View {
        Button { Task { await model.syncNow() } } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(model.syncing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: spin)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(Face.small).foregroundStyle(Ink.ink)
                    Text(detail).font(Face.tiny).foregroundStyle(Ink.ink2)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Ink.ink2)
        .disabled(model.syncing || !model.importAvailable)
        .onChange(of: model.syncing) { _, now in spin = now }
        .help(model.importAvailable ? "Reads new activities from your watch folder.  ⇧⌘S" : "Choose a folder in Settings → Sync to import watch activities.")
    }

    var title: String {
        if !model.importAvailable { return "Watch not connected" }
        if model.syncing { return "Importing…" }
        guard let s = model.lastSync else { return "Import from watch" }
        return "Imported \(s.at.formatted(date: .omitted, time: .shortened))"
    }

    var detail: String {
        if !model.importAvailable { return "Optional · Settings → Sync" }
        guard let s = model.lastSync else { return model.activityFolder?.lastPathComponent ?? "" }
        return s.summary
    }
}

#endif
