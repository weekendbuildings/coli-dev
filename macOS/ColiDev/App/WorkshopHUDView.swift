import AppKit
import Combine
import SwiftUI
import WebKit

// The Creator's workshop as the main HUD: the approved page (Three.js core, sea of particles, Liquid Glass drawn by
// WebGL) in a WKWebView, served from the app bundle with no network. Swift sends the core state, the answer, the path
// progress and Practice; the page sends questions and button presses. The logic without WebKit is in WorkshopHUDCore.swift.
// Мастерская Творца как главный HUD: одобренная страница (ядро на Three.js, море частиц, Liquid Glass через WebGL) в
// WKWebView из ресурсов приложения, без сети. Swift шлёт состояние ядра, ответ, прогресс пути и «Практику»; страница
// шлёт вопросы и нажатия. Логика без WebKit — в WorkshopHUDCore.swift.

// MARK: - Files from the bundle / файлы из приложения

/// Serves `WorkshopHUD/` as creator://hud/…: module scripts need a real origin, file:// has none.
/// Отдаёт `WorkshopHUD/` как creator://hud/…: модульным скриптам нужен настоящий источник, у file:// его нет.
final class HUDSchemeHandler: NSObject, WKURLSchemeHandler {
    private let root: URL?

    init(root: URL?) { self.root = root }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url, let root, let file = HUDResource.file(for: url, root: root),
              let data = try? Data(contentsOf: file) else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }
        let type = HUDResource.mimeType(file)
        let textual = type.hasPrefix("text/") || type == "application/json"
        let headers = ["Content-Type": type + (textual ? "; charset=utf-8" : ""), "Content-Length": String(data.count),
                       "Cache-Control": "no-store"]
        guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else {
            urlSchemeTask.didFailWithError(URLError(.badServerResponse))
            return
        }
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}
}

/// The content controller keeps its handler strongly; this proxy breaks the cycle. / Посредник против цикла ссылок.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?
    init(_ target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(controller, didReceive: message)
    }
}

// MARK: - Bridge / мост

@MainActor
final class HUDBridge: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    static let handlerName = "workshop"
    let webView: WKWebView
    var onMessage: (HUDInbound) -> Void = { _ in }
    private var isReady = false
    private var latest: [String: String] = [:]
    private var sent: [String: String] = [:]
    /// Order on (re)load: data first, so the state line already has its strings. / Порядок при загрузке.
    private let order = ["data", "practice", "answer", "terminal", "confirm", "state"]

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(HUDSchemeHandler(root: Bundle.main.resourceURL?.appendingPathComponent(HUDResource.folderName)),
                                          forURLScheme: HUDResource.scheme)
        configuration.suppressesIncrementalRendering = true
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        configuration.userContentController.add(WeakMessageHandler(self), name: Self.handlerName)
        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) { webView.underPageBackgroundColor = .black }
        webView.load(URLRequest(url: HUDResource.startURL))
    }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        // Only our own page in the main frame. / Только своя страница в главном окне.
        guard message.frameInfo.isMainFrame, message.frameInfo.securityOrigin.protocol == HUDResource.scheme,
              let inbound = HUDInbound.parse(message.body) else { return }
        if inbound == .ready {
            isReady = true
            sent = [:]
            for part in order { if let script = latest[part] { evaluate(part, script) } }
        }
        onMessage(inbound)
    }

    func send<T: Encodable>(_ part: String, _ payload: T) {
        guard let script = HUDScript.receive(payload) else { return }
        latest[part] = script
        if isReady, sent[part] != script { evaluate(part, script) }
    }

    private func evaluate(_ part: String, _ script: String) {
        sent[part] = script
        webView.evaluateJavaScript(script) { _, error in
            if let error { NSLog("Workshop HUD: %@ — %@", part, error.localizedDescription) }
        }
    }

    // Links never leave the page; a crashed page reloads. / Ссылки не уводят со страницы; упавшая страница перезагружается.
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        navigationAction.request.url?.scheme == HUDResource.scheme ? .allow : .cancel
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        isReady = false
        webView.load(URLRequest(url: HUDResource.startURL))
    }
}

private struct HUDWebView: NSViewRepresentable {
    let bridge: HUDBridge
    func makeNSView(context: Context) -> WKWebView { bridge.webView }
    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Controller / контроллер

@MainActor
final class WorkshopHUDController: ObservableObject {
    @Published var agentSheet: WorkshopAgent?
    @Published var editDocument: PracticeDocument?
    @Published var memoryOpen = false
    var onDismiss: (() -> Void)?

    let bridge = HUDBridge()
    let practice = PracticeModel()
    private weak var store: LearningStore?
    private weak var model: WorkshopModel?
    private weak var backend: LocalBackendSupervisor?
    private var subscriptions: Set<AnyCancellable> = []
    private var pushScheduled = false
    private var wasAnswering = false
    private var answerID: UUID?
    private var answerShownUntil = Date.distantPast
    private var localLine: String?
    private var localLineUntil = Date.distantPast
    private var installed: Set<WorkshopAgent> = []
    private var projects: [HUDListItem] = []
    private var notes: (count: Int, items: [HUDListItem]) = (0, [])
    private var tasks: [HUDTask] = []
    private var streakCache: (value: Int, at: Date) = (0, .distantPast)
    /// No free cloud has a key (or the Keychain was not opened to the backend). / Ни у одного облака нет ключа.
    private var cloudKeysMissing = false
    private var hasVoiceKey = VoiceKeychain.exists
    /// The agent that takes the next spoken or typed task; nil means the assistant. / Агент для следующей задачи.
    private var agentMode: WorkshopAgent?
    private var terminalRun = 0
    /// Agents in the order the orchestrator tries them for "агент: …". / Порядок агентов для «агент: …».
    static let agentOrder: [WorkshopAgent] = [.claude, .opencode, .gemini, .hermes, .openclaw]

    private var language: AppLanguage { store?.language ?? .ru }
    private func text(_ key: String) -> String { L10n.text(key, language) }
    private func format(_ key: String, _ values: String...) -> String { String(format: text(key), arguments: values.map { $0 as CVarArg }) }

    func connect(store: LearningStore, model: WorkshopModel, backend: LocalBackendSupervisor) {
        guard self.store == nil else { return }
        self.store = store
        self.model = model
        self.backend = backend
        // The overlay may come up before any window started the backend. / Оверлей может появиться раньше окна.
        if !backend.isReady { Task { _ = await backend.ensureRunning() } }
        if let data = UserDefaults.standard.data(forKey: HUDTask.defaultsKey),
           let saved = try? JSONDecoder().decode([HUDTask].self, from: data) { tasks = saved }
        refreshInstalled()
        refreshFolders()
        refreshProviders()
        bridge.onMessage = { [weak self] in self?.handle($0) }
        model.voiceHandler = { [weak self] heard in self?.routeToAgent(heard, byVoice: true) ?? false }
        let changes: [AnyPublisher<Void, Never>] = [
            store.objectWillChange.map { _ in }.eraseToAnyPublisher(),
            model.objectWillChange.map { _ in }.eraseToAnyPublisher(),
            model.voice.objectWillChange.map { _ in }.eraseToAnyPublisher(),
            practice.objectWillChange.map { _ in }.eraseToAnyPublisher(),
            backend.objectWillChange.map { _ in }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(changes).sink { [weak self] in self?.schedulePush() }.store(in: &subscriptions)
        push()
    }

    /// objectWillChange comes before the change: push on the next turn, at most every 50 ms.
    /// objectWillChange приходит до изменения: отправляем на следующем шаге, не чаще раза в 50 мс.
    private func schedulePush(after delay: Double = 0.05) {
        guard !pushScheduled else { return }
        pushScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.pushScheduled = false
            self?.push()
        }
    }

    private func pushLater(at date: Date) {
        let delay = max(0.05, date.timeIntervalSinceNow + 0.05)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.push() }
    }

    private func push() {
        guard let store, let model else { return }
        trackAnswer(model)
        bridge.send("data", dataMessage(store: store, model: model))
        bridge.send("practice", practiceMessage())
        bridge.send("confirm", confirmMessage(model))
        bridge.send("terminal", terminalMessage(model))
        if let answer = answerMessage(model) { bridge.send("answer", answer) }
        bridge.send("state", stateMessage(store: store, model: model))
    }

    // MARK: State and answer

    private func trackAnswer(_ model: WorkshopModel) {
        if wasAnswering && !model.isAnswering, let last = model.messages.last, last.role == "assistant", last.id != answerID {
            answerID = last.id
            answerShownUntil = Date().addingTimeInterval(HUDActivity.readingSeconds(last.text))
            // The voice speaks only answers to voice questions, as in the panel (WorkshopModel.finishAnswer).
            // Голосом звучит только ответ на голосовой вопрос, как в панели.
            pushLater(at: answerShownUntil)
        }
        wasAnswering = model.isAnswering
    }

    private func stateMessage(store: LearningStore, model: WorkshopModel) -> HUDStateMessage {
        let voice = model.voice
        let now = Date()
        let local = now < localLineUntil ? localLine : nil
        let activity = HUDActivity(
            isListening: voice.isListening, isAnswering: model.isAnswering, answerHasText: !model.current.text.isEmpty,
            isSpeakingAloud: voice.isSpeaking, showsFinishedAnswer: now < answerShownUntil || local != nil,
            agentsWorking: model.agentRunning || model.councilRunning || practice.phase != .idle
                || model.actionItems.contains { $0.state == .running })
        let line: String
        if voice.isListening {
            line = voice.transcript.isEmpty ? text("hud.listening") : HUDText.line(voice.transcript)
        } else if model.isAnswering {
            if !model.current.text.isEmpty {
                line = HUDText.line(model.current.text)
            } else if let trying = model.current.trying {
                line = format("hud.trying", trying)
            } else {
                line = format("hud.thinking", HUDText.short(lastQuestion(model) ?? "", limit: 90))
            }
        } else if let local {
            line = local
        } else if let notice = model.notice {
            line = HUDText.line(notice)
        } else if model.agentRunning {
            line = Self.lastLine(model.agentOutput).map { model.agent.title + ": " + HUDText.short($0, limit: 160) }
                ?? format("hud.agentRunning", model.agent.title, PracticeEnvironment.tilde(model.agentFolder))
        } else if let agent = agentMode {
            line = format("hud.agent.mode", agent.title)
        } else if model.councilRunning {
            line = format("hud.councilRunning", model.councilMembers.map(\.label).joined(separator: ", "))
        } else if let answerID, let last = model.messages.last(where: { $0.id == answerID }) {
            line = HUDText.line(last.text)
        } else if let next = nextLesson(store) {
            line = format("hud.hello", lessonName(next))
        } else {
            line = text("hud.idle")
        }
        return HUDStateMessage(mode: activity.mode, line: line)
    }

    private func lastQuestion(_ model: WorkshopModel) -> String? {
        model.messages.last(where: { $0.role == "user" })?.text
    }

    private func answerMessage(_ model: WorkshopModel) -> HUDAnswerMessage? {
        let title = HUDText.short(lastQuestion(model) ?? text("hud.ex.title"), limit: 80)
        if model.isAnswering {
            let partial = model.current.text
            guard !partial.isEmpty else { return nil }
            return HUDAnswerMessage(id: "live-\(model.messages.count)", title: title, html: HUDHTML.answer(partial),
                                    sources: text("hud.sources.pending"), open: HUDText.needsWindow(partial))
        }
        guard let last = model.messages.last(where: { $0.role == "assistant" }) else {
            return HUDAnswerMessage(id: "empty", title: text("hud.ex.title"), html: "<p>" + HUDHTML.escape(text("hud.ex.empty")) + "</p>",
                                    sources: text("hud.sources.pending"), open: false)
        }
        var sources = last.answeredBy.map { format("hud.sources", $0, last.model ?? "") } ?? text("hud.sources.pending")
        if cloudKeysMissing, last.answeredBy == "Ollama" { sources += "\n" + text("hud.keys.missing") }
        let checked = last.sources ?? []
        sources += "\n" + (checked.isEmpty ? text("hud.sources.none")
            : checked.map { source in
                ["[\(source.id)] \(source.title)", text("hud.source.\(source.kind)"), source.date, source.url]
                    .filter { !$0.isEmpty && !$0.hasPrefix("hud.source.") }.joined(separator: " · ")
            }.joined(separator: "\n"))
        let question = model.messages.last(where: { $0.role == "user" && $0.date <= last.date })?.text ?? text("hud.ex.title")
        // The same id as the live answer, so a window the owner closed does not open again.
        // Тот же id, что у живого ответа: закрытое окно не открывается снова.
        let index = model.messages.firstIndex(where: { $0.id == last.id }) ?? model.messages.count
        return HUDAnswerMessage(id: "live-\(index)", title: HUDText.short(question, limit: 80), html: HUDHTML.answer(last.text),
                                sources: sources, open: last.id == answerID && HUDText.needsWindow(last.text))
    }

    private static func lastLine(_ output: String) -> String? {
        output.split(separator: "\n").last { line in
            let text = line.trimmingCharacters(in: .whitespaces)
            return !text.isEmpty && text != "■" && !text.hasPrefix("$ ")
        }.map(String.init)
    }

    /// The «Терминал» tab: raw commands and the live agent output, newest at the bottom.
    /// Вкладка «Терминал»: команды и живой вывод агента, новое внизу.
    private func terminalMessage(_ model: WorkshopModel) -> HUDTerminalMessage {
        var lines: [String] = []
        for item in model.actionItems.suffix(8) where item.action.tool == .shell {
            lines.append("$ " + item.action.exactCommand)
            switch item.state {
            case .proposed: lines.append(text("hud.terminal.waiting"))
            case .running: lines.append("…")
            case .done(let output), .failed(let output): lines.append(HUDText.short(output, limit: 4000))
            case .cancelled: lines.append(text("hud.confirm.no"))
            }
        }
        if !model.agentOutput.isEmpty { lines.append(model.agentOutput) }
        if let status = model.agentStatus, !model.agentRunning { lines.append(status) }
        let all = lines.joined(separator: "\n").components(separatedBy: "\n").suffix(220)
        let html = all.isEmpty ? "<p>" + HUDHTML.escape(text("hud.terminal.empty")) + "</p>"
            : "<pre class=\"code\">" + all.map { "<span class=\"l\">" + (HUDHTML.escape($0).isEmpty ? " " : HUDHTML.escape($0)) + "</span>" }.joined() + "</pre>"
        return HUDTerminalMessage(id: String(terminalRun), title: model.agentRunning ? model.agent.title : text("hud.ex.terminal"),
                                  html: html, open: terminalRun > 0)
    }

    private func confirmMessage(_ model: WorkshopModel) -> HUDConfirmMessage {
        if !model.agentDenials.isEmpty, !model.actionItems.contains(where: { $0.state == .proposed && $0.risk.needsConfirmation }) {
            return HUDConfirmMessage(id: Self.agentToolsID,
                                     text: HUDText.short(format("hud.agent.approve", model.agent.title, model.agentDenials.joined(separator: ", ")), limit: 72))
        }
        guard let item = model.actionItems.first(where: { $0.state == .proposed && $0.risk.needsConfirmation }) else {
            return HUDConfirmMessage(id: nil, text: "")
        }
        let what = text("workshop.action.\(item.action.tool.rawValue)") + ": " + item.action.exactCommand
        return HUDConfirmMessage(id: item.id.uuidString, text: HUDText.short(what, limit: 72))
    }

    private func say(_ line: String, seconds: Double = 6) {
        localLine = line
        localLineUntil = Date().addingTimeInterval(seconds)
        pushLater(at: localLineUntil)
        schedulePush()
    }

    // MARK: Data

    private func nextLesson(_ store: LearningStore) -> AIPathLesson? {
        AIPathCatalog.next(completed: store.completedLessonIDs, available: Set(AIPathCatalog.available.map(\.resource)))
    }

    private func lessonName(_ lesson: AIPathLesson) -> String {
        AIPathCatalog.topics[lesson.resource]?.name.value(in: language) ?? lesson.resource
    }

    private func percent(_ done: Int, _ total: Int) -> Int {
        total == 0 ? 0 : Int((Double(done) / Double(total) * 100).rounded())
    }

    private func dataMessage(store: LearningStore, model: WorkshopModel) -> HUDDataMessage {
        let available = AIPathCatalog.available
        let isDone: (AIPathLesson) -> Bool = { store.isComplete(lessonID: $0.lessonID) }
        let finished = available.filter(isDone).count
        let next = nextLesson(store)
        let module = next.flatMap(AIPathCatalog.module(of:))
        let stages = AIPathCatalog.modules.compactMap { module -> HUDNamedPercent? in
            let lessons = module.lessons.filter { AIPathCatalog.topics[$0.resource] != nil }
            guard !lessons.isEmpty else { return nil }
            return HUDNamedPercent(name: text(module.titleKey), percent: percent(lessons.filter(isDone).count, lessons.count))
        }
        let moduleLessons = module?.lessons.filter { AIPathCatalog.topics[$0.resource] != nil } ?? []
        let sub = next.map { lesson in [module.map { text($0.titleKey) }, lessonName(lesson)].compactMap { $0 }.joined(separator: " · ") }
            ?? text("hud.path.none")
        let path = HUDPathInfo(
            percent: percent(finished, available.count), sub: sub, stages: stages,
            trio: [HUDPair(value: "\(moduleLessons.filter(isDone).count)/\(moduleLessons.count)", label: text("hud.trio.module")),
                   HUDPair(value: String(streak(store)), label: text("hud.trio.streak")),
                   HUDPair(value: String(finished), label: text("hud.trio.done"))])

        let lessons = available.enumerated().map { index, lesson -> HUDLessonCard in
            let state = isDone(lesson) ? text("hud.lesson.done") : (lesson == next ? text("hud.lesson.now") : text("hud.lesson.later"))
            return HUDLessonCard(title: format("hud.lesson", String(index + 1)), sub: lessonName(lesson) + " · " + state)
        }
        let lessonIndex = next.flatMap { available.firstIndex(of: $0) } ?? max(0, available.count - 1)

        var tiles: [String: HUDTile] = [:]
        let agents = WorkshopAgent.allCases.map { agent -> HUDAgentRow in
            let live = model.agentRunning && model.agent == agent
            let isInstalled = installed.contains(agent)
            let status = live ? text("hud.agent.live") : (isInstalled ? text("hud.agent.ready") : text("hud.agent.missing"))
            let detail = live ? HUDText.short(Self.lastLine(model.agentOutput) ?? model.agentTask, limit: 60)
                : text(isInstalled ? "hud.agent.\(agent.rawValue)" : "hud.agent.notInstalledShort")
            let tile = HUDTool.tile(ofAgent: agent.rawValue) ?? agent.rawValue
            tiles[tile] = HUDTile(tip: agent.title + " · " + (live ? status : text("hud.agent.\(agent.rawValue)")), live: live || agentMode == agent)
            return HUDAgentRow(icon: tile, name: agent.title, detail: detail.isEmpty ? status : detail, status: status, live: live)
        }
        tiles["obs"] = HUDTile(tip: text("hud.tile.obs"), live: false)
        tiles["nlm"] = HUDTile(tip: text("hud.tile.nlm"), live: false)
        tiles["term"] = HUDTile(tip: text("hud.tile.term"), live: false)
        tiles["oll"] = HUDTile(tip: text("hud.tile.oll"), live: false)

        let votes = model.councilMembers.map { member -> HUDVote in
            switch member.state {
            case .done: return HUDVote(name: member.label, percent: 100, mark: "✓")
            case .failed: return HUDVote(name: member.label, percent: 0, mark: "✗")
            case .thinking: return HUDVote(name: member.label, percent: min(90, 8 + member.text.count / 10), mark: "…")
            }
        }
        let councilHint = model.councilNote ?? (model.councilMembers.isEmpty ? text("hud.council.empty")
            : (model.councilSummary.text.isEmpty ? text("hud.council.waiting") : HUDText.line(model.councilSummary.text, limit: 160)))

        var reminders: [HUDTimed] = []
        if let next { reminders.append(HUDTimed(time: text("hud.rem.now"), text: format("hud.rem.lesson", lessonName(next)))) }
        if store.dueReviewCount > 0 {
            reminders.append(HUDTimed(time: text("hud.rem.today"), text: format("hud.rem.reviews", String(store.dueReviewCount))))
        }
        reminders += tasks.prefix(6).map { HUDTimed(time: shortTime($0.date), text: $0.text) }

        let settings = HUDListInfo(title: text("hud.rail.set"), sub: "", items: [
            HUDListItem(name: text("hud.set.voice"), detail: text(hasVoiceKey ? (model.speakAnswers ? "hud.set.voice.on" : "hud.set.voice.off") : "hud.voice.noKey"), path: nil),
            HUDListItem(name: text("hud.set.models"), detail: text(cloudKeysMissing ? "hud.keys.missing" : "hud.set.models.detail"), path: nil),
            HUDListItem(name: text("hud.set.access"), detail: text("hud.set.access.detail"), path: nil),
            HUDListItem(name: text("hud.set.keys"), detail: format("hud.set.keys.detail",
                        HUDShortcut.find(UserDefaults.standard.string(forKey: HUDShortcut.defaultsKey)).title, HUDShortcut.voice.title), path: nil),
        ], empty: "")
        let nextName = next.map(lessonName) ?? text("hud.rail.path")
        return HUDDataMessage(
            locale: language == .ru ? "ru-RU" : "en-US",
            strings: Dictionary(uniqueKeysWithValues: HUDStrings.pageKeys.map { ($0, text($0)) }),
            online: backend?.isReady ?? false, path: path, lessons: lessons, lessonIndex: lessonIndex,
            agents: agents, council: HUDCouncilInfo(members: votes, hint: councilHint),
            reminders: reminders, remindersEmpty: text("hud.rem.empty"),
            projects: HUDListInfo(title: text("hud.rail.proj"), sub: format("hud.proj.sub", String(projects.count)),
                                  items: Array(projects.prefix(4)), empty: text("hud.proj.empty")),
            notes: HUDListInfo(title: text("hud.notes.title"), sub: format("hud.notes.sub", String(notes.count)),
                               items: notes.items, empty: text("hud.notes.empty")),
            settings: settings,
            hints: [format("hud.hint.explain", nextName), text("hud.hint.next"), format("hud.hint.practice", nextName)],
            tiles: tiles)
    }

    /// Days in a row; read at most every 30 s (it reads the lab results file). / Дни подряд; не чаще раза в 30 с.
    private func streak(_ store: LearningStore) -> Int {
        if Date().timeIntervalSince(streakCache.at) < 30 { return streakCache.value }
        let calendar = CreatorActivity.mondayCalendar()
        var dates = store.studyProgress.values.compactMap { $0.lastReviewedAt.flatMap(CreatorDates.parse) }
        let results = CreatorLabResults.fileURL(environment: PracticeEnvironment.environment, home: PracticeEnvironment.home)
        dates += ((try? Data(contentsOf: results)).map(CreatorLabResults.parse) ?? []).compactMap(\.date)
        let value = CreatorActivity.streak(CreatorActivity.dayCounts(dates, calendar: calendar), today: Date(), calendar: calendar)
        streakCache = (value, Date())
        return value
    }

    private func shortTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language == .ru ? "ru_RU" : "en_US")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "EE"
        return formatter.string(from: date)
    }

    private func relativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: language == .ru ? "ru_RU" : "en_US")
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    /// Which free clouds have keys, from the backend this app started. / Какие облака с ключами — у своего backend.
    private func refreshProviders() {
        Task {
            struct Row: Decodable { let id: String; let configured: Bool? }
            struct Rows: Decodable { let providers: [Row] }
            guard let url = URL(string: LearningStore.orchestratorBaseURL + "/settings/assistant-models"),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let rows = try? JSONDecoder().decode(Rows.self, from: data) else { return }
            cloudKeysMissing = !rows.providers.contains { ["gemini", "groq", "openrouter"].contains($0.id) && $0.configured == true }
            schedulePush()
        }
    }

    private func refreshInstalled() {
        let home = NSHomeDirectory()
        installed = Set(WorkshopAgent.allCases.filter {
            ToolLaunch.firstExecutable(in: $0.candidates(home: home), isExecutable: { FileManager.default.isExecutableFile(atPath: $0) }) != nil
        })
    }

    /// Projects are the folders of ~/Творец/Проекты; notes are the .md files in ~/Творец. / Проекты и заметки.
    private func refreshFolders() {
        let fm = FileManager.default
        let root = WorkshopModel.root
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        func modified(_ url: URL) -> Date { (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast }
        let projectsFolder = root.appendingPathComponent("Проекты", isDirectory: true)
        let folders = ((try? fm.contentsOfDirectory(at: projectsFolder, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles])) ?? [])
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { modified($0) > modified($1) }
        projects = folders.map { HUDListItem(name: $0.lastPathComponent, detail: relativeDate(modified($0)), path: $0.path) }
        var found: [URL] = []
        if let walker = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles, .skipsPackageDescendants]) {
            for case let url as URL in walker {
                if walker.level > 4 { walker.skipDescendants(); continue }
                if url.pathExtension.lowercased() == "md", !["AGENTS.md", "CLAUDE.md"].contains(url.lastPathComponent) { found.append(url) }
                if found.count >= 5000 { break }
            }
        }
        let recent = found.sorted { modified($0) > modified($1) }.prefix(4)
        notes = (found.count, recent.map {
            HUDListItem(name: $0.deletingPathExtension().lastPathComponent,
                        detail: relativeDate(modified($0)) + " · " + PracticeEnvironment.tilde($0.deletingLastPathComponent()), path: $0.path)
        })
    }

    // MARK: Practice

    private func practiceMessage() -> HUDPracticeMessage {
        guard let document = practice.document else {
            return HUDPracticeMessage(file: text("hud.practice.noFile"), code: "", out: "", ok: "", good: false)
        }
        let tokens = PythonHighlighter.tokens(practice.text).map { (kind: $0.kind.rawValue, range: $0.range) }
        let code = HUDHTML.python(practice.text, tokens: tokens)
        var out = "", ok = "", good = false
        switch practice.phase {
        case .running: out = "…"; ok = text("hud.run.running")
        case .checking: out = "…"; ok = text("hud.check.checking")
        case .idle:
            if let report = practice.report, !report.lines.isEmpty {
                good = report.allPassed
                ok = good ? text("hud.check.labOk") : format("hud.check.labFail", String(report.passed), String(report.lines.count))
                out = HUDText.outputLine(report.lines.map { $0.text(russian: language == .ru) }.joined(separator: "\n"))
            } else if let result = practice.result {
                let seconds = L10n.number(result.seconds, fractionDigits: result.seconds < 10 ? 2 : 1, language)
                good = result.succeeded
                ok = format(good ? "hud.run.ok" : "hud.run.failed", seconds)
                out = practice.errorSummary.map { HUDText.short($0, limit: 120) } ?? HUDText.outputLine(practice.output)
            }
        }
        return HUDPracticeMessage(file: document.url.lastPathComponent, code: code, out: out, ok: ok, good: good)
    }

    private func runPractice() {
        guard practice.document != nil else { practice.restore(language); return }
        Task {
            await practice.run()
            guard let result = practice.result else { return }
            let name = practice.document?.url.lastPathComponent ?? ""
            if result.succeeded {
                let output = HUDText.outputLine(practice.output, limit: 140)
                say(format("hud.run.say.ok", name, output.isEmpty ? text("hud.run.empty") : output))
            } else {
                say(format("hud.run.say.error", practice.errorSummary ?? HUDText.outputLine(practice.output, limit: 140)))
            }
        }
    }

    private func checkPractice() {
        guard let store, let model else { return }
        if practice.document == nil { practice.restore(language) }
        guard let document = practice.document else { return }
        if document.lab != nil {
            Task {
                await practice.check(language: language)
                guard let report = practice.report else { return }
                say(report.allPassed ? text("hud.check.say.ok") : format("hud.check.say.fail", String(report.failed)), seconds: 8)
            }
            return
        }
        // Not a lab: the assistant reviews the code (part 3), the answer comes in the line. / Не задание: проверяет ассистент.
        practice.save()
        let task = document.task.isEmpty ? text("code.review.noTask") : document.task
        let prompt = PracticeReviewPrompt.make(template: text("code.review.prompt"), task: task,
                                               output: practice.output, outputTemplate: text("code.review.output"))
        model.notice = nil
        model.ask(prompt + "\n\n```python\n" + PracticeReviewPrompt.code(practice.text) + "\n```", store: store)
    }

    func reloadPractice() {
        if let document = practice.document { practice.open(document) }
    }

    // MARK: Messages from the page

    private func handle(_ inbound: HUDInbound) {
        guard let store, let model else { return }
        switch inbound {
        case .ready:
            push()
            typeTestQuestion()
        case .ask(let question):
            model.notice = nil
            localLineUntil = .distantPast
            if question.hasPrefix("$ ") || question.hasPrefix("$") && question.count > 1 {
                // A raw command in the «Терминал» tab, under the usual safety rule. / Команда во вкладке «Терминал».
                terminalRun += 1
                model.proposeShell(String(question.dropFirst()).trimmingCharacters(in: .whitespaces), language: language)
            } else if !routeToAgent(question, byVoice: false) {
                model.ask(question, store: store)
            }
        case .rail(let act):
            switch act {
            case "proj": refreshFolders()
            case "notes": memoryOpen = true
            case "agents": refreshInstalled()
            case "set": refreshProviders(); hasVoiceKey = VoiceKeychain.exists
            case "ed": if practice.document == nil { practice.restore(language) }
            default: break
            }
            schedulePush()
        case .tool(let tool):
            useTool(tool)
        case .confirm(let id, let yes) where id == Self.agentToolsID:
            if yes { terminalRun += 1; model.approveAgentTools(language: language) } else { model.declineAgentTools(); say(text("hud.confirm.no")) }
        case .confirm(let id, let yes):
            guard let uuid = UUID(uuidString: id) else { return }
            if yes { model.run(uuid, confirmed: true, language: language) } else { model.cancel(uuid); say(text("hud.confirm.no")) }
        case .task(let task):
            guard !task.isEmpty else { say(text("hud.task.ask")); return }
            tasks = HUDTask.adding(task, to: tasks, at: Date())
            if let data = try? JSONEncoder().encode(tasks) { UserDefaults.standard.set(data, forKey: HUDTask.defaultsKey) }
            say(format("hud.task.saved", HUDText.short(task, limit: 80)))
        case .practiceOpen:
            if practice.document == nil { practice.restore(language) }
            schedulePush()
        case .practiceRun:
            runPractice()
        case .practiceCheck:
            checkPractice()
        case .practiceEdit:
            if practice.document == nil { practice.restore(language) }
            editDocument = practice.document
        case .voice:
            if model.voice.isListening { model.stopListeningAndAsk(store: store) } else { model.startListening(language: language) }
        case .dismiss:
            onDismiss?()
        case .reveal(let path):
            let url = URL(fileURLWithPath: path)
            guard WorkshopAgents.isInside(url, root: WorkshopModel.root), FileManager.default.fileExists(atPath: url.path) else { return }
            NSWorkspace.shared.open(url)
        }
    }

    /// `COLIDEV_HUD_TEST_ASK`: a check types this question into the page's own form and sends it, the same path as a person.
    /// `COLIDEV_HUD_TEST_ASK`: проверка вписывает вопрос в форму страницы и отправляет его — тем же путём, что и человек.
    private var testQuestionTyped = false
    private func typeTestQuestion() {
        let environment = ProcessInfo.processInfo.environment
        // With the overlay check only the overlay types it. / При проверке оверлея вопрос вписывает только оверлей.
        if environment["COLIDEV_OVERLAY_AT_LAUNCH"] == "1", onDismiss == nil { return }
        guard !testQuestionTyped, let question = environment["COLIDEV_HUD_TEST_ASK"], !question.isEmpty,
              let json = try? JSONEncoder().encode([question]), let literal = String(data: json, encoding: .utf8) else { return }
        testQuestionTyped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.bridge.webView.evaluateJavaScript(
                "(() => { const q = \(literal)[0]; const f = document.getElementById('ask'); f.focus(); f.value = q; document.getElementById('form').requestSubmit(); })();")
        }
    }

    static let agentToolsID = "agent-tools"

    /// Agent mode or "агент: …" sends the task to a CLI agent inside the workshop; false means the assistant answers.
    /// Режим агента или «агент: …» отдают задачу агенту внутри Мастерской; false — отвечает ассистент.
    private func routeToAgent(_ question: String, byVoice: Bool) -> Bool {
        guard let model else { return false }
        var task = question
        var agent = agentMode
        for prefix in ["агент:", "agent:"] where question.lowercased().hasPrefix(prefix) {
            task = String(question.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
            refreshInstalled()
            // The first installed agent in order; missing ones are skipped. / Первый установленный, отсутствующие пропускаются.
            agent = agent.flatMap { installed.contains($0) ? $0 : nil } ?? Self.agentOrder.first { installed.contains($0) }
            if agent == nil { say(text("hud.agent.none")); return true }
        }
        guard let agent, !task.isEmpty, !model.agentRunning else { return false }
        model.agent = agent
        model.agentFolder = WorkshopModel.root
        model.agentTask = task
        terminalRun += 1
        model.runAgent(language: language)
        return true
    }

    private func useTool(_ tool: String) {
        if let id = HUDTool.agentID(tool), let agent = WorkshopAgent(rawValue: id) {
            refreshInstalled()
            guard let model else { return }
            guard installed.contains(agent) else { say(format("hud.agent.notInstalled", agent.title)); return }
            if !agent.runsNonInteractively {
                // FreeBuff has only its own screen: it opens in Terminal. / У FreeBuff только свой экран — открывается в Терминале.
                model.agent = agent
                model.agentFolder = WorkshopModel.root
                model.runAgent(language: language)
                return
            }
            agentMode = agentMode == agent ? nil : agent
            say(agentMode == nil ? text("hud.agent.modeOff") : format("hud.agent.mode", agent.title))
            return
        }
        switch tool {
        case "obs":
            let url = URL(string: "obsidian://open")!
            if NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
                NSWorkspace.shared.open(url)
                say(text("hud.obs.open"))
            } else {
                say(text("hud.obs.missing"))
            }
        case "nlm":
            NotebookWindow.shared.show(title: "NotebookLM · " + text("hud.sub"))
            say(text("hud.nlm.open"))
        case "term":
            let folder = WorkshopModel.existingRoot
            let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
            NSWorkspace.shared.open([folder], withApplicationAt: terminal, configuration: NSWorkspace.OpenConfiguration())
            say(format("hud.term.open", PracticeEnvironment.tilde(folder)))
        case "oll":
            Task { say(await ollamaLine()) }
        default:
            break
        }
    }

    private func ollamaLine() async -> String {
        struct Tags: Decodable { struct Model: Decodable { let name: String }; let models: [Model] }
        var request = URLRequest(url: URL(string: "http://127.0.0.1:11434/api/tags")!)
        request.timeoutInterval = 4
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let tags = try? JSONDecoder().decode(Tags.self, from: data) else { return text("hud.oll.down") }
        let names = tags.models.map { $0.name.replacingOccurrences(of: ":latest", with: "") }
        return format("hud.oll.models", String(names.count), HUDText.short(names.joined(separator: ", "), limit: 140))
    }
}

// MARK: - View / экран

struct WorkshopHUDView: View {
    @EnvironmentObject private var store: LearningStore
    @EnvironmentObject private var backend: LocalBackendSupervisor
    @ObservedObject var model: WorkshopModel
    /// Set for the overlay: Esc on an empty HUD hides it. / Для оверлея: Esc на пустом HUD прячет его.
    var onDismiss: (() -> Void)?
    @StateObject private var controller = WorkshopHUDController()

    var body: some View {
        HUDWebView(bridge: controller.bridge)
            .background(Color.black)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("workshop.hud")
            .onAppear {
                controller.onDismiss = onDismiss
                controller.connect(store: store, model: model, backend: backend)
            }
            .sheet(item: $controller.agentSheet) { _ in
                VStack(spacing: 0) {
                    WorkshopView(model: model)
                    Divider()
                    HStack {
                        Spacer()
                        Button(L10n.text("workshop.close", store.language)) { controller.agentSheet = nil }
                            .keyboardShortcut(.cancelAction)
                    }
                    .padding(12)
                }
                .environmentObject(store)
                .frame(minWidth: 760, minHeight: 600)
            }
            .sheet(isPresented: $controller.memoryOpen) {
                MemoryView().environmentObject(store)
            }
            .sheet(item: $controller.editDocument, onDismiss: controller.reloadPractice) { document in
                PracticeView(initial: document, asSheet: true)
                    .environmentObject(store)
                    .frame(minWidth: 820, minHeight: 600)
            }
    }
}
