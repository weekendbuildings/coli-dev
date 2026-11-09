import Foundation

// Logic of the Creator's workshop without SwiftUI, checked by scripts/verify_workshop.swift:
// assistant actions and the confirmation rule, agent commands, live processes, the ~/Творец folder
// with mentor rules, the voice route and text for speaking.
// Логика Мастерской Творца без SwiftUI, её проверяет scripts/verify_workshop.swift:
// действия ассистента и правило подтверждения, команды агентов, живые процессы, папка ~/Творец
// с правилами наставника, маршрут голоса и текст для озвучки.

// MARK: - Actions / Действия

enum WorkshopTool: String, CaseIterable {
    case openApp = "open_app"
    case open
    case findFiles = "find_files"
    case writeNote = "write_note"
    case runCheck = "run_check"
    case shell
}

/// One action the assistant proposed in an ```action block. / Действие, предложенное ассистентом в блоке ```action.
struct WorkshopAction: Identifiable, Equatable {
    let id = UUID()
    let tool: WorkshopTool
    let arguments: [String: String]

    func argument(_ name: String) -> String {
        (arguments[name] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The exact thing that will run, shown before confirmation. / Что именно выполнится — показывается до подтверждения.
    var exactCommand: String {
        switch tool {
        case .openApp: return "open -a " + ToolLaunch.shellQuoted(argument("app"))
        case .open: return "open " + ToolLaunch.shellQuoted(argument("target"))
        case .findFiles: return "mdfind -onlyin ~ " + ToolLaunch.shellQuoted(argument("query"))
        case .writeNote: return "Obsidian: \(WorkshopNotes.path(title: argument("title"), date: Date()))"
        case .runCheck: return "python3 check_\(argument("lab")).py"
        case .shell: return argument("command")
        }
    }

    static func == (lhs: WorkshopAction, rhs: WorkshopAction) -> Bool {
        lhs.tool == rhs.tool && lhs.arguments == rhs.arguments
    }
}

enum WorkshopActionParser {
    static let maxActions = 3

    /// Splits a reply into the text to show and the proposed actions; broken blocks are dropped.
    /// Делит ответ на текст и предложенные действия; испорченные блоки отбрасываются.
    static func split(_ reply: String) -> (text: String, actions: [WorkshopAction]) {
        var kept: [String] = []
        var actions: [WorkshopAction] = []
        var block: [String]?
        for line in reply.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if block == nil, trimmed.lowercased() == "```action" {
                block = []
            } else if var current = block {
                if trimmed == "```" {
                    if actions.count < maxActions, let action = parse(json: current.joined(separator: "\n")) {
                        actions.append(action)
                    }
                    block = nil
                } else {
                    current.append(line)
                    block = current
                }
            } else {
                kept.append(line)
            }
        }
        let text = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return (text, actions)
    }

    static func parse(json: String) -> WorkshopAction? {
        guard let data = json.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["tool"] as? String,
              let tool = WorkshopTool(rawValue: name) else { return nil }
        var arguments: [String: String] = [:]
        for (key, value) in object where key != "tool" {
            if let text = value as? String { arguments[key] = text }
            else if let number = value as? NSNumber { arguments[key] = number.stringValue }
        }
        let action = WorkshopAction(tool: tool, arguments: arguments)
        let required: String
        switch tool {
        case .openApp: required = "app"
        case .open: required = "target"
        case .findFiles: required = "query"
        case .writeNote: required = "text"
        case .runCheck: required = "lab"
        case .shell: required = "command"
        }
        return action.argument(required).isEmpty ? nil : action
    }
}

// MARK: - Confirmation rule / Правило подтверждения

enum WorkshopRisk: Equatable {
    /// Read-only or opening things: runs at once. / Только чтение или открытие: выполняется сразу.
    case safe
    /// May delete, overwrite, send, install or change settings: only after "yes". / Может навредить: только после «да».
    case confirm(String)
    /// `sudo`: after "yes", and macOS asks the owner for the password itself. / После «да», пароль спрашивает macOS.
    case admin

    var needsConfirmation: Bool { self != .safe }
    /// The L10n key of the reason. / Ключ причины в L10n.
    var reasonKey: String {
        switch self {
        case .safe: return "workshop.risk.safe"
        case .confirm(let key): return key
        case .admin: return "workshop.risk.sudo"
        }
    }
}

enum WorkshopSafety {
    /// Commands that only read or show things, when used without the flags below.
    /// Команды, которые только читают или показывают, если нет флагов ниже.
    static let readOnlyCommands: Set<String> = [
        "ls", "pwd", "cat", "head", "tail", "wc", "grep", "egrep", "rg", "find", "mdfind", "mdls", "which", "whereis",
        "whoami", "date", "cal", "echo", "printf", "df", "du", "uptime", "sw_vers", "uname", "file", "stat", "tree",
        "sort", "uniq", "cut", "diff", "basename", "dirname", "realpath", "hostname", "id", "ps", "vm_stat",
        "system_profiler", "type",
    ]
    /// Subcommands that only read. / Подкоманды, которые только читают.
    static let readOnlySubcommands: [String: Set<String>] = [
        "git": ["status", "log", "diff", "show", "branch", "remote", "blame", "shortlog", "describe", "rev-parse"],
        "ollama": ["list", "ps", "show"],
        "brew": ["list", "info", "search", "outdated", "deps", "config", "doctor"],
        "pip3": ["list", "show", "freeze"],
        "pip": ["list", "show", "freeze"],
        "npm": ["ls", "list", "view", "outdated"],
        "python3": ["--version", "-V"],
        "node": ["--version", "-v"],
    ]
    /// Flags that turn a read-only command into a writing one. / Флаги, с которыми команда начинает писать или удалять.
    static let writingFlags: Set<String> = ["-delete", "-exec", "-execdir", "-ok", "-okdir", "-fprint", "-fprintf", "-fls",
                                            "-d", "-D", "--delete", "-m", "-M", "--move", "--set-upstream-to", "-u"]
    /// Files that run, install or reconfigure something when opened. / Файлы, которые при открытии запускают или ставят что-то.
    static let runnableExtensions: Set<String> = ["app", "pkg", "mpkg", "dmg", "command", "sh", "zsh", "bash", "tool",
                                                  "terminal", "workflow", "scpt", "applescript", "scptd", "mobileconfig",
                                                  "prefpane", "kext", "py", "rb", "pl", "jar", "action", "osax"]

    static func risk(of action: WorkshopAction) -> WorkshopRisk {
        switch action.tool {
        case .openApp, .findFiles, .runCheck:
            return .safe
        case .writeNote:
            // Always a new note with a unique name: nothing is overwritten. / Всегда новая заметка: ничего не перезаписывается.
            return .safe
        case .open:
            return openRisk(action.argument("target"))
        case .shell:
            return shellRisk(action.argument("command"))
        }
    }

    static func openRisk(_ target: String) -> WorkshopRisk {
        let lower = target.lowercased()
        if lower.hasPrefix("https://") || lower.hasPrefix("http://") { return .safe }
        if lower.contains("://") || lower.hasPrefix("mailto:") || lower.hasPrefix("tel:") || lower.hasPrefix("sms:") {
            return .confirm("workshop.risk.scheme")
        }
        let ext = (target as NSString).pathExtension.lowercased()
        return runnableExtensions.contains(ext) ? .confirm("workshop.risk.runnable") : .safe
    }

    /// Allow-list: anything not known to be read-only needs "yes". / Белый список: всё, что не точно безопасно, — после «да».
    static func shellRisk(_ command: String) -> WorkshopRisk {
        let text = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return .confirm("workshop.risk.unknown") }
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ";|&()"))).filter { !$0.isEmpty }
        if words.contains(where: { $0 == "sudo" || $0 == "doas" || $0 == "su" }) { return .admin }
        // Redirection, chaining, substitution and background jobs. / Перенаправление, цепочки, подстановки, фон.
        for marker in [">", "<", ";", "&", "`", "$(", "\n", "\\"] where text.contains(marker) {
            return .confirm("workshop.risk.compound")
        }
        for segment in text.components(separatedBy: "|") {
            guard segmentIsReadOnly(segment) else { return .confirm("workshop.risk.unknown") }
        }
        return .safe
    }

    private static func segmentIsReadOnly(_ segment: String) -> Bool {
        let words = segment.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard let first = words.first else { return false }
        let name = (first as NSString).lastPathComponent
        if words.dropFirst().contains(where: { writingFlags.contains($0) }) { return false }
        if readOnlyCommands.contains(name) { return true }
        guard let allowed = readOnlySubcommands[name], words.count >= 2 else { return false }
        return allowed.contains(words[1])
    }

    /// The rule itself: a risky action never runs without the owner's "yes".
    /// Само правило: рискованное действие без «да» владельца не выполняется.
    static func mayRun(_ action: WorkshopAction, confirmed: Bool) -> Bool {
        !risk(of: action).needsConfirmation || confirmed
    }
}

/// `sudo` goes through the macOS password window; the app never sees the password.
/// `sudo` идёт через системное окно пароля; приложение пароль не видит.
enum WorkshopAdmin {
    /// AppleScript for `do shell script … with administrator privileges`, or nil if `sudo` is not at the start.
    /// AppleScript для запуска с правами администратора или nil, если `sudo` не в начале.
    static func appleScript(for command: String) -> String? {
        let text = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.hasPrefix("sudo ") else { return nil }
        var rest = String(text.dropFirst(5)).trimmingCharacters(in: .whitespaces)
        // sudo's own flags (-k, -S …) make no sense here. / Флаги самого sudo тут не нужны.
        while rest.hasPrefix("-") {
            guard let space = rest.firstIndex(of: " ") else { return nil }
            rest = String(rest[space...]).trimmingCharacters(in: .whitespaces)
        }
        guard !rest.isEmpty, !rest.split(separator: " ").contains("sudo") else { return nil }
        let escaped = rest.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }
}

// MARK: - Executor / Исполнитель

/// What the executor may touch; tests replace it with a spy. / С чем работает исполнитель; в тестах подменяется.
protocol WorkshopSystem {
    func openApplication(_ name: String) -> Bool
    func open(_ target: String) -> Bool
    func run(_ executable: String, _ arguments: [String], directory: URL) async -> (status: Int32, output: String)
    func runAdmin(_ appleScript: String) async -> (ok: Bool, output: String)
    func writeNote(path: String, text: String) async -> Bool
    func runCheck(lab: String) async -> (ok: Bool, output: String)
}

enum WorkshopOutcome: Equatable {
    case done(String)
    case failed(String)
    /// Not run: the owner has not said "yes" yet. / Не выполнено: владелец ещё не сказал «да».
    case needsConfirmation(WorkshopRisk)
}

struct WorkshopExecutor {
    let system: WorkshopSystem
    let workFolder: URL

    func execute(_ action: WorkshopAction, confirmed: Bool) async -> WorkshopOutcome {
        let risk = WorkshopSafety.risk(of: action)
        guard WorkshopSafety.mayRun(action, confirmed: confirmed) else { return .needsConfirmation(risk) }
        switch action.tool {
        case .openApp:
            return system.openApplication(action.argument("app")) ? .done(action.argument("app")) : .failed(action.argument("app"))
        case .open:
            let target = (action.argument("target") as NSString).expandingTildeInPath
            return system.open(target) ? .done(target) : .failed(target)
        case .findFiles:
            let result = await system.run("/usr/bin/mdfind", ["-onlyin", NSHomeDirectory(), action.argument("query")], directory: workFolder)
            let lines = result.output.split(separator: "\n").prefix(30).map(String.init)
            return result.status == 0 ? .done(lines.joined(separator: "\n")) : .failed(result.output)
        case .writeNote:
            let path = WorkshopNotes.path(title: action.argument("title"), date: Date())
            let note = WorkshopNotes.markdown(title: action.argument("title"), text: action.argument("text"), date: Date())
            return await system.writeNote(path: path, text: note) ? .done(path) : .failed(path)
        case .runCheck:
            let result = await system.runCheck(lab: action.argument("lab"))
            return result.ok ? .done(result.output) : .failed(result.output)
        case .shell:
            let command = action.argument("command")
            if risk == .admin {
                guard let script = WorkshopAdmin.appleScript(for: command) else { return .failed("sudo") }
                let result = await system.runAdmin(script)
                return result.ok ? .done(result.output) : .failed(result.output)
            }
            let result = await system.run("/bin/zsh", ["-lc", command], directory: workFolder)
            return result.status == 0 ? .done(result.output) : .failed(result.output)
        }
    }
}

enum WorkshopNotes {
    static func path(title: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = AssistantObsidianNote.safeName(title.isEmpty ? "note" : title)
        return "Творец/Заметки/\(name)-\(formatter.string(from: date)).md"
    }

    static func markdown(title: String, text: String, date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return "# \(title.isEmpty ? "Заметка" : title)\n\n- date: \(formatter.string(from: date))\n\n\(text)\n"
    }
}

// MARK: - Agents / Агенты

struct WorkshopAgentCommand: Equatable {
    let executable: String
    let arguments: [String]
    let directory: URL
    /// No non-interactive mode: opens in Terminal. / Нет неинтерактивного режима: открывается в Терминале.
    let interactive: Bool
}

enum WorkshopAgent: String, CaseIterable, Identifiable {
    case claude, opencode, hermes, openclaw, freebuff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .claude: return "Claude Code"
        case .opencode: return "OpenCode"
        case .hermes: return "Hermes"
        case .openclaw: return "OpenClaw"
        case .freebuff: return "FreeBuff"
        }
    }

    func candidates(home: String) -> [String] {
        switch self {
        case .claude: return ["\(home)/.local/bin/claude", "/opt/homebrew/bin/claude", "/usr/local/bin/claude"]
        case .opencode: return ToolLaunch.openCodeCandidates() + ["/usr/local/bin/opencode", "\(home)/.opencode/bin/opencode"]
        case .hermes: return ToolLaunch.hermesCandidates(home: home) + ["/opt/homebrew/bin/hermes"]
        case .openclaw: return ToolLaunch.openClawCandidates(home: home)
        case .freebuff: return ["/opt/homebrew/bin/freebuff", "/usr/local/bin/freebuff", "\(home)/.npm-global/bin/freebuff"]
        }
    }

    /// FreeBuff has no one-shot mode in `freebuff --help` (0.2.x): only its own terminal UI.
    /// У FreeBuff нет разового режима в `freebuff --help` (0.2.x): только свой экран в Терминале.
    var runsNonInteractively: Bool { self != .freebuff }

    /// Arguments checked against each tool's `--help` on 2026-11-08; no auto-approval flags.
    /// Аргументы сверены с `--help` каждого на 2026-11-08; без флагов автоодобрения.
    func arguments(task: String, directory: URL, sessionID: String) -> [String] {
        switch self {
        case .claude: return ["-p", task, "--output-format", "stream-json", "--verbose"]
        case .opencode: return ["run", task]
        case .hermes: return ["-z", task]
        case .openclaw: return ["agent", "--local", "--session-id", sessionID, "-m", task]
        case .freebuff: return ["--cwd", directory.path]
        }
    }
}

enum WorkshopAgents {
    /// Flags that approve dangerous steps on their own; never passed. / Флаги автоодобрения; никогда не передаются.
    static let forbiddenFlags: [String] = ["--auto", "--yolo", "--dangerously-skip-permissions", "--accept-hooks",
                                           "--trust-agents", "--allow-dangerously-skip-permissions"]

    static func isForbidden(_ argument: String) -> Bool {
        forbiddenFlags.contains(argument) || argument.hasPrefix("--dangerously")
            || argument == "--permission-mode=bypassPermissions" || argument == "bypassPermissions"
    }

    /// The task with a reminder to read the mentor rules first (OpenClaw reads AGENTS.md only from its own workspace).
    /// Задача с напоминанием сначала прочитать правила (OpenClaw читает AGENTS.md только из своей рабочей папки).
    static func task(_ text: String, directory: URL, root: URL, russian: Bool) -> String {
        let rules = root.appendingPathComponent("AGENTS.md").path
        let lead = russian
            ? "Работай только в папке \(directory.path). Сначала прочитай правила \(rules) и следуй им: ты наставник, а не исполнитель."
            : "Work only in the folder \(directory.path). First read the rules in \(rules) and follow them: you are a mentor, not a doer."
        return lead + "\n\n" + text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The folder must be ~/Творец or inside it (symlinks resolved). / Папка — ~/Творец или внутри неё.
    static func isInside(_ folder: URL, root: URL) -> Bool {
        let base = root.standardizedFileURL.resolvingSymlinksInPath().path
        let path = folder.standardizedFileURL.resolvingSymlinksInPath().path
        return path == base || path.hasPrefix(base + "/")
    }

    static func command(for agent: WorkshopAgent, task: String, directory: URL, root: URL, home: String,
                        sessionID: String = "colidev-" + UUID().uuidString.lowercased(),
                        isExecutable: (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }) -> WorkshopAgentCommand? {
        guard isInside(directory, root: root),
              let executable = ToolLaunch.firstExecutable(in: agent.candidates(home: home), isExecutable: isExecutable) else { return nil }
        let arguments = agent.arguments(task: task, directory: directory, sessionID: sessionID)
        guard !arguments.contains(where: isForbidden) else { return nil }
        return WorkshopAgentCommand(executable: executable, arguments: arguments, directory: directory,
                                    interactive: !agent.runsNonInteractively)
    }

    /// Environment for agents started from Finder: Homebrew and ~/.local/bin on PATH, no colours,
    /// and no ANTHROPIC_* / CLAUDE_CODE_* so Claude uses the owner's subscription login.
    /// Окружение агентов: PATH с Homebrew и ~/.local/bin, без цветов и без ANTHROPIC_* / CLAUDE_CODE_*.
    static func environment(base: [String: String], home: String) -> [String: String] {
        var environment = base.filter { key, _ in
            !key.hasPrefix("ANTHROPIC_") && !key.hasPrefix("CLAUDE_CODE_") && key != "CLAUDECODE"
        }
        let extra = ["/opt/homebrew/bin", "/usr/local/bin", "\(home)/.local/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        let existing = (base["PATH"] ?? "").split(separator: ":").map(String.init)
        var seen = Set<String>()
        environment["PATH"] = (extra + existing).filter { seen.insert($0).inserted }.joined(separator: ":")
        environment["NO_COLOR"] = "1"
        environment["FORCE_COLOR"] = "0"
        environment["TERM"] = "dumb"
        return environment
    }
}

/// Turns raw agent output into readable lines. / Делает вывод агентов читаемым.
enum AgentOutputText {
    /// Removes ANSI colour and cursor codes; `\r` becomes a new line. / Убирает ANSI-коды; `\r` → новая строка.
    static func clean(_ text: String) -> String {
        var result = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        for pattern in ["\u{1B}\\][^\u{07}\u{1B}]*(\u{07}|\u{1B}\\\\)", "\u{1B}\\[[0-9;?]*[ -/]*[@-~]", "\u{1B}[()][A-Z0-9]", "\u{1B}[=>]"] {
            result = result.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
        }
        return result
    }

    /// One line of `claude -p --output-format stream-json`; nil means nothing to show.
    /// Одна строка потока Claude; nil — показывать нечего.
    static func claudeLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("{"), let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            return trimmed.isEmpty ? nil : line
        }
        switch type {
        case "system":
            guard (object["subtype"] as? String) == "init" else { return nil }
            return "▸ Claude Code · \(object["model"] as? String ?? "?")"
        case "assistant":
            guard let message = object["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else { return nil }
            let parts: [String] = content.compactMap { block in
                switch block["type"] as? String {
                case "text": return block["text"] as? String
                case "tool_use":
                    let input = block["input"] as? [String: Any] ?? [:]
                    let detail = (input["file_path"] ?? input["command"] ?? input["pattern"] ?? input["path"]) as? String ?? ""
                    return "▸ \(block["name"] as? String ?? "tool") \(detail)".trimmingCharacters(in: .whitespaces)
                default: return nil
                }
            }
            return parts.isEmpty ? nil : parts.joined(separator: "\n")
        case "result":
            if (object["is_error"] as? Bool) == true { return "✗ " + (object["result"] as? String ?? "error") }
            return "■"
        default:
            return nil
        }
    }
}

/// Collects bytes and gives back whole UTF-8 text and whole lines. / Собирает байты в целый UTF-8 текст и строки.
struct LiveTextBuffer {
    private var pending = Data()
    private var partialLine = ""

    /// Decodes as much as forms valid UTF-8; an unfinished letter waits for the next chunk.
    /// Декодирует целые буквы; недописанная буква ждёт следующего куска.
    mutating func append(_ data: Data) -> String {
        pending.append(data)
        for cut in 0...min(3, pending.count) {
            let end = pending.count - cut
            if let text = String(data: pending.prefix(end), encoding: .utf8) {
                pending = Data(pending.suffix(cut))
                return text
            }
        }
        // Not UTF-8 at all: show it lossily rather than block. / Совсем не UTF-8: показываем как есть.
        let text = String(decoding: pending, as: UTF8.self)
        pending = Data()
        return text
    }

    /// Whole lines from the text; the unfinished end is kept. / Целые строки; незаконченный конец хранится.
    mutating func lines(from text: String) -> [String] {
        let joined = partialLine + text
        var parts = joined.components(separatedBy: "\n")
        partialLine = parts.removeLast()
        return parts
    }

    mutating func flushLine() -> String? {
        defer { partialLine = "" }
        return partialLine.isEmpty ? nil : partialLine
    }
}

/// Runs one process with live output, a stop button and an output limit.
/// Запускает один процесс с живым выводом, кнопкой «Остановить» и пределом вывода.
final class LiveProcess {
    struct Ending: Equatable {
        let status: Int32?
        let stopped: Bool
        let timedOut: Bool
        let failedToStart: String?
        var succeeded: Bool { status == 0 && !stopped && !timedOut && failedToStart == nil }
    }

    static let outputLimit = 512_000

    private let lock = NSLock()
    private var process: Process?
    private var stopped = false
    private var timedOut = false

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return process != nil
    }

    /// Starts the process; `onOutput` and `onExit` are called on a background queue.
    /// Запускает процесс; обратные вызовы приходят в фоновой очереди.
    func start(executable: String, arguments: [String], directory: URL, environment: [String: String],
               timeout: TimeInterval?, onOutput: @escaping (String) -> Void, onExit: @escaping (Ending) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        var buffer = LiveTextBuffer()
        var used = 0
        let queue = DispatchQueue(label: "colidev.workshop.process")
        let group = DispatchGroup()
        group.enter()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            queue.sync {
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    group.leave()
                    return
                }
                guard used < Self.outputLimit else { return }
                used += data.count
                let text = buffer.append(data)
                if !text.isEmpty { onOutput(text) }
            }
        }
        lock.lock()
        stopped = false
        timedOut = false
        self.process = process
        lock.unlock()
        group.enter()
        process.terminationHandler = { _ in group.leave() }
        do {
            try process.run()
        } catch {
            pipe.fileHandleForReading.readabilityHandler = nil
            lock.lock(); self.process = nil; lock.unlock()
            onExit(Ending(status: nil, stopped: false, timedOut: false, failedToStart: error.localizedDescription))
            return
        }
        if let timeout {
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let same = self.process === process
                if same { self.timedOut = true }
                self.lock.unlock()
                if same { Self.killTree(process.processIdentifier) }
            }
        }
        group.notify(queue: .global()) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let ending = Ending(status: process.terminationStatus, stopped: self.stopped, timedOut: self.timedOut, failedToStart: nil)
            if self.process === process { self.process = nil }
            self.lock.unlock()
            if used >= Self.outputLimit { onOutput("\n…") }
            onExit(ending)
        }
    }

    func stop() {
        lock.lock()
        let running = process
        if running != nil { stopped = true }
        lock.unlock()
        guard let running, running.isRunning else { return }
        Self.killTree(running.processIdentifier)
    }

    /// Agents start node and shell children: stop them too, then the process itself.
    /// Агенты запускают дочерние процессы: останавливаем и их, затем сам процесс.
    static func killTree(_ pid: pid_t) {
        let children = childProcesses(of: pid)
        kill(pid, SIGTERM)
        for child in children { killTree(child) }
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            for child in children { kill(child, SIGKILL) }
            kill(pid, SIGKILL)
        }
    }

    static func childProcesses(of pid: pid_t) -> [pid_t] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-P", String(pid)]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self).split(separator: "\n").compactMap { pid_t($0.trimmingCharacters(in: .whitespaces)) }
    }
}

// MARK: - The ~/Творец folder / Папка ~/Творец

enum CreatorWorkspace {
    static let folderName = "Творец"
    static let environmentKey = "COLIDEV_CREATOR_DIR"
    static let extraFolders = ["Практика", "Проекты", "Статьи"]
    /// Files the agents read: OpenCode, Hermes and FreeBuff read AGENTS.md, Claude Code reads CLAUDE.md,
    /// FreeBuff also reads knowledge.md (names found in each tool's docs and binary on 2026-11-08).
    /// Файлы, которые читают агенты (сверено с документацией и программами на 2026-11-08).
    static let ruleFiles = ["AGENTS.md", "CLAUDE.md", "knowledge.md"]

    static func root(environment: [String: String], home: URL) -> URL {
        if let custom = environment[environmentKey], !custom.isEmpty { return URL(fileURLWithPath: custom, isDirectory: true) }
        return home.appendingPathComponent(folderName, isDirectory: true)
    }

    /// "01 Python" … "10 …": one folder per path module. / По папке на модуль пути.
    static func moduleFolderName(number: Int, title: String) -> String {
        let clean = title.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: " ")
        return String(format: "%02d ", number) + clean.trimmingCharacters(in: .whitespaces)
    }

    static func folderNames(moduleTitles: [(Int, String)]) -> [String] {
        moduleTitles.map { moduleFolderName(number: $0.0, title: $0.1) } + extraFolders
    }

    /// Creates what is missing; rule files the owner already has are never overwritten.
    /// Создаёт недостающее; уже существующие файлы правил не перезаписывает.
    @discardableResult
    static func prepare(root: URL, moduleTitles: [(Int, String)], fileManager: FileManager = .default) throws -> [String] {
        var created: [String] = []
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        for name in folderNames(moduleTitles: moduleTitles) {
            let url = root.appendingPathComponent(name, isDirectory: true)
            if !fileManager.fileExists(atPath: url.path) {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                created.append(name + "/")
            }
        }
        let text = rulesMarkdown(folders: folderNames(moduleTitles: moduleTitles))
        for name in ruleFiles {
            let url = root.appendingPathComponent(name)
            if !fileManager.fileExists(atPath: url.path) {
                try Data(text.utf8).write(to: url, options: .withoutOverwriting)
                created.append(name)
            }
        }
        return created
    }

    static func rulesMarkdown(folders: [String]) -> String {
        """
        # Правила мастерской «Творец» / Creator workshop rules

        Этот файл создало приложение «Творец». Его читают OpenCode, Hermes, FreeBuff (AGENTS.md, knowledge.md) \
        и Claude Code (CLAUDE.md). Правь его здесь — приложение не перезаписывает его.
        This file was created by the Creator app. Edit it here: the app never overwrites it.

        ## Кто ты / Who you are

        Ты — наставник Творца, а не исполнитель. Владелец учится создавать ИИ: Python → математика → \
        машинное обучение → своя языковая модель → AGI → сознание. Цель — чтобы он понял и умел сам.
        You are the Creator's mentor, not a doer. The owner is learning to build AI; the goal is that they \
        understand and can do it themselves.

        ## Как помогать / How to help

        1. Объясняй простыми словами, по-русски, коротко и с примером.
        2. Задавай вопросы, которые ведут к ответу, а не сразу давай ответ.
        3. Проверяй код и рассуждения ученика: найди ошибку, объясни почему, подскажи направление.
        4. В заданиях «Собери и проверь сам» (`Практика/`, `~/ai-path/creator_labs`) и в задачах Skillbox \
        **не пиши ключевой шаг за ученика**: места `TODO` заполняет он сам. Можно: подсказка, наводящий \
        вопрос, пример на другой задаче, разбор ошибки, запуск проверки.
        5. Если ученик просит готовое решение такого задания, напомни это правило и дай подсказку следующего уровня.
        6. В `Проекты/` и `Статьи/` можно писать код и текст вместе с ним, но объясняй каждый шаг.

        1. Explain plainly and briefly, with an example. 2. Ask leading questions. 3. Check the learner's \
        code and reasoning. 4. In build-and-check-it-yourself labs and Skillbox tasks **never write the key \
        step for the learner**: the `TODO` parts are theirs. 5. If asked for a finished solution, remind them \
        of this rule and give the next hint. 6. In `Проекты/` and `Статьи/` you may write together, explaining each step.

        ## Безопасность / Safety

        - Работай только внутри этой папки. Work only inside this folder.
        - Ничего не удаляй и не перезаписывай без явного «да» владельца. Never delete or overwrite without the owner's "yes".
        - Ничего не устанавливай, не отправляй и не меняй настройки без явного согласия. No installs, sending or settings changes without consent.
        - Не используй `sudo`, не читай и не показывай ключи и пароли. No `sudo`; never read or show keys and passwords.
        - Не выдумывай факты и ссылки; если не уверен — так и скажи. Do not invent facts or links.

        ## Папки / Folders

        \(folders.map { "- `\($0)/`" }.joined(separator: "\n"))

        """
    }
}

// MARK: - Voice route / Маршрут голоса

enum VoicePermission: Equatable { case granted, denied, undetermined }

/// What the Mac offers for voice right now. / Что Mac сейчас даёт для голоса.
struct VoiceEnvironment: Equatable {
    var hasMicrophone: Bool
    var microphone: VoicePermission
    var speech: VoicePermission
    /// macOS 26+ SpeechAnalyzer supports the language and its model is installed. / SpeechAnalyzer готов для языка.
    var analyzerReady: Bool
    /// SpeechAnalyzer supports the language, but Apple's model is not downloaded yet. / Модель Apple ещё не скачана.
    var analyzerNeedsDownload: Bool
    /// SFSpeechRecognizer can work fully on this device for the language. / SFSpeechRecognizer работает на устройстве.
    var onDeviceRecognizer: Bool
}

enum VoiceProblem: String, Equatable {
    case noMicrophone, microphoneDenied, speechDenied, languageNotOnDevice
    var key: String { "workshop.voice.problem.\(rawValue)" }
}

enum VoiceRoute: Equatable {
    case speechAnalyzer
    case onDeviceRecognizer
    case unavailable(VoiceProblem)

    /// Never sends audio off the Mac: no server recognition, no Whisper.
    /// Звук не уходит с Mac: без серверного распознавания и без Whisper.
    static func decide(_ environment: VoiceEnvironment) -> VoiceRoute {
        guard environment.hasMicrophone else { return .unavailable(.noMicrophone) }
        if environment.microphone == .denied { return .unavailable(.microphoneDenied) }
        if environment.speech == .denied { return .unavailable(.speechDenied) }
        if environment.analyzerReady { return .speechAnalyzer }
        if environment.onDeviceRecognizer { return .onDeviceRecognizer }
        return .unavailable(.languageNotOnDevice)
    }
}

/// Text for the speech synthesizer: no code, no action blocks, no Markdown marks.
/// Текст для озвучки: без кода, блоков действий и значков Markdown.
enum SpokenText {
    static let maxCharacters = 900

    static func from(markdown: String, codeWord: String) -> String {
        var lines: [String] = []
        var inCode = false
        var codeAnnounced = false
        for line in markdown.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                inCode.toggle()
                if inCode, !codeAnnounced { lines.append(codeWord); codeAnnounced = true }
                continue
            }
            if inCode { continue }
            lines.append(line)
        }
        var text = lines.joined(separator: " ")
        text = text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "https?://\\S+", with: "", options: .regularExpression)
        for mark in ["**", "__", "`", "#", "*", ">", "|"] { text = text.replacingOccurrences(of: mark, with: " ") }
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
        guard text.count > maxCharacters else { return text }
        let cut = String(text.prefix(maxCharacters))
        if let end = cut.lastIndex(where: { ".!?…".contains($0) }) { return String(cut[...end]) }
        return cut + "…"
    }
}
