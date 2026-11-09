import Foundation

// The logic of the workshop HUD without WebKit or SwiftUI, so `scripts/verify_workshop_hud.swift` can check it:
// messages from the page, the core state, the answer line, HTML for the page and safe paths of its files.
// Логика HUD Мастерской без WebKit и SwiftUI, чтобы её проверял `scripts/verify_workshop_hud.swift`:
// сообщения страницы, состояние ядра, строка ответа, HTML для страницы и безопасные пути к её файлам.

// MARK: - Core state / состояние ядра

/// What the core shows. Only the motion changes, never the colour (the owner's rule).
/// Что показывает ядро. Меняется только движение, цвет не меняется (правило владельца).
enum HUDMode: String, Codable, Equatable {
    case listen, think, agents, speak
}

struct HUDActivity: Equatable {
    var isListening = false
    var isAnswering = false
    var answerHasText = false
    var isSpeakingAloud = false
    var showsFinishedAnswer = false
    var agentsWorking = false

    /// Listening wins (the owner is talking); then the answer; then agents; otherwise the core listens.
    /// Сначала слушание (владелец говорит), потом ответ, потом агенты, иначе ядро слушает.
    var mode: HUDMode {
        if isListening { return .listen }
        if isAnswering { return answerHasText ? .speak : .think }
        if isSpeakingAloud || showsFinishedAnswer { return .speak }
        if agentsWorking { return .agents }
        return .listen
    }

    /// How long the core keeps "answering" after the text is in: about the time to read it, 3–12 s.
    /// Сколько ядро ещё «отвечает» после ответа: примерно время чтения, от 3 до 12 с.
    static func readingSeconds(_ text: String) -> Double {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        return min(12, max(3, Double(words) * 0.25))
    }
}

// MARK: - Messages from the page / сообщения страницы

enum HUDInbound: Equatable {
    case ready
    case ask(String)
    case rail(String)
    case tool(String)
    case confirm(id: String, yes: Bool)
    case task(String)
    case practiceOpen
    case practiceRun
    case practiceCheck
    case practiceEdit
    case voice
    case reveal(String)

    static let maxText = 4000
    static let rails: Set<String> = ["path", "new", "ex", "ed", "proj", "notes", "rem", "agents", "set"]
    static let tools: Set<String> = ["claude", "open", "hermes", "claw", "buff", "obs", "nlm", "term", "oll"]

    /// The page is not trusted: unknown types, wrong fields and empty text are dropped, long text is cut.
    /// Странице не доверяем: неизвестные типы, неверные поля и пустой текст отбрасываются, длинный текст обрезается.
    static func parse(_ body: Any) -> HUDInbound? {
        guard let message = body as? [String: Any], let type = message["type"] as? String else { return nil }
        func text(_ key: String) -> String? {
            guard let value = message[key] as? String else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : String(trimmed.prefix(maxText))
        }
        switch type {
        case "ready": return .ready
        case "ask": return text("text").map(HUDInbound.ask)
        case "rail": return text("act").flatMap { rails.contains($0) ? .rail($0) : nil }
        case "tool": return text("tool").flatMap { tools.contains($0) ? .tool($0) : nil }
        case "confirm":
            guard let id = text("id"), let yes = message["yes"] as? Bool else { return nil }
            return .confirm(id: id, yes: yes)
        case "task": return .task(text("text") ?? "")
        case "practiceOpen": return .practiceOpen
        case "practiceRun": return .practiceRun
        case "practiceCheck": return .practiceCheck
        case "practiceEdit": return .practiceEdit
        case "voice": return .voice
        case "reveal": return text("path").map(HUDInbound.reveal)
        default: return nil
        }
    }

    /// "совет: …" / "council: …" asks 2–3 models at once. / «совет: …» спрашивает сразу 2–3 модели.
    static func councilQuestion(_ text: String) -> String? {
        let lower = text.lowercased()
        for prefix in ["совет:", "council:"] where lower.hasPrefix(prefix) {
            let rest = text.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            return rest.isEmpty ? nil : rest
        }
        return nil
    }
}

/// Dock tile → agent of the workshop. / Плитка дока → агент Мастерской.
enum HUDTool {
    static func agentID(_ tool: String) -> String? {
        ["claude": "claude", "open": "opencode", "hermes": "hermes", "claw": "openclaw", "buff": "freebuff"][tool]
    }

    static func tile(ofAgent agent: String) -> String? {
        ["claude": "claude", "opencode": "open", "hermes": "hermes", "openclaw": "claw", "freebuff": "buff"][agent]
    }
}

// MARK: - Text for the page / текст для страницы

enum HUDText {
    /// Markdown made plain for one line: no code, headings, emphasis or links. / Markdown в простой строке.
    static func plain(_ markdown: String) -> String {
        var lines: [String] = []
        var inCode = false
        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") { inCode.toggle(); continue }
            if inCode || line.isEmpty { continue }
            var text = line
            while text.hasPrefix("#") || text.hasPrefix(">") { text.removeFirst() }
            if text.hasPrefix("- ") || text.hasPrefix("* ") { text.removeFirst(2) }
            text = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "__", with: "")
                .replacingOccurrences(of: "`", with: "")
            text = replaceLinks(text)
            lines.append(text.trimmingCharacters(in: .whitespaces))
        }
        return lines.filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// "[name](url)" → "name". / «[имя](адрес)» → «имя».
    private static func replaceLinks(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\([^)]*\\)") else { return text }
        return regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "$1")
    }

    /// The answer under the core: whole sentences up to `limit` characters, otherwise cut on a word with "…".
    /// Ответ под ядром: целые предложения до `limit` символов, иначе обрезка по слову с «…».
    static func line(_ markdown: String, limit: Int = 220) -> String {
        let text = plain(markdown)
        guard text.count > limit else { return text }
        let head = String(text.prefix(limit))
        if let end = head.lastIndex(where: { ".!?…".contains($0) }), head.distance(from: head.startIndex, to: end) > limit / 3 {
            return String(head[...end])
        }
        let cut = head.lastIndex(of: " ").map { String(head[..<$0]) } ?? head
        return cut + "…"
    }

    /// The answer needs the explanation window when it does not fit the line. / Окно объяснения, если ответ не влез в строку.
    static func needsWindow(_ markdown: String, limit: Int = 220) -> Bool {
        markdown.contains("```") || plain(markdown).count > limit
    }

    /// Short single-line text for the confirmation bar. / Короткая строка для полосы подтверждения.
    static func short(_ text: String, limit: Int) -> String {
        let one = text.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespaces)
        return one.count > limit ? String(one.prefix(limit - 1)) + "…" : one
    }

    /// Program output in the design's style: lines joined with " · ". / Вывод программы в стиле макета.
    static func outputLine(_ output: String, limit: Int = 120) -> String {
        let lines = output.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return short(lines.joined(separator: " · "), limit: limit)
    }
}

enum HUDHTML {
    static func escape(_ text: String) -> String {
        var out = ""
        out.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(character)
            }
        }
        return out
    }

    /// `**bold**` and `` `code` `` inside one escaped line. / Жирный и код внутри одной экранированной строки.
    static func inline(_ text: String) -> String {
        var html = escape(text)
        for (pattern, template) in [("\\*\\*([^*]+)\\*\\*", "<b>$1</b>"), ("`([^`]+)`", "<code>$1</code>")] {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                html = regex.stringByReplacingMatches(in: html, range: NSRange(html.startIndex..., in: html), withTemplate: template)
            }
        }
        return html
    }

    /// The answer for the explanation window: paragraphs, list items and code blocks in the design's classes.
    /// Ответ для окна объяснения: абзацы, пункты списка и блоки кода в классах макета.
    static func answer(_ markdown: String) -> String {
        var html = ""
        var code: [String]?
        var paragraph: [String] = []
        func flush() {
            if !paragraph.isEmpty { html += "<p>" + inline(paragraph.joined(separator: " ")) + "</p>" }
            paragraph = []
        }
        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("```") {
                if let lines = code {
                    html += "<pre class=\"code\">" + lines.map { "<span class=\"l\">" + (escape($0).isEmpty ? " " : escape($0)) + "</span>" }.joined() + "</pre>"
                    code = nil
                } else {
                    flush()
                    code = []
                }
                continue
            }
            if code != nil { code?.append(raw); continue }
            if line.isEmpty { flush(); continue }
            if line.hasPrefix("#") {
                flush()
                html += "<p><b>" + inline(line.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)) + "</b></p>"
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                flush()
                html += "<p>• " + inline(String(line.dropFirst(2))) + "</p>"
            } else {
                paragraph.append(line)
            }
        }
        if let lines = code {
            html += "<pre class=\"code\">" + lines.map { "<span class=\"l\">" + escape($0) + "</span>" }.joined() + "</pre>"
        }
        flush()
        return html
    }

    /// Python with the design's colour classes (k, f, nm, s, c); one `span.l` per line for the line numbers.
    /// Python с классами цвета макета (k, f, nm, s, c); по одному `span.l` на строку для номеров строк.
    static func python(_ source: String, tokens: [(kind: String, range: NSRange)], maxLines: Int = 80) -> String {
        let units = Array(source.utf16)
        let names = ["keyword": "k", "builtin": "f", "definition": "f", "decorator": "f", "number": "nm", "string": "s", "comment": "c"]
        var classes = [String?](repeating: nil, count: units.count)
        for token in tokens {
            let start = max(0, token.range.location), end = min(units.count, token.range.location + token.range.length)
            guard start < end else { continue }
            for index in start..<end { classes[index] = names[token.kind] ?? "f" }
        }
        var html = ""
        var lineStart = 0
        var lines = 0
        func emitLine(_ end: Int) {
            var line = ""
            var index = lineStart
            while index < end {
                let kind = classes[index]
                var stop = index
                while stop < end, classes[stop] == kind { stop += 1 }
                let piece = escape(String(decoding: units[index..<stop], as: UTF16.self))
                line += kind.map { "<span class=\"\($0)\">\(piece)</span>" } ?? piece
                index = stop
            }
            html += "<span class=\"l\">" + (line.isEmpty ? " " : line) + "</span>"
            lines += 1
        }
        for index in 0..<units.count where units[index] == 10 {
            guard lines < maxLines else { return html }
            emitLine(index)
            lineStart = index + 1
        }
        if lineStart < units.count, lines < maxLines { emitLine(units.count) }
        return html
    }
}

// MARK: - Swift → page / из Swift в страницу

enum HUDScript {
    /// One call into the page; JSON is valid JavaScript, so no string is built by hand.
    /// Один вызов в страницу; JSON — правильный JavaScript, строки руками не собираются.
    static func receive<T: Encodable>(_ payload: T) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(payload), let json = String(data: data, encoding: .utf8) else { return nil }
        // U+2028/2029 are fine in JSON but end a line in older JavaScript. / Разделители строк экранируем.
        let safe = json.replacingOccurrences(of: "\u{2028}", with: "\\u2028").replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return "window.creatorApp && window.creatorApp.receive(\(safe));"
    }
}

// MARK: - Files of the page / файлы страницы

enum HUDResource {
    static let scheme = "creator"
    static let host = "hud"
    static let folderName = "WorkshopHUD"
    static var startURL: URL { URL(string: "\(scheme)://\(host)/index.html")! }

    /// A file inside the page folder, or nil: no "..", no hidden files, no way out through symlinks.
    /// Файл внутри папки страницы или nil: без «..», без скрытых файлов, без выхода по ссылкам.
    static func file(for url: URL, root: URL) -> URL? {
        guard url.scheme == scheme, url.host == host else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard !parts.isEmpty, !parts.contains(where: { $0 == ".." || $0 == "." || $0.hasPrefix(".") }) else { return nil }
        let base = root.standardizedFileURL.resolvingSymlinksInPath()
        var file = parts.reduce(base) { $0.appendingPathComponent($1) }.standardizedFileURL
        if FileManager.default.fileExists(atPath: file.path) { file = file.resolvingSymlinksInPath() }
        guard file.path.hasPrefix(base.path + "/") else { return nil }
        return file
    }

    static func mimeType(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html": return "text/html"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "woff2": return "font/woff2"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        default: return "application/octet-stream"
        }
    }
}

// MARK: - Messages to the page / сообщения в страницу

struct HUDStateMessage: Encodable, Equatable {
    var type = "state"
    var mode: HUDMode
    var line: String
}

struct HUDNamedPercent: Encodable, Equatable { var name: String; var percent: Int }
struct HUDPair: Encodable, Equatable { var value: String; var label: String }
struct HUDPathInfo: Encodable, Equatable {
    var percent: Int
    var sub: String
    var stages: [HUDNamedPercent]
    var trio: [HUDPair]
}
struct HUDLessonCard: Encodable, Equatable { var title: String; var sub: String }
struct HUDAgentRow: Encodable, Equatable { var icon: String; var name: String; var detail: String; var status: String; var live: Bool }
struct HUDVote: Encodable, Equatable { var name: String; var percent: Int; var mark: String }
struct HUDCouncilInfo: Encodable, Equatable { var members: [HUDVote]; var hint: String }
struct HUDTimed: Encodable, Equatable { var time: String; var text: String }
struct HUDListItem: Encodable, Equatable { var name: String; var detail: String; var path: String? }
struct HUDListInfo: Encodable, Equatable { var title: String; var sub: String; var items: [HUDListItem]; var empty: String }
struct HUDTile: Encodable, Equatable { var tip: String; var live: Bool }

struct HUDDataMessage: Encodable, Equatable {
    var type = "data"
    var locale: String
    var strings: [String: String]
    var online: Bool
    var path: HUDPathInfo
    var lessons: [HUDLessonCard]
    var lessonIndex: Int
    var agents: [HUDAgentRow]
    var council: HUDCouncilInfo
    var reminders: [HUDTimed]
    var remindersEmpty: String
    var projects: HUDListInfo
    var notes: HUDListInfo
    var settings: HUDListInfo
    var hints: [String]
    var tiles: [String: HUDTile]
}

struct HUDPracticeMessage: Encodable, Equatable {
    var type = "practice"
    var file: String
    var code: String
    var out: String
    var ok: String
    var good: Bool
}

struct HUDAnswerMessage: Encodable, Equatable {
    var type = "answer"
    var id: String
    var title: String
    var html: String
    var sources: String
    var open: Bool
}

/// No `id` hides the bar. / Без `id` полоса скрыта.
struct HUDConfirmMessage: Encodable, Equatable {
    var type = "confirm"
    var id: String?
    var text: String
}

/// Static texts of the page; the page swaps them in by key. / Постоянные тексты страницы; страница подставляет их по ключу.
enum HUDStrings {
    static let pageKeys = [
        "hud.sub", "hud.online", "hud.starting", "hud.tip.claude", "hud.tip.gemini", "hud.tip.qwen", "hud.tip.access",
        "hud.rail.path", "hud.rail.new", "hud.rail.ex", "hud.rail.ed", "hud.rail.proj", "hud.rail.notes", "hud.rail.rem",
        "hud.rail.agents", "hud.rail.set", "hud.seg.council", "hud.note", "hud.noteLabel", "hud.addTask", "hud.run", "hud.check",
        "hud.ask", "hud.askLabel", "hud.send", "hud.yes", "hud.no", "hud.confirmLabel", "hud.state.listen", "hud.state.think",
        "hud.state.agents", "hud.state.speak", "hud.fallback", "hud.ex.title", "hud.ex.answer", "hud.ex.sources", "hud.ex.empty",
        "hud.newProject", "hud.newProject.say", "hud.voice", "hud.edit",
    ]
}

/// A task written in the card ("Task" button). / Задача из карточки (кнопка «Задача»).
struct HUDTask: Codable, Equatable {
    var text: String
    var date: Date

    static let defaultsKey = "workshop.hud.tasks"
    static let limit = 30

    static func adding(_ text: String, to tasks: [HUDTask], at date: Date) -> [HUDTask] {
        let clean = HUDText.short(text, limit: 200)
        guard !clean.isEmpty else { return tasks }
        return Array(([HUDTask(text: clean, date: date)] + tasks).prefix(limit))
    }
}
