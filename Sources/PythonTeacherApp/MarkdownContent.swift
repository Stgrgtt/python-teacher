import AppKit
import SwiftUI

/// The small Markdown subset used by lessons, exercise instructions and teacher replies.
enum MarkdownDocument {
    enum CalloutKind: Equatable {
        case key, tip, warning, note

        init(label: String?) {
            let label = label?.lowercased() ?? ""
            if ["watch", "mistake", "careful", "warning", "avoid", "pitfall"].contains(where: label.contains) { self = .warning }
            else if ["tip", "try"].contains(where: label.contains) { self = .tip }
            else if ["key", "remember", "important", "rule"].contains(where: label.contains) { self = .key }
            else { self = .note }
        }
    }

    struct ListItem: Equatable {
        var marker: String
        var text: String
    }

    enum Block: Equatable {
        case heading(level: Int, text: String)
        case paragraph(String)
        case list(ordered: Bool, items: [ListItem])
        case callout(CalloutKind, text: String)
        case code(language: String, text: String)
        /// An exercise instruction section such as `Goal:`.
        case section(String)
    }

    struct Group: Identifiable {
        let id: Int
        let section: String?
        let blocks: [Block]
    }

    struct LessonPart: Equatable, Identifiable {
        let id: Int
        let title: String
        let markdown: String
    }

    static let sectionTitles = ["Goal", "Starting code", "Your task", "Expected result", "Expected results", "Examples", "Check"]
    private static let sectionPattern = try! NSRegularExpression(pattern: #"^(?:#{1,6}\s+)?\*{0,2}(Goal|Starting code|Your task|Expected results?|Examples|Check)\*{0,2}:\*{0,2}\s*(.*)$"#)
    private static let orderedPattern = try! NSRegularExpression(pattern: #"^(\d{1,3})[.)]\s+(.*)$"#)

    static func parse(_ text: String) -> [Block] {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var list: (ordered: Bool, items: [ListItem])?
        var quote: [String] = []
        var fence: (language: String, lines: [String])?

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
            if let current = list { blocks.append(.list(ordered: current.ordered, items: current.items)); list = nil }
            if !quote.isEmpty {
                let body = quote.joined(separator: "\n")
                let label = body.hasPrefix("**") ? body.dropFirst(2).components(separatedBy: "**").first.flatMap { $0.hasSuffix(":") ? $0 : nil } : nil
                blocks.append(.callout(CalloutKind(label: label), text: body))
                quote = []
            }
        }

        for rawLine in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if var open = fence {
                if line.hasPrefix("```") {
                    blocks.append(.code(language: open.language, text: open.lines.joined(separator: "\n").trimmingCharacters(in: .newlines)))
                    fence = nil
                } else {
                    open.lines.append(rawLine)
                    fence = open
                }
                continue
            }
            if line.hasPrefix("```") {
                flush()
                fence = (String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces).lowercased(), [])
                continue
            }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix(">") {
                if quote.isEmpty { flush() }
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            } else if !quote.isEmpty { flush() }

            let ns = line as NSString
            let whole = NSRange(location: 0, length: ns.length)
            if paragraph.isEmpty, let match = sectionPattern.firstMatch(in: line, range: whole) {
                flush()
                blocks.append(.section(ns.substring(with: match.range(at: 1))))
                let rest = ns.substring(with: match.range(at: 2))
                if !rest.isEmpty { paragraph.append(rest) }
                continue
            }
            if let level = headingLevel(line) {
                flush()
                blocks.append(.heading(level: level, text: String(line.dropFirst(level + 1))))
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                if list?.ordered != false { flush(); list = (false, []) }
                list?.items.append(ListItem(marker: "•", text: String(line.dropFirst(2))))
                continue
            }
            if let match = orderedPattern.firstMatch(in: line, range: whole) {
                if list?.ordered != true { flush(); list = (true, []) }
                list?.items.append(ListItem(marker: ns.substring(with: match.range(at: 1)), text: ns.substring(with: match.range(at: 2))))
                continue
            }
            if var current = list, !current.items.isEmpty, rawLine.hasPrefix(" ") {
                current.items[current.items.count - 1].text += " " + line
                list = current
                continue
            }
            if list != nil { flush() }
            paragraph.append(line)
        }
        if let open = fence { blocks.append(.code(language: open.language, text: open.lines.joined(separator: "\n").trimmingCharacters(in: .newlines))) }
        flush()
        return blocks
    }

    private static func headingLevel(_ line: String) -> Int? {
        let hashes = line.prefix { $0 == "#" }.count
        guard (1...4).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") else { return nil }
        return min(hashes, 3)
    }

    /// Splits blocks at exercise section labels so each section can be presented as a unit.
    static func groups(_ blocks: [Block]) -> [Group] {
        var groups: [Group] = []
        var section: String?
        var current: [Block] = []
        func close() {
            if section != nil || !current.isEmpty { groups.append(Group(id: groups.count, section: section, blocks: current)) }
        }
        for block in blocks {
            if case .section(let title) = block {
                close()
                section = title
                current = []
            } else {
                current.append(block)
            }
        }
        close()
        return groups
    }

    /// Splits a lesson at its `##` headings; the opening `#` text becomes the first part.
    static func lessonParts(_ lesson: String) -> [LessonPart] {
        var parts: [(title: String, lines: [String])] = []
        var inCode = false
        for line in lesson.components(separatedBy: "\n") {
            if line.hasPrefix("```") { inCode.toggle() }
            if !inCode, line.hasPrefix("## ") || (parts.isEmpty && line.hasPrefix("# ")) {
                parts.append((String(line.drop { $0 == "#" || $0 == " " }), [line]))
            } else if parts.isEmpty {
                parts.append(("Introduction", [line]))
            } else {
                parts[parts.count - 1].lines.append(line)
            }
        }
        return parts.enumerated().compactMap { index, part in
            let text = part.lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : LessonPart(id: index, title: part.title, markdown: text)
        }.enumerated().map { LessonPart(id: $0.offset, title: $0.element.title, markdown: $0.element.markdown) }
    }

    static func inline(_ text: String, style: ReadingStyle) -> AttributedString {
        var result = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
        let codeRanges = result.runs.filter { $0.inlinePresentationIntent?.contains(.code) == true }.map(\.range)
        for range in codeRanges {
            result[range].font = .system(size: style.bodySize * 0.9, weight: .medium, design: .monospaced)
            result[range].backgroundColor = Color.secondary.opacity(0.14)
        }
        return result
    }
}

struct MarkdownContent: View {
    let text: String
    /// Slightly smaller text for chat bubbles.
    var compact = false
    @Environment(\.readingStyle) private var environmentStyle

    private var style: ReadingStyle {
        var style = environmentStyle
        if compact { style.scale *= 0.88 }
        return style
    }

    var body: some View {
        let groups = MarkdownDocument.groups(MarkdownDocument.parse(text))
        VStack(alignment: .leading, spacing: style.blockSpacing * 1.1) {
            ForEach(groups) { group in
                if let section = group.section {
                    InstructionSection(title: section, blocks: group.blocks, style: style)
                } else {
                    MarkdownBlocks(blocks: group.blocks, style: style)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MarkdownBlocks: View {
    let blocks: [MarkdownDocument.Block]
    let style: ReadingStyle

    var body: some View {
        VStack(alignment: .leading, spacing: style.blockSpacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                MarkdownBlockView(block: block, style: style, isFirst: index == 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MarkdownBlockView: View {
    let block: MarkdownDocument.Block
    let style: ReadingStyle
    let isFirst: Bool

    var body: some View {
        switch block {
        case .heading(let level, let text):
            heading(level: level, text: text)
        case .paragraph(let text):
            prose(text)
        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: style.blockSpacing * 0.55) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .firstTextBaseline, spacing: style.bodySize * 0.65) {
                        if ordered {
                            Text(item.marker)
                                .font(.system(size: style.bodySize * 0.78, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(.teal)
                                .frame(minWidth: style.bodySize * 1.5, minHeight: style.bodySize * 1.5)
                                .background(Circle().fill(Color.teal.opacity(0.13)))
                        } else {
                            Text("•").font(style.font(1.1, weight: .bold)).foregroundStyle(.teal.opacity(0.8))
                                .frame(width: style.bodySize * 0.7)
                        }
                        prose(item.text)
                    }
                }
            }
        case .callout(let kind, let text):
            Callout(kind: kind, text: text, style: style)
        case .code(let language, let text):
            CodeSample(language: language, code: text, style: style)
        case .section(let title):
            Text(title).font(style.font(weight: .semibold))
        }
    }

    @ViewBuilder
    private func heading(level: Int, text: String) -> some View {
        let content = MarkdownDocument.inline(text, style: style)
        switch level {
        case 1:
            Text(content).font(style.font(1.45, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        case 2:
            Text(content).font(style.font(1.22, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
                .padding(.top, isFirst ? 0 : style.blockSpacing * 0.6)
                .accessibilityAddTraits(.isHeader)
        default:
            Text(content).font(style.font(1.0, weight: .semibold)).foregroundStyle(.teal)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, isFirst ? 0 : style.blockSpacing * 0.35)
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func prose(_ text: String) -> some View {
        Text(MarkdownDocument.inline(text, style: style))
            .font(style.font())
            .lineSpacing(style.lineSpacing)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct InstructionSection: View {
    let title: String
    let blocks: [MarkdownDocument.Block]
    let style: ReadingStyle

    private var symbol: String {
        switch title {
        case "Goal": "target"
        case "Starting code": "shippingbox"
        case "Your task": "list.number"
        case "Check": "checkmark.circle"
        default: "flag.checkered"
        }
    }

    private var isGoal: Bool { title == "Goal" }

    var body: some View {
        VStack(alignment: .leading, spacing: style.blockSpacing * 0.75) {
            Label(title.uppercased(), systemImage: symbol)
                .font(.system(size: max(10, style.bodySize * 0.72), weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(.teal)
            MarkdownBlocks(blocks: blocks, style: style)
        }
        .padding(style.bodySize * 0.95)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(isGoal ? Color.teal.opacity(0.08) : Color.primary.opacity(0.035)))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isGoal ? Color.teal.opacity(0.22) : Color.primary.opacity(0.07)))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }
}

private struct Callout: View {
    let kind: MarkdownDocument.CalloutKind
    let text: String
    let style: ReadingStyle

    private var tint: Color {
        switch kind {
        case .key: .teal
        case .tip: .indigo
        case .warning: .orange
        case .note: .secondary
        }
    }

    private var symbol: String {
        switch kind {
        case .key: "key.fill"
        case .tip: "lightbulb.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .note: "info.circle.fill"
        }
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: style.bodySize * 0.6) {
            Image(systemName: symbol).font(.system(size: style.bodySize * 0.85)).foregroundStyle(tint)
            Text(MarkdownDocument.inline(text, style: style))
                .font(style.font(0.96))
                .lineSpacing(style.lineSpacing)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, style.bodySize * 0.7)
        .padding(.horizontal, style.bodySize * 0.85)
        .background(tint.opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: 10, bottomLeadingRadius: 10).fill(tint.opacity(0.7)).frame(width: 3)
        }
    }
}

private struct CodeSample: View {
    let language: String
    let code: String
    let style: ReadingStyle
    @State private var copied = false

    private var isOutput: Bool { ["text", "output", "console", "plaintext", "txt"].contains(language) }
    private var title: String { isOutput ? "Output" : language == "python" || language == "py" ? "Python" : language.isEmpty ? "Code" : language.capitalized }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Label(title, systemImage: isOutput ? "text.alignleft" : "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: max(10, style.codeSize * 0.8), weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if !isOutput {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        copied = true
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: max(10, style.codeSize * 0.8)))
                    }
                    .buttonStyle(.borderless)
                    .help("Copy this example")
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 6)
            Divider().opacity(0.6)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(isOutput ? AttributedString(code) : PythonSyntax.highlighted(code))
                    .font(style.codeFont)
                    .lineSpacing(style.codeSize * 0.3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isOutput ? Color.primary.opacity(0.045) : Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
        .onChange(of: code) { _, _ in copied = false }
    }
}
