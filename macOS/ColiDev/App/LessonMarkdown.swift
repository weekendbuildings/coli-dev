import Foundation

/// Renders lesson Markdown for SwiftUI `Text` without losing paragraph breaks.
/// Full-syntax `AttributedString(markdown:)` drops the separators between paragraphs and list items,
/// so "…в секунду.\n\nУ маятника…" renders as "…в секунду.У маятника…". Each block is parsed with
/// inline syntax only, fenced code keeps its line breaks, and blocks are rejoined with a blank line.
/// Отрисовывает Markdown урока для SwiftUI `Text`, не теряя разрывы абзацев и строки списков.
enum LessonMarkdown {
    enum Block: Equatable {
        case prose(String)
        case code(String)
    }

    /// Text and code blocks in order, with neighbouring paragraphs kept together, so code can be drawn on its own.
    /// Текст и блоки кода по порядку, соседние абзацы вместе: так код можно нарисовать отдельно.
    static func segments(_ markdown: String) -> [Block] {
        var result: [Block] = []
        for block in blocks(in: markdown) {
            if case .prose(let text) = block, case .prose(let earlier)? = result.last {
                result[result.count - 1] = .prose(earlier + "\n\n" + text)
            } else {
                result.append(block)
            }
        }
        return result
    }

    static func attributed(_ markdown: String) -> AttributedString {
        var result = AttributedString()
        for (index, block) in blocks(in: markdown).enumerated() {
            if index > 0 {
                result += AttributedString("\n\n")
            }
            switch block {
            case .prose(let text):
                result += inline(text)
            case .code(let text):
                var code = AttributedString(text)
                code.inlinePresentationIntent = .code
                result += code
            }
        }
        return result
    }

    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    static func plainText(_ markdown: String) -> String {
        String(attributed(markdown).characters)
    }

    private static func blocks(in markdown: String) -> [Block] {
        var blocks: [Block] = []
        var prose: [String] = []
        var code: [String]?

        func flushProse() {
            let text = prose.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(.prose(text))
            }
            prose.removeAll()
        }

        for line in markdown.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if let codeLines = code {
                    blocks.append(.code(codeLines.joined(separator: "\n")))
                    code = nil
                } else {
                    flushProse()
                    code = []
                }
            } else if code != nil {
                code?.append(line)
            } else if trimmed.isEmpty {
                flushProse()
            } else {
                prose.append(line)
            }
        }
        if let codeLines = code {
            blocks.append(.code(codeLines.joined(separator: "\n")))
        }
        flushProse()
        return blocks
    }
}
