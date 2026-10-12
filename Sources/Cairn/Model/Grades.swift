import Foundation
import SwiftUI

/// The two bouldering scales. Everything the plan decides (caps, quests)
/// runs on V; Font is finer, so a problem logged in Font keeps its exact
/// grade and converts to V for the rules.
enum GradeScale: String, Codable, CaseIterable, Identifiable {
    case v, font
    var id: String { rawValue }
    var name: String { self == .v ? "V scale (Hueco)" : "Font (Fontainebleau)" }

    /// Font grades in order. The index is what Cairn stores.
    static let fontNames = ["3", "4", "4+", "5", "5+", "6A", "6A+", "6B", "6B+", "6C", "6C+",
                            "7A", "7A+", "7B", "7B+", "7C", "7C+", "8A", "8A+", "8B", "8B+", "8C"]
    /// The usual conversion table: each Font grade's V grade.
    static let fontToV = [0, 0, 0, 1, 2, 3, 3, 4, 4, 5, 5, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14, 15]

    static func v(font i: Int) -> Int { fontToV[max(0, min(fontToV.count - 1, i))] }
    /// The easiest Font grade that is this V grade (V3 → 6A). V0 starts at
    /// 4: Font 3 is below the V scale.
    static func font(v: Int) -> Int { fontToV.indices.dropFirst().first { fontToV[$0] >= v } ?? fontToV.count - 1 }
    /// The hardest Font grade that is still this V grade (V3 → 6A+).
    static func fontTop(v: Int) -> Int { fontToV.lastIndex { $0 <= v } ?? 0 }
    static func fontName(_ i: Int) -> String { fontNames[max(0, min(fontNames.count - 1, i))] }
}

/// One colour on the gym's wall and the grades it covers. Gyms that grade
/// by colour give ranges, not points: green might be 4–5+, or V0–V2. The
/// range is kept in the scale the gym uses; `low`/`high` are always V.
struct GradeCircuit: Codable, Hashable, Identifiable {
    var id = UUID().uuidString
    var name: String
    var hex: UInt32
    var low: Int
    var high: Int
    /// Set when the gym gives this colour in Font grades.
    var fontLow: Int? = nil
    var fontHigh: Int? = nil

    var color: Color { Color(hex: hex) }

    /// The range in Font, exact when the gym gave it, converted otherwise.
    var fontRange: ClosedRange<Int> {
        let lo = fontLow ?? GradeScale.font(v: low)
        return lo...max(lo, fontHigh ?? GradeScale.fontTop(v: high))
    }

    func range(in scale: GradeScale) -> String {
        switch scale {
        case .v: return low == high ? "V\(low)" : "V\(low)–V\(high)"
        case .font:
            let r = fontRange
            return r.lowerBound == r.upperBound ? GradeScale.fontName(r.lowerBound)
                : "\(GradeScale.fontName(r.lowerBound))–\(GradeScale.fontName(r.upperBound))"
        }
    }
    var range: String { range(in: .v) }

    mutating func setFont(low lo: Int, high hi: Int) {
        fontLow = lo; fontHigh = max(lo, hi)
        low = GradeScale.v(font: lo); high = GradeScale.v(font: max(lo, hi))
    }

    mutating func setV(low lo: Int, high hi: Int) {
        low = lo; high = max(lo, hi); fontLow = nil; fontHigh = nil
    }

    /// A starting guess at one gym's colour circuits. Edit the colours and
    /// their V ranges in Settings to match your own wall.
    static let starter: [GradeCircuit] = [
        GradeCircuit(name: "Green", hex: 0x3F8F4F, low: 0, high: 3),
        GradeCircuit(name: "Blue", hex: 0x2F6DB5, low: 3, high: 4),
    ]

    static let palette: [(String, UInt32)] = [
        ("White", 0xE9E4DA), ("Yellow", 0xE8C33A), ("Orange", 0xE58A2B), ("Green", 0x3F8F4F),
        ("Blue", 0x2F6DB5), ("Cyan", 0x2BB5C9), ("Teal", 0x1F9E8F), ("Purple", 0x7B4FA8), ("Pink", 0xE07AA5),
        ("Red", 0xC7362B), ("Brown", 0x7A5230), ("Grey", 0x8A8A8A), ("Black", 0x222222),
    ]
}

extension AppModel {
    /// The colour circuits in use, easiest first, or empty when the gym uses V grades.
    var circuits: [GradeCircuit] {
        store.settings.useCircuits ? store.settings.circuits.sorted { ($0.fontRange.lowerBound, $0.fontRange.upperBound) < ($1.fontRange.lowerBound, $1.fontRange.upperBound) } : []
    }

    func circuit(_ id: String?) -> GradeCircuit? { id.flatMap { i in store.settings.circuits.first { $0.id == i } } }

    var scale: GradeScale { store.settings.gradeScale }

    /// A problem's exact Font grade: as logged, or converted from its V.
    func fontIndex(_ p: Problem) -> Int { p.font ?? GradeScale.font(v: p.grade) }

    /// A grade without colours, in the chosen scale.
    func plainName(_ p: Problem) -> String {
        scale == .font ? GradeScale.fontName(fontIndex(p)) : "V\(p.grade)"
    }

    /// How a logged problem reads on screen: its colour, or its grade.
    func gradeName(_ p: Problem) -> String { circuit(p.circuit)?.name ?? plainName(p) }

    /// A V grade as the gym would say it: the easiest colour whose range
    /// contains it, or the grade in the chosen scale.
    func gradeName(v: Int) -> String {
        if let c = circuits.first(where: { $0.low <= v && v <= $0.high }) { return c.name }
        return scale == .font ? GradeScale.fontName(GradeScale.font(v: v)) : "V\(v)"
    }

    /// Rewrite the plan's V-grade language ("Repeats V0–V2") into the gym's
    /// colours ("Repeats green") when circuits are on. Text without V grades,
    /// or a gym without circuits, passes through unchanged.
    func grades(_ text: String) -> String {
        let cs = circuits
        if cs.isEmpty && scale == .v { return text }
        let pattern = #"V(\d+)(?:\s*[–-]\s*V(\d+))?"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return text }
        var out = text
        let ns = text as NSString
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let lo = Int(ns.substring(with: m.range(at: 1))) ?? 0
            let hi = m.range(at: 2).location != NSNotFound ? (Int(ns.substring(with: m.range(at: 2))) ?? lo) : lo
            if cs.isEmpty {
                // Font: "V0–V2" → "4–5+", "V3" → "6A".
                let a = GradeScale.fontName(GradeScale.font(v: lo))
                let b = GradeScale.fontName(GradeScale.fontTop(v: hi))
                let replacement = lo == hi ? GradeScale.fontName(GradeScale.font(v: lo)) : "\(a)–\(b)"
                out = (out as NSString).replacingCharacters(in: m.range, with: replacement)
                continue
            }
            var matches = cs.filter { $0.low <= hi && $0.high >= lo }
            // A single grade ("max 2 V3") means that grade's own colour: the
            // one that starts there, else the hardest colour that holds it.
            if lo == hi, matches.count > 1 {
                matches = [matches.first { $0.low == lo } ?? matches.last!]
            }
            let names = matches.map { $0.name.lowercased() }
            guard !names.isEmpty else { continue }
            let replacement = names.count == 1 ? names[0] : names.joined(separator: " or ")
            out = (out as NSString).replacingCharacters(in: m.range, with: replacement)
        }
        return out
    }

    /// The grades to offer in the logger: colours, V0–V7, or Font 4–7A.
    struct GradeOption: Identifiable, Hashable {
        var id: String
        var label: String
        var detail: String?
        var v: Int
        var font: Int? = nil
        var circuit: String?
        var color: Color?

        func matches(_ p: Problem) -> Bool {
            if let circuit { return p.circuit == circuit }
            if p.circuit != nil { return false }
            if let font { return (p.font ?? GradeScale.font(v: p.grade)) == font }
            return p.grade == v
        }

        func problem() -> Problem { Problem(grade: v, attempts: 1, sent: false, circuit: circuit, font: font) }
    }

    var gradeOptions: [GradeOption] {
        let cs = circuits
        if cs.isEmpty {
            if scale == .font {
                return (1...11).map { i in
                    GradeOption(id: "f\(i)", label: GradeScale.fontName(i), detail: nil, v: GradeScale.v(font: i), font: i, circuit: nil, color: nil)
                }
            }
            return (0...7).map { GradeOption(id: "v\($0)", label: "V\($0)", detail: nil, v: $0, circuit: nil, color: nil) }
        }
        return cs.map { GradeOption(id: $0.id, label: $0.name, detail: $0.range(in: scale), v: $0.low,
                                    font: $0.fontLow, circuit: $0.id, color: $0.color) }
    }

    func option(for p: Problem) -> GradeOption? { gradeOptions.first { $0.matches(p) } }

    /// Sends counted per grade option, for the pyramid.
    func sendCounts() -> [(option: GradeOption, count: Int)] {
        let sends = climbSessions.flatMap { $0.climb?.sends ?? [] }
        return gradeOptions.map { o in (o, sends.filter(o.matches).count) }
    }
}

extension AppModel {
    /// A problem's place on the gym's scale: the colour's position (easiest
    /// is 0) with circuits, the V grade without. Older V-logged problems map
    /// onto the first colour whose range holds them.
    func rank(_ p: Problem) -> Int {
        let cs = circuits
        guard !cs.isEmpty else { return scale == .font ? fontIndex(p) : p.grade }
        if let id = p.circuit, let i = cs.firstIndex(where: { $0.id == id }) { return i }
        return cs.firstIndex { $0.low <= p.grade && p.grade <= $0.high } ?? (p.grade > (cs.last?.high ?? 0) ? cs.count - 1 : 0)
    }

    func rankLabel(_ r: Int) -> String {
        let cs = circuits
        guard !cs.isEmpty else { return scale == .font ? GradeScale.fontName(r) : "V\(r)" }
        return cs.indices.contains(r) ? cs[r].name : "?"
    }

    func rankColor(_ r: Int) -> Color? {
        let cs = circuits
        return cs.indices.contains(r) ? cs[r].color : nil
    }

    func hardest(_ problems: [Problem]) -> Int? { problems.filter(\.sent).map(rank).max() }

    func hardestName(_ problems: [Problem]) -> String? { hardest(problems).map(rankLabel) }

    var hardestEverRank: Int? { hardest(climbSessions.flatMap { $0.climb?.problems ?? [] }) }
}

/// A colour from the wheel, as the hex the circuits store.
enum Hex {
    static func color(_ hex: UInt32) -> Color { Color(hex: hex) }

    static func value(_ c: Color) -> UInt32 {
        let r = c.resolve(in: EnvironmentValues())
        func b(_ x: Float) -> UInt32 { UInt32((max(0, min(1, x)) * 255).rounded()) }
        return b(r.red) << 16 | b(r.green) << 8 | b(r.blue)
    }
}
