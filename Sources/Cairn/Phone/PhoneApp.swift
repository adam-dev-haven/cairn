#if os(iOS)
import SwiftUI
import UIKit

struct PhoneApp: App {
    @State private var model = AppModel.load()
    @State private var nav = Navigator()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            PhoneRoot()
                .environment(model)
                .environment(nav)
                .preferredColorScheme(.light)
                .tint(Ink.ink)
                .onAppear {
                    model.refreshBadges()
                    model.evaluateAdaptation()
                    PeerClient.askForLocalNetwork()
                }
        }
        .onChange(of: phase) { _, now in
            switch now {
            case .active:
                // Back in the app: pick up whatever the Mac has merged since.
                model.evaluateAdaptation()
                Task { await model.syncWithMac(device: PhoneDevice.name) }
            case .background:
                // Phone back in the pocket after logging: send it home. iOS
                // gives a few seconds for this; ask for them explicitly.
                model.save()
                guard PeerSync.pairingCode != nil else { return }
                let grant = BackgroundGrant()
                grant.id = UIApplication.shared.beginBackgroundTask(withName: "Cairn sync") {
                    // iOS calls this on the main thread when time runs out.
                    MainActor.assumeIsolated { grant.end() }
                }
                Task {
                    await model.syncWithMac(device: PhoneDevice.name)
                    grant.end()
                }
            default:
                break
            }
        }
    }
}
/// The few seconds iOS lends for finishing a sync in the background. Ends
/// exactly once, whether the sync finishes first or iOS runs out of patience.
@MainActor
final class BackgroundGrant {
    var id: UIBackgroundTaskIdentifier = .invalid
    func end() {
        guard id != .invalid else { return }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}
#endif
