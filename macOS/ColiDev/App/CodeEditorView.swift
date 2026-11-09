import AppKit
import SwiftUI

// The code editor of "Practice": NSTextView with line numbers, Python colours, light and dark themes.
// Редактор кода «Практики»: NSTextView с номерами строк, цветами Python, светлой и тёмной темой.

enum CodeEditorTheme {
    static func token(_ pair: CodeEditorColors.Pair) -> ColorToken { ColorToken(lightHex: pair.light, darkHex: pair.dark) }

    static let background = AppPalette.card
    static let gutter = AppPalette.inset
    static let text = token(CodeEditorColors.text)
    static let gutterText = token(CodeEditorColors.gutterText)
    static let errorLine = token(CodeEditorColors.errorLine)

    static func color(_ kind: PythonTokenKind) -> NSColor { token(CodeEditorColors.token(kind)).nsColor }

    static func font(size: CGFloat) -> NSFont { NSFont.monospacedSystemFont(ofSize: size, weight: .regular) }
}

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    /// The line to mark red and scroll to, from 1. / Строка с ошибкой (с 1): красный фон и прокрутка к ней.
    var errorLine: Int?
    var fontSize: CGFloat = 13
    var isEditable = true

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        let font = CodeEditorTheme.font(size: fontSize)
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true
        textView.smartInsertDeleteEnabled = false
        // Code must stay exactly as typed: no curly quotes, dashes, corrections or links.
        // Код должен остаться как набран: без «умных» кавычек, тире, исправлений и ссылок.
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.font = font
        textView.textColor = CodeEditorTheme.text.nsColor
        textView.backgroundColor = CodeEditorTheme.background.nsColor
        textView.insertionPointColor = AppPalette.accent.nsColor
        textView.selectedTextAttributes = [.backgroundColor: AppPalette.selection.nsColor]
        textView.textContainerInset = NSSize(width: 6, height: 8)
        textView.typingAttributes = [.font: font, .foregroundColor: CodeEditorTheme.text.nsColor]
        textView.setAccessibilityIdentifier("practice.editor")

        // Long lines scroll sideways instead of wrapping, as in any code editor.
        // Длинные строки прокручиваются вбок, а не переносятся, как в любом редакторе кода.
        textView.isHorizontallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scrollView.hasHorizontalScroller = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = CodeEditorTheme.background.nsColor

        let ruler = LineNumberRulerView(textView: textView, scrollView: scrollView)
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        context.coordinator.ruler = ruler
        context.coordinator.textView = textView

        textView.string = text
        context.coordinator.highlight()
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(context.coordinator, selector: #selector(Coordinator.scrolled),
                                               name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = context.coordinator.textView else { return }
        textView.isEditable = isEditable
        if textView.string != text {
            textView.string = text
            // Another file: its undo must not bring back the previous file. / Отмена не должна вернуть прежний файл.
            textView.undoManager?.removeAllActions()
            textView.setSelectedRange(NSRange(location: 0, length: 0))
            context.coordinator.highlight()
            textView.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
        let font = CodeEditorTheme.font(size: fontSize)
        if textView.font != font {
            textView.font = font
            textView.typingAttributes[.font] = font
            context.coordinator.highlight()
        }
        context.coordinator.showError(line: errorLine)
    }

    static func dismantleNSView(_ scrollView: NSScrollView, coordinator: Coordinator) {
        NotificationCenter.default.removeObserver(coordinator)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView
        weak var textView: NSTextView?
        weak var ruler: LineNumberRulerView?
        private var shownErrorLine: Int?

        init(_ parent: CodeEditorView) { self.parent = parent }

        @objc func scrolled() { ruler?.needsDisplay = true }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            parent.text = textView.string
            highlight()
        }

        /// Tab inserts four spaces; Return keeps the indent and adds four after a `:`.
        /// Tab ставит четыре пробела; Return сохраняет отступ и добавляет четыре после «:».
        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertTab(_:)):
                textView.insertText("    ", replacementRange: textView.selectedRange())
                return true
            case #selector(NSResponder.insertNewline(_:)):
                let indent = CodeLines.indentForNewLine(in: textView.string, at: textView.selectedRange().location)
                textView.insertText("\n" + indent, replacementRange: textView.selectedRange())
                return true
            case #selector(NSResponder.insertBacktab(_:)):
                return removeIndent(textView)
            default:
                return false
            }
        }

        /// Shift-Tab removes up to four spaces before the cursor. / Shift-Tab убирает до четырёх пробелов перед курсором.
        private func removeIndent(_ textView: NSTextView) -> Bool {
            let source = textView.string as NSString
            let cursor = textView.selectedRange().location
            let lineStart = source.lineRange(for: NSRange(location: cursor, length: 0)).location
            var start = cursor
            while start > lineStart && cursor - start < 4 && source.character(at: start - 1) == 32 { start -= 1 }
            guard start < cursor else { return true }
            textView.insertText("", replacementRange: NSRange(location: start, length: cursor - start))
            return true
        }

        func highlight() {
            guard let textView, let storage = textView.textStorage else { return }
            let font = CodeEditorTheme.font(size: parent.fontSize)
            let whole = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes([.font: font, .foregroundColor: CodeEditorTheme.text.nsColor], range: whole)
            for token in PythonHighlighter.tokens(textView.string) where NSMaxRange(token.range) <= storage.length {
                storage.addAttribute(.foregroundColor, value: CodeEditorTheme.color(token.kind), range: token.range)
            }
            storage.endEditing()
            ruler?.invalidateLines(textView.string)
            if let line = shownErrorLine { markError(line: line, scroll: false) }
        }

        func showError(line: Int?) {
            guard line != shownErrorLine else { return }
            clearError()
            shownErrorLine = line
            ruler?.errorLine = line
            if let line { markError(line: line, scroll: true) }
        }

        private func clearError() {
            guard let textView, let layoutManager = textView.layoutManager else { return }
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: NSRange(location: 0, length: (textView.string as NSString).length))
        }

        private func markError(line: Int, scroll: Bool) {
            guard let textView, let layoutManager = textView.layoutManager,
                  let range = CodeLines.range(ofLine: line, in: textView.string) else { return }
            let full = (textView.string as NSString).lineRange(for: range)
            layoutManager.addTemporaryAttribute(.backgroundColor, value: CodeEditorTheme.errorLine.nsColor, forCharacterRange: full)
            if scroll {
                textView.scrollRangeToVisible(range)
                textView.setSelectedRange(NSRange(location: range.location + range.length, length: 0))
            }
        }
    }
}

/// Line numbers to the left of the code; the error line number is red. / Номера строк слева, номер строки с ошибкой красный.
final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private var lineStarts: [Int] = [0]
    var errorLine: Int? { didSet { needsDisplay = true } }

    init(textView: NSTextView, scrollView: NSScrollView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 40
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }

    func invalidateLines(_ source: String) {
        var starts = [0]
        for (offset, unit) in source.utf16.enumerated() where unit == 10 { starts.append(offset + 1) }
        lineStarts = starts
        let digits = max(2, String(starts.count).count)
        let width = CGFloat(digits) * ((textView?.font?.pointSize ?? 13) * 0.62) + 20
        if abs(ruleThickness - width) > 0.5 {
            ruleThickness = width
            // Without this the text slides under a wider ruler. / Иначе текст уезжает под расширившуюся колонку.
            scrollView?.tile()
        }
        needsDisplay = true
    }

    /// Index of the line that holds `location`, from 0. / Номер строки (с 0), где стоит символ.
    private func lineIndex(of location: Int) -> Int {
        var low = 0, high = lineStarts.count - 1
        while low < high {
            let middle = (low + high + 1) / 2
            if lineStarts[middle] <= location { low = middle } else { high = middle - 1 }
        }
        return low
    }

    override func draw(_ dirtyRect: NSRect) {
        CodeEditorTheme.gutter.nsColor.setFill()
        bounds.fill()
        AppPalette.stroke.nsColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()
        drawHashMarksAndLabels(in: dirtyRect)
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView, let layoutManager = textView.layoutManager, let container = textView.textContainer else { return }
        let length = (textView.string as NSString).length
        let font = NSFont.monospacedDigitSystemFont(ofSize: max(9, (textView.font?.pointSize ?? 13) - 1), weight: .regular)
        let plain: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: CodeEditorTheme.gutterText.nsColor]
        let red: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.systemRed]
        let inset = textView.textContainerInset.height

        func label(_ number: Int, lineRectY: CGFloat, height: CGFloat) {
            let y = convert(NSPoint(x: 0, y: lineRectY + inset), from: textView).y
            let string = NSAttributedString(string: "\(number)", attributes: number == errorLine ? red : plain)
            let size = string.size()
            string.draw(at: NSPoint(x: ruleThickness - size.width - 8, y: y + (height - size.height) / 2))
        }

        let visible = textView.visibleRect
        let glyphs = layoutManager.glyphRange(forBoundingRect: visible, in: container)
        let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
        var line = lineIndex(of: characters.location)
        while line < lineStarts.count {
            let start = lineStarts[line]
            if start > NSMaxRange(characters) || start >= length { break }
            let glyph = layoutManager.glyphIndexForCharacter(at: start)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
            label(line + 1, lineRectY: fragment.minY, height: fragment.height)
            line += 1
        }
        // The empty line after a final line break. / Пустая строка после последнего перевода строки.
        if lineStarts.last == length {
            let extra = layoutManager.extraLineFragmentRect
            if extra.height > 0 { label(lineStarts.count, lineRectY: extra.minY, height: extra.height) }
            else if length == 0 { label(1, lineRectY: 0, height: textView.font?.boundingRectForFont.height ?? 16) }
        }
    }
}
