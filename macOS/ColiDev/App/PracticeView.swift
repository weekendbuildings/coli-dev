import AppKit
import SwiftUI

// "Practice": write Python, run it with the Mac's python3, check the "build and check it yourself" labs
// and ask the assistant to review the code. The sidebar screen and the sheet from a lesson or a Skillbox topic.
// «Практика»: пишешь Python, запускаешь системным python3, проверяешь задания «Собери и проверь сам»
// и просишь ассистента проверить код. Экран в боковой панели и окно из урока или темы Skillbox.

/// One file open in the editor and what the assistant should know about it.
/// Файл в редакторе и то, что о нём должен знать ассистент.
struct PracticeDocument: Identifiable, Equatable {
    enum Kind: Equatable {
        case scratch
        case lab(CreatorLab)
        case lesson
        case skillbox
        case file
    }

    let url: URL
    let kind: Kind
    let title: String
    /// What the code must do, for "Check my code". / Условие для «Проверь мой код».
    let task: String
    let context: AssistantLessonContext
    /// The text of a new file. / Текст нового файла.
    var header: String = ""

    var id: String { url.path }
    var lab: CreatorLab? {
        if case .lab(let lab) = kind { return lab }
        return nil
    }
}

enum PracticeEnvironment {
    static var environment: [String: String] { ProcessInfo.processInfo.environment }
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }
    static var practiceRoot: URL { PracticeFiles.root(environment: environment, home: home) }
    static var labsFolder: URL { CreatorLabCatalog.workspace(environment: environment, home: home) }
    /// The copy of `01_Projects/creator_labs` inside the app. / Копия заданий внутри приложения.
    static var labsSource: URL? {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent(CreatorLabCatalog.bundleFolderName, isDirectory: true),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    static func tilde(_ url: URL) -> String { url.path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
}

extension PracticeDocument {
    static func scratch(_ language: AppLanguage) -> PracticeDocument {
        let title = L10n.text("code.scratch.title", language)
        return PracticeDocument(
            url: PracticeFiles.scratchFile(root: PracticeEnvironment.practiceRoot), kind: .scratch, title: title, task: "",
            context: AssistantLessonContext(kind: "lesson", title: title, subject: "Python"),
            header: PracticeFiles.header(title: L10n.text("code.scratch.header", language), detail: "") + "print(\"Привет, Творец!\")\n"
        )
    }

    static func lab(_ lab: CreatorLab, _ language: AppLanguage) -> PracticeDocument {
        let title = AIPathCatalog.topics[lab.lesson]?.name.value(in: language) ?? lab.lesson
        let task = L10n.text(lab.taskKey, language)
        return PracticeDocument(
            url: PracticeEnvironment.labsFolder.appendingPathComponent(lab.blank), kind: .lab(lab), title: title,
            task: String(format: L10n.text("code.lab.taskFull", language), title, task, lab.blank, lab.checkFile),
            context: AssistantLessonContext(kind: "lesson", title: title, subject: Subject.programming.title(in: language),
                                            goal: task, position: L10n.text("code.lab.position", language))
        )
    }

    /// A lesson with a lab opens the lab; another lesson gets its own file. / Урок с заданием открывает задание, иначе свой файл.
    static func lesson(subject: Subject, resource: String, title: String, goal: String, _ language: AppLanguage) -> PracticeDocument {
        if let lab = CreatorLabCatalog.lab(forLesson: resource) { return .lab(lab, language) }
        let heading = String(format: L10n.text("code.lesson.header", language), title)
        let shortGoal = AssistantExplainPrompt.shortGoal(goal)
        return PracticeDocument(
            url: PracticeFiles.lessonFile(resource: resource, root: PracticeEnvironment.practiceRoot), kind: .lesson, title: title,
            task: shortGoal,
            context: AssistantLessonContext(kind: "lesson", title: title, subject: subject.title(in: language), goal: shortGoal),
            header: PracticeFiles.header(title: heading, detail: shortGoal.isEmpty ? "" : String(format: L10n.text("code.lesson.goal", language), shortGoal))
        )
    }

    static func skillbox(topic: String, course: String, track: String, _ language: AppLanguage) -> PracticeDocument {
        let url = PracticeFiles.skillboxFile(course: course, topic: topic, root: PracticeEnvironment.practiceRoot)
        return PracticeDocument(
            url: url, kind: .skillbox, title: topic,
            task: String(format: L10n.text("code.skillbox.task", language), topic, course),
            context: AssistantLessonContext(kind: "skillbox", title: topic, subject: "Python", course: course, track: track),
            header: PracticeFiles.header(title: String(format: L10n.text("code.skillbox.header", language), topic, course),
                                         detail: L10n.text("code.skillbox.note", language))
        )
    }

    /// A file from "My files": a Skillbox topic when it lies in a course folder. / Файл из «Моих файлов».
    static func file(_ url: URL, _ language: AppLanguage) -> PracticeDocument {
        let root = PracticeEnvironment.practiceRoot.standardizedFileURL.path
        let folder = url.deletingLastPathComponent().standardizedFileURL
        if url.standardizedFileURL.path == PracticeFiles.scratchFile(root: PracticeEnvironment.practiceRoot).standardizedFileURL.path {
            return .scratch(language)
        }
        let name = url.deletingPathExtension().lastPathComponent
        if folder.path != root, folder.lastPathComponent != PracticeFiles.lessonsFolder,
           folder.deletingLastPathComponent().path == root {
            return .skillbox(topic: name, course: folder.lastPathComponent, track: "", language)
        }
        return PracticeDocument(url: url, kind: .file, title: url.lastPathComponent, task: "",
                                context: AssistantLessonContext(kind: "lesson", title: name, subject: "Python"))
    }
}

@MainActor
final class PracticeModel: ObservableObject {
    enum Phase: Equatable { case idle, running, checking }

    @Published private(set) var document: PracticeDocument?
    @Published var text = "" { didSet { textChanged(oldValue) } }
    @Published private(set) var isSaved = true
    @Published private(set) var saveError: String?
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var result: PythonRunResult?
    @Published private(set) var report: CreatorCheckReport?
    @Published private(set) var errorLine: Int?
    @Published private(set) var errorSummary: String?
    @Published private(set) var labSummaries: [String: CreatorLabSummary] = [:]
    @Published private(set) var files: [URL] = []
    @Published var notice: String?
    @Published private(set) var interpreter: String?

    static let lastFileKey = "code.practice.lastFile"
    static let runTimeout: TimeInterval = 15
    static let checkTimeout: TimeInterval = 90

    private let runner = PythonRunner()
    private var saveTask: Task<Void, Never>?
    private var loading = false

    var output: String {
        guard let result else { return "" }
        return [result.stdout, result.stderr].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    private func textChanged(_ old: String) {
        guard !loading, text != old else { return }
        isSaved = false
        errorLine = nil
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            self?.save()
        }
    }

    func save() {
        saveTask?.cancel()
        guard let document, !isSaved else { return }
        do {
            try FileManager.default.createDirectory(at: document.url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(text.utf8).write(to: document.url, options: .atomic)
            isSaved = true
            saveError = nil
        } catch {
            saveError = error.localizedDescription
        }
    }

    func open(_ next: PracticeDocument) {
        save()
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: next.url.path) {
                try fm.createDirectory(at: next.url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try Data(next.header.utf8).write(to: next.url, options: .withoutOverwriting)
            }
            let data = try Data(contentsOf: next.url)
            loading = true
            text = String(decoding: data, as: UTF8.self)
            loading = false
            document = next
            isSaved = true
            saveError = nil
            result = nil
            report = nil
            errorLine = nil
            errorSummary = nil
            UserDefaults.standard.set(next.url.path, forKey: Self.lastFileKey)
        } catch {
            loading = false
            notice = error.localizedDescription
        }
        refreshFiles()
    }

    /// Copies the missing lab files (like `cp -n`) and opens the blank. / Копирует недостающее (как `cp -n`) и открывает заготовку.
    func openLab(_ lab: CreatorLab, language: AppLanguage) {
        guard prepareLabs(language: language) else { return }
        open(.lab(lab, language))
    }

    @discardableResult
    private func prepareLabs(language: AppLanguage) -> Bool {
        guard let source = PracticeEnvironment.labsSource else {
            notice = L10n.text("code.lab.missing", language)
            return false
        }
        do {
            let copied = try CreatorLabCatalog.copyMissing(from: source, to: PracticeEnvironment.labsFolder)
            if !copied.isEmpty {
                notice = String(format: L10n.text("code.lab.copied", language),
                                PracticeEnvironment.tilde(PracticeEnvironment.labsFolder), String(copied.count))
            }
            return true
        } catch {
            notice = String(format: L10n.text("code.lab.copyFailed", language), error.localizedDescription)
            return false
        }
    }

    func run() async {
        guard let document, phase == .idle else { return }
        save()
        phase = .running
        result = nil
        report = nil
        errorLine = nil
        errorSummary = nil
        let name = document.url.lastPathComponent
        let outcome = await runner.run(code: text, fileName: name, timeout: Self.runTimeout)
        finish(outcome, fileName: name)
    }

    /// Runs `check_<lesson>.py` on the open file; the check writes `.results.json` for "Creator progress".
    /// Запускает проверку на открытом файле; итог проверка пишет в `.results.json` для «Прогресса Творца».
    func check(language: AppLanguage) async {
        guard let document, let lab = document.lab, phase == .idle else { return }
        save()
        guard prepareLabs(language: language) else { return }
        phase = .checking
        result = nil
        report = nil
        errorLine = nil
        errorSummary = nil
        let folder = PracticeEnvironment.labsFolder
        let outcome = await runner.run(
            arguments: [lab.checkFile, document.url.path], in: folder, timeout: Self.checkTimeout,
            extraEnvironment: ["CREATOR_LABS_RESULTS": folder.appendingPathComponent(CreatorLabResults.fileName).path]
        )
        finish(outcome, fileName: document.url.lastPathComponent)
        report = CreatorCheckOutput.parse(outcome.stdout)
        reloadLabs()
    }

    private func finish(_ outcome: PythonRunResult, fileName: String) {
        result = outcome
        phase = .idle
        let errors = outcome.stderr.isEmpty ? outcome.stdout : outcome.stderr
        errorLine = outcome.succeeded ? nil : PythonTraceback.errorLine(in: errors, fileName: fileName)
        errorSummary = outcome.succeeded ? nil : PythonTraceback.summary(errors)
    }

    func stop() { runner.cancel() }

    func reloadLabs() {
        let url = PracticeEnvironment.labsFolder.appendingPathComponent(CreatorLabResults.fileName)
        labSummaries = CreatorLabResults.summaries((try? Data(contentsOf: url)).map(CreatorLabResults.parse) ?? [])
    }

    func refreshFiles() {
        files = PracticeFiles.list(root: PracticeEnvironment.practiceRoot)
    }

    func restore(_ language: AppLanguage) {
        guard document == nil else { return }
        if let path = UserDefaults.standard.string(forKey: Self.lastFileKey), FileManager.default.fileExists(atPath: path) {
            let url = URL(fileURLWithPath: path)
            if let lab = CreatorLabCatalog.labs.first(where: { PracticeEnvironment.labsFolder.appendingPathComponent($0.blank).path == path }) {
                open(.lab(lab, language))
            } else {
                open(.file(url, language))
            }
        } else {
            open(.scratch(language))
        }
    }

    func loadInterpreter() async {
        guard interpreter == nil else { return }
        let path = PythonRunner.interpreter()
        let outcome = await PythonRunner().run(arguments: ["-c", "import sys; print(sys.version.split()[0])"],
                                               in: FileManager.default.temporaryDirectory, timeout: 10)
        let version = outcome.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        interpreter = outcome.succeeded && !version.isEmpty ? "python3 \(version) · \(path)" : "✗ \(path)"
    }
}

struct PracticeView: View {
    @EnvironmentObject private var store: LearningStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = PracticeModel()
    @AppStorage("code.practice.fontSize") private var fontSize = 13.0
    @State private var assistantRequest: LessonAssistantRequest?

    /// The file to open first; nil restores the last one. / Какой файл открыть; nil — последний открытый.
    var initial: PracticeDocument?
    /// The sheet from a lesson shows only the editor and a Close button. / Окно из урока: только редактор и «Закрыть».
    var asSheet = false

    private func text(_ key: String) -> String { L10n.text(key, store.language) }
    private func format(_ key: String, _ values: String...) -> String { String(format: text(key), arguments: values.map { $0 as CVarArg }) }
    private func seconds(_ value: Double) -> String { L10n.number(value, fractionDigits: value < 10 ? 2 : 1, store.language) }

    var body: some View {
        HStack(spacing: 0) {
            if !asSheet {
                library.frame(width: 270)
                Divider()
            }
            VStack(spacing: 0) {
                header
                Divider()
                VSplitView {
                    CodeEditorView(text: $model.text, errorLine: model.errorLine, fontSize: CGFloat(fontSize),
                                   isEditable: model.document != nil)
                        .frame(minHeight: 200)
                    outputPane.frame(minHeight: 120, idealHeight: 220)
                }
            }
        }
        .background(AppPalette.canvas.color)
        .frame(minWidth: asSheet ? 900 : 700, minHeight: asSheet ? 640 : 480)
        .onAppear {
            if let initial {
                if let lab = initial.lab { model.openLab(lab, language: store.language) } else { model.open(initial) }
            } else {
                model.restore(store.language)
            }
            model.reloadLabs()
        }
        .task { await model.loadInterpreter() }
        .onDisappear { model.save(); model.stop() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in model.save() }
        .sheet(item: $assistantRequest) { request in
            LessonAssistantView(request: request).environmentObject(store)
        }
    }

    // MARK: Library / Список слева

    private var library: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                libraryRow(title: text("code.scratch.title"), subtitle: nil, symbol: "square.and.pencil",
                           selected: model.document?.kind == .scratch, identifier: "practice.scratch") {
                    model.open(.scratch(store.language))
                }
                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle(text("code.library.labs"))
                    ForEach(CreatorLabCatalog.labs) { lab in
                        libraryRow(title: AIPathCatalog.topics[lab.lesson]?.name.value(in: store.language) ?? lab.lesson,
                                   subtitle: text(lab.taskKey), symbol: nil, status: labStatus(lab),
                                   selected: model.document?.lab == lab, identifier: "practice.lab.\(lab.lesson)") {
                            model.openLab(lab, language: store.language)
                        }
                    }
                    Text(format("code.library.labsFolder", PracticeEnvironment.tilde(PracticeEnvironment.labsFolder)))
                        .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                }
                VStack(alignment: .leading, spacing: 6) {
                    sectionTitle(text("code.library.files"))
                    let files = model.files.filter { $0.lastPathComponent != PracticeFiles.scratchName }
                    if files.isEmpty {
                        Text(text("code.library.noFiles")).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(files, id: \.path) { url in
                        let folder = url.deletingLastPathComponent().lastPathComponent
                        libraryRow(title: url.deletingPathExtension().lastPathComponent, subtitle: folder, symbol: "doc.text",
                                   selected: model.document?.url.path == url.path, identifier: nil) {
                            model.open(.file(url, store.language))
                        }
                    }
                    Text(PracticeEnvironment.tilde(PracticeEnvironment.practiceRoot))
                        .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                }
                if let interpreter = model.interpreter {
                    Label(interpreter, systemImage: "terminal")
                        .font(.caption2).foregroundStyle(.secondary).textSelection(.enabled)
                        .accessibilityIdentifier("practice.interpreter")
                }
            }
            .padding(12)
        }
        .background(AppPalette.sidebar.color)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
    }

    private enum LabStatus { case passed, tried, new }

    private func labStatus(_ lab: CreatorLab) -> LabStatus {
        guard let summary = model.labSummaries[lab.lesson] else { return .new }
        return summary.everPassed ? .passed : .tried
    }

    private func libraryRow(title: String, subtitle: String?, symbol: String?, status: LabStatus? = nil,
                            selected: Bool, identifier: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 8) {
                Group {
                    switch status {
                    case .passed?: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .tried?: Image(systemName: "xmark.circle").foregroundStyle(.orange)
                    case .new?: Image(systemName: "circle").foregroundStyle(.secondary)
                    case nil: Image(systemName: symbol ?? "doc").foregroundStyle(AppPalette.accent.color)
                    }
                }
                .frame(width: 16)
                .accessibilityLabel(status.map { text($0 == .passed ? "code.lab.passed" : $0 == .tried ? "code.lab.tried" : "code.lab.new") } ?? "")
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(2).multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(selected ? AppPalette.selection.color : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier ?? "practice.file")
    }

    // MARK: Header / Заголовок

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.document?.title ?? text("code.empty")).font(.title3.weight(.semibold)).lineLimit(1)
                    if let document = model.document {
                        HStack(spacing: 6) {
                            Text(PracticeEnvironment.tilde(document.url)).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle).textSelection(.enabled)
                            saveState
                        }
                    }
                }
                Spacer(minLength: 8)
                if asSheet {
                    Button(text("assistant.close")) { model.save(); dismiss() }.keyboardShortcut(.cancelAction)
                }
            }
            // Full labels when they fit, icons with tooltips in a narrow window.
            // Подписи целиком, когда помещаются; в узком окне — значки с подсказками.
            ViewThatFits(in: .horizontal) {
                toolbar(compact: false)
                toolbar(compact: true)
            }
            if let task = model.document?.task, !task.isEmpty, model.document?.lab != nil {
                Text(task).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let notice = model.notice {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text(notice).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button { model.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(AppPalette.card.color)
    }

    /// Run / Check / Stop, Check my code, font size and Finder. / Запуск, проверка, «Проверь мой код», шрифт, Finder.
    private func toolbar(compact: Bool) -> some View {
        HStack(spacing: 8) {
            if model.phase == .idle {
                Button { Task { await model.run() } } label: { Label(text("code.run"), systemImage: "play.fill") }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut("r", modifiers: .command)
                    .help(text("code.run.help"))
                    .accessibilityIdentifier("practice.run")
                    .disabled(model.document == nil)
                if let lab = model.document?.lab {
                    Button { Task { await model.check(language: store.language) } } label: {
                        Label(text("code.check"), systemImage: "checkmark.seal")
                    }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .help(format("code.check.help", lab.checkFile))
                    .accessibilityIdentifier("practice.check")
                }
            } else {
                Button(role: .cancel) { model.stop() } label: { Label(text("code.stop"), systemImage: "stop.fill") }
                    .keyboardShortcut(".", modifiers: .command)
                    .accessibilityIdentifier("practice.stop")
                ProgressView().controlSize(.small)
            }
            Button { assistantRequest = reviewRequest() } label: {
                Label(text("code.review"), systemImage: "bubble.left.and.bubble.right")
                    .labelStyle(compact ? AnyLabelStyle(.iconOnly) : AnyLabelStyle(.titleAndIcon))
            }
            .help(text("code.review.help"))
            .disabled(model.document == nil || model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("practice.review")
            Spacer(minLength: 8)
            Button { fontSize = max(10, fontSize - 1) } label: { Image(systemName: "textformat.size.smaller") }
                .help(text("code.fontSmaller")).keyboardShortcut("-", modifiers: .command)
            Button { fontSize = min(24, fontSize + 1) } label: { Image(systemName: "textformat.size.larger") }
                .help(text("code.fontLarger")).keyboardShortcut("=", modifiers: .command)
            if let url = model.document?.url {
                Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: { Image(systemName: "folder") }
                    .help(text("code.reveal"))
            }
        }
        .buttonStyle(.bordered)
        .fixedSize(horizontal: !compact, vertical: false)
    }

    @ViewBuilder
    private var saveState: some View {
        if let error = model.saveError {
            Label(format("code.saveFailed", error), systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
        } else {
            Text(text(model.isSaved ? "code.saved" : "code.saving")).font(.caption).foregroundStyle(.secondary)
                .accessibilityIdentifier("practice.saveState")
        }
    }

    // MARK: Output / Вывод

    private var outputPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            statusLine
            if let report = model.report { checkList(report) }
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if let result = model.result {
                        if !result.stdout.isEmpty {
                            Text(result.stdout).foregroundStyle(CodeEditorTheme.text.color)
                        }
                        if !result.stderr.isEmpty {
                            Text(result.stderr).foregroundStyle(Color(nsColor: .systemRed))
                        }
                        if result.stdout.isEmpty && result.stderr.isEmpty, case .finished = result.ending {
                            Text(text("code.status.noOutput")).foregroundStyle(.secondary)
                        }
                    }
                }
                .font(.system(size: max(11, fontSize - 1), design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("practice.output")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppPalette.inset.color)
    }

    @ViewBuilder
    private var statusLine: some View {
        Group {
            switch model.phase {
            case .running: Label(text("code.status.running"), systemImage: "hourglass")
            case .checking: Label(text("code.status.checking"), systemImage: "hourglass")
            case .idle:
                if let result = model.result {
                    finishedStatus(result)
                } else {
                    Label(text("code.status.idle"), systemImage: "play.circle").foregroundStyle(.secondary)
                }
            }
        }
        .font(.callout)
        .accessibilityIdentifier("practice.status")
    }

    @ViewBuilder
    private func finishedStatus(_ result: PythonRunResult) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            switch result.ending {
            case .finished(0):
                Label(format("code.status.done", seconds(result.seconds)), systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            case .finished(let code):
                let line = model.errorLine.map { format("code.status.errorLine", String($0)) + " · " } ?? ""
                Label(line + (model.errorSummary ?? format("code.status.exit", String(code), seconds(result.seconds))),
                      systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(nsColor: .systemRed))
                if model.errorSummary != nil {
                    Text(format("code.status.exit", String(code), seconds(result.seconds))).font(.caption).foregroundStyle(.secondary)
                }
            case .timedOut:
                Label(format("code.status.timeout", seconds(model.report == nil ? PracticeModel.runTimeout : PracticeModel.checkTimeout)),
                      systemImage: "clock.badge.exclamationmark").foregroundStyle(.orange)
            case .cancelled:
                Label(text("code.status.cancelled"), systemImage: "stop.circle").foregroundStyle(.secondary)
            case .failedToStart(let reason):
                Label(format("code.status.failed", reason), systemImage: "xmark.octagon").foregroundStyle(Color(nsColor: .systemRed))
            }
            if result.truncated {
                Text(text("code.status.truncated")).font(.caption).foregroundStyle(.orange)
            }
        }
    }

    private func checkList(_ report: CreatorCheckReport) -> some View {
        let russian = store.language == .ru
        return VStack(alignment: .leading, spacing: 4) {
            if report.lines.isEmpty {
                Text(text("code.check.noLines")).font(.callout).foregroundStyle(.orange)
            } else {
                Text(format("code.check.passed", String(report.passed), String(report.lines.count))
                     + " · " + text(report.allPassed ? "code.check.allPassed" : "code.check.fixFirst"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(report.allPassed ? Color.green : Color.primary)
                    .accessibilityIdentifier("practice.checkSummary")
                ForEach(Array(report.lines.enumerated()), id: \.offset) { _, line in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(line.passed ? "✓" : "✗").bold().foregroundStyle(line.passed ? Color.green : Color(nsColor: .systemRed))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(line.text(russian: russian)).font(.callout)
                            if !line.detail.isEmpty {
                                Text(line.detail).font(.caption.monospaced()).foregroundStyle(.secondary).textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(AppPalette.card.color))
    }

    // MARK: Assistant / Ассистент

    private func reviewRequest() -> LessonAssistantRequest? {
        guard let document = model.document else { return nil }
        model.save()
        let task = document.task.isEmpty ? text("code.review.noTask") : document.task
        let prompt = PracticeReviewPrompt.make(template: text("code.review.prompt"), task: task,
                                               output: model.output, outputTemplate: text("code.review.output"))
        let explain: String
        if document.context.isSkillbox {
            explain = format("skillbox.explain.prompt", document.context.title, document.context.course,
                             document.context.track.isEmpty ? "Skillbox" : document.context.track)
        } else {
            explain = AssistantExplainPrompt.make(template: text("assistant.explain.prompt"), title: document.context.title,
                                                  subject: document.context.subject, goal: document.context.goal)
        }
        return LessonAssistantRequest(context: document.context, explainPrompt: explain,
                                      initialCode: PracticeReviewPrompt.code(model.text), checkPrompt: prompt, startCheckingCode: true)
    }
}

/// Switches a label between text and icon at run time. / Переключает подпись между текстом и значком.
private struct AnyLabelStyle: LabelStyle {
    private let make: (Configuration) -> AnyView
    init<S: LabelStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
