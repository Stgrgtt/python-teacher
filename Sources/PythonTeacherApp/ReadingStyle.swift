import SwiftUI

enum ReadingTypeface: String, CaseIterable, Identifiable {
    case system, serif, rounded

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "System"
        case .serif: "Serif"
        case .rounded: "Rounded"
        }
    }
    var design: Font.Design {
        switch self {
        case .system: .default
        case .serif: .serif
        case .rounded: .rounded
        }
    }
}

enum ReadingSpacing: String, CaseIterable, Identifiable {
    case compact, comfortable, spacious

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    /// Extra space between lines, as a fraction of the body size.
    var lineFactor: Double {
        switch self {
        case .compact: 0.18
        case .comfortable: 0.38
        case .spacious: 0.58
        }
    }
    /// Space between blocks, as a fraction of the body size.
    var blockFactor: Double {
        switch self {
        case .compact: 0.7
        case .comfortable: 1.0
        case .spacious: 1.35
        }
    }
}

enum LessonLayout: String, CaseIterable, Identifiable {
    case paced, continuous

    var id: String { rawValue }
    var title: String {
        switch self {
        case .paced: "One part at a time"
        case .continuous: "Whole lesson"
        }
    }
}

/// Device-local display preferences. They are not learning evidence, so they live in
/// UserDefaults rather than the progress file.
enum AppearanceKey {
    static let interfaceScale = "appearance.interfaceScale"
    static let readingScale = "appearance.readingScale"
    static let typeface = "appearance.readingTypeface"
    static let spacing = "appearance.readingSpacing"
    static let codeSize = "appearance.codeFontSize"
    static let lessonLayout = "appearance.lessonLayout"

    static let interfaceRange = 0.85...1.3
    static let readingRange = 0.85...1.6
    static let codeRange = 11.0...22.0
}

struct ReadingStyle: Equatable {
    static let baseBodySize = 15.0

    var scale = 1.0
    var typeface = ReadingTypeface.system
    var spacing = ReadingSpacing.comfortable
    var codeSize = 14.0

    var bodySize: Double { Self.baseBodySize * scale }
    var lineSpacing: Double { bodySize * spacing.lineFactor }
    var blockSpacing: Double { bodySize * spacing.blockFactor }
    func font(_ relative: Double = 1, weight: Font.Weight = .regular) -> Font {
        .system(size: bodySize * relative, weight: weight, design: typeface.design)
    }
    var codeFont: Font { .system(size: codeSize * 0.92, design: .monospaced) }
}

private struct ReadingStyleKey: EnvironmentKey {
    static let defaultValue = ReadingStyle()
}

private struct InterfaceScaleKey: EnvironmentKey {
    static let defaultValue = 1.0
}

extension EnvironmentValues {
    var readingStyle: ReadingStyle {
        get { self[ReadingStyleKey.self] }
        set { self[ReadingStyleKey.self] = newValue }
    }
    var interfaceScale: Double {
        get { self[InterfaceScaleKey.self] }
        set { self[InterfaceScaleKey.self] = newValue }
    }
}

/// Reads the saved preferences and publishes them to every descendant, including sheets and popovers.
struct AppearanceEnvironment: ViewModifier {
    @AppStorage(AppearanceKey.interfaceScale) private var interfaceScale = 1.0
    @AppStorage(AppearanceKey.readingScale) private var readingScale = 1.0
    @AppStorage(AppearanceKey.typeface) private var typeface = ReadingTypeface.system
    @AppStorage(AppearanceKey.spacing) private var spacing = ReadingSpacing.comfortable
    @AppStorage(AppearanceKey.codeSize) private var codeSize = 14.0

    func body(content: Content) -> some View {
        content
            .environment(\.interfaceScale, interfaceScale.clamped(to: AppearanceKey.interfaceRange))
            .environment(\.readingStyle, ReadingStyle(scale: readingScale.clamped(to: AppearanceKey.readingRange), typeface: typeface,
                                                      spacing: spacing, codeSize: codeSize.clamped(to: AppearanceKey.codeRange)))
    }
}

extension Font.TextStyle {
    /// macOS point sizes for the system text styles; macOS has no Dynamic Type, so the app scales these itself.
    var macPointSize: Double {
        switch self {
        case .largeTitle: 26
        case .title: 22
        case .title2: 17
        case .title3: 15
        case .headline, .body: 13
        case .callout: 12
        case .subheadline: 11
        case .footnote, .caption, .caption2: 10
        @unknown default: 13
        }
    }
}

private struct AppFont: ViewModifier {
    @Environment(\.interfaceScale) private var scale
    let style: Font.TextStyle
    let weight: Font.Weight?
    let design: Font.Design
    let monospacedDigit: Bool

    func body(content: Content) -> some View {
        let font = Font.system(size: style.macPointSize * scale, weight: weight ?? (style == .headline ? .bold : .regular), design: design)
        content.font(monospacedDigit ? font.monospacedDigit() : font)
    }
}

extension View {
    /// A system text style that follows the user's interface text size.
    func appFont(_ style: Font.TextStyle, weight: Font.Weight? = nil, design: Font.Design = .default, monospacedDigit: Bool = false) -> some View {
        modifier(AppFont(style: style, weight: weight, design: design, monospacedDigit: monospacedDigit))
    }

    func appearanceEnvironment() -> some View { modifier(AppearanceEnvironment()) }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
