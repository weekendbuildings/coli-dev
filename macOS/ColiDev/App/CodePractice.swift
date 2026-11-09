import Foundation

// Plain logic of the "Practice" code editor, kept free of SwiftUI and AppKit so `scripts/verify_code_practice.swift`
// can check it: Python highlighting, running python3, reading tracebacks and the ✓/✗ lines of the lab checks.
// Простая логика редактора «Практика» без SwiftUI и AppKit, чтобы её проверял `scripts/verify_code_practice.swift`:
// подсветка Python, запуск python3, разбор ошибок и строк ✓/✗ проверок «Собери и проверь сам».

// MARK: - Highlighting / Подсветка

enum PythonTokenKind: String, CaseIterable {
    case keyword, builtin, string, comment, number, definition, decorator
}

/// A coloured piece of the source. The range is in UTF-16 units, as NSTextView counts them.
/// Окрашенный кусок текста. Диапазон в единицах UTF-16, как их считает NSTextView.
struct PythonToken: Equatable {
    let kind: PythonTokenKind
    let range: NSRange
}

/// A small hand-written tokenizer: enough for colours, never fails on broken code.
/// Небольшой собственный разборщик: его хватает для цвета, на сломанном коде он не падает.
enum PythonHighlighter {
    /// Hard keywords of Python 3. `match` and `case` are soft keywords and often variable names, so they stay plain.
    /// Ключевые слова Python 3. `match` и `case` — мягкие, это часто имена переменных, поэтому без цвета.
    static let keywords: Set<String> = [
        "False", "None", "True", "and", "as", "assert", "async", "await", "break", "class", "continue", "def",
        "del", "elif", "else", "except", "finally", "for", "from", "global", "if", "import", "in", "is", "lambda",
        "nonlocal", "not", "or", "pass", "raise", "return", "try", "while", "with", "yield"
    ]

    static let builtins: Set<String> = [
        "self", "cls", "print", "len", "range", "int", "float", "str", "bool", "list", "dict", "set", "tuple",
        "abs", "min", "max", "sum", "round", "sorted", "reversed", "enumerate", "zip", "map", "filter", "any", "all",
        "isinstance", "type", "super", "open", "input", "iter", "next", "pow", "divmod", "repr", "format", "hash",
        "id", "chr", "ord", "hasattr", "getattr", "setattr", "object", "property", "staticmethod", "classmethod",
        "Exception", "ValueError", "TypeError", "KeyError", "IndexError", "ZeroDivisionError", "NotImplementedError",
        "RuntimeError", "AssertionError", "StopIteration", "NameError", "AttributeError"
    ]

    private static let stringPrefixes: Set<String> = [
        "r", "u", "b", "f", "br", "rb", "fr", "rf"
    ]

    static func tokens(_ source: String) -> [PythonToken] {
        let units = Array(source.utf16)
        let count = units.count
        var result: [PythonToken] = []
        var index = 0
        var previousWord = ""
        var lineHasCode = false

        func unit(_ offset: Int) -> UInt16? { offset < count ? units[offset] : nil }
        func add(_ kind: PythonTokenKind, _ start: Int, _ end: Int) {
            if end > start { result.append(PythonToken(kind: kind, range: NSRange(location: start, length: end - start))) }
        }

        /// Scans a string from its opening quote; returns the index after the closing quote.
        /// Читает строку от открывающей кавычки; возвращает место после закрывающей.
        func scanString(from quoteIndex: Int) -> Int {
            let quote = units[quoteIndex]
            let triple = unit(quoteIndex + 1) == quote && unit(quoteIndex + 2) == quote
            var position = quoteIndex + (triple ? 3 : 1)
            while position < count {
                let current = units[position]
                if current == Char.backslash {
                    position += 2
                    continue
                }
                if triple {
                    if current == quote && unit(position + 1) == quote && unit(position + 2) == quote { return position + 3 }
                } else {
                    if current == quote { return position + 1 }
                    if current == Char.newline { return position }  // an unclosed string stops at the line end
                }
                position += 1
            }
            return count
        }

        while index < count {
            let current = units[index]
            if current == Char.newline {
                lineHasCode = false
                index += 1
                continue
            }
            if current == Char.space || current == Char.tab || current == Char.carriageReturn {
                index += 1
                continue
            }
            if current == Char.hash {
                var end = index
                while end < count && units[end] != Char.newline { end += 1 }
                add(.comment, index, end)
                index = end
                continue
            }
            if current == Char.quote || current == Char.apostrophe {
                let end = min(scanString(from: index), count)
                add(.string, index, end)
                index = end
                previousWord = ""
                lineHasCode = true
                continue
            }
            if current == Char.at && !lineHasCode, let next = unit(index + 1), Char.isIdentifierStart(next) {
                var end = index + 1
                while end < count && (Char.isIdentifierPart(units[end]) || units[end] == Char.dot) { end += 1 }
                add(.decorator, index, end)
                index = end
                lineHasCode = true
                continue
            }
            if Char.isDigit(current) || (current == Char.dot && unit(index + 1).map(Char.isDigit) == true) {
                let end = scanNumber(units, from: index)
                add(.number, index, end)
                index = end
                previousWord = ""
                lineHasCode = true
                continue
            }
            if Char.isIdentifierStart(current) {
                var end = index + 1
                while end < count && Char.isIdentifierPart(units[end]) { end += 1 }
                let word = String(decoding: units[index..<end], as: UTF16.self)
                lineHasCode = true
                if let next = unit(end), next == Char.quote || next == Char.apostrophe, stringPrefixes.contains(word.lowercased()) {
                    let stringEnd = min(scanString(from: end), count)
                    add(.string, index, stringEnd)
                    index = stringEnd
                    previousWord = ""
                    continue
                }
                if keywords.contains(word) {
                    add(.keyword, index, end)
                } else if previousWord == "def" || previousWord == "class" {
                    add(.definition, index, end)
                } else if builtins.contains(word) {
                    add(.builtin, index, end)
                }
                previousWord = word
                index = end
                continue
            }
            previousWord = ""
            lineHasCode = true
            index += 1
        }
        return result
    }

    /// 42, 3.14, .5, 1e-3, 1_000, 0xFF, 0b101, 2j.
    private static func scanNumber(_ units: [UInt16], from start: Int) -> Int {
        let count = units.count
        var position = start
        if units[position] == Char.zero, position + 1 < count, [Char.x, Char.X, Char.b, Char.B, Char.o, Char.O].contains(units[position + 1]) {
            position += 2
            while position < count && (Char.isHexDigit(units[position]) || units[position] == Char.underscore) { position += 1 }
            return position
        }
        while position < count && (Char.isDigit(units[position]) || units[position] == Char.underscore) { position += 1 }
        if position < count && units[position] == Char.dot {
            position += 1
            while position < count && (Char.isDigit(units[position]) || units[position] == Char.underscore) { position += 1 }
        }
        if position < count && (units[position] == Char.e || units[position] == Char.E) {
            var exponent = position + 1
            if exponent < count && (units[exponent] == Char.plus || units[exponent] == Char.minus) { exponent += 1 }
            if exponent < count && Char.isDigit(units[exponent]) {
                position = exponent
                while position < count && Char.isDigit(units[position]) { position += 1 }
            }
        }
        if position < count && (units[position] == Char.j || units[position] == Char.J) { position += 1 }
        return position
    }

    private enum Char {
        static let newline = UInt16(10), carriageReturn = UInt16(13), space = UInt16(32), tab = UInt16(9)
        static let hash = UInt16(35), quote = UInt16(34), apostrophe = UInt16(39), backslash = UInt16(92)
        static let at = UInt16(64), dot = UInt16(46), underscore = UInt16(95), plus = UInt16(43), minus = UInt16(45)
        static let zero = UInt16(48)
        static let x = UInt16(120), X = UInt16(88), b = UInt16(98), B = UInt16(66), o = UInt16(111), O = UInt16(79)
        static let e = UInt16(101), E = UInt16(69), j = UInt16(106), J = UInt16(74)

        static func isDigit(_ c: UInt16) -> Bool { c >= 48 && c <= 57 }
        static func isHexDigit(_ c: UInt16) -> Bool { isDigit(c) || (c >= 65 && c <= 70) || (c >= 97 && c <= 102) }
        /// Letters, `_` and any non-ASCII unit: Python allows Cyrillic names. / Python разрешает имена по-русски.
        static func isIdentifierStart(_ c: UInt16) -> Bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95 || c >= 0x80 }
        static func isIdentifierPart(_ c: UInt16) -> Bool { isIdentifierStart(c) || isDigit(c) }
    }
}

/// Colours of the editor as light/dark hex pairs; `verify_code_practice.swift` checks their contrast with the card.
/// Цвета редактора парами «светлая / тёмная тема»; контраст с карточкой проверяет `verify_code_practice.swift`.
enum CodeEditorColors {
    struct Pair: Equatable { let light: UInt32; let dark: UInt32 }

    /// The same as `AppPalette.card`. / То же, что `AppPalette.card`.
    static let background = Pair(light: 0xFFFFFF, dark: 0x1E212C)
    static let text = Pair(light: 0x1D2030, dark: 0xE4E6EF)
    static let gutterText = Pair(light: 0x6E7487, dark: 0x8A91A5)
    static let errorLine = Pair(light: 0xFCE6E9, dark: 0x4A2029)

    static func token(_ kind: PythonTokenKind) -> Pair {
        switch kind {
        case .keyword: return Pair(light: 0x8B36B5, dark: 0xD39BFF)
        case .builtin: return Pair(light: 0x1666A3, dark: 0x7CC4FF)
        case .string: return Pair(light: 0x1B7340, dark: 0x8DDBA4)
        case .comment: return Pair(light: 0x636979, dark: 0x8A91A5)
        case .number: return Pair(light: 0xA34A00, dark: 0xF6AD72)
        case .definition: return Pair(light: 0x0B6670, dark: 0x55D4DF)
        case .decorator: return Pair(light: 0xA33D52, dark: 0xFF98AA)
        }
    }
}

// MARK: - Lines / Строки

enum CodeLines {
    /// Range of line `number` (from 1) without its line break, in UTF-16 units. / Диапазон строки без перевода строки.
    static func range(ofLine number: Int, in source: String) -> NSRange? {
        guard number >= 1 else { return nil }
        let units = Array(source.utf16)
        var line = 1
        var start = 0
        for (offset, unit) in units.enumerated() where unit == 10 {
            if line == number { return NSRange(location: start, length: offset - start) }
            line += 1
            start = offset + 1
        }
        return line == number ? NSRange(location: start, length: units.count - start) : nil
    }

    /// The leading spaces of the line before `location`, plus four after a `:`. / Отступ новой строки.
    static func indentForNewLine(in source: String, at location: Int) -> String {
        let units = Array(source.utf16.prefix(location))
        var start = units.count
        while start > 0 && units[start - 1] != 10 { start -= 1 }
        let line = units[start..<units.count]
        let indent = line.prefix { $0 == 32 || $0 == 9 }
        var text = String(decoding: Array(indent), as: UTF16.self)
        let code = String(decoding: Array(line), as: UTF16.self)
        let withoutComment = code.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? code
        if withoutComment.trimmingCharacters(in: .whitespaces).hasSuffix(":") { text += "    " }
        return text
    }
}

// MARK: - Running python3 / Запуск python3

struct PythonRunResult: Equatable {
    enum Ending: Equatable {
        case finished(Int32)
        case timedOut
        case cancelled
        case failedToStart(String)
    }

    let ending: Ending
    let stdout: String
    let stderr: String
    let seconds: Double
    /// The output was longer than the limit and was cut. / Вывод был длиннее предела и обрезан.
    let truncated: Bool

    var succeeded: Bool { ending == .finished(0) }
}

/// Runs the system python3 with a timeout. One runner runs one program at a time.
/// Запускает системный python3 с ограничением времени. Один запуск за раз.
final class PythonRunner {
    /// The Mac's own python3 (3.9, NumPy is installed there); Homebrew's python3 often lacks NumPy.
    /// Системный python3 этого Mac (3.9, в нём стоит NumPy); у python3 из Homebrew NumPy часто нет.
    static let defaultInterpreter = "/usr/bin/python3"
    static let interpreterEnvironmentKey = "COLIDEV_PYTHON3"
    static let outputLimit = 256_000

    static func interpreter(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        if let custom = environment[interpreterEnvironmentKey], !custom.isEmpty { return custom }
        return defaultInterpreter
    }

    private let lock = NSLock()
    private var process: Process?
    private var cancelled = false

    var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return process != nil
    }

    func cancel() {
        lock.lock()
        let running = process
        cancelled = running != nil
        lock.unlock()
        running?.terminate()
    }

    /// Writes `code` to `fileName` in a new temporary folder, runs it there and removes the folder.
    /// Записывает код в новую временную папку, запускает его там и удаляет папку.
    func run(code: String, fileName: String = "main.py", timeout: TimeInterval,
             interpreter: String = PythonRunner.interpreter()) async -> PythonRunResult {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ColiDevPractice-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try Data(code.utf8).write(to: folder.appendingPathComponent(fileName))
        } catch {
            return PythonRunResult(ending: .failedToStart(error.localizedDescription), stdout: "", stderr: "", seconds: 0, truncated: false)
        }
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = await run(arguments: [fileName], in: folder, timeout: timeout, interpreter: interpreter)
        // The temporary folder means nothing to the learner: a traceback names just the file.
        // Временная папка ученику ничего не говорит: в трассировке остаётся только имя файла.
        func short(_ text: String) -> String {
            var text = text
            for prefix in ["/private" + folder.path + "/", folder.path + "/"] { text = text.replacingOccurrences(of: prefix, with: "") }
            return text
        }
        return PythonRunResult(ending: result.ending, stdout: short(result.stdout), stderr: short(result.stderr),
                               seconds: result.seconds, truncated: result.truncated)
    }

    func run(arguments: [String], in folder: URL, timeout: TimeInterval,
             interpreter: String = PythonRunner.interpreter(), extraEnvironment: [String: String] = [:]) async -> PythonRunResult {
        await withCheckedContinuation { continuation in
            start(arguments: arguments, folder: folder, timeout: timeout, interpreter: interpreter,
                  extraEnvironment: extraEnvironment) { continuation.resume(returning: $0) }
        }
    }

    private final class Collected {
        var stdout = Data()
        var stderr = Data()
        var truncated = false
        var stdoutClosed = false
        var stderrClosed = false
        var exited = false
        var timedOut = false
        var done = false
    }

    private func start(arguments: [String], folder: URL, timeout: TimeInterval, interpreter: String,
                       extraEnvironment: [String: String], completion: @escaping (PythonRunResult) -> Void) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: interpreter)
        // -B: no __pycache__ next to the owner's files; -u: output arrives at once and survives a timeout.
        // -B: без __pycache__ рядом с файлами; -u: вывод приходит сразу и не теряется при таймауте.
        process.arguments = ["-B", "-u"] + arguments
        process.currentDirectoryURL = folder
        var environment = ProcessInfo.processInfo.environment
        for key in ["PYTHONHOME", "PYTHONPATH", "PYTHONSTARTUP", "PYTHONINSPECT"] { environment[key] = nil }
        environment["PYTHONIOENCODING"] = "utf-8"
        environment["PYTHONUTF8"] = "1"
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        environment["MPLBACKEND"] = "Agg"  // plt.show() must not open a window and hang / окно графика не должно зависать
        for (key, value) in extraEnvironment { environment[key] = value }
        process.environment = environment
        process.standardInput = FileHandle.nullDevice
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let queue = DispatchQueue(label: "colidev.python-runner")
        let collected = Collected()
        var startTime = DispatchTime.now()
        var endTime = startTime

        func finish(force: Bool) {
            guard !collected.done else { return }
            guard force || (collected.exited && collected.stdoutClosed && collected.stderrClosed) else { return }
            collected.done = true
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            lock.lock()
            let wasCancelled = cancelled
            self.process = nil
            cancelled = false
            lock.unlock()
            let ending: PythonRunResult.Ending
            if collected.timedOut {
                ending = .timedOut
            } else if wasCancelled {
                ending = .cancelled
            } else {
                ending = .finished(process.isRunning ? -1 : process.terminationStatus)
            }
            let seconds = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000_000
            completion(PythonRunResult(
                ending: ending,
                stdout: String(decoding: collected.stdout, as: UTF8.self),
                stderr: String(decoding: collected.stderr, as: UTF8.self),
                seconds: max(0, seconds),
                truncated: collected.truncated
            ))
        }

        func reader(_ isOut: Bool) -> (FileHandle) -> Void {
            { handle in
                let data = handle.availableData
                queue.async {
                    if data.isEmpty {
                        if isOut { collected.stdoutClosed = true } else { collected.stderrClosed = true }
                        handle.readabilityHandler = nil
                        finish(force: false)
                        return
                    }
                    let used = collected.stdout.count + collected.stderr.count
                    let room = max(0, PythonRunner.outputLimit - used)
                    if data.count > room { collected.truncated = true }
                    if room > 0 {
                        if isOut { collected.stdout.append(data.prefix(room)) } else { collected.stderr.append(data.prefix(room)) }
                    }
                }
            }
        }
        outPipe.fileHandleForReading.readabilityHandler = reader(true)
        errPipe.fileHandleForReading.readabilityHandler = reader(false)
        process.terminationHandler = { _ in
            queue.async {
                endTime = DispatchTime.now()
                collected.exited = true
                finish(force: false)
                // A child process may keep the pipes open: stop waiting a second later. / Дочерний процесс может держать вывод.
                queue.asyncAfter(deadline: .now() + 1) { finish(force: true) }
            }
        }

        lock.lock()
        self.process = process
        cancelled = false
        lock.unlock()
        do {
            startTime = DispatchTime.now()
            try process.run()
        } catch {
            lock.lock()
            self.process = nil
            lock.unlock()
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil
            completion(PythonRunResult(ending: .failedToStart(error.localizedDescription), stdout: "", stderr: "", seconds: 0, truncated: false))
            return
        }
        queue.asyncAfter(deadline: .now() + timeout) {
            guard !collected.exited else { return }
            collected.timedOut = true
            process.terminate()
            let pid = process.processIdentifier
            queue.asyncAfter(deadline: .now() + 1) {
                if !collected.exited { kill(pid, SIGKILL) }
            }
            queue.asyncAfter(deadline: .now() + 2.5) {
                endTime = DispatchTime.now()
                finish(force: true)
            }
        }
    }
}

// MARK: - Errors / Ошибки

enum PythonTraceback {
    private static let framePattern = try? NSRegularExpression(pattern: #"File "([^"]+)", line (\d+)"#)

    /// The last line of the learner's file named in the traceback: the deepest place of the error in their code.
    /// Последняя строка файла ученика в трассировке: самое глубокое место ошибки в его коде.
    static func errorLine(in stderr: String, fileName: String) -> Int? {
        guard let pattern = framePattern else { return nil }
        let text = stderr as NSString
        var line: Int?
        for match in pattern.matches(in: stderr, range: NSRange(location: 0, length: text.length)) {
            let path = text.substring(with: match.range(at: 1))
            guard path == fileName || (path as NSString).lastPathComponent == fileName else { continue }
            line = Int(text.substring(with: match.range(at: 2)))
        }
        return line
    }

    /// The closing "NameError: …" line of a traceback. / Итоговая строка «NameError: …».
    static func summary(_ stderr: String) -> String? {
        let lines = stderr.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
        guard stderr.contains("Traceback") || stderr.contains("Error") else { return nil }
        return lines.last { line in
            guard let first = line.first, !first.isWhitespace else { return false }
            return !line.hasPrefix("Traceback") && !line.hasPrefix("During handling")
        }
    }
}

// MARK: - Lab checks / Проверки «Собери и проверь сам»

struct CreatorCheckLine: Equatable {
    let passed: Bool
    /// "ru / en" as the check prints it. / «ru / en», как печатает проверка.
    let text: String
    var detail: String

    /// The half of "ru / en" for the app language; the whole line when it is not split that way.
    /// Половина «ru / en» на языке приложения; вся строка, если она так не делится.
    func text(russian: Bool) -> String {
        let parts = text.components(separatedBy: " / ")
        guard parts.count == 2 else { return text }
        return (russian ? parts[0] : parts[1]).trimmingCharacters(in: .whitespaces)
    }
}

struct CreatorCheckReport: Equatable {
    var lines: [CreatorCheckLine] = []
    var passed: Int { lines.filter(\.passed).count }
    var failed: Int { lines.count - passed }
    var allPassed: Bool { !lines.isEmpty && failed == 0 }
}

enum CreatorCheckOutput {
    /// Reads the ✓ and ✗ lines of `_checklib.Checker`; indented lines under a ✗ are its detail.
    /// Читает строки ✓ и ✗ из `_checklib.Checker`; строки с отступом под ✗ — подробность.
    static func parse(_ output: String) -> CreatorCheckReport {
        var report = CreatorCheckReport()
        var lastFailedIndex: Int?
        for raw in output.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("✓") {
                report.lines.append(CreatorCheckLine(passed: true, text: String(line.dropFirst()).trimmingCharacters(in: .whitespaces), detail: ""))
                lastFailedIndex = nil
            } else if line.hasPrefix("✗") {
                report.lines.append(CreatorCheckLine(passed: false, text: String(line.dropFirst()).trimmingCharacters(in: .whitespaces), detail: ""))
                lastFailedIndex = report.lines.count - 1
            } else if let index = lastFailedIndex, raw.hasPrefix("    "), !line.isEmpty {
                let detail = report.lines[index].detail
                report.lines[index].detail = detail.isEmpty ? line : detail + "\n" + line
            } else if !raw.hasPrefix(" ") {
                lastFailedIndex = nil
            }
        }
        return report
    }
}

struct CreatorLab: Identifiable, Equatable {
    /// The lesson resource, also the name in `check_<lesson>.py` and in `.results.json`. / Урок и имя проверки.
    let lesson: String
    let blank: String

    var id: String { lesson }
    var checkFile: String { "check_\(lesson).py" }
    var taskKey: String { "code.lab.\(lesson).task" }
}

enum CreatorLabCatalog {
    /// The order of `01_Projects/creator_labs/README.md`; `test_creator_labs.py` checks the blank names.
    /// Порядок как в README; имена заготовок сверяет `test_creator_labs.py`.
    static let labs: [CreatorLab] = [
        CreatorLab(lesson: "attention_mechanism", blank: "attention_blank.py"),
        CreatorLab(lesson: "autograd_engine", blank: "autograd_blank.py"),
        CreatorLab(lesson: "tokenizer_bpe", blank: "tokenizer_blank.py"),
        CreatorLab(lesson: "rl_policy_gradient", blank: "policy_gradient_blank.py"),
        CreatorLab(lesson: "finetuning_and_lora", blank: "lora_blank.py"),
        CreatorLab(lesson: "interp_probes", blank: "probe_blank.py"),
        CreatorLab(lesson: "consciousness_integrated_information", blank: "phi_blank.py")
    ]

    /// The copy of `01_Projects/creator_labs` inside the app (Resources/creator_labs). / Копия заданий внутри приложения.
    static let bundleFolderName = "creator_labs"

    static func lab(forLesson lesson: String) -> CreatorLab? { labs.first { $0.lesson == lesson } }

    /// `~/ai-path/creator_labs` (or `COLIDEV_CREATOR_LABS_DIR`): the folder next to `.results.json`.
    /// Папка, где лежит `.results.json` экрана «Прогресс Творца».
    static func workspace(environment: [String: String], home: URL) -> URL {
        CreatorLabResults.fileURL(environment: environment, home: home).deletingLastPathComponent()
    }

    /// Like `cp -Rn`: copies the files that are missing and never overwrites what is already there.
    /// Как `cp -Rn`: копирует недостающие файлы и не перезаписывает уже написанное.
    @discardableResult
    static func copyMissing(from source: URL, to destination: URL, fileManager: FileManager = .default) throws -> [String] {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        var copied: [String] = []
        let names = try fileManager.contentsOfDirectory(atPath: source.path).sorted()
        for name in names where !name.hasPrefix(".") && name != "__pycache__" {
            let from = source.appendingPathComponent(name)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: from.path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
            let to = destination.appendingPathComponent(name)
            if fileManager.fileExists(atPath: to.path) { continue }
            try fileManager.copyItem(at: from, to: to)
            copied.append(name)
        }
        return copied
    }
}

// MARK: - Practice files / Файлы практики

enum PracticeFiles {
    /// Another root for checks of the app itself. / Другая папка для проверки самого приложения.
    static let rootEnvironmentKey = "COLIDEV_PRACTICE_DIR"
    static let scratchName = "Черновик.py"
    static let lessonsFolder = "Уроки"

    /// `~/Творец/Практика`. The rest of `~/Творец` belongs to the Workshop (part 5). / Остальное в `~/Творец` — Мастерская.
    static func root(environment: [String: String], home: URL) -> URL {
        if let folder = environment[rootEnvironmentKey], !folder.isEmpty {
            return URL(fileURLWithPath: (folder as NSString).expandingTildeInPath, isDirectory: true)
        }
        return home.appendingPathComponent("Творец", isDirectory: true).appendingPathComponent("Практика", isDirectory: true)
    }

    /// A file or folder name from a course or topic title: no `/`, `:`, control characters or leading dots.
    /// Имя файла или папки из названия курса или темы: без `/`, `:`, служебных знаков и точек в начале.
    static func safeName(_ title: String, fallback: String = "Тема") -> String {
        var cleaned = String(title.unicodeScalars.map { scalar -> Character in
            if CharacterSet.controlCharacters.contains(scalar) || "/:\\".unicodeScalars.contains(scalar) { return " " }
            return Character(scalar)
        })
        cleaned = cleaned.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        if cleaned.count > 80 { cleaned = String(cleaned.prefix(80)).trimmingCharacters(in: .whitespaces) }
        return cleaned.isEmpty ? fallback : cleaned
    }

    /// `~/Творец/Практика/<курс>/<тема>.py`: one file per Skillbox topic. / Один файл на тему Skillbox.
    static func skillboxFile(course: String, topic: String, root: URL) -> URL {
        root.appendingPathComponent(safeName(course, fallback: "Skillbox"), isDirectory: true)
            .appendingPathComponent(safeName(topic) + ".py")
    }

    /// `~/Творец/Практика/Уроки/<урок>.py` for a lesson without its own lab. / Файл урока без своего задания.
    static func lessonFile(resource: String, root: URL) -> URL {
        root.appendingPathComponent(lessonsFolder, isDirectory: true).appendingPathComponent(safeName(resource, fallback: "lesson") + ".py")
    }

    static func scratchFile(root: URL) -> URL { root.appendingPathComponent(scratchName) }

    /// The first lines of a new practice file. / Первые строки нового файла практики.
    static func header(title: String, detail: String) -> String {
        var lines = ["# \(title)"]
        for line in detail.split(separator: "\n", omittingEmptySubsequences: true).prefix(6) {
            lines.append("# \(line.trimmingCharacters(in: .whitespaces))")
        }
        return lines.joined(separator: "\n") + "\n\n"
    }

    /// Python files under the root, newest first. / Файлы Python в папке практики, сначала новые.
    static func list(root: URL, limit: Int = 60, fileManager: FileManager = .default) -> [URL] {
        guard let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.contentModificationDateKey],
                                                      options: [.skipsHiddenFiles, .skipsPackageDescendants]) else { return [] }
        var files: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "py" {
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            files.append((url, date))
        }
        return files.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }
}

// MARK: - "Check my code" / «Проверь мой код»

enum PracticeReviewPrompt {
    static let codeLimit = 20_000  // the backend's `code` limit / предел backend
    static let outputLimit = 2_500

    /// The request to the assistant: the task, the code goes separately, plus the end of the last output.
    /// Просьба к ассистенту: условие, код отдельно, плюс конец последнего вывода.
    static func make(template: String, task: String, output: String?, outputTemplate: String) -> String {
        var prompt = String(format: template, task)
        if let output = output?.trimmingCharacters(in: .whitespacesAndNewlines), !output.isEmpty {
            let tail = output.count > outputLimit ? "…" + String(output.suffix(outputLimit)) : output
            prompt += "\n\n" + String(format: outputTemplate, tail)
        }
        return prompt
    }

    static func code(_ source: String) -> String {
        source.count > codeLimit ? String(source.prefix(codeLimit)) : source
    }
}
