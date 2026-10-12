import Foundation

/// Optional activity import. Cairn never signs in to Garmin, or to anything
/// else. If the user points it at a folder holding a `manifest.json` (format
/// in docs/ACTIVITY-IMPORT.md), bouldering and walking entries become climb
/// and walk logs. With no folder set the feature is off and the UI says so.
extension AppModel {
    struct SyncReport: Equatable {
        var at: Date
        var imported: Int

        var summary: String { imported > 0 ? "\(imported) new from your watch" : "Up to date" }
    }

    /// The folder to read, or nil while nothing is connected.
    var activityFolder: URL? {
        let path = store.settings.garminFolder
        return path.isEmpty ? nil : URL(fileURLWithPath: path)
    }

    var importAvailable: Bool { activityFolder != nil }

    @MainActor
    func syncNow() async {
        guard importAvailable, !syncing else { return }
        syncing = true
        defer { syncing = false }
        let imported = importGarmin(announce: false)
        lastSync = SyncReport(at: Date(), imported: imported)
        evaluateAdaptation()
    }

    /// Import unless one ran recently. Used on launch, on activation and hourly.
    @MainActor
    func syncIfStale(minutes: Double = 30) async {
        guard importAvailable, store.settings.autoSync else { return }
        if let last = lastSync?.at, Date().timeIntervalSince(last) < minutes * 60 { return }
        await syncNow()
    }
}
