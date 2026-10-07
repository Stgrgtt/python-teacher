import PythonTeacherCore
import SwiftUI
import XCTest
@testable import PythonTeacherApp

final class MarkdownDocumentTests: XCTestCase {
    func testParsesReadingBlocks() {
        let text = """
        # Title

        Intro line one.
        Still the same paragraph.

        ### Step

        - first
        - second
        1. one
        2. two

        > **Watch out:** `=` saves; `==` compares.

        ```python
        print("hi")
        ```

        ```text
        hi
        ```
        """
        XCTAssertEqual(MarkdownDocument.parse(text), [
            .heading(level: 1, text: "Title"),
            .paragraph("Intro line one.\nStill the same paragraph."),
            .heading(level: 3, text: "Step"),
            .list(ordered: false, items: [.init(marker: "•", text: "first"), .init(marker: "•", text: "second")]),
            .list(ordered: true, items: [.init(marker: "1", text: "one"), .init(marker: "2", text: "two")]),
            .callout(.warning, text: "**Watch out:** `=` saves; `==` compares."),
            .code(language: "python", text: "print(\"hi\")"),
            .code(language: "text", text: "hi")
        ])
    }

    func testInstructionSectionsGroupTheirContent() {
        let text = "Goal:\nSave a name.\n\nStarting code:\n- `name = ''` is a placeholder.\n\nYour task:\n1. Replace it.\n\nExpected result:\n- `name` is `'Mira'`\n\nCheck: Choose Check solution."
        let groups = MarkdownDocument.groups(MarkdownDocument.parse(text))
        XCTAssertEqual(groups.map(\.section), ["Goal", "Starting code", "Your task", "Expected result", "Check"])
        XCTAssertEqual(groups[2].blocks, [.list(ordered: true, items: [.init(marker: "1", text: "Replace it.")])])
        XCTAssertEqual(groups[4].blocks, [.paragraph("Choose Check solution.")])
        XCTAssertEqual(MarkdownDocument.groups(MarkdownDocument.parse("Plain text that mentions Goal: inline.")).map(\.section), [nil])
    }

    func testCalloutKindsFollowLabels() {
        XCTAssertEqual(MarkdownDocument.CalloutKind(label: "Key idea:"), .key)
        XCTAssertEqual(MarkdownDocument.CalloutKind(label: "Remember:"), .key)
        XCTAssertEqual(MarkdownDocument.CalloutKind(label: "Tip:"), .tip)
        XCTAssertEqual(MarkdownDocument.CalloutKind(label: "Watch out:"), .warning)
        XCTAssertEqual(MarkdownDocument.CalloutKind(label: nil), .note)
    }

    func testLessonPartsSplitAtSectionHeadingsOnly() {
        let lesson = "# Intro\nWelcome.\n\n## First\n```python\n## not a heading\nx = 1\n```\n\n## Second\nDone."
        let parts = MarkdownDocument.lessonParts(lesson)
        XCTAssertEqual(parts.map(\.title), ["Intro", "First", "Second"])
        XCTAssertTrue(parts[1].markdown.contains("## not a heading"))
    }

    func testEveryCurriculumTextParsesCleanly() {
        for chapter in Curriculum.chapters {
            let sections = chapter.lesson.components(separatedBy: .newlines).filter { $0.hasPrefix("# ") || $0.hasPrefix("## ") }
            XCTAssertEqual(MarkdownDocument.lessonParts(chapter.lesson).count, sections.count, chapter.id)
            let lessonBlocks = MarkdownDocument.parse(chapter.lesson)
            let fences = chapter.lesson.components(separatedBy: .newlines).filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("```") }.count
            XCTAssertEqual(lessonBlocks.filter { if case .code = $0 { true } else { false } }.count * 2, fences, "\(chapter.id) has unbalanced code fences")
            for exercise in chapter.exercises + [chapter.assessment] {
                let groups = MarkdownDocument.groups(MarkdownDocument.parse(exercise.instructions))
                let titles = groups.compactMap(\.section).map { $0 == "Examples" || $0 == "Expected results" ? "Expected result" : $0 }
                XCTAssertEqual(titles, ["Goal", "Starting code", "Your task", "Expected result", "Check"], exercise.id)
                XCTAssertTrue(groups.allSatisfy { $0.section == nil || !$0.blocks.isEmpty }, exercise.id)
                XCTAssertNil(groups.first { $0.section == nil && !$0.blocks.isEmpty }, "\(exercise.id) has text before Goal")
            }
        }
    }

    func testInlineCodeIsStyled() {
        let styled = MarkdownDocument.inline("Use `print` here", style: ReadingStyle())
        let code = styled.runs.filter { $0.inlinePresentationIntent?.contains(.code) == true }
        XCTAssertEqual(code.count, 1)
        XCTAssertNotNil(code.first?.backgroundColor)
    }

    func testPythonHighlightingColorsKeywordsAndStrings() {
        let highlighted = PythonSyntax.highlighted("if x:\n    print('hi')")
        XCTAssertEqual(String(highlighted.characters), "if x:\n    print('hi')")
        XCTAssertGreaterThanOrEqual(highlighted.runs.filter { $0.foregroundColor != nil }.count, 3)
    }

    @MainActor
    func testReadingSurfacesRenderAtDefaultAndLargeSizes() throws {
        _ = NSApplication.shared
        let chapter = try XCTUnwrap(Curriculum.graph.chapter("basics"))
        let part = MarkdownDocument.lessonParts(chapter.lesson)[1]
        let styles: [(String, ReadingStyle, Double)] = [
            ("default", ReadingStyle(), 1.0),
            ("large-serif", ReadingStyle(scale: 1.4, typeface: .serif, spacing: .spacious, codeSize: 18), 1.25)
        ]
        for (name, style, interface) in styles {
            let lesson = NSHostingView(rootView: ScrollView { MarkdownContent(text: part.markdown).padding(24) }
                .frame(width: 420, height: 1400).background(Color(nsColor: .windowBackgroundColor))
                .environment(\.readingStyle, style))
            lesson.frame = NSRect(x: 0, y: 0, width: 420, height: 1400)
            try snapshot(lesson, name: "reading-lesson-\(name)")
            let settings = NSHostingView(rootView: Form { AppearanceSettingsSection() }.formStyle(.grouped)
                .frame(width: 680, height: 760).background(Color(nsColor: .windowBackgroundColor))
                .environment(\.readingStyle, style).environment(\.interfaceScale, interface))
            settings.frame = NSRect(x: 0, y: 0, width: 680, height: 760)
            try snapshot(settings, name: "reading-settings-\(name)")
        }
    }

    @MainActor
    private func snapshot(_ view: NSView, name: String) throws {
        view.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
        view.cacheDisplay(in: view.bounds, to: bitmap)
        XCTAssertGreaterThan(bitmap.pixelsWide, 0)
        guard let path = ProcessInfo.processInfo.environment["PYTHON_TEACHER_UI_SNAPSHOTS_DIR"] else { return }
        let destination = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try XCTUnwrap(bitmap.representation(using: .png, properties: [:])).write(to: destination.appendingPathComponent("\(name).png"))
    }

    func testStyleValuesStayWithinSupportedRanges() {
        XCTAssertEqual(3.0.clamped(to: AppearanceKey.readingRange), AppearanceKey.readingRange.upperBound)
        XCTAssertEqual(0.1.clamped(to: AppearanceKey.interfaceRange), AppearanceKey.interfaceRange.lowerBound)
        let large = ReadingStyle(scale: 1.5, spacing: .spacious)
        XCTAssertGreaterThan(large.bodySize, ReadingStyle().bodySize)
        XCTAssertGreaterThan(large.lineSpacing, ReadingStyle().lineSpacing)
    }
}
