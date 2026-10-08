import AppKit
import Carbon
import SwiftUI

struct CodeEditorFindCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Menu("Find") {
                Button("Find…") { Self.perform(.showFindInterface) }
                    .keyboardShortcut("f", modifiers: .command)
                Button("Find Next") { Self.perform(.nextMatch) }
                    .keyboardShortcut("g", modifiers: .command)
                Button("Find Previous") { Self.perform(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { Self.perform(.setSearchString) }
                    .keyboardShortcut("e", modifiers: .command)
            }
        }
    }

    @MainActor
    @discardableResult
    static func perform(_ action: NSTextFinder.Action) -> Bool {
        let item = NSMenuItem()
        item.tag = action.rawValue
        return NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: item)
    }
}

struct EditorRevealRequest: Equatable {
    let id = UUID()
    let sourceIdentity: String
    let source: String
    let line: Int

    static func lineRange(_ line: Int, in source: String) -> NSRange? {
        guard line > 0 else { return nil }
        let units = Array(source.utf16)
        var current = 1
        var start = 0
        var index = 0
        while index < units.count {
            if units[index] == 10 || units[index] == 13 {
                if current == line { return NSRange(location: start, length: index - start) }
                if units[index] == 13, index + 1 < units.count, units[index + 1] == 10 { index += 1 }
                current += 1
                start = index + 1
            }
            index += 1
        }
        return current == line ? NSRange(location: start, length: units.count - start) : nil
    }
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var editable: Bool = true
    var fontSize: CGFloat = 14
    var sourceIdentity: String = ""
    var revealRequest: EditorRevealRequest?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.borderType = .noBorder
        scroll.autohidesScrollers = true
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(containerSize: NSSize(width: 100_000, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = false
        layout.addTextContainer(container)
        let editor = PythonTextView(frame: .zero, textContainer: container)
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = true
        editor.autoresizingMask = [.width]
        editor.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        editor.textContainerInset = NSSize(width: 14, height: 16)
        editor.backgroundColor = .textBackgroundColor
        editor.insertionPointColor = .labelColor
        editor.textColor = .labelColor
        editor.isRichText = false
        editor.allowsUndo = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticTextCompletionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.smartInsertDeleteEnabled = false
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("Python code editor")
        editor.string = text
        scroll.documentView = editor
        let ruler = LineNumberRuler(textView: editor, scrollView: scroll)
        scroll.verticalRulerView = ruler
        scroll.hasVerticalRuler = true
        scroll.rulersVisible = true
        context.coordinator.highlight(editor)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? PythonTextView else { return }
        editor.isEditable = editable
        if editor.font?.pointSize != fontSize {
            editor.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
            (scroll.verticalRulerView as? LineNumberRuler)?.fontSize = max(10, fontSize - 3)
        }
        if !editor.hasMarkedText(), editor.string != text {
            editor.string = text
            editor.undoManager?.removeAllActions()
            context.coordinator.highlight(editor)
        }
        scroll.verticalRulerView?.needsDisplay = true
        context.coordinator.reveal(in: editor)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        private var handledRevealID: UUID?
        init(_ parent: CodeEditor) { self.parent = parent }

        func reveal(in editor: NSTextView) {
            guard let request = parent.revealRequest, request.id != handledRevealID else { return }
            handledRevealID = request.id
            guard !editor.hasMarkedText(), request.sourceIdentity == parent.sourceIdentity,
                  request.source == parent.text, request.source == editor.string,
                  let range = EditorRevealRequest.lineRange(request.line, in: editor.string) else { return }
            editor.window?.makeFirstResponder(editor)
            editor.setSelectedRange(range)
            editor.scrollRangeToVisible(range)
        }

        func textDidChange(_ notification: Notification) {
            guard let editor = notification.object as? NSTextView, !editor.hasMarkedText() else { return }
            parent.text = editor.string
            highlight(editor)
            editor.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        func highlight(_ editor: NSTextView) {
            guard !editor.hasMarkedText(), let layout = editor.layoutManager else { return }
            let range = NSRange(location: 0, length: editor.string.utf16.count)
            layout.removeTemporaryAttribute(.foregroundColor, forCharacterRange: range)
            if range.length < 100_000 {
                PythonSyntax.enumerateColors(in: editor.string) { range, color in
                    layout.addTemporaryAttribute(.foregroundColor, value: color, forCharacterRange: range)
                }
            }
        }
    }
}

/// Lightweight Python coloring shared by the editor and read-only code samples.
enum PythonSyntax {
    private static let rules: [(NSRegularExpression, NSColor)] = [
        (#"\b(False|None|True|and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield)\b"#, NSColor.systemPurple),
        (#"\b(print|len|range|str|int|float|bool|list|dict|set|sum|min|max|sorted|enumerate|zip|isinstance|ValueError|TypeError)\b"#, .systemTeal),
        (#"\b\d+(\.\d+)?\b"#, .systemOrange),
        (#"("([^"\\]|\\.)*"|'([^'\\]|\\.)*')"#, .systemGreen),
        (#"#[^\n]*"#, .secondaryLabelColor)
    ].compactMap { pattern, color in (try? NSRegularExpression(pattern: pattern)).map { ($0, color) } }

    /// Later rules win, so strings and comments override keywords inside them.
    static func enumerateColors(in source: String, _ body: (NSRange, NSColor) -> Void) {
        let range = NSRange(location: 0, length: source.utf16.count)
        for (regex, color) in rules {
            for match in regex.matches(in: source, range: range) { body(match.range, color) }
        }
    }

    static func highlighted(_ source: String) -> AttributedString {
        let text = NSMutableAttributedString(string: source)
        enumerateColors(in: source) { range, color in text.addAttribute(.foregroundColor, value: color, range: range) }
        var result = AttributedString(source)
        text.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let color = value as? NSColor, let bounds = Range(range, in: source),
                  let lower = AttributedString.Index(bounds.lowerBound, within: result),
                  let upper = AttributedString.Index(bounds.upperBound, within: result) else { return }
            result[lower..<upper].foregroundColor = Color(nsColor: color)
        }
        return result
    }
}

final class PythonTextView: NSTextView {
    override func keyDown(with event: NSEvent) {
        if isEditable, !hasMarkedText(), let quote = Self.literalQuote(for: event) {
            insertText(quote, replacementRange: selectedRange())
        } else {
            super.keyDown(with: event)
        }
    }

    static func literalQuote(for event: NSEvent, inputSource: TISInputSource? = nil) -> String? {
        guard event.modifierFlags.intersection([.command, .control, .option]).isEmpty else { return nil }
        if let characters = event.characters, !characters.isEmpty {
            return characters == "\"" || characters == "'" ? characters : nil
        }
        let source = inputSource ?? TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let property = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
        let data = Unmanaged<CFData>.fromOpaque(property).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var modifiers: UInt32 = 0
        if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if event.modifierFlags.contains(.capsLock) { modifiers |= UInt32(alphaLock) }
        var state: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(layout, event.keyCode, UInt16(kUCKeyActionDown), modifiers >> 8,
                                    UInt32(LMGetKbdType()), OptionBits(kUCKeyTranslateNoDeadKeysMask),
                                    &state, characters.count, &length, &characters)
        guard status == noErr, length == 1, characters[0] == 34 || characters[0] == 39 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }

    override func insertTab(_ sender: Any?) {
        insertText("    ", replacementRange: selectedRange())
    }

    override func insertNewline(_ sender: Any?) {
        let source = string as NSString
        let selection = selectedRange()
        let lineRange = source.lineRange(for: NSRange(location: selection.location, length: 0))
        let beforeCursor = source.substring(with: NSRange(location: lineRange.location, length: selection.location - lineRange.location))
        let indentation = String(beforeCursor.prefix { $0 == " " || $0 == "\t" })
        let extra = beforeCursor.trimmingCharacters(in: .whitespaces).hasSuffix(":") ? "    " : ""
        insertText("\n" + indentation + extra, replacementRange: selection)
    }
}

final class LineNumberRuler: NSRulerView {
    weak var editor: NSTextView?
    var fontSize: CGFloat = 11 { didSet { needsDisplay = true } }

    init(textView: NSTextView, scrollView: NSScrollView) {
        editor = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 48
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is unavailable") }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        bounds.fill()
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return }
        let source = editor.string as NSString
        let visible = editor.visibleRect
        let glyphs = layout.glyphRange(forBoundingRect: visible.offsetBy(dx: -editor.textContainerOrigin.x, dy: -editor.textContainerOrigin.y), in: container)
        let start = layout.numberOfGlyphs == 0 ? 0 : min(layout.characterIndexForGlyph(at: min(glyphs.location, layout.numberOfGlyphs - 1)), source.length)
        var line = source.substring(to: start).filter { $0 == "\n" }.count + 1
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular), .foregroundColor: NSColor.tertiaryLabelColor]
        layout.enumerateLineFragments(forGlyphRange: glyphs) { _, used, _, _, _ in
            let label = "\(line)" as NSString
            let y = used.minY + editor.textContainerOrigin.y - visible.minY
            label.draw(at: NSPoint(x: self.ruleThickness - label.size(withAttributes: attributes).width - 10, y: y + 2), withAttributes: attributes)
            line += 1
        }
        if layout.numberOfGlyphs == 0 {
            ("1" as NSString).draw(at: NSPoint(x: 29, y: editor.textContainerOrigin.y + 2), withAttributes: attributes)
        }
    }
}
