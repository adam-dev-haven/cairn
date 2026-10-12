import SwiftUI

enum PhoneTab: String, CaseIterable, Identifiable {
    case today, week, mountain, learn, more
    var id: String { rawValue }
    var name: String {
        switch self {
        case .today: "Today"
        case .week: "Week"
        case .mountain: "Mountain"
        case .learn: "Learn"
        case .more: "More"
        }
    }
    var symbol: String {
        switch self {
        case .today: "sun.horizon"
        case .week: "calendar"
        case .mountain: "mountain.2"
        case .learn: "book"
        case .more: "ellipsis"
        }
    }
}

/// The iPhone app: five tabs over the same screens as the Mac, stacked for
/// one hand. Built from plain SwiftUI so the Mac can preview it too.
struct PhoneRoot: View {
    @Environment(AppModel.self) private var model
    @Environment(Navigator.self) private var nav
    @State private var tab: PhoneTab = ProcessInfo.processInfo.environment["CAIRN_TAB"].flatMap(PhoneTab.init(rawValue:)) ?? .today

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                Group {
                    switch tab {
                    case .today: TodayView()
                    case .week: WeekView()
                    case .mountain: MountainPage()
                    case .learn: PhoneLearn()
                    case .more: PhoneMore()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let notice = model.notice {
                    Banner(text: notice, tone: .quiet, action: ("OK", { model.notice = nil }))
                        .padding(.horizontal, 12).padding(.top, 6)
                        .task(id: notice) {
                            try? await Task.sleep(for: .seconds(5))
                            if model.notice == notice { model.notice = nil }
                        }
                }
                BubbleHost()
            }
            PhoneTabBar(tab: $tab)
        }
        .onChange(of: tab) { _, _ in nav.dismissBubble() }
        // The keyboard covers the tab bar instead of pushing it up.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .environment(\.compact, true)
        .background(Ink.paper)
    }
}

struct PhoneTabBar: View {
    @Binding var tab: PhoneTab
    var body: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Ink.line).frame(height: 1)
            HStack(spacing: 0) {
                ForEach(PhoneTab.allCases) { t in
                    Button { tab = t } label: {
                        VStack(spacing: 4) {
                            Image(systemName: t.symbol).font(.system(size: 19, weight: tab == t ? .semibold : .regular))
                                .frame(height: 24)
                            Text(t.name).font(.system(size: 10.5, weight: tab == t ? .semibold : .medium))
                            Circle().fill(tab == t ? Ink.red : .clear).frame(width: 4, height: 4)
                        }
                        .foregroundStyle(tab == t ? Ink.ink : Ink.ink2)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(t.name)
                    .accessibilityAddTraits(tab == t ? .isSelected : [])
                }
            }
            .padding(.top, 6)
        }
        .background(Ink.sheet.ignoresSafeArea(edges: .bottom))
    }
}

struct PhoneLearn: View {
    @State private var page = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $page) {
                Text("Bouldering").tag(0)
                Text("Calisthenics").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 10)
            if page == 0 { BoulderPage() } else { BarPage() }
        }
        .background(Ink.paper)
    }
}

struct PhoneMore: View {
    @Environment(AppModel.self) private var model
    @State private var page: Int?

    var body: some View {
        if page == 1 {
            SettingsView(onExit: { self.page = nil })
        } else if let page {
            VStack(spacing: 0) {
                HStack {
                    Button { self.page = nil } label: { Label("More", systemImage: "chevron.left") }
                        .buttonStyle(InkButtonStyle(filled: false))
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 8)
                switch page {
                case 0: JournalView()
                case 3: CoachPage()
                default: Page(title: "Sync with your Mac") { PhoneSyncSettings() }
                }
            }
            .background(Ink.paper)
        } else {
            Page(title: "More") {
                VStack(spacing: 12) {
                    row(0, "Journal", "Every session you've logged", "book.closed")
                    row(3, "Coach", model.coachReports.first.map { "\($0.scope.name) · \($0.headline.isEmpty ? "waiting for your answers" : $0.headline)" } ?? "Check-ins and what to change", "person.wave.2")
                    row(2, "Sync with your Mac", model.lastPeer.map { "\($0.ok ? "Synced" : "Not synced") \($0.at.formatted(date: .omitted, time: .shortened))" } ?? "Pair once, then it syncs on its own", "arrow.triangle.2.circlepath")
                    row(1, "Settings", "Profiles, your week, sessions, points, reset", "slider.horizontal.3")
                }
            }
        }
    }

    func row(_ id: Int, _ title: String, _ detail: String, _ symbol: String) -> some View {
        Button { page = id } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol).font(.system(size: 17)).frame(width: 28).foregroundStyle(Ink.ink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(Face.heading).foregroundStyle(Ink.ink)
                    Text(detail).font(Face.small).foregroundStyle(Ink.ink2)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Ink.ink2)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheetCard(padding: 16)
    }
}

/// Small status + button for the phone's Mac sync, shown on Today.
struct PhoneSyncChip: View {
    @Environment(AppModel.self) private var model
    @State private var pairing = false
    var body: some View {
        Button {
            if PeerSync.pairingCode == nil { pairing = true }
            else { Task { await model.syncWithMac(device: PhoneDevice.name) } }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .symbolEffect(.pulse, isActive: model.peerSyncing)
                Text(label).font(Face.small)
            }
            .foregroundStyle(model.lastPeer?.ok == false ? Ink.amber : Ink.ink2)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(Capsule().fill(Ink.sand.opacity(0.7)))
        }
        .buttonStyle(.plain)
        .disabled(model.peerSyncing)
        .accessibilityLabel("Sync with Mac. \(label)")
        .sheet(isPresented: $pairing) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pair with your Mac").font(Face.title)
                PhoneSyncSettings(onPaired: { pairing = false })
                Spacer()
            }
            .padding(20)
            .background(Ink.paper)
            .environment(\.compact, true)
            .presentationDetents([.large])
        }
    }

    var label: String {
        if model.peerSyncing { return "Syncing with Mac…" }
        guard let p = model.lastPeer else { return PeerSync.pairingCode == nil ? "Pair with your Mac" : "Sync with Mac" }
        return p.ok ? "Synced \(p.at.formatted(date: .omitted, time: .shortened))" : "Not synced — tap to retry"
    }
}

enum PhoneDevice {
    static var name: String {
        #if os(iOS)
        return "iPhone"
        #else
        return "Mac preview"
        #endif
    }
}

/// Pairing and status, in Settings and More on the phone.
struct PhoneSyncSettings: View {
    @Environment(AppModel.self) private var model
    @State private var code = PeerSync.pairingCode ?? ""
    @FocusState private var typing: Bool
    var onPaired: (() -> Void)? = nil
    /// Inside another card (Settings): no card of its own.
    var embedded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your logs from the gym go to the Mac, and the Mac's copy comes back, whenever the phone and the Mac are on the same Wi-Fi with Cairn open on the Mac.")
                .font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                Text("Pairing code").font(Face.heading)
                Text("On the Mac: Cairn → Settings → Sync → Pairing code.").font(Face.small).foregroundStyle(Ink.ink2)
                HStack(spacing: 10) {
                    TextField("000000", text: $code)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14).frame(height: 48)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Ink.sand))
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .focused($typing)
                        .onChange(of: code) { _, v in
                            code = String(v.filter(\.isNumber).prefix(6))
                            if code.count == 6 { typing = false }   // six digits: done, keyboard away
                        }
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { typing = false }
                            }
                        }
                    Button("Pair") {
                        typing = false
                        PeerSync.pairingCode = code
                        Task {
                            await model.syncWithMac(device: PhoneDevice.name)
                            if model.lastPeer?.ok == true { onPaired?() }
                        }
                    }
                    .buttonStyle(InkButtonStyle())
                    .disabled(code.count != 6)
                }
            }
            if let p = model.lastPeer {
                Label(p.ok ? "Synced \(p.at.formatted(date: .omitted, time: .shortened)) \(p.detail)" : p.detail,
                      systemImage: p.ok ? "checkmark.circle" : "exclamationmark.circle")
                    .font(Face.body).foregroundStyle(p.ok ? Ink.ink : Ink.amber).fixedSize(horizontal: false, vertical: true)
            }
            Button(model.peerSyncing ? "Syncing…" : "Sync now") { Task { await model.syncWithMac(device: PhoneDevice.name) } }
                .buttonStyle(InkButtonStyle(filled: false))
                .disabled(model.peerSyncing || PeerSync.pairingCode == nil)
        }
        .modifier(CardUnless(embedded: embedded))
    }
}

private struct CardUnless: ViewModifier {
    var embedded: Bool
    func body(content: Content) -> some View {
        if embedded { content } else { content.sheetCard(padding: 18) }
    }
}
