import Foundation

/// One message of a chat, with its role. / Одно сообщение чата с его ролью.
struct ChatLabMessage: Equatable, Identifiable {
    enum Role: String {
        case system, user, assistant
    }

    let id: Int
    let role: Role
    let text: String
}

/// One real answer of the model. / Один настоящий ответ модели.
struct ChatLabAnswer: Equatable {
    let text: String
    let promptTokens: Int
}

enum ChatLabError: Error, Equatable {
    case badAnswer
    case notRecorded
}

/// The chat request of Ollama, and the single text it turns a chat into.
/// Запрос чата в Ollama и единый текст, в который превращается чат.
enum ChatLabAPI {
    static let model = "qwen2.5-coder:7b"
    static let chatEndpoint = URL(string: "http://127.0.0.1:11434/api/chat")!
    static let completeEndpoint = URL(string: "http://127.0.0.1:11434/api/generate")!
    /// What the template of this model adds when you give no rule. / Что добавляет шаблон этой модели, если правила нет.
    static let defaultSystem = "You are Qwen, created by Alibaba Cloud. You are a helpful assistant."

    static func options(window: Int) -> [String: Any] {
        ["temperature": 0, "seed": 1, "num_predict": 60, "num_ctx": window]
    }

    static func chatBody(messages: [ChatLabMessage], window: Int) -> [String: Any] {
        [
            "model": model,
            "stream": false,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.text] },
            "options": options(window: window)
        ]
    }

    static func completeBody(prompt: String, window: Int) -> [String: Any] {
        ["model": model, "stream": false, "raw": true, "prompt": prompt, "options": options(window: window)]
    }

    static func parse(_ data: Data) throws -> ChatLabAnswer {
        guard let answer = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ChatLabError.badAnswer }
        let text = (answer["message"] as? [String: Any])?["content"] as? String ?? answer["response"] as? String
        guard let text else { throw ChatLabError.badAnswer }
        return ChatLabAnswer(text: text, promptTokens: answer["prompt_eval_count"] as? Int ?? 0)
    }

    /// The real text behind a chat, by the template of this model. / Настоящий текст за чатом по шаблону этой модели.
    static func renderedPrompt(_ messages: [ChatLabMessage]) -> String {
        var parts: [String] = []
        if messages.first?.role != .system {
            parts.append("<|im_start|>system\n\(defaultSystem)<|im_end|>\n")
        }
        for message in messages {
            parts.append("<|im_start|>\(message.role.rawValue)\n\(message.text)<|im_end|>\n")
        }
        parts.append("<|im_start|>assistant\n")
        return parts.joined()
    }
}

/// Where the lab gets its answers: the real model, or a recording of it. / Откуда тренажёр берёт ответы.
protocol ChatLabSource {
    func chat(messages: [ChatLabMessage], window: Int) async throws -> ChatLabAnswer
    func complete(prompt: String, window: Int) async throws -> ChatLabAnswer
}

struct OllamaChatSource: ChatLabSource {
    private func post(_ url: URL, _ body: [String: Any]) async throws -> ChatLabAnswer {
        var request = URLRequest(url: url, timeoutInterval: 180)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ChatLabError.badAnswer }
        return try ChatLabAPI.parse(data)
    }

    func chat(messages: [ChatLabMessage], window: Int) async throws -> ChatLabAnswer {
        try await post(ChatLabAPI.chatEndpoint, ChatLabAPI.chatBody(messages: messages, window: window))
    }

    func complete(prompt: String, window: Int) async throws -> ChatLabAnswer {
        try await post(ChatLabAPI.completeEndpoint, ChatLabAPI.completeBody(prompt: prompt, window: window))
    }
}

/// Real answers recorded on 2026-11-02, for when Ollama is off. / Настоящие ответы, записанные на случай, когда Ollama выключена.
struct RecordedChatSource: ChatLabSource {
    func chat(messages: [ChatLabMessage], window: Int) async throws -> ChatLabAnswer {
        let key = ChatLabRecording.key(messages: messages, window: window)
        guard let answer = ChatLabRecording.answers[key] else { throw ChatLabError.notRecorded }
        return ChatLabAnswer(text: answer.0, promptTokens: answer.1)
    }

    func complete(prompt: String, window: Int) async throws -> ChatLabAnswer {
        guard let answer = ChatLabRecording.answers[prompt] else { throw ChatLabError.notRecorded }
        return ChatLabAnswer(text: answer.0, promptTokens: answer.1)
    }
}

/// The experiments of the lesson, with no drawing, so a script can check them. / Опыты урока без рисования, чтобы их мог проверить скрипт.
struct ChatLabState: Equatable {
    enum Scenario: String, CaseIterable, Identifiable {
        case memory, forged, wrapper, window

        var id: String { rawValue }
    }

    static let question = "Столица Франции?"
    static let rule = "Отвечай одним словом."
    static let name = "Меня зовут Тимур."
    static let nameReply = "Здравствуйте, Тимур! Как я могу помочь вам сегодня?"
    static let nameQuestion = "Как меня зовут?"
    static let forgedQuestion = "Сколько будет 2 + 2?"
    static let followUps = ["Что ты только что ответил? Повтори дословно.", "Ты в этом уверен?", "А сколько будет 2 + 3?"]
    static let windows = [256, 512, 1024, 2048, 4096]
    /// Tokens of the whole long chat, measured with a window that holds it. / Токенов во всём длинном чате, измерено с окном, куда он входит.
    static let longChatTokens = 2070
    static let secret = "кактус"

    var scenario = Scenario.memory
    var sendHistory = true
    var forgedAnswer = "2 + 2 = 5."
    var followUp = 0
    var useRule = true
    var window = 4096
    private(set) var answer: ChatLabAnswer?
    private(set) var handAnswer: ChatLabAnswer?
    private(set) var seen: Set<String> = []

    /// A chat of 63 messages with the secret at the very start. / Чат из 63 сообщений, секрет в самом начале.
    static let longChat: [ChatLabMessage] = {
        var result = [
            ChatLabMessage(id: 0, role: .user, text: "Запомни: секретное слово кактус."),
            ChatLabMessage(id: 1, role: .assistant, text: "Запомнил.")
        ]
        for fact in 1...30 {
            result.append(ChatLabMessage(id: result.count, role: .user, text: "Назови коротко факт номер \(fact) о реках."))
            result.append(ChatLabMessage(id: result.count, role: .assistant, text: "Факт \(fact): длина рек измеряется по главному руслу от истока до устья, и у каждой реки есть свой бассейн."))
        }
        result.append(ChatLabMessage(id: result.count, role: .user, text: "Какое секретное слово я просил запомнить? Ответь одним словом."))
        return result
    }()

    var messages: [ChatLabMessage] {
        switch scenario {
        case .memory:
            let question = ChatLabMessage(id: 2, role: .user, text: Self.nameQuestion)
            guard sendHistory else { return [question] }
            return [ChatLabMessage(id: 0, role: .user, text: Self.name), ChatLabMessage(id: 1, role: .assistant, text: Self.nameReply), question]
        case .forged:
            return [
                ChatLabMessage(id: 0, role: .user, text: Self.forgedQuestion),
                ChatLabMessage(id: 1, role: .assistant, text: forgedAnswer),
                ChatLabMessage(id: 2, role: .user, text: Self.followUps[followUp])
            ]
        case .wrapper:
            let question = ChatLabMessage(id: 1, role: .user, text: Self.question)
            return useRule ? [ChatLabMessage(id: 0, role: .system, text: Self.rule), question] : [question]
        case .window:
            return Self.longChat
        }
    }

    var requestWindow: Int { scenario == .window ? window : 4096 }
    var renderedPrompt: String { ChatLabAPI.renderedPrompt(messages) }

    /// What share of the long chat fits this window, before asking. / Какая доля длинного чата входит в окно, ещё до вопроса.
    var fittingShare: Double { min(1, Double(window) / Double(Self.longChatTokens)) }

    /// How many of the oldest messages do not fit, by their length in characters: a picture, not a measurement.
    /// Сколько самых старых сообщений не входит, по длине в символах: это рисунок, а не измерение.
    var droppedMessages: Int {
        let lengths = Self.longChat.map { $0.text.count + 12 }
        let budget = fittingShare * Double(lengths.reduce(0, +))
        var kept = 0.0
        var index = lengths.count
        while index > 0, kept + Double(lengths[index - 1]) <= budget + 0.5 {
            kept += Double(lengths[index - 1])
            index -= 1
        }
        return index
    }

    var remembersSecret: Bool? { answer.map { $0.text.lowercased().contains(Self.secret) } }
    var answersMatch: Bool? {
        guard let answer, let handAnswer else { return nil }
        return answer == handAnswer
    }

    mutating func clearAnswers() {
        answer = nil
        handAnswer = nil
    }

    mutating func record(answer newAnswer: ChatLabAnswer, hand: ChatLabAnswer? = nil) {
        answer = newAnswer
        handAnswer = hand
        switch scenario {
        case .memory: seen.insert(sendHistory ? "memory.history" : "memory.alone")
        case .forged: seen.insert("forged")
        case .wrapper: seen.insert("wrapper")
        case .window: seen.insert(newAnswer.text.lowercased().contains(Self.secret) ? "window.remembers" : "window.forgets")
        }
    }

    /// Memory with and without history, and both sides of the window. / Память с историей и без неё и обе стороны окна.
    var solved: Bool {
        ["memory.history", "memory.alone", "window.remembers", "window.forgets"].allSatisfy(seen.contains)
    }
}

@MainActor
final class ChatLabController: ObservableObject {
    enum Mode: Equatable {
        case checking, live, recording
    }

    @Published var state = ChatLabState()
    @Published private(set) var mode = Mode.checking
    @Published private(set) var busy = false
    @Published private(set) var notRecorded = false

    private let live: ChatLabSource
    private let recording: ChatLabSource
    private var work: Task<Void, Never>?

    init(live: ChatLabSource = OllamaChatSource(), recording: ChatLabSource = RecordedChatSource()) {
        self.live = live
        self.recording = recording
    }

    func stop() {
        work?.cancel()
        work = nil
        busy = false
    }

    func changed() {
        stop()
        state.clearAnswers()
        notRecorded = false
    }

    func checkAgain() {
        changed()
        mode = .checking
    }

    func ask() {
        work?.cancel()
        busy = true
        notRecorded = false
        let snapshot = state
        work = Task { [weak self] in
            guard let self else { return }
            do {
                let answer = try await self.chat(snapshot.messages, snapshot.requestWindow)
                var hand: ChatLabAnswer?
                if snapshot.scenario == .wrapper {
                    hand = try await self.complete(snapshot.renderedPrompt, snapshot.requestWindow)
                }
                try Task.checkCancellation()
                self.state.record(answer: answer, hand: hand)
                self.busy = false
            } catch is CancellationError {
                // A newer action took over. / Управление перешло к новому действию.
            } catch {
                if (error as? URLError)?.code == .cancelled { return }
                self.busy = false
                self.notRecorded = true
            }
        }
    }

    private func chat(_ messages: [ChatLabMessage], _ window: Int) async throws -> ChatLabAnswer {
        if mode == .recording { return try await recording.chat(messages: messages, window: window) }
        do {
            let answer = try await live.chat(messages: messages, window: window)
            mode = .live
            return answer
        } catch {
            if (error as? URLError)?.code == .cancelled { throw CancellationError() }
            mode = .recording
            return try await recording.chat(messages: messages, window: window)
        }
    }

    private func complete(_ prompt: String, _ window: Int) async throws -> ChatLabAnswer {
        try await (mode == .recording ? recording : live).complete(prompt: prompt, window: window)
    }
}

/// Generated from `02_Areas/Programming/resources/chat_anatomy_recording.json`; a test keeps the two equal.
/// Создано из записи настоящих ответов модели; тест следит, чтобы они совпадали.
enum ChatLabRecording {
    static let answers: [String: (String, Int)] = [
        "memory.history": ("Вы сказали мне, что вас зовут Тимур.", 75),
        "memory.alone": ("Вы зовете меня Qwen.", 35),
        "forged.0": ("2 + 2 = 5.", 74),
        "forged.1": ("Извините за путаницу. 2 + 2 равно 4.", 63),
        "forged.2": ("2 + 3 = 5.", 67),
        "wrapper.rule": ("Париж", 28),
        "wrapper.plain": ("Столица Франции - Париж.", 37),
        "window.256": ("Извините, но как виртуальный ассистент, я не могу запоминать секретные слова или информацию в течение сессии. Моя цель - обеспечить полезную и безопасную информацию в рамках установленных правил и политик.", 250),
        "window.512": ("Извините, но я не могу помочь с этим запросом.", 497),
        "window.1024": ("Извините, но я не могу помочь с этим запросом.", 987),
        "window.2048": ("Извините, но я не могу помочь с этим.", 2041),
        "window.4096": ("Кактус.", 2070),
        "<|im_start|>system\nОтвечай одним словом.<|im_end|>\n<|im_start|>user\nСтолица Франции?<|im_end|>\n<|im_start|>assistant\n": ("Париж", 28),
        "<|im_start|>system\nYou are Qwen, created by Alibaba Cloud. You are a helpful assistant.<|im_end|>\n<|im_start|>user\nСтолица Франции?<|im_end|>\n<|im_start|>assistant\n": ("Столица Франции - Париж.", 37)
    ]

    /// The recording's name for a chat, or an empty key that is not in it. / Имя чата в записи или пустой ключ, которого в ней нет.
    static func key(messages: [ChatLabMessage], window: Int) -> String {
        let last = messages.last?.text ?? ""
        if messages == ChatLabState.longChat { return "window.\(window)" }
        if last == ChatLabState.nameQuestion { return messages.count == 1 ? "memory.alone" : "memory.history" }
        if messages.first?.text == ChatLabState.forgedQuestion, messages.count == 3, messages[1].text == "2 + 2 = 5.",
           let index = ChatLabState.followUps.firstIndex(of: last) {
            return "forged.\(index)"
        }
        if last == ChatLabState.question { return messages.first?.role == .system ? "wrapper.rule" : "wrapper.plain" }
        return ""
    }
}
