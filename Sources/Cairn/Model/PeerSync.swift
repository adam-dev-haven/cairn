import Foundation
import Network

/// Mac ↔ iPhone sync over the home Wi-Fi. The Mac advertises a Bonjour
/// service; the phone finds it, sends its whole store, and gets back the
/// merged one. The Mac does the merge (Merge.swift), so anything it imported
/// from a watch folder reaches the phone too.
///
/// A six-digit pairing code, shown on the Mac, keeps other devices on the
/// network out. Messages are length-prefixed JSON over TCP.

struct PeerRequest: Codable {
    var key: String
    var profileID: String
    var profileName: String
    var device: String
    var store: Store
}

struct PeerResponse: Codable {
    var ok: Bool
    var error: String?
    var store: Store?
    var mac: String?
}

struct PeerReport: Equatable {
    var at: Date
    var ok: Bool
    var detail: String
}

enum PeerSync {
    static let service = "_cairn._tcp"
    static let maxFrame = 32 * 1024 * 1024

    /// Phone: the code it was paired with.
    static var pairingCode: String? {
        get { UserDefaults.standard.string(forKey: "peer.code") }
        set { UserDefaults.standard.set(newValue, forKey: "peer.code") }
    }

    /// Mac: the code it shows and accepts. Created on first use.
    static var hostCode: String {
        get {
            if let c = UserDefaults.standard.string(forKey: "peer.hostCode") { return c }
            let c = newCode()
            UserDefaults.standard.set(c, forKey: "peer.hostCode")
            return c
        }
        set { UserDefaults.standard.set(newValue, forKey: "peer.hostCode") }
    }

    static func newCode() -> String { String(format: "%06d", Int.random(in: 0...999_999)) }

    /// Compares two codes without stopping at the first differing byte.
    static func codesMatch(_ a: String, _ b: String) -> Bool {
        let x = Array(a.utf8), y = Array(b.utf8)
        var diff = x.count ^ y.count
        for i in 0..<min(x.count, y.count) { diff |= Int(x[i] ^ y[i]) }
        return diff == 0
    }

    /// Profile ids become part of a file name, so only the shapes Cairn itself
    /// creates are accepted: "main", or a short run of letters, digits and dashes.
    static func isValidProfileID(_ id: String) -> Bool {
        (1...32).contains(id.count) && id.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }

    // MARK: Framing

    static func send(_ data: Data, on c: NWConnection, done: @escaping (Error?) -> Void) {
        var len = UInt32(data.count).bigEndian
        var frame = Data(bytes: &len, count: 4)
        frame.append(data)
        c.send(content: frame, completion: .contentProcessed { done($0) })
    }

    static func receive(on c: NWConnection, done: @escaping (Result<Data, Error>) -> Void) {
        c.receive(minimumIncompleteLength: 4, maximumLength: 4) { head, _, _, error in
            if let error { return done(.failure(error)) }
            guard let head, head.count == 4 else { return done(.failure(PeerError.closed)) }
            let len = Int(head.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian })
            guard len > 0, len <= maxFrame else { return done(.failure(PeerError.tooLarge)) }
            c.receive(minimumIncompleteLength: len, maximumLength: len) { body, _, _, error in
                if let error { return done(.failure(error)) }
                guard let body, body.count == len else { return done(.failure(PeerError.closed)) }
                done(.success(body))
            }
        }
    }
}

/// Slows down anyone guessing the six-digit code. Five wrong codes in a row
/// lock the Mac's sync listener for a minute, which caps a guesser at about
/// five tries a minute against a million possible codes. A correct code
/// resets the count. Lives in memory only, so quitting Cairn clears it.
struct PairingGuard {
    static let allowedMisses = 5
    static let lockout: TimeInterval = 60

    private(set) var misses = 0
    private(set) var lockedUntil = Date.distantPast

    enum Verdict: Equatable { case accepted, wrong, locked(seconds: Int) }

    mutating func check(_ key: String, against code: String, now: Date = Date()) -> Verdict {
        if now < lockedUntil { return .locked(seconds: Int(lockedUntil.timeIntervalSince(now).rounded(.up))) }
        if PeerSync.codesMatch(key, code) { misses = 0; return .accepted }
        misses += 1
        if misses >= Self.allowedMisses {
            misses = 0
            lockedUntil = now.addingTimeInterval(Self.lockout)
        }
        return .wrong
    }
}

enum PeerError: LocalizedError {
    case closed, tooLarge, notFound, timeout, localNetworkOff, refused(String)
    var errorDescription: String? {
        switch self {
        case .localNetworkOff: "Cairn isn't allowed on your local network. Turn it on in Settings → Privacy & Security → Local Network → Cairn."
        case .closed: "The connection closed early."
        case .tooLarge: "The data was too large."
        case .notFound: "Couldn't find Cairn on a Mac on this Wi-Fi."
        case .timeout: "The Mac didn't answer in time."
        case .refused(let why): why
        }
    }
}

// MARK: - Mac side

/// Listens for the phone. `handle` runs on the main actor.
final class PeerServer {
    private var listener: NWListener?
    private let handle: @MainActor (PeerRequest) -> PeerResponse
    private(set) var state = "Off"

    init(handle: @escaping @MainActor (PeerRequest) -> PeerResponse) { self.handle = handle }

    func start(name: String) {
        guard listener == nil else { return }
        do {
            let l = try NWListener(using: .tcp)
            l.service = NWListener.Service(name: name, type: PeerSync.service)
            l.stateUpdateHandler = { [weak self] s in
                switch s {
                case .ready: self?.state = "Listening"
                case .failed(let e): self?.state = "Failed: \(e.localizedDescription)"
                default: break
                }
            }
            l.newConnectionHandler = { [weak self] c in self?.serve(c) }
            l.start(queue: .main)
            listener = l
        } catch {
            state = "Failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        listener?.cancel()
        listener = nil
        state = "Off"
    }

    private func serve(_ c: NWConnection) {
        c.start(queue: .main)
        PeerSync.receive(on: c) { [weak self] result in
            guard let self else { c.cancel(); return }
            let response: PeerResponse
            switch result {
            case .failure(let e):
                response = PeerResponse(ok: false, error: e.localizedDescription)
            case .success(let data):
                if let req = try? JSONDecoder().decode(PeerRequest.self, from: data) {
                    response = MainActor.assumeIsolated { self.handle(req) }
                } else {
                    response = PeerResponse(ok: false, error: "The Mac couldn't read that. Update Cairn on both devices.")
                }
            }
            let out = (try? JSONEncoder().encode(response)) ?? Data()
            PeerSync.send(out, on: c) { _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { c.cancel() }
            }
        }
    }
}

// MARK: - Phone side

enum PeerClient {
    /// Find the Mac, send the request, wait for the merged store.
    static func exchange(_ request: PeerRequest, timeout: TimeInterval = 20) async throws -> PeerResponse {
        let endpoint = try await find(timeout: 6)
        let body = try JSONEncoder().encode(request)
        return try await withCheckedThrowingContinuation { cont in
            let once = Once(cont)
            let c = NWConnection(to: endpoint, using: .tcp)
            c.stateUpdateHandler = { s in
                switch s {
                case .ready:
                    PeerSync.send(body, on: c) { error in
                        if let error { once.fail(error); c.cancel(); return }
                        PeerSync.receive(on: c) { result in
                            switch result {
                            case .success(let data):
                                if let r = try? JSONDecoder().decode(PeerResponse.self, from: data) { once.succeed(r) }
                                else { once.fail(PeerError.closed) }
                            case .failure(let e): once.fail(e)
                            }
                            c.cancel()
                        }
                    }
                case .failed(let e): once.fail(e)
                case .waiting(let e): once.fail(e); c.cancel()
                default: break
                }
            }
            c.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { once.fail(PeerError.timeout); c.cancel() }
        }
    }

    /// The Mac this phone last synced with. With more than one Cairn on the
    /// network, that one wins; any other is only used after a short wait.
    static var preferredMac: String? {
        get { UserDefaults.standard.string(forKey: "peer.mac") }
        set { UserDefaults.standard.set(newValue, forKey: "peer.mac") }
    }

    private static func find(timeout: TimeInterval) async throws -> NWEndpoint {
        try await withCheckedThrowingContinuation { cont in
            let once = Once(cont)
            let b = NWBrowser(for: .bonjour(type: PeerSync.service, domain: nil), using: .tcp)
            let preferred = preferredMac.map { "Cairn on \($0)" }
            let fallback = EndpointBox()
            b.browseResultsChangedHandler = { results, _ in
                for r in results {
                    if case .service(let name, _, _, _) = r.endpoint, name == preferred {
                        once.succeed(r.endpoint); b.cancel(); return
                    }
                }
                guard let first = results.first else { return }
                if preferred == nil { once.succeed(first.endpoint); b.cancel(); return }
                if fallback.endpoint == nil {
                    fallback.endpoint = first.endpoint
                    // Give the paired Mac a moment to show up before settling.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if let f = fallback.endpoint { once.succeed(f); b.cancel() }
                    }
                }
            }
            let blocked = EndpointBox()
            b.stateUpdateHandler = { s in
                print("cairn.peer browser \(s)")
                switch s {
                case .failed(let e): once.fail(PeerClient.isPolicyDenied(e) ? PeerError.localNetworkOff : e); b.cancel()
                // Waiting on a policy denial means iOS is holding the Local
                // Network prompt or the user said no. Give the prompt time,
                // but name the reason if nothing turns up.
                case .waiting(let e): blocked.denied = PeerClient.isPolicyDenied(e)
                case .ready: blocked.denied = false
                default: break
                }
            }
            b.start(queue: .main)
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                once.fail(blocked.denied ? PeerError.localNetworkOff : PeerError.notFound); b.cancel()
            }
        }
    }

    /// Everything here runs on the main queue; the box just carries the value
    /// between the browse callback and the timer.
    private final class EndpointBox: @unchecked Sendable { var endpoint: NWEndpoint?; var denied = false }

    static func isPolicyDenied(_ e: NWError) -> Bool {
        if case .dns(let code) = e { return code == -65570 }   // kDNSServiceErr_PolicyDenied
        return false
    }

    /// Browse briefly so iOS shows the Local Network prompt on first launch,
    /// not halfway through typing the pairing code.
    static func askForLocalNetwork() {
        let b = NWBrowser(for: .bonjour(type: PeerSync.service, domain: nil), using: .tcp)
        b.browseResultsChangedHandler = { results, _ in print("cairn.peer prime found \(results.count)") }
        b.stateUpdateHandler = { s in print("cairn.peer prime \(s)") }
        b.start(queue: .main)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { b.cancel() }
    }

    /// Resumes a continuation exactly once, whichever callback gets there first.
    private final class Once<T>: @unchecked Sendable {
        private var cont: CheckedContinuation<T, Error>?
        private let lock = NSLock()
        init(_ c: CheckedContinuation<T, Error>) { cont = c }
        func succeed(_ v: T) { take()?.resume(returning: v) }
        func fail(_ e: Error) { take()?.resume(throwing: e) }
        private func take() -> CheckedContinuation<T, Error>? {
            lock.lock(); defer { lock.unlock() }
            let c = cont; cont = nil; return c
        }
    }
}

// MARK: - Model glue

extension AppModel {
    /// Mac: answer one phone sync.
    @MainActor
    func answerPeer(_ req: PeerRequest, macName: String) -> PeerResponse {
        switch pairingGuard.check(req.key, against: PeerSync.hostCode) {
        case .accepted: break
        case .wrong:
            return PeerResponse(ok: false, error: "Wrong pairing code. Check it in Cairn on the Mac: Settings → Sync.")
        case .locked(let seconds):
            return PeerResponse(ok: false, error: "Too many wrong codes. The Mac is waiting \(seconds) seconds before it accepts another try.")
        }
        guard PeerSync.isValidProfileID(req.profileID) else {
            return PeerResponse(ok: false, error: "The Mac didn't recognise that profile, so it left everything alone.")
        }
        let detail = "\(req.device) · \(req.profileName)"
        if req.profileID == profiles.active {
            absorb(req.store)
            lastPeer = PeerReport(at: Date(), ok: true, detail: detail)
            if store.settings.autoSync { Task { await syncIfStale() } }
            return PeerResponse(ok: true, store: store, mac: macName)
        }
        // Another profile: merge straight into its file, creating it if new.
        let dir = Self.dataDirectory()
        let url = ProfileIndex.file(for: req.profileID, in: dir)
        var merged = req.store
        if let data = try? Data(contentsOf: url) {
            guard let local = try? JSONDecoder().decode(Store.self, from: data) else {
                return PeerResponse(ok: false, error: "The Mac couldn't read that profile's file, so it left it alone.")
            }
            try? FileManager.default.copyItem(at: url, to: url.deletingPathExtension().appendingPathExtension("before-peer-\(Int(Date().timeIntervalSince1970)).json"))
            merged = Merge.merge(local: local, remote: req.store)
        } else if !profiles.profiles.contains(where: { $0.id == req.profileID }) {
            profiles.profiles.append(Profile(id: req.profileID, name: String(req.profileName.prefix(40)), created: Day.key(Date())))
            profiles.save(to: dir)
        }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? enc.encode(merged).write(to: url, options: .atomic)
        lastPeer = PeerReport(at: Date(), ok: true, detail: detail)
        return PeerResponse(ok: true, store: merged, mac: macName)
    }

    /// Phone: sync with the Mac now.
    @MainActor
    func syncWithMac(device: String) async {
        guard !peerSyncing else { return }
        // Not paired yet isn't a failure — the chip just invites pairing.
        guard let code = PeerSync.pairingCode, !code.isEmpty else { return }
        peerSyncing = true
        defer { peerSyncing = false }
        save()
        let req = PeerRequest(key: code, profileID: profiles.active, profileName: profiles.activeProfile.name, device: device, store: store)
        do {
            print("cairn.peer sync start")
            let r = try await PeerClient.exchange(req)
            print("cairn.peer sync answer ok=\(r.ok) \(r.error ?? "")")
            if r.ok, let merged = r.store {
                if let mac = r.mac { PeerClient.preferredMac = mac }
                absorb(merged)
                lastPeer = PeerReport(at: Date(), ok: true, detail: r.mac.map { "with \($0)" } ?? "with your Mac")
                UserDefaults.standard.set(Date(), forKey: "peer.lastOK")
            } else {
                lastPeer = PeerReport(at: Date(), ok: false, detail: r.error ?? "The Mac said no.")
            }
        } catch {
            print("cairn.peer sync error \(error)")
            let why = (error as? PeerError)?.errorDescription
                ?? "Couldn't reach the Mac (\(error.localizedDescription))."
            lastPeer = PeerReport(at: Date(), ok: false, detail: why + " Your logs stay on the phone until the next sync.")
        }
    }
}
