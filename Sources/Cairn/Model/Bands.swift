import Foundation

/// The five resistance bands the plan assumes, and what you get by stacking them. Band
/// labels are what the maker prints for the full stretch, so they rank the
/// combinations; they aren't dumbbell kilos.
enum Bands {
    static let kg: [Double] = [4.5, 9, 13.5, 18, 22.5]

    struct Rung: Hashable {
        let total: Double
        let bands: [Double]
        var combo: String { bands.map { Bands.label($0) }.joined(separator: " + ") }
    }

    /// Every combination of the five bands, lightest first. Where two
    /// combinations give the same total, the one with fewer bands wins.
    static let rungs: [Rung] = {
        var best: [Double: Rung] = [:]
        for mask in 1..<(1 << kg.count) {
            let picked = kg.indices.filter { mask & (1 << $0) != 0 }.map { kg[$0] }
            let total = (picked.reduce(0, +) * 10).rounded() / 10
            if let old = best[total], old.bands.count <= picked.count { continue }
            best[total] = Rung(total: total, bands: picked)
        }
        return best.values.sorted { $0.total < $1.total }
    }()

    static func label(_ x: Double) -> String { x == x.rounded() ? "\(Int(x))" : String(format: "%.1f", x) }

    /// "31.5 kg"
    static func text(_ x: Double) -> String { "\(label(x)) kg" }

    /// "31.5 kg (13.5 + 18)"
    static func describe(_ x: Double) -> String {
        guard let r = rungs.first(where: { abs($0.total - x) < 0.05 }), r.bands.count > 1 else { return text(x) }
        return "\(text(x)) (\(r.combo))"
    }

    /// The rung nearest a load, so a typed value or an old log still lands on the ladder.
    static func nearest(_ x: Double) -> Int {
        rungs.indices.min { abs(rungs[$0].total - x) < abs(rungs[$1].total - x) } ?? 0
    }

    static func up(from x: Double) -> Double { rungs[min(rungs.count - 1, nearest(x) + 1)].total }
    static func down(from x: Double) -> Double { rungs[max(0, nearest(x) - 1)].total }
}
