import AppKit
import SwiftUI

// The Creator's workshop: chat with the assistant (it knows the path and progress), voice, Mac actions with
// confirmation, CLI agents in ~/Творец with live output, the model council and the folder with mentor rules.
// One model is shared by the main window, the menu bar panel and the hot-key panel.
// Мастерская Творца: чат с ассистентом (знает путь и прогресс), голос, действия на Mac с подтверждением,
// агенты CLI в ~/Творец с живым выводом, совет моделей и папка с правилами наставника.
// Одна модель на окно, панель в строке меню и панель по горячей клавише.

// MARK: - Backend client / клиент backend

struct WorkshopNextStep: Encodable, Equatable {
    var lesson = ""
    var module = ""
    var step = ""
    var why = ""
    var finished: Int?
    var total: Int?
}

private struct WorkshopAskBody: Encodable {
    let language: String
    let question: String
    let history: [AssistantTurn]
    let nextStep: WorkshopNextStep?
    let labs: [String]
    let voice: Bool

    enum CodingKeys: String, CodingKey {
        case language, question, history, labs, voice
        case nextStep = "next_step"
    }
}

private struct WorkshopCouncilBody: Encodable {
    let language: String
    let question: String
    let members: Int
    let nextStep: WorkshopNextStep?

    enum CodingKeys: String, CodingKey {
        case language, question, members
        case nextStep = "next_step"
    }
}

struct CouncilEvent: Decodable {
    struct Member: Decodable { let provider: String; let label: String; let model: String }
    let type: String
    var provider: String?
    var label: String?
    var model: String?
    var content: String?
    var answer: String?
    var reason: String?
    var phase: String?
    var members: [Member]?

    static func parse(line: String) -> CouncilEvent? {
        guard line.hasPrefix("data:"), let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CouncilEvent.self, from: data)
    }
}

extension OrchestratorClient {
    static func streamLines(path: String, body: Data, onLine: @MainActor (String) -> Void) async throws {
        guard let url = URL(string: LearningStore.orchestratorBaseURL + path) else { throw ClientError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 900
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = body
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { throw ClientError.unavailable }
        for try await line in bytes.lines {
            try Task.checkCancellation()
            await onLine(line)
        }
    }

    static func obsidianNoteExists(path: String) async -> Bool? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))
        let encoded = path.split(separator: "/").map { String($0).addingPercentEncoding(withAllowedCharacters: allowed) ?? "" }.joined(separator: "/")
        guard let url = URL(string: LearningStore.orchestratorBaseURL + "/obsidian/read/" + encoded) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        guard let (_, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return false }
        return (200..<300).contains(http.statusCode) ? true : nil
    }
}

// MARK: - Model / модель

struct WorkshopMessage: Codable, Identifiable, Equatable {
    var id = UUID()
    let role: String
    let text: String
    var answeredBy: String?
    var model: String?
    var voice = false
    var date = Date()
}

struct WorkshopActionItem: Identifiable, Equatable {
    enum State: Equatable { case proposed, running, done(String), failed(String), cancelled }
    let id = UUID()
    let messageID: UUID
    let action: WorkshopAction
    var state: State = .proposed
    var risk: WorkshopRisk { WorkshopSafety.risk(of: action) }
}

struct CouncilMemberState: Identifiable, Equatable {
    enum State: Equatable { case thinking, done, failed(String) }
    var id: String { provider }
    let provider: String
    let label: String
    var model: String
    var text = ""
    var state: State = .thinking
}

enum WorkshopTab: String, CaseIterable, Identifiable {
    case chat, agents, council, folder
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .agents: return "terminal"
        case .council: return "person.3"
        case .folder: return "folder"
        }
    }
}

/// Real Mac access for the executor. / Настоящий доступ к Mac для исполнителя.
struct MacWorkshopSystem: WorkshopSystem {
    let language: AppLanguage

    func openApplication(_ name: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", name]
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    func open(_ target: String) -> Bool {
        if let url = URL(string: target), let scheme = url.scheme, scheme.count > 1 { return NSWorkspace.shared.open(url) }
        guard FileManager.default.fileExists(atPath: target) else { return false }
        return NSWorkspace.shared.open(URL(fileURLWithPath: target))
    }

    func run(_ executable: String, _ arguments: [String], directory: URL) async -> (status: Int32, output: String) {
        let box = TextBox()
        let ending: LiveProcess.Ending = await withCheckedContinuation { continuation in
            LiveProcess().start(executable: executable, arguments: arguments, directory: directory,
                                environment: WorkshopAgents.environment(base: ProcessInfo.processInfo.environment, home: NSHomeDirectory()),
                                timeout: 120, onOutput: { box.add($0) }, onExit: { continuation.resume(returning: $0) })
        }
        let output = String(AgentOutputText.clean(box.text).prefix(20_000))
        if let failure = ending.failedToStart { return (-1, failure) }
        return (ending.timedOut ? -2 : ending.status ?? -1, output)
    }

    /// osascript shows the macOS password window; the password goes to macOS, never to this app.
    /// osascript показывает системное окно пароля; пароль получает macOS, а не приложение.
    func runAdmin(_ appleScript: String) async -> (ok: Bool, output: String) {
        let result = await run("/usr/bin/osascript", ["-e", appleScript], directory: URL(fileURLWithPath: NSHomeDirectory()))
        return (result.status == 0, result.output)
    }

    func writeNote(path: String, text: String) async -> Bool {
        do {
            try await OrchestratorClient.saveObsidianNote(path: path, content: text)
            return true
        } catch {
            return false
        }
    }

    func runCheck(lab id: String) async -> (ok: Bool, output: String) {
        let key = id.lowercased()
        guard let lab = CreatorLabCatalog.labs.first(where: { $0.lesson == key || $0.lesson.hasPrefix(key) || $0.blank.hasPrefix(key) }) else {
            return (false, L10n.text("workshop.action.noLab", language) + " " + CreatorLabCatalog.labs.map(\.lesson).joined(separator: ", "))
        }
        guard let source = PracticeEnvironment.labsSource else { return (false, L10n.text("code.lab.missing", language)) }
        let folder = PracticeEnvironment.labsFolder
        do { try CreatorLabCatalog.copyMissing(from: source, to: folder) } catch { return (false, error.localizedDescription) }
        let outcome = await PythonRunner().run(
            arguments: [lab.checkFile, folder.appendingPathComponent(lab.blank).path], in: folder, timeout: 120,
            extraEnvironment: ["CREATOR_LABS_RESULTS": folder.appendingPathComponent(CreatorLabResults.fileName).path]
        )
        let report = CreatorCheckOutput.parse(outcome.stdout)
        let summary = String(format: L10n.text("workshop.action.checkSummary", language), lab.lesson, String(report.passed), String(report.lines.count))
        return (report.allPassed, summary + "\n" + String((outcome.stdout + outcome.stderr).suffix(3000)))
    }
}

final class TextBox {
    private let lock = NSLock()
    private var value = ""
    var text: String { lock.lock(); defer { lock.unlock() }; return value }
    func add(_ text: String) { lock.lock(); value += text; lock.unlock() }
}

@MainActor
final class WorkshopModel: ObservableObject {
    // Chat / чат
    @Published private(set) var messages: [WorkshopMessage] = []
    @Published private(set) var actionItems: [WorkshopActionItem] = []
    @Published private(set) var current = AssistantAnswerState()
    @Published private(set) var isAnswering = false
    @Published var draft = ""
    @Published var pendingConfirmation: WorkshopActionItem?
    @Published var notice: String?
    @Published var tab: WorkshopTab = .chat
    @Published var speakAnswers = UserDefaults.standard.object(forKey: "workshop.speakAnswers") as? Bool ?? true {
        didSet { UserDefaults.standard.set(speakAnswers, forKey: "workshop.speakAnswers") }
    }
    let voice = WorkshopVoice()
    private var askTask: Task<Void, Never>?

    // Agents / агенты
    @Published var agent: WorkshopAgent = .claude
    @Published var agentTask = ""
    @Published var agentFolder: URL
    @Published private(set) var agentOutput = ""
    @Published private(set) var agentRunning = false
    @Published private(set) var agentStatus: String?
    private let agentProcess = LiveProcess()
    private var agentLines = LiveTextBuffer()

    // Council / совет
    @Published var councilQuestion = ""
    @Published var councilSize = 3
    @Published private(set) var councilMembers: [CouncilMemberState] = []
    @Published private(set) var councilSummary = AssistantAnswerState()
    @Published private(set) var councilNote: String?
    @Published private(set) var councilRunning = false
    private var councilTask: Task<Void, Never>?

    // Folder / папка
    @Published private(set) var folderReport: String?

    static var root: URL { CreatorWorkspace.root(environment: ProcessInfo.processInfo.environment, home: FileManager.default.homeDirectoryForCurrentUser) }

    static var conversationURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/coli-dev-workshop/conversation.json")
    }

    init() {
        agentFolder = Self.root
        if let data = try? Data(contentsOf: Self.conversationURL),
           let saved = try? JSONDecoder().decode([WorkshopMessage].self, from: data) {
            messages = Array(saved.suffix(200))
        }
    }

    // MARK: Chat

    static func nextStep(store: LearningStore) -> WorkshopNextStep {
        let language = store.language
        let available = AIPathCatalog.available
        let finished = available.filter { store.isComplete(lessonID: $0.lessonID) }.count
        var step = WorkshopNextStep(finished: finished, total: available.count)
        if let next = AIPathCatalog.next(completed: store.completedLessonIDs, available: Set(available.map(\.resource))) {
            step.lesson = AIPathCatalog.topics[next.resource]?.name.value(in: language) ?? next.resource
            if let module = AIPathCatalog.module(of: next) { step.module = "\(module.number) · \(L10n.text(module.titleKey, language))" }
            if let pathStep = AIPathCatalog.step(of: next) {
                step.step = String(pathStep.number)
                step.why = L10n.text(pathStep.whyKey, language)
            }
        }
        return step
    }

    func send(store: LearningStore, voiceQuestion: String? = nil) {
        let question = (voiceQuestion ?? draft).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !isAnswering else { return }
        if voiceQuestion == nil { draft = "" }
        let byVoice = voiceQuestion != nil
        let history = messages.suffix(16).map { AssistantTurn(role: $0.role, content: $0.text) }
        messages.append(WorkshopMessage(role: "user", text: question, voice: byVoice))
        save()
        current = AssistantAnswerState()
        isAnswering = true
        let language = store.language
        let body = WorkshopAskBody(language: language.rawValue, question: question, history: history,
                                   nextStep: Self.nextStep(store: store), labs: CreatorLabCatalog.labs.map(\.lesson), voice: byVoice)
        askTask = Task {
            do {
                let data = try JSONEncoder().encode(body)
                try await OrchestratorClient.streamLines(path: "/workshop/ask/stream", body: data) { line in
                    if let event = AssistantStreamEvent.parse(line: line) { self.current.apply(event) }
                }
            } catch is CancellationError {
            } catch {
                if current.error == nil { current.error = L10n.text("workshop.chat.offline", language) }
            }
            finishAnswer(language: language, speak: byVoice)
        }
    }

    private func finishAnswer(language: AppLanguage, speak: Bool) {
        isAnswering = false
        if let error = current.error, current.text.isEmpty {
            notice = error
            return
        }
        let reply = current.text
        guard !reply.isEmpty else { return }
        let split = WorkshopActionParser.split(reply)
        let message = WorkshopMessage(role: "assistant", text: split.text.isEmpty ? reply : split.text,
                                      answeredBy: current.answeredBy, model: current.model)
        messages.append(message)
        current = AssistantAnswerState()
        save()
        for action in split.actions {
            let item = WorkshopActionItem(messageID: message.id, action: action)
            actionItems.append(item)
            // Safe actions run at once; risky ones wait for "yes". / Безопасное — сразу, рискованное ждёт «да».
            if !item.risk.needsConfirmation { run(item.id, confirmed: false, language: language) }
        }
        if speak && speakAnswers { voice.speak(message.text, language: language) }
    }

    func stopAnswer() { askTask?.cancel() }

    func run(_ id: UUID, confirmed: Bool, language: AppLanguage) {
        guard let index = actionItems.firstIndex(where: { $0.id == id }) else { return }
        let item = actionItems[index]
        actionItems[index].state = .running
        let executor = WorkshopExecutor(system: MacWorkshopSystem(language: language), workFolder: Self.existingRoot)
        Task {
            let outcome = await executor.execute(item.action, confirmed: confirmed)
            guard let index = actionItems.firstIndex(where: { $0.id == id }) else { return }
            switch outcome {
            case .done(let text): actionItems[index].state = .done(text)
            case .failed(let text): actionItems[index].state = .failed(text)
            case .needsConfirmation: actionItems[index].state = .proposed
            }
        }
    }

    func cancel(_ id: UUID) {
        if let index = actionItems.firstIndex(where: { $0.id == id }) { actionItems[index].state = .cancelled }
    }

    /// The work folder if it exists, otherwise home (actions must not fail before the folder is made).
    static var existingRoot: URL {
        FileManager.default.fileExists(atPath: root.path) ? root : FileManager.default.homeDirectoryForCurrentUser
    }

    func actions(for message: WorkshopMessage) -> [WorkshopActionItem] { actionItems.filter { $0.messageID == message.id } }

    func clear() {
        messages = []
        actionItems = []
        save()
    }

    private func save() {
        let url = Self.conversationURL
        let snapshot = Array(messages.suffix(200))
        Task.detached(priority: .utility) {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(snapshot) { try? data.write(to: url, options: .atomic) }
        }
    }

    func exportToObsidian(language: AppLanguage) {
        guard !messages.isEmpty else { return }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let path = "Творец/Разговоры/\(formatter.string(from: Date())).md"
        let you = L10n.text("workshop.chat.you", language)
        var lines = ["# " + L10n.text("workshop.title", language), ""]
        for message in messages {
            if message.role == "user" {
                lines += ["## \(you)\(message.voice ? " 🎙" : ""): \(message.text)", ""]
            } else {
                lines += [message.text, ""]
                if let by = message.answeredBy { lines += ["*\(by) · \(message.model ?? "")*", ""] }
            }
        }
        let note = lines.joined(separator: "\n")
        Task {
            do {
                try await OrchestratorClient.saveObsidianNote(path: path, content: note)
                notice = String(format: L10n.text("module.obsidianSaved", language), path)
            } catch {
                notice = L10n.text("module.obsidianSaveFailed", language)
            }
        }
    }

    // MARK: Voice

    func startListening(language: AppLanguage) {
        Task { await voice.start(language: language) }
    }

    func stopListeningAndAsk(store: LearningStore) {
        Task {
            let heard = await voice.stop()
            if !heard.isEmpty { send(store: store, voiceQuestion: heard) }
        }
    }

    // MARK: Agents

    func agentCommand() -> WorkshopAgentCommand? {
        WorkshopAgents.command(for: agent, task: WorkshopAgents.task(agentTask, directory: agentFolder, root: Self.root, russian: true),
                               directory: agentFolder, root: Self.root, home: NSHomeDirectory())
    }

    func runAgent(language: AppLanguage) {
        guard !agentRunning else { return }
        let task = agentTask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard agent == .freebuff || !task.isEmpty else { return }
        guard FileManager.default.fileExists(atPath: agentFolder.path) else {
            agentStatus = L10n.text("workshop.agents.noFolder", language)
            return
        }
        let text = WorkshopAgents.task(task, directory: agentFolder, root: Self.root, russian: language == .ru)
        guard let command = WorkshopAgents.command(for: agent, task: text, directory: agentFolder, root: Self.root, home: NSHomeDirectory()) else {
            agentStatus = String(format: L10n.text("workshop.agents.missing", language), agent.title)
            return
        }
        if command.interactive {
            openInTerminal(command, language: language)
            return
        }
        agentOutput = "$ \(agent.title) · \(PracticeEnvironment.tilde(agentFolder))\n"
        agentLines = LiveTextBuffer()
        agentRunning = true
        agentStatus = nil
        let isClaude = agent == .claude
        agentProcess.start(
            executable: command.executable, arguments: command.arguments, directory: command.directory,
            environment: WorkshopAgents.environment(base: ProcessInfo.processInfo.environment, home: NSHomeDirectory()),
            timeout: 30 * 60,
            onOutput: { [weak self] chunk in
                Task { @MainActor in self?.appendAgent(chunk, claude: isClaude) }
            },
            onExit: { [weak self] ending in
                Task { @MainActor in self?.agentFinished(ending, claude: isClaude, language: language) }
            }
        )
    }

    private func appendAgent(_ chunk: String, claude: Bool) {
        let clean = AgentOutputText.clean(chunk)
        if claude {
            for line in agentLines.lines(from: clean) {
                if let shown = AgentOutputText.claudeLine(line) { agentOutput += shown + "\n" }
            }
        } else {
            agentOutput += clean
        }
        if agentOutput.count > 300_000 { agentOutput = String(agentOutput.suffix(250_000)) }
    }

    private func agentFinished(_ ending: LiveProcess.Ending, claude: Bool, language: AppLanguage) {
        if let rest = agentLines.flushLine() {
            agentOutput += (claude ? AgentOutputText.claudeLine(rest) ?? "" : rest) + "\n"
        }
        agentRunning = false
        if let failure = ending.failedToStart {
            agentStatus = failure
        } else if ending.stopped {
            agentStatus = L10n.text("workshop.agents.stopped", language)
        } else if ending.timedOut {
            agentStatus = L10n.text("workshop.agents.timedOut", language)
        } else {
            agentStatus = String(format: L10n.text("workshop.agents.exit", language), String(ending.status ?? -1))
        }
    }

    func stopAgent() { agentProcess.stop() }

    private func openInTerminal(_ command: WorkshopAgentCommand, language: AppLanguage) {
        let script = ToolLaunch.scriptText(directory: command.directory.path, executable: command.executable,
                                           arguments: command.arguments, missingFolderMessage: L10n.text("workshop.agents.noFolder", language))
        do {
            let url = try ToolLaunch.writeScript(script, toolID: agent.rawValue, in: FileManager.default.temporaryDirectory)
            NSWorkspace.shared.open(url)
            agentStatus = String(format: L10n.text("workshop.agents.inTerminal", language), agent.title)
        } catch {
            agentStatus = error.localizedDescription
        }
    }

    var agentSubfolders: [URL] {
        let root = Self.root
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        let folders = names.sorted().compactMap { name -> URL? in
            guard !name.hasPrefix(".") else { return nil }
            let url = root.appendingPathComponent(name, isDirectory: true)
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue ? url : nil
        }
        return [root] + folders
    }

    /// An empty temporary folder inside ~/Творец for a safe first try. / Пустая временная папка внутри ~/Творец.
    func makeTemporaryAgentFolder(language: AppLanguage) {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let url = Self.root.appendingPathComponent("Проекты/tmp-agent-\(formatter.string(from: Date()))", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            agentFolder = url
        } catch {
            agentStatus = error.localizedDescription
        }
    }

    // MARK: Council

    func askCouncil(store: LearningStore) {
        let question = councilQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !councilRunning else { return }
        councilMembers = []
        councilSummary = AssistantAnswerState()
        councilNote = nil
        councilRunning = true
        let language = store.language
        let body = WorkshopCouncilBody(language: language.rawValue, question: question, members: councilSize,
                                       nextStep: Self.nextStep(store: store))
        councilTask = Task {
            do {
                let data = try JSONEncoder().encode(body)
                try await OrchestratorClient.streamLines(path: "/workshop/council/stream", body: data) { line in
                    self.applyCouncil(line: line, language: language)
                }
            } catch is CancellationError {
            } catch {
                councilNote = L10n.text("workshop.chat.offline", language)
            }
            councilRunning = false
        }
    }

    private func applyCouncil(line: String, language: AppLanguage) {
        guard let event = CouncilEvent.parse(line: line) else { return }
        if event.phase == "summary" {
            if let summary = AssistantStreamEvent.parse(line: line) { councilSummary.apply(summary) }
            return
        }
        switch event.type {
        case "members":
            councilMembers = (event.members ?? []).map { CouncilMemberState(provider: $0.provider, label: $0.label, model: $0.model) }
        case "member_token":
            if let index = councilMembers.firstIndex(where: { $0.provider == event.provider }) { councilMembers[index].text += event.content ?? "" }
        case "member_done":
            if let index = councilMembers.firstIndex(where: { $0.provider == event.provider }) {
                councilMembers[index].text = event.answer ?? councilMembers[index].text
                councilMembers[index].model = event.model ?? councilMembers[index].model
                councilMembers[index].state = .done
            }
        case "member_failed":
            if let index = councilMembers.firstIndex(where: { $0.provider == event.provider }) {
                councilMembers[index].state = .failed(L10n.text(AssistantReason.key(event.reason ?? "failed"), language))
            }
        case "single":
            councilNote = L10n.text("workshop.council.single", language)
        case "error":
            councilNote = L10n.text(event.reason == "no_members" ? "workshop.council.noMembers" : "workshop.council.noAnswers", language)
        default:
            break
        }
    }

    func stopCouncil() { councilTask?.cancel() }

    // MARK: Folder and Obsidian

    func prepareFolder(language: AppLanguage) {
        let titles = AIPathCatalog.modules.map { ($0.number, L10n.text($0.titleKey, .ru)) }
        do {
            let created = try CreatorWorkspace.prepare(root: Self.root, moduleTitles: titles)
            folderReport = created.isEmpty
                ? L10n.text("workshop.folder.upToDate", language)
                : String(format: L10n.text("workshop.folder.created", language), created.joined(separator: ", "))
            agentFolder = Self.root
        } catch {
            folderReport = error.localizedDescription
        }
    }

    static let obsidianTemplates: [(path: String, text: String)] = [
        ("Творец/Шаблоны/Шаг дня.md", """
        # Шаг дня — {{date}}

        **Модуль и урок:**
        **Зачем этот шаг:**

        ## Что понял
        -

        ## Что сделал сам («Собери и проверь сам»)
        - [ ] Проверка пройдена

        ## Что осталось непонятным
        -

        ## Вопрос наставнику
        -
        """),
        ("Творец/Шаблоны/Понятие.md", """
        # {{title}}

        **Одной фразой:**
        **Формула или код:**

        ## Интуиция
        Как объяснить другу без формул.

        ## Пример
        Маленький пример, который я посчитал сам.

        ## Где встречается на пути Творца
        - Модуль:

        ## Связанные понятия
        - [[ ]]

        ## Источник
        -
        """),
        ("Творец/Шаблоны/Статья.md", """
        # {{title}}

        **Авторы, год:**
        **Ссылка:**
        **Прочитано:** {{date}}

        ## Вопрос статьи
        Какую задачу решают и почему это важно.

        ## Главная идея
        Одним абзацем, своими словами.

        ## Опыт
        Что сделали, на каких данных, что измерили.

        ## Что повторю сам
        - [ ] Минимальный опыт в ~/Творец/Статьи

        ## Сомнения и вопросы
        -
        """),
        ("Творец/README.md", """
        # Творец

        Хранилище пути Творца: `Шаблоны/` (шаг дня, понятие, статья), `Разговоры/` (из Мастерской), `Заметки/`.
        Чтобы шаблоны появились в меню, в настройках Obsidian → «Шаблоны» укажи папку `Творец/Шаблоны`.
        """),
    ]

    func createObsidianTemplates(language: AppLanguage) {
        Task {
            var created: [String] = []
            for template in Self.obsidianTemplates {
                guard let exists = await OrchestratorClient.obsidianNoteExists(path: template.path) else {
                    folderReport = L10n.text("workshop.folder.obsidianOffline", language)
                    return
                }
                if exists { continue }
                do {
                    try await OrchestratorClient.saveObsidianNote(path: template.path, content: template.text + "\n")
                    created.append(template.path)
                } catch {
                    folderReport = L10n.text("workshop.folder.obsidianOffline", language)
                    return
                }
            }
            folderReport = created.isEmpty
                ? L10n.text("workshop.folder.templatesExist", language)
                : String(format: L10n.text("workshop.folder.templatesCreated", language), created.joined(separator: ", "))
        }
    }
}

// MARK: - Views / виды

struct WorkshopView: View {
    @EnvironmentObject private var store: LearningStore
    @ObservedObject private var model: WorkshopModel
    @ObservedObject private var voice: WorkshopVoice
    let compact: Bool

    init(model: WorkshopModel, compact: Bool = false) {
        _model = ObservedObject(wrappedValue: model)
        _voice = ObservedObject(wrappedValue: model.voice)
        self.compact = compact
    }

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            switch model.tab {
            case .chat: chat
            case .agents: agents
            case .council: council
            case .folder: folder
            }
        }
        .sheet(item: $model.pendingConfirmation) { item in
            WorkshopConfirmSheet(item: item) { confirmed in
                model.pendingConfirmation = nil
                if confirmed { model.run(item.id, confirmed: true, language: store.language) } else { model.cancel(item.id) }
            }
            .environmentObject(store)
        }
        .task { await voice.refreshRoute(language: store.language) }
        .accessibilityIdentifier("workshop.root")
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(AppPalette.accent.color).accessibilityHidden(true)
            if !compact {
                Text(text("workshop.title")).font(.title3.weight(.bold))
            }
            Picker("", selection: $model.tab) {
                ForEach(WorkshopTab.allCases) { tab in
                    if compact {
                        Image(systemName: tab.symbol).help(text("workshop.tab.\(tab.rawValue)")).tag(tab)
                    } else {
                        Label(text("workshop.tab.\(tab.rawValue)"), systemImage: tab.symbol).tag(tab)
                    }
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: compact ? 200 : 460)
            .accessibilityIdentifier("workshop.tabs")
            Spacer()
            Toggle(isOn: $model.speakAnswers) { Image(systemName: model.speakAnswers ? "speaker.wave.2" : "speaker.slash") }
                .toggleStyle(.button)
                .help(text("workshop.voice.speakAnswers"))
                .accessibilityLabel(text("workshop.voice.speakAnswers"))
            if model.tab == .chat {
                Button { model.exportToObsidian(language: store.language) } label: { Image(systemName: "square.and.arrow.down") }
                    .help(text("workshop.chat.export"))
                    .accessibilityLabel(text("workshop.chat.export"))
                    .disabled(model.messages.isEmpty)
                    .accessibilityIdentifier("workshop.export")
                Button { model.clear() } label: { Image(systemName: "trash") }
                    .help(text("workshop.chat.clear"))
                    .accessibilityLabel(text("workshop.chat.clear"))
                    .disabled(model.messages.isEmpty || model.isAnswering)
            }
        }
        .padding(.horizontal, compact ? 10 : 16)
        .padding(.vertical, 10)
    }

    // MARK: Chat

    private var chat: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if model.messages.isEmpty && !model.isAnswering {
                            Text(text("workshop.chat.empty"))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                        }
                        ForEach(model.messages) { message in
                            messageView(message).id(message.id)
                        }
                        if model.isAnswering { answeringView.id("answering") }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(compact ? 10 : 16)
                }
                .onChange(of: model.messages.count) { _ in withAnimation { proxy.scrollTo("bottom") } }
                .onChange(of: model.current.text.count) { _ in proxy.scrollTo("bottom") }
            }
            if let notice = model.notice {
                HStack {
                    Text(notice).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    Button { model.notice = nil } label: { Image(systemName: "xmark") }.buttonStyle(.borderless)
                        .accessibilityLabel(text("workshop.close"))
                }
                .padding(.horizontal, 16).padding(.vertical, 6)
            }
            Divider()
            composer
        }
    }

    private func messageView(_ message: WorkshopMessage) -> some View {
        VStack(alignment: message.role == "user" ? .trailing : .leading, spacing: 6) {
            if message.role == "user" {
                HStack(alignment: .top, spacing: 6) {
                    Spacer(minLength: 40)
                    if message.voice { Image(systemName: "mic.fill").font(.caption).foregroundStyle(.secondary).accessibilityLabel(text("workshop.voice.asked")) }
                    Text(message.text)
                        .textSelection(.enabled)
                        .padding(10)
                        .background(AppPalette.accent.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                }
            } else {
                WorkshopMarkdown(source: message.text)
                if let by = message.answeredBy {
                    Text(String(format: text("assistant.answeredBy"), by, message.model ?? ""))
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(model.actions(for: message)) { item in actionCard(item) }
            }
        }
        .frame(maxWidth: .infinity, alignment: message.role == "user" ? .trailing : .leading)
    }

    private var answeringView: some View {
        VStack(alignment: .leading, spacing: 6) {
            if model.current.text.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(model.current.trying.map { String(format: text("assistant.trying"), $0) } ?? text("workshop.chat.thinking"))
                        .font(.callout).foregroundStyle(.secondary)
                }
            } else {
                WorkshopMarkdown(source: WorkshopActionParser.split(model.current.text).text)
            }
        }
    }

    private func actionCard(_ item: WorkshopActionItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: item.risk.needsConfirmation ? "exclamationmark.shield" : "bolt.fill")
                    .foregroundStyle(item.risk.needsConfirmation ? Color.orange : AppPalette.accent.color)
                    .accessibilityHidden(true)
                Text(text("workshop.action.\(item.action.tool.rawValue)")).font(.callout.weight(.semibold))
                Spacer()
                switch item.state {
                case .proposed:
                    Button(text("workshop.action.run")) {
                        if item.risk.needsConfirmation { model.pendingConfirmation = item } else { model.run(item.id, confirmed: false, language: store.language) }
                    }
                    .accessibilityIdentifier("workshop.action.run")
                    Button(text("workshop.cancel")) { model.cancel(item.id) }
                case .running:
                    ProgressView().controlSize(.small)
                case .done:
                    Label(text("workshop.action.done"), systemImage: "checkmark.circle.fill").foregroundStyle(.green).font(.caption)
                case .failed:
                    Label(text("workshop.action.failed"), systemImage: "xmark.octagon.fill").foregroundStyle(.red).font(.caption)
                case .cancelled:
                    Text(text("workshop.action.cancelled")).font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(item.action.exactCommand)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
            if item.risk.needsConfirmation, item.state == .proposed {
                Text(text(item.risk.reasonKey)).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
            switch item.state {
            case .done(let output), .failed(let output):
                if !output.isEmpty {
                    ScrollView {
                        Text(output).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 160)
                }
            default:
                EmptyView()
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityIdentifier("workshop.action")
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if voice.isListening {
                Text(voice.transcript.isEmpty ? text("workshop.voice.listening") : voice.transcript)
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            voiceStatus
            HStack(alignment: .bottom, spacing: 8) {
                micButton
                TextField(text("workshop.chat.placeholder"), text: $model.draft, axis: .vertical)
                    .lineLimit(1...5)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { model.send(store: store) }
                    .accessibilityIdentifier("workshop.question")
                if model.isAnswering {
                    Button(role: .cancel) { model.stopAnswer() } label: { Image(systemName: "stop.circle") }
                        .accessibilityLabel(text("assistant.stop"))
                } else {
                    Button(text("assistant.send")) { model.send(store: store) }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)
                        .accessibilityIdentifier("workshop.send")
                }
            }
        }
        .padding(compact ? 10 : 14)
    }

    /// Press and hold to talk; release to send. / Нажми и держи, чтобы говорить; отпусти — вопрос уйдёт.
    private var micButton: some View {
        Image(systemName: voice.isListening ? "mic.fill" : "mic")
            .font(.title3)
            .foregroundStyle(voice.isListening ? Color.red : (isVoiceUnavailable ? Color.secondary : AppPalette.accent.color))
            .frame(width: 34, height: 30)
            .background(Color.secondary.opacity(voice.isListening ? 0.2 : 0.1), in: RoundedRectangle(cornerRadius: 7))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !voice.isListening { model.startListening(language: store.language) } }
                    .onEnded { _ in model.stopListeningAndAsk(store: store) }
            )
            .help(text("workshop.voice.hold"))
            .accessibilityLabel(text("workshop.voice.hold"))
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("workshop.mic")
    }

    private var isVoiceUnavailable: Bool {
        if case .unavailable = voice.route { return true }
        return false
    }

    @ViewBuilder private var voiceStatus: some View {
        if case .unavailable(let problem) = voice.route {
            Text(text(problem.key)).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
        }
        if voice.analyzerNeedsDownload {
            HStack(spacing: 8) {
                Text(text("workshop.voice.downloadHint")).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button(voice.isDownloading ? text("workshop.voice.downloading") : text("workshop.voice.download")) {
                    Task { await voice.downloadAnalyzerModel(language: store.language) }
                }
                .disabled(voice.isDownloading)
                .controlSize(.small)
            }
        }
        if let error = voice.errorText {
            Text(error).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Agents

    private var agents: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Picker(text("workshop.agents.agent"), selection: $model.agent) {
                    ForEach(WorkshopAgent.allCases) { agent in Text(agent.title).tag(agent) }
                }
                .frame(maxWidth: 240)
                .accessibilityIdentifier("workshop.agents.picker")
                Picker(text("workshop.agents.folder"), selection: $model.agentFolder) {
                    ForEach(model.agentSubfolders, id: \.self) { url in
                        Text(PracticeEnvironment.tilde(url)).tag(url)
                    }
                    if !model.agentSubfolders.contains(model.agentFolder) {
                        Text(PracticeEnvironment.tilde(model.agentFolder)).tag(model.agentFolder)
                    }
                }
                .accessibilityIdentifier("workshop.agents.folder")
                Button(text("workshop.agents.tempFolder")) { model.makeTemporaryAgentFolder(language: store.language) }
                    .help(text("workshop.agents.tempFolder.help"))
                    .disabled(model.agentRunning)
            }
            Text(text(model.agent.runsNonInteractively ? "workshop.agents.hint" : "workshop.agents.interactiveHint"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .bottom, spacing: 8) {
                TextField(text("workshop.agents.task"), text: $model.agentTask, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.agent == .freebuff)
                    .accessibilityIdentifier("workshop.agents.task")
                if model.agentRunning {
                    Button(role: .destructive) { model.stopAgent() } label: { Label(text("workshop.agents.stop"), systemImage: "stop.fill") }
                        .accessibilityIdentifier("workshop.agents.stop")
                } else {
                    Button { model.runAgent(language: store.language) } label: {
                        Label(text(model.agent.runsNonInteractively ? "workshop.agents.run" : "workshop.agents.openTerminal"), systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.agent.runsNonInteractively && model.agentTask.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("workshop.agents.run")
                }
            }
            ScrollViewReader { proxy in
                ScrollView {
                    Text(model.agentOutput.isEmpty ? text("workshop.agents.outputEmpty") : model.agentOutput)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(model.agentOutput.isEmpty ? .secondary : .primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                    Color.clear.frame(height: 1).id("agentBottom")
                }
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                .onChange(of: model.agentOutput.count) { _ in proxy.scrollTo("agentBottom") }
                .accessibilityIdentifier("workshop.agents.output")
            }
            HStack {
                if model.agentRunning { ProgressView().controlSize(.small) }
                Text(model.agentStatus ?? "").font(.caption).foregroundStyle(.secondary)
                    .accessibilityIdentifier("workshop.agents.status")
            }
        }
        .padding(compact ? 10 : 16)
    }

    // MARK: Council

    private var council: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(text("workshop.council.hint")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(text("workshop.council.placeholder"), text: $model.councilQuestion, axis: .vertical)
                        .lineLimit(1...4)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("workshop.council.question")
                    Picker("", selection: $model.councilSize) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                    .help(text("workshop.council.size"))
                    if model.councilRunning {
                        Button(role: .cancel) { model.stopCouncil() } label: { Image(systemName: "stop.circle") }
                            .accessibilityLabel(text("assistant.stop"))
                    } else {
                        Button(text("workshop.council.ask")) { model.askCouncil(store: store) }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.councilQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("workshop.council.ask")
                    }
                }
                if !model.councilMembers.isEmpty {
                    let columns = [GridItem(.adaptive(minimum: compact ? 260 : 240), spacing: 10, alignment: .top)]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                        ForEach(model.councilMembers) { member in memberCard(member) }
                    }
                }
                if let note = model.councilNote {
                    Text(note).font(.callout).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                }
                if !model.councilSummary.text.isEmpty || model.councilSummary.trying != nil {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(text("workshop.council.summary"), systemImage: "checkmark.seal").font(.headline)
                        if model.councilSummary.text.isEmpty {
                            HStack { ProgressView().controlSize(.small); Text(String(format: text("assistant.trying"), model.councilSummary.trying ?? "")).foregroundStyle(.secondary) }
                        } else {
                            WorkshopMarkdown(source: model.councilSummary.text)
                        }
                        if let by = model.councilSummary.answeredBy {
                            Text(String(format: text("assistant.answeredBy"), by, model.councilSummary.model ?? "")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(AppPalette.accent.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityIdentifier("workshop.council.summary")
                }
            }
            .padding(compact ? 10 : 16)
        }
    }

    private func memberCard(_ member: CouncilMemberState) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(member.label).font(.callout.weight(.semibold))
                Text(member.model).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Spacer()
                switch member.state {
                case .thinking: ProgressView().controlSize(.small)
                case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel(text("workshop.action.done"))
                case .failed: Image(systemName: "xmark.octagon.fill").foregroundStyle(.red).accessibilityLabel(text("workshop.action.failed"))
                }
            }
            if case .failed(let reason) = member.state {
                Text(reason).font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                Text(member.text).font(.callout).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: Folder

    private var folder: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(text("workshop.folder.title")).font(.headline)
                Text(String(format: text("workshop.folder.hint"), PracticeEnvironment.tilde(WorkshopModel.root)))
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    Button { model.prepareFolder(language: store.language) } label: { Label(text("workshop.folder.prepare"), systemImage: "folder.badge.plus") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("workshop.folder.prepare")
                    Button { NSWorkspace.shared.open(WorkshopModel.root) } label: { Label(text("workshop.folder.reveal"), systemImage: "folder") }
                        .disabled(!FileManager.default.fileExists(atPath: WorkshopModel.root.path))
                    Button { model.createObsidianTemplates(language: store.language) } label: { Label(text("workshop.folder.templates"), systemImage: "doc.badge.plus") }
                        .accessibilityIdentifier("workshop.folder.templates")
                }
                if let report = model.folderReport {
                    Text(report).font(.callout).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("workshop.folder.report")
                }
                Divider()
                Text(text("workshop.hotkeys.title")).font(.headline)
                Text(text("workshop.hotkeys.body")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(text("workshop.safety.title")).font(.headline)
                Text(text("workshop.safety.body")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(compact ? 10 : 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Markdown with code blocks, like the lesson assistant. / Markdown с блоками кода, как у ассистента в уроке.
struct WorkshopMarkdown: View {
    let source: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(LessonMarkdown.segments(source).enumerated()), id: \.offset) { _, block in
                switch block {
                case .prose(let prose):
                    Text(LessonMarkdown.attributed(prose)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                case .code(let code):
                    ScrollView(.horizontal) {
                        Text(code).font(.system(.callout, design: .monospaced)).textSelection(.enabled).padding(10)
                    }
                    .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

/// The confirmation window: the exact command first, then "Run" or "Cancel". / Окно подтверждения с точной командой.
struct WorkshopConfirmSheet: View {
    @EnvironmentObject private var store: LearningStore
    let item: WorkshopActionItem
    let decide: (Bool) -> Void

    private func text(_ key: String) -> String { L10n.text(key, store.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(text("workshop.confirm.title"), systemImage: "exclamationmark.shield.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.orange)
            Text(text(item.risk.reasonKey)).fixedSize(horizontal: false, vertical: true)
            Text(text("workshop.confirm.exact")).font(.callout.weight(.semibold))
            ScrollView {
                Text(item.action.exactCommand)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 60, maxHeight: 200)
            .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier("workshop.confirm.command")
            if item.risk == .admin {
                Text(text("workshop.confirm.sudo")).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button(text("workshop.cancel")) { decide(false) }
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("workshop.confirm.cancel")
                Button(text("workshop.confirm.run"), role: .destructive) { decide(true) }
                    .accessibilityIdentifier("workshop.confirm.run")
            }
        }
        .padding(20)
        .frame(width: 480)
    }
}
