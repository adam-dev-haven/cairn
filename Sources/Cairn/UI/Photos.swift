import SwiftUI
#if os(macOS)
import AppKit
typealias PlatformImage = NSImage
#else
import UIKit
typealias PlatformImage = UIImage
#endif

/// Form photos for the exercises: public-domain pictures from free-exercise-db
/// (two frames each, start and finish) and two Wikimedia Commons photos for the
/// L-sit and the crow. They ship inside the app as flat files named
/// `<id>-<frame>.jpg` (single photos: `<id>.jpg`), so it works offline.
enum Photos {
    /// File name without extension → file, for every jpg that came with the app.
    private static let index: [String: URL] = {
        var out: [String: URL] = [:]
        var roots: [URL] = []
        if let r = Bundle.main.resourceURL { roots.append(r) }
        // Running the bare binary (swift build, the self-test): look beside the sources.
        roots.append(URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("ios/Resources/photos"))
        if let dev = ProcessInfo.processInfo.environment["CAIRN_PHOTOS"] { roots.append(URL(fileURLWithPath: dev)) }
        for root in roots {
            guard let walker = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) else { continue }
            for case let url as URL in walker where url.pathExtension.lowercased() == "jpg" {
                out[url.deletingPathExtension().lastPathComponent] = out[url.deletingPathExtension().lastPathComponent] ?? url
            }
        }
        return out
    }()

    private static let cache = NSCache<NSString, PlatformImage>()

    static func url(_ id: String, frame: Int) -> URL? { index["\(id)-\(frame)"] ?? index[id] }

    /// The frames that exist for a photo id: start and finish, or the one photo.
    static func frames(_ id: String) -> [URL] {
        var out: [URL] = []
        for f in 0...1 { if let u = index["\(id)-\(f)"] { out.append(u) } }
        if out.isEmpty, let u = index[id] { out = [u] }
        return out
    }

    static func image(_ url: URL) -> PlatformImage? {
        if let c = cache.object(forKey: url.path as NSString) { return c }
        guard let img = PlatformImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(img, forKey: url.path as NSString)
        return img
    }

    static var available: Bool { !index.isEmpty }
}

/// One photo, cropped to 4:3.
struct PhotoFrame: View {
    let url: URL
    var label: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if let img = Photos.image(url) {
                Group {
                    #if os(macOS)
                    Image(nsImage: img).resizable()
                    #else
                    Image(uiImage: img).resizable()
                    #endif
                }
                .aspectRatio(4 / 3, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityHidden(true)
            }
            if let label { Text(label).font(Face.tiny).foregroundStyle(Ink.ink3).textCase(.uppercase) }
        }
    }
}

/// Start and finish of one exercise, side by side.
struct PhotoPair: View {
    let id: String
    var body: some View {
        let frames = Photos.frames(id)
        if !frames.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                ForEach(Array(frames.enumerated()), id: \.offset) { i, u in
                    PhotoFrame(url: u, label: frames.count > 1 ? (i == 0 ? "Start" : "Finish") : nil)
                }
            }
        }
    }
}

/// A row of finish-frame photos for a skill's ladder.
struct PhotoStrip: View {
    let ids: [String]
    var body: some View {
        let urls = ids.compactMap { id -> (String, URL)? in
            let f = Photos.frames(id)
            return f.last.map { (id, $0) }
        }
        if !urls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(urls, id: \.0) { _, u in
                        PhotoFrame(url: u).frame(width: 170)
                    }
                }
            }
        }
    }
}
