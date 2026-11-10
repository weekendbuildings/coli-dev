import CryptoKit
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
    case dismiss
    case memoryNote(String)
    case memorySearch(String)
    case memoryObsidian
    case memoryChoose
    case notebookRect(x: Double, y: Double, width: Double, height: Double, open: Bool)
    case openLesson
    case video(String)
    case practiceTopic
    case practiceFix

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
        case "dismiss": return .dismiss
        case "memoryNote": return text("id").map(HUDInbound.memoryNote)
        case "memorySearch": return .memorySearch(text("text") ?? "")
        case "memoryObsidian": return .memoryObsidian
        case "memoryChoose": return .memoryChoose
        case "openLesson": return .openLesson
        case "video": return text("id").map(HUDInbound.video)
        case "practiceTopic": return .practiceTopic
        case "practiceFix": return .practiceFix
        case "nbRect":
            guard let x = message["x"] as? Double, let y = message["y"] as? Double, let width = message["w"] as? Double,
                  let height = message["h"] as? Double, let open = message["open"] as? Bool,
                  [x, y, width, height].allSatisfy({ $0.isFinite && abs($0) < 100_000 }) else { return nil }
            return .notebookRect(x: x, y: y, width: max(0, width), height: max(0, height), open: open)
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

/// The state shown at the top of an agent's panel. / Состояние в шапке панели агента.
enum HUDAgentState: String, Equatable {
    case notInstalled, ready, running, done, failed, needsLogin, interactiveOnly

    /// Sign-in problems as the CLIs print them. / Как CLI сообщают, что нужен вход.
    static func needsLogin(_ output: String) -> Bool {
        let lower = output.lowercased()
        return ["/login", "not logged in", "please log in", "please login", "invalid api key", "auth login", "unauthorized",
                "authentication required", "not authenticated", "sign in"].contains { lower.contains($0) }
    }

    static func of(installed: Bool, interactive: Bool, running: Bool, exitCode: Int32?, output: String) -> HUDAgentState {
        if !installed { return .notInstalled }
        if interactive { return .interactiveOnly }
        if running { return .running }
        guard let exitCode else { return .ready }
        if exitCode != 0 && needsLogin(String(output.suffix(1500))) { return .needsLogin }
        return exitCode == 0 ? .done : .failed
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
    /// The answer without ```action blocks, finished or still streaming: actions are shown as buttons, not text.
    /// Ответ без блоков ```action, законченных и ещё идущих: действия показываются кнопками, а не текстом.
    static func withoutActions(_ markdown: String) -> String {
        var result = markdown
        while let start = result.range(of: "```action") {
            if let end = result.range(of: "```", range: start.upperBound..<result.endIndex) {
                result.removeSubrange(start.lowerBound..<end.upperBound)
            } else {
                result.removeSubrange(start.lowerBound..<result.endIndex)
            }
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
    var openID = 0
    var hints: [String] = []
    var canFix = false
}

struct HUDAnswerMessage: Encodable, Equatable {
    var type = "answer"
    var id: String
    var title: String
    var html: String
    var sources: String
    var open: Bool
    var explain = HUDExplainInfo(template: "", lesson: "", videos: [])
}

struct HUDTerminalMessage: Encodable, Equatable {
    var type = "terminal"
    var id: String
    var title: String
    var html: String
    var open: Bool
}

struct HUDMemoryItem: Encodable, Equatable { var id: String; var title: String; var folder: String }

/// «Память» inside the HUD. / «Память» внутри HUD.
struct HUDMemoryMessage: Encodable, Equatable {
    var type = "memory"
    var openID: Int
    var vault: String
    var items: [HUDMemoryItem]
    var selected: String
    var html: String
    var empty: String
}

struct HUDNotebookMessage: Encodable, Equatable {
    var type = "notebook"
    var openID: Int
    var title = "NotebookLM"
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
        "hud.newProject", "hud.newProject.say", "hud.voice", "hud.edit", "hud.ex.terminal",
        "hud.ex.slides", "hud.ex.video", "hud.ex.practice", "hud.ex.practiceText", "hud.ex.practiceOpen", "hud.ex.openLesson",
        "hud.ex.three.surface", "hud.ex.three.vectors", "hud.ex.three.function", "hud.practice.fix",
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

// MARK: - Summoning the workshop / вызов Мастерской

/// The wake word, heard on the Mac. / Слово вызова, распознаётся на Mac.
enum HUDWakeWord {
    /// "Creator" as the Russian and English recognizers write it, and «Творец». / Как его пишут оба распознавателя.
    static let words: Set<String> = ["creator", "креатор", "криэйтор", "криейтор", "крейтор", "креэйтор", "творец", "tvorets", "tvorec"]
    static let hints = ["Creator", "Креатор", "Творец"]

    /// "Close workshop" by voice; never sent to the assistant. / «Закрыть мастерскую» голосом; ассистенту не уходит.
    static func isClose(_ transcript: String) -> Bool {
        let words = transcript.lowercased().replacingOccurrences(of: "ё", with: "е").split(whereSeparator: { !$0.isLetter }).map(String.init)
        let text = " " + words.joined(separator: " ") + " "
        return [" закрыть мастерскую ", " закрой мастерскую ", " закрыть мастерская ", " close workshop ", " close the workshop ",
                " close creator workshop "].contains { text.contains($0) }
    }

    /// Whole words only, any case, ё = е; «Путь Творца» does not count. / Только целые слова; «Творца» не считается.
    static func count(in transcript: String) -> Int {
        transcript.lowercased().replacingOccurrences(of: "ё", with: "е")
            .split(whereSeparator: { !$0.isLetter }).filter { words.contains(String($0)) }.count
    }
}

/// Voice commands, never sent to the model as questions. / Голосовые команды; модели как вопросы не уходят.
enum HUDVoiceCommand: Equatable {
    case openWorkshop, closeWorkshop, openPath, closePath

    static func parse(_ transcript: String) -> HUDVoiceCommand? {
        let words = transcript.lowercased().replacingOccurrences(of: "ё", with: "е").replacingOccurrences(of: "’", with: "'")
            .split(whereSeparator: { !$0.isLetter && $0 != "'" }).map(String.init)
        let text = " " + words.joined(separator: " ") + " "
        func has(_ phrases: [String]) -> Bool { phrases.contains { text.contains(" " + $0 + " ") } }
        let path = ["путь творца", "creator's path", "creators path", "creator path"]
        if has(["закрыть путь творца", "закрой путь творца", "close creator's path", "close creators path", "close creator path"]) { return .closePath }
        if HUDWakeWord.isClose(transcript) { return .closeWorkshop }
        if has(path) { return .openPath }
        if has(["открыть мастерскую", "открой мастерскую", "мастерская", "open workshop", "open the workshop"]) { return .openWorkshop }
        return nil
    }
}

/// When a voice turn after the wake word ends. / Когда кончается голосовой вопрос после слова вызова.
enum HUDVoiceTurn {
    enum Ending: Equatable { case ask, cancel }
    static let pause: TimeInterval = 1.8
    static let silenceLimit: TimeInterval = 7
    static let longest: TimeInterval = 40

    /// A pause after words sends the question; silence from the start or a too long turn ends it.
    /// Пауза после слов отправляет вопрос; тишина с самого начала или слишком долгий вопрос — конец.
    static func ending(transcript: String, started: Date, lastChange: Date, now: Date) -> Ending? {
        let heard = !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if now.timeIntervalSince(started) >= longest { return heard ? .ask : .cancel }
        if heard { return now.timeIntervalSince(lastChange) >= pause ? .ask : nil }
        return now.timeIntervalSince(started) >= silenceLimit ? .cancel : nil
    }
}

/// Global hot keys to call the workshop; Carbon codes written out so this file needs no Carbon.
/// Горячие клавиши вызова Мастерской; коды Carbon записаны числами, чтобы файл не зависел от Carbon.
struct HUDShortcut: Identifiable, Equatable {
    let id: String
    let keyCode: UInt32
    let modifiers: UInt32
    let title: String

    static let control: UInt32 = 0x1000, option: UInt32 = 0x0800, command: UInt32 = 0x0100, shift: UInt32 = 0x0200
    static let all = [
        HUDShortcut(id: "ctrl-opt-t", keyCode: 0x11, modifiers: control | option, title: "⌃⌥T"),
        HUDShortcut(id: "ctrl-opt-space", keyCode: 0x31, modifiers: control | option, title: "⌃⌥Space"),
        HUDShortcut(id: "opt-space", keyCode: 0x31, modifiers: option, title: "⌥Space"),
        HUDShortcut(id: "ctrl-opt-c", keyCode: 0x08, modifiers: control | option, title: "⌃⌥C"),
        HUDShortcut(id: "cmd-shift-c", keyCode: 0x08, modifiers: command | shift, title: "⇧⌘C"),
        HUDShortcut(id: "f13", keyCode: 0x69, modifiers: 0, title: "F13"),
    ]
    /// ⌃⌥V stays the hold-to-talk key. / ⌃⌥V остаётся клавишей «держи и говори».
    static let voice = HUDShortcut(id: "ctrl-opt-v", keyCode: 0x09, modifiers: control | option, title: "⌃⌥V")
    static let defaultsKey = "workshop.summon.shortcut"

    static func find(_ id: String?) -> HUDShortcut { all.first { $0.id == id } ?? all[0] }
}

// MARK: - ElevenLabs voice / голос ElevenLabs

/// The request and the fallback rules for spoken answers through ElevenLabs. Any failure means the macOS voice.
/// Запрос и правила отката для ответа голосом ElevenLabs. Любая ошибка — значит системный голос macOS.
enum ElevenLabsVoice {
    /// Premade ElevenLabs voices; with the multilingual flash model each also speaks Russian.
    /// Готовые голоса ElevenLabs; с многоязычной моделью каждый говорит и по-русски.
    struct Voice: Identifiable, Equatable { let id: String; let name: String; let note: String }
    static let voices = [
        Voice(id: "onwK4e9ZLuTAKqWW03F9", name: "Daniel", note: "calm, low · спокойный, низкий"),
        Voice(id: "nPczCjzI2devNBz1zQrb", name: "Brian", note: "deep · глубокий"),
        Voice(id: "JBFqnCBsd6RMkjVDRZzb", name: "George", note: "warm · тёплый"),
        Voice(id: "pNInz6obpgDQGcFmaJgB", name: "Adam", note: "deep · глубокий"),
        Voice(id: "21m00Tcm4TlvDq8EV7DXq", name: "Rachel", note: "calm · спокойный"),
    ]
    /// Daniel: the calm low male voice the owner asked for. / Daniel — спокойный низкий мужской голос.
    static let defaultVoiceID = voices[0].id
    /// Short fixed phrases are kept on disk and never spend the quota twice. / Короткие фразы хранятся и не тратят лимит дважды.
    static let cacheLimit = 80
    /// Flash v2.5: multilingual, fast and the cheapest per character. / Многоязычная, быстрая и самая экономная по символам.
    static let model = "eleven_flash_v2_5"
    /// Every character counts against the owner's plan, so long answers are cut. / Символы тратят тариф владельца.
    static let maxCharacters = 1200
    static let voiceDefaultsKey = "workshop.voice.elevenlabs.voice"
    static let keychainService = "ColiDev.voice"
    static let keychainAccount = "elevenlabs"
    /// After a key or quota failure the Mac voice is used for a while, so failing calls do not repeat.
    /// После ошибки ключа или лимита какое-то время говорит системный голос, чтобы не повторять неудачные запросы.
    static let cooldown: TimeInterval = 15 * 60

    enum Failure: String, Equatable, Error { case key, quota, server, network, audio }

    static func voiceID(_ stored: String?) -> String {
        let trimmed = (stored ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let valid = !trimmed.isEmpty && trimmed.count <= 64 && trimmed.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
        return valid ? trimmed : defaultVoiceID
    }

    /// Whole sentences up to the limit. / Целые предложения до предела.
    static func spoken(_ text: String) -> String {
        guard text.count > maxCharacters else { return text }
        let head = String(text.prefix(maxCharacters))
        if let end = head.lastIndex(where: { ".!?…".contains($0) }), head.distance(from: head.startIndex, to: end) > maxCharacters / 2 {
            return String(head[...end])
        }
        return head
    }

    /// The answer in pieces of whole sentences (short ones joined, up to `target` characters), spoken one after another,
    /// so speech starts quickly and a lost network moves only the rest to the Mac voice.
    /// Ответ кусками из целых предложений (короткие склеиваются, до ~240 символов): речь начинается быстро, а при
    /// потере сети на голос Mac уходит только остаток.
    static func sentences(_ text: String, target: Int = 240) -> [String] {
        let clean = spoken(text).replacingOccurrences(of: "\n", with: " ")
        var pieces: [String] = []
        var current = ""
        for character in clean {
            current.append(character)
            if ".!?…".contains(character), current.trimmingCharacters(in: .whitespaces).count > 1 {
                pieces.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { pieces.append(current.trimmingCharacters(in: .whitespaces)) }
        var chunks: [String] = []
        for piece in pieces where !piece.isEmpty {
            // Only short sentences are joined, so the first sound comes fast. / Склеиваются только короткие — звук начинается быстро.
            if let last = chunks.last, last.count + piece.count + 1 <= target, last.count < 60, piece.count < 60 {
                chunks[chunks.count - 1] = last + " " + piece
            } else {
                chunks.append(piece)
            }
        }
        return chunks
    }

    /// "ru" or "en" by the letters of a sentence, so each sentence gets a voice of its own language.
    /// «ru» или «en» по буквам предложения: каждое предложение читает голос своего языка.
    static func language(of text: String) -> String? {
        var cyrillic = 0, latin = 0
        for scalar in text.unicodeScalars where CharacterSet.letters.contains(scalar) {
            if (0x0400...0x04FF).contains(scalar.value) { cyrillic += 1 } else if scalar.isASCII { latin += 1 }
        }
        if cyrillic == 0 && latin == 0 { return nil }
        return cyrillic >= latin ? "ru" : "en"
    }

    static func isCacheable(_ text: String) -> Bool { !text.isEmpty && text.count <= cacheLimit }

    /// A file name for a cached phrase: voice, model and text, hashed. / Имя файла фразы в кэше: хэш голоса, модели и текста.
    static func cacheName(text: String, voiceID: String) -> String {
        let digest = SHA256.hash(data: Data("\(Self.voiceID(voiceID))|\(model)|\(text)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined() + ".mp3"
    }

    static func request(text: String, voiceID: String, key: String) -> URLRequest? {
        guard !key.isEmpty, !text.isEmpty,
              let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(Self.voiceID(voiceID))?output_format=mp3_44100_128"),
              let body = try? JSONSerialization.data(withJSONObject: ["text": spoken(text), "model_id": model]) else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("audio/mpeg", forHTTPHeaderField: "Accept")
        request.httpBody = body
        return request
    }

    /// nil means play the audio. ElevenLabs reports a spent quota as 401 "quota_exceeded".
    /// nil — играть звук. Исчерпанный лимит ElevenLabs приходит как 401 «quota_exceeded».
    static func failure(status: Int, body: Data) -> Failure? {
        if status == 200 { return body.isEmpty ? .audio : nil }
        let text = String(decoding: body.prefix(2000), as: UTF8.self).lowercased()
        if status == 402 || status == 429 || text.contains("quota_exceeded") || text.contains("quota") { return .quota }
        if status == 401 || status == 403 { return .key }
        return .server
    }
}

// MARK: - Memory (Obsidian vault, read-only) / Память (хранилище Obsidian, только чтение)

enum MemoryVault {
    static let defaultsKey = "workshop.memory.vault"
    static let maxFiles = 5000
    static let maxBytes = 400_000

    /// The note without its YAML front matter. / Заметка без YAML-шапки.
    static func body(_ text: String) -> String {
        guard text.hasPrefix("---\n") || text.hasPrefix("---\r\n") else { return text }
        let lines = text.components(separatedBy: "\n")
        guard let end = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else { return text }
        return lines[(end + 1)...].joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    /// `[[link|name]]` → name, `[[link]]` → link: wiki links read as plain words. / Вики-ссылки как обычные слова.
    static func readable(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "!?\\[\\[([^\\]|]+)(?:\\|([^\\]]+))?\\]\\]") else { return text }
        var result = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let whole = Range(match.range, in: result) else { continue }
            let label = Range(match.range(at: 2), in: text).map { String(text[$0]) } ?? Range(match.range(at: 1), in: text).map { String(text[$0]) } ?? ""
            result.replaceSubrange(whole, with: "**" + label + "**")
        }
        return result
    }

    /// obsidian://open?path=… for one note. / Ссылка, открывающая заметку в Obsidian.
    static func obsidianURL(path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        return components.url
    }

    /// Every word of the query must be in the name or the text, any case. / Каждое слово запроса — в имени или тексте.
    static func matches(query: String, name: String, text: String) -> Bool {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return true }
        let haystack = (name + "\n" + text).lowercased()
        return words.allSatisfy { haystack.contains($0) }
    }

    /// Hidden folders (.obsidian, .trash, .git) are skipped. / Скрытые папки пропускаются.
    static func isNote(relativePath: String) -> Bool {
        relativePath.lowercased().hasSuffix(".md") && !relativePath.split(separator: "/").contains { $0.hasPrefix(".") }
    }
}

// MARK: - Explanation views / виды объяснения

/// Topic → a 3D template and trusted video lessons (no API key; played via youtube-nocookie inside the HUD).
/// Тема → 3D-шаблон и проверенные видеоуроки (без ключа; играют через youtube-nocookie внутри HUD).
enum HUDTopic {
    struct Video: Encodable, Equatable { let id: String; let title: String; let channel: String }

    private static let templates: [(template: String, stems: [String])] = [
        ("surface", ["градиент", "спуск", "ошибк", "потер", "loss", "gradient", "оптимиз", "optimiz", "поверхн", "surface", "минимум"]),
        ("vectors", ["вектор", "матриц", "эмбедд", "embedding", "vector", "matrix", "линейн", "linear", "внимани", "attention"]),
        ("function", ["функци", "function", "график", "производн", "derivative", "сигмоид", "sigmoid", "активац", "activation"]),
    ]

    /// Video IDs checked by hand: 3Blue1Brown and Andrej Karpathy. / Видео проверены вручную.
    private static let videos: [(stems: [String], video: Video)] = [
        (["нейросет", "нейрон", "neural", "network"], Video(id: "aircAruvnKk", title: "But what is a neural network?", channel: "3Blue1Brown")),
        (["градиент", "спуск", "gradient", "обучени", "learn"], Video(id: "IHZwWFHWa-w", title: "Gradient descent, how neural networks learn", channel: "3Blue1Brown")),
        (["обратн", "backprop", "распростр"], Video(id: "Ilg3gGewQ5U", title: "What is backpropagation really doing?", channel: "3Blue1Brown")),
        (["трансформ", "transformer", "gpt", "языков", "language model"], Video(id: "wjZofJX0v4M", title: "Transformers, the tech behind LLMs", channel: "3Blue1Brown")),
        (["внимани", "attention"], Video(id: "eMlx5fFNoYc", title: "Attention in transformers, step by step", channel: "3Blue1Brown")),
        (["вектор", "vector", "линейн", "linear"], Video(id: "fNk_zzaMoSs", title: "Vectors | Essence of linear algebra", channel: "3Blue1Brown")),
        (["матриц", "matrix", "преобраз", "transformation"], Video(id: "kYB8IZa5AuE", title: "Linear transformations and matrices", channel: "3Blue1Brown")),
        (["производн", "derivative", "анализ", "calculus"], Video(id: "WUvTyaaNkzM", title: "The essence of calculus", channel: "3Blue1Brown")),
        (["micrograd", "autograd", "обратн", "backprop"], Video(id: "VMj-3S1tku0", title: "The spelled-out intro to neural networks and backpropagation", channel: "Andrej Karpathy")),
        (["gpt", "трансформ", "transformer", "с нуля", "from scratch"], Video(id: "kCc8FmEb1nY", title: "Let's build GPT: from scratch, in code", channel: "Andrej Karpathy")),
        (["токен", "token", "bpe"], Video(id: "zduSFxRajkE", title: "Let's build the GPT Tokenizer", channel: "Andrej Karpathy")),
        (["llm", "языков", "language model", "чат", "chat"], Video(id: "zjkBMFhNj_g", title: "Intro to Large Language Models", channel: "Andrej Karpathy")),
    ]

    private static func lowered(_ text: String) -> String { text.lowercased().replacingOccurrences(of: "ё", with: "е") }

    static func template(for question: String) -> String {
        let text = lowered(question)
        return templates.first { $0.stems.contains { text.contains($0) } }?.template ?? ""
    }

    static func videos(for question: String, limit: Int = 4) -> [Video] {
        let text = lowered(question)
        var found: [Video] = []
        for entry in videos where entry.stems.contains(where: { text.contains($0) }) && !found.contains(entry.video) {
            found.append(entry.video)
        }
        return Array(found.prefix(limit))
    }

    static func video(_ id: String) -> Video? { videos.first { $0.video.id == id }?.video }

    /// The embed address; only these IDs, nothing from the model. / Адрес встраивания; только эти ID, ничего от модели.
    static func embedURL(_ id: String) -> URL? {
        guard videos.contains(where: { $0.video.id == id }) else { return nil }
        return URL(string: "https://www.youtube-nocookie.com/embed/\(id)?autoplay=1&rel=0")
    }

    /// The best lesson by shared word stems (5 letters), at least one match. / Лучший урок по общим основам слов.
    static func bestMatch(question: String, names: [(id: String, name: String)]) -> String? {
        func stems(_ text: String) -> Set<String> {
            Set(lowered(text).split(whereSeparator: { !$0.isLetter }).filter { $0.count >= 4 }.map { String($0.prefix(5)) })
        }
        let asked = stems(question)
        let scored = names.map { ($0.id, stems($0.name).intersection(asked).count) }.filter { $0.1 > 0 }
        return scored.max { $0.1 < $1.1 }?.0
    }
}

struct HUDExplainInfo: Encodable, Equatable {
    var template: String
    var lesson: String
    var videos: [HUDTopic.Video]
}
