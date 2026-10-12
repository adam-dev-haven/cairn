import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

/// Sand-white paper, sumi ink, and one chalk-bag red.
enum Ink {
    static let paper = Color(hex: 0xF4EFE6)      // window ground, sand white
    static let sheet = Color(hex: 0xFCFAF6)      // the white page things sit on
    static let sand = Color(hex: 0xECE4D5)       // inset fields, sidebar selection
    static let sandDeep = Color(hex: 0xE2D8C5)
    static let line = Color(hex: 0xE4DBCC)
    static let lineStrong = Color(hex: 0xCDBFA8)
    static let ink = Color(hex: 0x1F1C19)
    static let ink2 = Color(hex: 0x5A534A)       // 7:1 on sheet
    static let ink3 = Color(hex: 0x857C6E)       // large or non-essential only
    static let red = Color(hex: 0xD3392B)        // you, today, unlocked
    static let redSoft = Color(hex: 0xF6DAD4)
    static let wash = Color(hex: 0x2B3540)       // sumi blue-black
    static let amber = Color(hex: 0xC98A12)
    static let green = Color(hex: 0x4E7D52)

    /// The light behind the frosted week card, one per phase. Taken from the
    /// reference glass cards: pale sky, sun, blush.
    static func light(_ phase: Phase) -> [Color] {
        switch phase {
        case .foundation: [Color(hex: 0xB9D3E6), Color(hex: 0xE9E1F1)]
        case .deload, .recovery: [Color(hex: 0xC9DFC8), Color(hex: 0xEFEBD0)]
        case .build: [Color(hex: 0xF3E48E), Color(hex: 0xF4CFC4)]
        case .push: [Color(hex: 0xF4B9AE), Color(hex: 0xF5D98F)]
        case .holiday: [Color(hex: 0xD6CCEE), Color(hex: 0xC6DDEB)]
        case .test: [Color(hex: 0xF4D77E), Color(hex: 0xF6F0DC)]
        }
    }

    static func phaseDot(_ phase: Phase) -> Color { light(phase)[0] }

    static func pain(_ light: PainLight) -> Color {
        switch light {
        case .green: green
        case .amber: amber
        case .red: red
        }
    }
}

enum Face {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight).width(.expanded)
    }
    static let pageTitle = Font.system(size: 30, weight: .semibold).width(.expanded)
    static let title = Font.system(size: 19, weight: .semibold).width(.expanded)
    static let heading = Font.system(size: 14, weight: .semibold)
    static let body = Font.system(size: 13.5)
    static let small = Font.system(size: 12)
    static let tiny = Font.system(size: 11, weight: .medium)
}

func grade(_ g: Int) -> String { "V\(g)" }

// MARK: - Surfaces

struct SheetBackground: ViewModifier {
    var padding: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Ink.sheet)
                    .shadow(color: Ink.ink.opacity(0.035), radius: 1, y: 1)
                    .shadow(color: Ink.ink.opacity(0.05), radius: 18, y: 10)
            )
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Ink.line, lineWidth: 1))
    }
}

extension View {
    func sheetCard(padding: CGFloat = 20) -> some View { modifier(SheetBackground(padding: padding)) }
}

/// A hand-drawn rule: a pen line that wanders a little, like the sketches.
struct InkRule: Shape {
    var seed: Int = 1
    func path(in rect: CGRect) -> Path {
        var p = Path()
        var rng = SeededRandom(seed: UInt64(seed * 7919 + 17))
        let steps = max(2, Int(rect.width / 24))
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + CGFloat(rng.next(-0.4, 0.4))))
        for i in 1...steps {
            let x = rect.minX + rect.width * CGFloat(i) / CGFloat(steps)
            let y = rect.midY + CGFloat(rng.next(-0.7, 0.7))
            p.addLine(to: CGPoint(x: x, y: y))
        }
        return p
    }
}

struct Rule: View {
    var seed = 1
    var body: some View {
        InkRule(seed: seed).stroke(Ink.lineStrong, style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round))
            .frame(height: 3)
    }
}

/// Deterministic noise so the drawings are the same every launch.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func nextUInt() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 33)) &* 0xff51afd7ed558ccd
        return z ^ (z >> 33)
    }
    mutating func next() -> Double { Double(nextUInt() >> 11) / Double(1 << 53) }
    mutating func next(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
}

/// Frosted glass with the phase's light glowing through it. Used once per
/// page at most, where the light means something (the week you're in).
struct PhaseGlass<Content: View>: View {
    var phase: Phase
    @ViewBuilder var content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let colors = Ink.light(phase)
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Ink.sheet)
            GeometryReader { geo in
                ZStack {
                    Ellipse().fill(colors[0]).frame(width: geo.size.width * 0.9, height: geo.size.height * 0.8)
                        .offset(x: -geo.size.width * 0.18, y: geo.size.height * 0.22)
                    Ellipse().fill(colors[1]).frame(width: geo.size.width * 0.7, height: geo.size.height * 0.7)
                        .offset(x: geo.size.width * 0.28, y: -geo.size.height * 0.2)
                    Circle().fill(Color.white).frame(width: geo.size.width * 0.35)
                        .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.3)
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .blur(radius: 38)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            if !reduceTransparency {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
            }
            content.padding(22)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.2)], startPoint: .top, endPoint: .bottom), lineWidth: 1.2)
        )
        .shadow(color: Ink.wash.opacity(0.10), radius: 24, y: 14)
    }
}

// MARK: - Controls

struct InkButtonStyle: ButtonStyle {
    var filled = true
    var red = false
    func makeBody(configuration: Configuration) -> some View {
        InkButtonBody(configuration: configuration, filled: filled, red: red)
    }
}

/// Split out so it can read `isEnabled`: a disabled button must look it.
private struct InkButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let filled: Bool
    let red: Bool
    @Environment(\.isEnabled) private var enabled
    var body: some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 16).padding(.vertical, 9)
            .foregroundStyle(filled ? Ink.sheet : (red ? Ink.red : Ink.ink))
            .background(
                Capsule().fill(filled ? (red ? Ink.red : Ink.ink) : Color.clear)
            )
            .overlay(Capsule().strokeBorder(filled ? Color.clear : Ink.lineStrong, lineWidth: 1))
            .contentShape(Capsule())
            .opacity(!enabled ? 0.35 : configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ChipStyle: ButtonStyle {
    var on: Bool
    var tint: Color = Ink.ink
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .foregroundStyle(on ? Ink.sheet : Ink.ink2)
            .background(Capsule().fill(on ? tint : Ink.sand.opacity(0.7)))
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct QuietIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Ink.ink2)
            .frame(width: 26, height: 26)
            .background(Circle().fill(configuration.isPressed ? Ink.sandDeep : Ink.sand))
            .contentShape(Circle())
    }
}

/// Page scaffold: big expanded title, optional line under it, content below.
struct Page<Content: View, Trailing: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var content: Content
    @Environment(\.compact) private var compact

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: compact ? 20 : 28) {
                if compact {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title).font(.system(size: 26, weight: .semibold).width(.expanded)).foregroundStyle(Ink.ink)
                            .fixedSize(horizontal: false, vertical: true)
                        if let subtitle {
                            Text(subtitle).font(Face.body).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true)
                        }
                        trailing.padding(.top, 6)
                    }
                } else {
                    HStack(alignment: .lastTextBaseline) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(title).font(Face.pageTitle).foregroundStyle(Ink.ink)
                            if let subtitle {
                                Text(subtitle).font(Face.body).foregroundStyle(Ink.ink2)
                            }
                        }
                        Spacer(minLength: 20)
                        trailing
                    }
                }
                content
            }
            .padding(.horizontal, compact ? 16 : 40)
            .padding(.top, compact ? 12 : 30)
            .padding(.bottom, compact ? 32 : 48)
            .frame(maxWidth: 1180, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Ink.paper)
    }
}

extension Page where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = EmptyView()
        self.content = content()
    }
}

struct SectionTitle: View {
    var text: String
    var detail: String? = nil
    @Environment(\.compact) private var compact
    var body: some View {
        if compact {
            VStack(alignment: .leading, spacing: 3) {
                Text(text).font(Face.title).foregroundStyle(Ink.ink)
                if let detail { Text(detail).font(Face.small).foregroundStyle(Ink.ink2).fixedSize(horizontal: false, vertical: true) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(text).font(Face.title).foregroundStyle(Ink.ink)
                if let detail { Text(detail).font(Face.small).foregroundStyle(Ink.ink2) }
                Spacer()
            }
        }
    }
}

/// Small tabular stat: number over a plain label (no eyebrow, the number leads).
struct Stat: View {
    var value: String
    var label: String
    var size: CGFloat = 30
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(Face.display(size)).monospacedDigit().foregroundStyle(Ink.ink)
                .contentTransition(.numericText())
            Text(label).font(Face.small).foregroundStyle(Ink.ink2)
        }
    }
}

struct StepperField: View {
    @Binding var value: Int
    var range: ClosedRange<Int> = 0...999
    var step = 1
    var suffix: String = ""
    /// Shows something other than the number (a Font grade for its index).
    var label: ((Int) -> String)? = nil
    @Environment(\.compact) private var compact
    var body: some View {
        HStack(spacing: 0) {
            Button { value = max(range.lowerBound, value - step) } label: {
                Image(systemName: "minus").font(.system(size: compact ? 12 : 10, weight: .bold))
                    .frame(width: compact ? 36 : 22, height: compact ? 36 : 26).contentShape(Rectangle())
            }.buttonStyle(.plain)
            Text(label?(value) ?? "\(value)\(suffix)").font(.system(size: compact ? 15 : 13, weight: .medium)).monospacedDigit()
                .frame(minWidth: 34)
            Button { value = min(range.upperBound, value + step) } label: {
                Image(systemName: "plus").font(.system(size: compact ? 12 : 10, weight: .bold))
                    .frame(width: compact ? 36 : 22, height: compact ? 36 : 26).contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .foregroundStyle(Ink.ink)
        .background(Capsule().fill(Ink.sand))
    }
}

// MARK: - Platform

/// True on the phone layout. Screens shared with the Mac read this to stack
/// instead of sitting side by side, and to size controls for a thumb.
private struct CompactKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var compact: Bool {
        get { self[CompactKey.self] }
        set { self[CompactKey.self] = newValue }
    }
}

/// HStack on the Mac, VStack on the phone.
struct AdaptiveStack<Content: View>: View {
    @Environment(\.compact) private var compact
    var spacing: CGFloat = 24
    @ViewBuilder var content: Content
    var body: some View {
        if compact {
            VStack(alignment: .leading, spacing: spacing * 0.75) { content }
        } else {
            HStack(alignment: .top, spacing: spacing) { content }
        }
    }
}

/// An ink checkbox that works the same on Mac and iPhone: a rounded square
/// that fills with ink, the whole row tappable.
struct InkCheck: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(configuration.isOn ? Ink.ink : Ink.sheet)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .strokeBorder(configuration.isOn ? Ink.ink : Ink.lineStrong, lineWidth: 1.2)
                    if configuration.isOn {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Ink.sheet)
                    }
                }
                .frame(width: 18, height: 18)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 4 }
                configuration.label.foregroundStyle(Ink.ink)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}

/// Text-only button, underlined, for secondary actions inside a row.
struct TextLinkStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .underline(true, color: Ink.lineStrong)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(Rectangle())
    }
}

extension View {
    /// Compact date field: a typed field on the Mac, the system popup on iPhone.
    @ViewBuilder func fieldDatePicker() -> some View {
        #if os(macOS)
        self.datePickerStyle(.field)
        #else
        self.datePickerStyle(.compact)
        #endif
    }
}
