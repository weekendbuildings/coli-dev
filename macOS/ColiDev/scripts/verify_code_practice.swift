import Foundation

// Checks of the "Practice" editor logic: highlighting, colours, tracebacks, ✓/✗ lines, files and running python3.
// Проверки логики редактора «Практика»: подсветка, цвета, ошибки, строки ✓/✗, файлы и запуск python3.

var failures = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        failures += 1
        print("FAIL: \(message)")
    }
}

func pieces(_ source: String, _ kind: PythonTokenKind) -> [String] {
    let text = source as NSString
    return PythonHighlighter.tokens(source).filter { $0.kind == kind }.map { text.substring(with: $0.range) }
}

func contrast(_ first: UInt32, _ second: UInt32) -> Double {
    func luminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let unit = Double(value & 0xFF) / 255
            return unit <= 0.03928 ? unit / 12.92 : pow((unit + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(hex >> 16) + 0.7152 * channel(hex >> 8) + 0.0722 * channel(hex)
    }
    let (a, b) = (luminance(first), luminance(second))
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)
}

func checkHighlighter() {
    let source = """
    @dataclass
    class Модель(Base):
        def forward(self, x1, шаг=0.5):  # "not a string" here
            text = f"x = {x1}" + 'it\\'s' + rb'\\d'
            if x1 is None and шаг > 1e-3:
                return [0xFF, 1_000, .25, 2j, 10]
            match = "# not a comment"
            return print(len(text))
    doc = \"\"\"line one
    line 'two' # still a string\"\"\"
    broken = "no end
    after = 7
    """
    expect(pieces(source, .keyword) == ["class", "def", "if", "is", "None", "and", "return", "return"], "keywords: \(pieces(source, .keyword))")
    expect(pieces(source, .definition) == ["Модель", "forward"], "names after def/class, Cyrillic too: \(pieces(source, .definition))")
    expect(pieces(source, .decorator) == ["@dataclass"], "decorator: \(pieces(source, .decorator))")
    expect(pieces(source, .comment) == ["# \"not a string\" here"], "only the real comment: \(pieces(source, .comment))")
    let strings = pieces(source, .string)
    expect(strings.contains("f\"x = {x1}\""), "f-string with its prefix: \(strings)")
    expect(strings.contains("'it\\'s'"), "an escaped quote does not end the string: \(strings)")
    expect(strings.contains("rb'\\d'"), "two-letter prefix: \(strings)")
    expect(strings.contains("\"# not a comment\""), "# inside a string is not a comment")
    expect(strings.contains("\"\"\"line one\nline 'two' # still a string\"\"\""), "triple-quoted string across lines: \(strings)")
    expect(strings.contains("\"no end"), "an unclosed string stops at the line end: \(strings)")
    let numbers = pieces(source, .number)
    expect(numbers == ["0.5", "1e-3", "0xFF", "1_000", ".25", "2j", "10", "7"], "numbers, not the 1 of x1: \(numbers)")
    expect(pieces(source, .builtin) == ["self", "print", "len"], "builtins: \(pieces(source, .builtin))")
    expect(!pieces(source, .keyword).contains("match"), "match is a soft keyword and stays plain")
    let tokens = PythonHighlighter.tokens(source)
    expect(zip(tokens, tokens.dropFirst()).allSatisfy { $0.range.location + $0.range.length <= $1.range.location }, "tokens do not overlap")
    expect(tokens.allSatisfy { $0.range.location + $0.range.length <= (source as NSString).length }, "tokens stay inside the text")
    expect(PythonHighlighter.tokens("").isEmpty && PythonHighlighter.tokens("\"").count == 1, "empty and one-quote sources do not crash")
    expect(pieces("x = 'а' # 😀 б", .comment) == ["# 😀 б"], "UTF-16 ranges with emoji and Cyrillic")
}

func checkColours() {
    let background = CodeEditorColors.background
    for kind in PythonTokenKind.allCases {
        let pair = CodeEditorColors.token(kind)
        expect(contrast(pair.light, background.light) >= 4.5, "\(kind) light contrast \(contrast(pair.light, background.light))")
        expect(contrast(pair.dark, background.dark) >= 4.5, "\(kind) dark contrast \(contrast(pair.dark, background.dark))")
    }
    for pair in [CodeEditorColors.text, CodeEditorColors.gutterText] {
        expect(contrast(pair.light, background.light) >= 4.5 && contrast(pair.dark, background.dark) >= 4.5, "text contrast \(pair)")
    }
    let error = CodeEditorColors.errorLine
    let onError = [CodeEditorColors.text] + PythonTokenKind.allCases.map(CodeEditorColors.token)
    for pair in onError {
        expect(contrast(pair.light, error.light) >= 4.0 && contrast(pair.dark, error.dark) >= 4.0,
               "code stays readable on the error line \(pair): \(contrast(pair.light, error.light)) \(contrast(pair.dark, error.dark))")
    }
}

func checkLines() {
    let source = "a = 1\nif a:\n    print(a)  # x:\n"
    expect(CodeLines.range(ofLine: 2, in: source) == NSRange(location: 6, length: 5), "line 2 range")
    expect(CodeLines.range(ofLine: 4, in: source) == NSRange(location: 31, length: 0), "the empty last line")
    expect(CodeLines.range(ofLine: 5, in: source) == nil && CodeLines.range(ofLine: 0, in: source) == nil, "no such line")
    expect(CodeLines.indentForNewLine(in: source, at: 11) == "    ", "indent after a colon")
    expect(CodeLines.indentForNewLine(in: source, at: 30) == "    ", "a colon in a comment does not indent more")
    expect(CodeLines.indentForNewLine(in: "x = 1", at: 5) == "", "no indent")
}

func checkTracebacks() {
    let runtime = """
    Traceback (most recent call last):
      File "/private/var/folders/x/main.py", line 7, in <module>
        main()
      File "/private/var/folders/x/main.py", line 4, in main
        print(1 / 0)
      File "/usr/lib/python3.9/other.py", line 99, in helper
    ZeroDivisionError: division by zero
    """
    expect(PythonTraceback.errorLine(in: runtime, fileName: "main.py") == 4, "deepest line of the learner's file")
    expect(PythonTraceback.summary(runtime) == "ZeroDivisionError: division by zero", "summary line")
    let syntax = """
      File "/tmp/a/Черновик.py", line 2
        print("x"
             ^
    SyntaxError: '(' was never closed
    """
    expect(PythonTraceback.errorLine(in: syntax, fileName: "Черновик.py") == 2, "syntax error line with a Cyrillic file name")
    expect(PythonTraceback.summary(syntax) == "SyntaxError: '(' was never closed", "syntax summary")
    expect(PythonTraceback.errorLine(in: "hello", fileName: "main.py") == nil && PythonTraceback.summary("hello") == nil, "no error")
}

func checkLabOutput() {
    let output = """
    Механизм градиентов / Autograd engine
    Файл / File: /Users/me/ai-path/creator_labs/autograd_blank.py

      ✓ сложение / addition
      ✗ умножение / multiplication
          не реализовано / not implemented: mul
          ещё строка
      ✓ tanh / tanh

    Пройдено 2 из 3. Исправь первую ✗ и запусти снова.
    """
    let report = CreatorCheckOutput.parse(output)
    expect(report.lines.count == 3 && report.passed == 2 && report.failed == 1 && !report.allPassed, "counts: \(report)")
    expect(report.lines[1].detail == "не реализовано / not implemented: mul\nещё строка", "detail under ✗: \(report.lines[1].detail)")
    expect(report.lines[0].text(russian: true) == "сложение" && report.lines[0].text(russian: false) == "addition", "ru/en halves")
    expect(CreatorCheckLine(passed: true, text: "a / b / c", detail: "").text(russian: true) == "a / b / c", "unsplittable line stays whole")
    expect(!report.lines[2].detail.contains("Пройдено"), "the summary is not a detail")
    expect(CreatorCheckOutput.parse("  ✓ a / b\n  ✓ c / d\n").allPassed, "all passed")
    expect(!CreatorCheckOutput.parse("✗ Файл не запускается / The file does not run\n").allPassed, "a load failure")
    expect(!CreatorCheckOutput.parse("").allPassed, "no lines is not a pass")
}

func checkCatalogAndFiles() throws {
    expect(CreatorLabCatalog.labs.map(\.lesson) == CreatorLabResults.lessons, "the editor and the progress screen list the same labs")
    expect(Set(CreatorLabCatalog.labs.map(\.blank)).count == 7, "seven different blanks")
    expect(CreatorLabCatalog.lab(forLesson: "autograd_engine")?.checkFile == "check_autograd_engine.py", "check file name")
    let home = URL(fileURLWithPath: "/Users/me")
    expect(CreatorLabCatalog.workspace(environment: [:], home: home).path == "/Users/me/ai-path/creator_labs", "default lab folder")
    expect(CreatorLabCatalog.workspace(environment: ["COLIDEV_CREATOR_LABS_DIR": "/tmp/l"], home: home).path == "/tmp/l", "lab folder override")
    expect(PracticeFiles.root(environment: [:], home: home).path == "/Users/me/Творец/Практика", "practice root")
    let root = PracticeFiles.root(environment: [:], home: home)
    expect(PracticeFiles.skillboxFile(course: "Python: основы", topic: "Циклы / while", root: root).path
           == "/Users/me/Творец/Практика/Python  основы/Циклы while.py".replacingOccurrences(of: "  ", with: " "),
           "Skillbox file: \(PracticeFiles.skillboxFile(course: "Python: основы", topic: "Циклы / while", root: root).path)")
    expect(PracticeFiles.safeName("..\n") == "Тема" && PracticeFiles.safeName(String(repeating: "я", count: 200)).count == 80, "safe names")
    expect(PracticeFiles.lessonFile(resource: "loops", root: root).lastPathComponent == "loops.py", "lesson file")
    expect(PracticeFiles.header(title: "Тема", detail: "a\nb") == "# Тема\n# a\n# b\n\n", "header")

    let fm = FileManager.default
    let base = fm.temporaryDirectory.appendingPathComponent("verify-code-practice-\(UUID().uuidString)")
    defer { try? fm.removeItem(at: base) }
    let source = base.appendingPathComponent("src"), target = base.appendingPathComponent("dst")
    try fm.createDirectory(at: source.appendingPathComponent("__pycache__"), withIntermediateDirectories: true)
    try "blank".write(to: source.appendingPathComponent("a_blank.py"), atomically: true, encoding: .utf8)
    try "check".write(to: source.appendingPathComponent("check_a.py"), atomically: true, encoding: .utf8)
    try "{}".write(to: source.appendingPathComponent(".results.json"), atomically: true, encoding: .utf8)
    try fm.createDirectory(at: target, withIntermediateDirectories: true)
    try "my own code".write(to: target.appendingPathComponent("a_blank.py"), atomically: true, encoding: .utf8)
    let copied = try CreatorLabCatalog.copyMissing(from: source, to: target)
    expect(copied == ["check_a.py"], "only missing files are copied: \(copied)")
    expect((try? String(contentsOf: target.appendingPathComponent("a_blank.py"), encoding: .utf8)) == "my own code", "the owner's code is kept")
    expect(!fm.fileExists(atPath: target.appendingPathComponent(".results.json").path), "no results file from the app")
    expect(!fm.fileExists(atPath: target.appendingPathComponent("__pycache__").path), "no __pycache__")
    let second = try CreatorLabCatalog.copyMissing(from: source, to: target)
    expect(second.isEmpty, "a second copy changes nothing")

    let prompt = PracticeReviewPrompt.make(template: "Task: %@", task: "T", output: String(repeating: "x", count: 3000) + "END",
                                           outputTemplate: "Output:\n%@")
    expect(prompt.hasPrefix("Task: T\n\nOutput:\n…") && prompt.hasSuffix("END") && prompt.count < 2_600, "prompt keeps the end of the output")
    expect(PracticeReviewPrompt.make(template: "Task: %@", task: "T", output: "  ", outputTemplate: "%@") == "Task: T", "no empty output")
}

func checkRunner() async {
    let python = PythonRunner.defaultInterpreter
    guard FileManager.default.isExecutableFile(atPath: python) else {
        print("SKIP runner: no \(python)")
        return
    }
    let runner = PythonRunner()
    let hello = await runner.run(code: "print('Привет, Творец!')\nimport sys\nprint('ошибка', file=sys.stderr)\n", timeout: 20)
    expect(hello.succeeded, "a simple program finishes: \(hello.ending) \(hello.stderr)")
    expect(hello.stdout == "Привет, Творец!\n", "Cyrillic stdout: \(hello.stdout)")
    expect(hello.stderr == "ошибка\n", "Cyrillic stderr: \(hello.stderr)")
    expect(hello.seconds > 0 && hello.seconds < 20, "time is measured: \(hello.seconds)")

    let broken = await runner.run(code: "x = 1\n\ndef f():\n    return y\n\nf()\n", fileName: "Черновик.py", timeout: 20)
    expect(broken.ending == .finished(1), "an error exits with 1: \(broken.ending)")
    expect(PythonTraceback.errorLine(in: broken.stderr, fileName: "Черновик.py") == 4, "the error is on line 4: \(broken.stderr)")
    expect(PythonTraceback.summary(broken.stderr) == "NameError: name 'y' is not defined", "summary: \(broken.stderr)")

    let syntax = await runner.run(code: "print('a')\nx = = 2\nprint('b')\n", timeout: 20)
    expect(PythonTraceback.errorLine(in: syntax.stderr, fileName: "main.py") == 2, "syntax error line: \(syntax.stderr)")

    let slow = await runner.run(code: "import time\nprint('start')\nwhile True:\n    time.sleep(0.05)\n", timeout: 1)
    expect(slow.ending == .timedOut, "an endless loop is stopped: \(slow.ending)")
    expect(slow.stdout == "start\n", "output before the timeout survives: \(slow.stdout)")
    expect(slow.seconds >= 1 && slow.seconds < 6, "stopped soon after the timeout: \(slow.seconds)")

    let input = await runner.run(code: "input('?')\n", timeout: 10)
    expect(input.ending == .finished(1) && input.stderr.contains("EOFError"), "input() gets no keyboard and does not hang")

    let flood = await runner.run(code: "for i in range(200000):\n    print('строка', i)\n", timeout: 20)
    expect(flood.truncated && flood.stdout.utf8.count <= PythonRunner.outputLimit, "a flood of output is cut")

    let cancelling = PythonRunner()
    async let cancelled = cancelling.run(code: "import time\ntime.sleep(30)\n", timeout: 30)
    try? await Task.sleep(nanoseconds: 500_000_000)
    expect(cancelling.isRunning, "the runner knows it runs")
    cancelling.cancel()
    let stopped = await cancelled
    expect(stopped.ending == .cancelled && !cancelling.isRunning, "Stop ends the program: \(stopped.ending)")

    let missing = await runner.run(code: "print(1)", timeout: 5, interpreter: "/nonexistent/python3")
    if case .failedToStart = missing.ending {} else { expect(false, "a missing interpreter is reported: \(missing.ending)") }
}

@main
struct VerifyCodePractice {
    static func main() async {
        checkHighlighter()
        checkColours()
        checkLines()
        checkTracebacks()
        checkLabOutput()
        do { try checkCatalogAndFiles() } catch { expect(false, "files: \(error)") }
        await checkRunner()
        if failures > 0 {
            print("\(failures) check(s) failed")
            exit(1)
        }
        print("verify_code_practice: all checks passed")
    }
}
