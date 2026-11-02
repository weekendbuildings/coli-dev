import Foundation

/// A possible next token with the probability the model computed for it. / Возможный следующий токен и вероятность, посчитанная моделью.
struct NextTokenCandidate: Equatable, Identifiable {
    let token: String
    let probability: Double

    var id: String { token }
}

/// One answer of the model: the token it chose and the candidates it weighed. / Один ответ модели: выбранный токен и кандидаты.
struct LiveModelStep: Equatable {
    let chosen: String
    let candidates: [NextTokenCandidate]
    let promptTokens: Int
    let milliseconds: Double
}

enum LiveModelError: Error, Equatable {
    case badAnswer
    case notRecorded
}

/// The temperature formula, used by the lab's small three-candidate example.
/// Формула температуры для маленького примера с тремя кандидатами в тренажёре.
enum LiveModelMath {
    /// pᵢ(T) = pᵢ^(1/T) / Σⱼ pⱼ^(1/T). At T = 0 the whole probability goes to the best candidate.
    /// При T = 0 вся вероятность уходит лучшему кандидату.
    static func reshape(_ probabilities: [Double], temperature: Double) -> [Double] {
        guard let best = probabilities.max() else { return [] }
        if temperature < 0.001 {
            let first = probabilities.firstIndex(of: best)
            return probabilities.indices.map { $0 == first ? 1 : 0 }
        }
        let powered = probabilities.map { pow($0, 1 / temperature) }
        let total = powered.reduce(0, +)
        return powered.map { $0 / total }
    }

    /// Makes spaces and line breaks visible, since they are part of a token. / Показывает пробелы и переводы строк: они часть токена.
    static func visibleToken(_ token: String) -> String {
        token.replacingOccurrences(of: " ", with: "␣")
            .replacingOccurrences(of: "\r\n", with: "⏎")
            .replacingOccurrences(of: "\n", with: "⏎")
            .replacingOccurrences(of: "\t", with: "⇥")
    }
}

/// The request and answer of Ollama's `/api/generate`, as the lesson's Python program uses them.
/// Запрос и ответ `/api/generate` в Ollama, как в программе на Python из урока.
enum LiveModelAPI {
    static let model = "qwen2.5-coder:7b"
    static let endpoint = URL(string: "http://127.0.0.1:11434/api/generate")!
    /// The largest number of candidates Ollama returns. / Больше кандидатов Ollama не отдаёт.
    static let candidateLimit = 20

    static func body(prompt: String, temperature: Double, seed: Int) -> [String: Any] {
        [
            "model": model,
            "prompt": prompt,
            "raw": true,
            "stream": false,
            "logprobs": true,
            "top_logprobs": candidateLimit,
            "options": [
                "temperature": temperature,
                "seed": seed,
                "num_predict": 1,
                "top_k": 0,
                "top_p": 1,
                "min_p": 0,
                "repeat_penalty": 1
            ] as [String: Any]
        ]
    }

    static func parse(_ data: Data) throws -> LiveModelStep {
        guard let answer = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let steps = answer["logprobs"] as? [[String: Any]],
              let first = steps.first,
              let chosen = first["token"] as? String,
              let top = first["top_logprobs"] as? [[String: Any]] else {
            throw LiveModelError.badAnswer
        }
        let candidates = top.compactMap { item -> NextTokenCandidate? in
            guard let token = item["token"] as? String, let logprob = item["logprob"] as? Double else { return nil }
            return NextTokenCandidate(token: token, probability: exp(logprob))
        }
        guard !candidates.isEmpty else { throw LiveModelError.badAnswer }
        let promptTokens = answer["prompt_eval_count"] as? Int ?? 0
        let nanoseconds = (answer["eval_duration"] as? Double) ?? Double(answer["eval_duration"] as? Int ?? 0)
        return LiveModelStep(chosen: chosen, candidates: candidates, promptTokens: promptTokens, milliseconds: nanoseconds / 1_000_000)
    }
}

/// Where the lab gets its answers: the real model, or a recording of it. / Откуда тренажёр берёт ответы: настоящая модель или её запись.
protocol LiveModelSource {
    func step(prompt: String, temperature: Double, seed: Int) async throws -> LiveModelStep
}

struct OllamaLiveSource: LiveModelSource {
    func step(prompt: String, temperature: Double, seed: Int) async throws -> LiveModelStep {
        var request = URLRequest(url: LiveModelAPI.endpoint, timeoutInterval: 120)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: LiveModelAPI.body(prompt: prompt, temperature: temperature, seed: seed))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw LiveModelError.badAnswer }
        return try LiveModelAPI.parse(data)
    }
}

/// Real answers of the model, recorded on 2026-11-02 from `02_Areas/Programming/resources/live_model_recording.json`,
/// so the lab still teaches when Ollama is off. Настоящие ответы модели, записанные на случай, когда Ollama выключена.
struct RecordedLiveSource: LiveModelSource {
    /// Rare tokens are not in the recording by name. / Редкие токены в записи не названы.
    static let otherToken = "…"

    func step(prompt: String, temperature: Double, seed: Int) async throws -> LiveModelStep {
        guard let recorded = LiveModelRecording.path.first(where: { $0.prefix == prompt }) else { throw LiveModelError.notRecorded }
        let candidates = recorded.candidates.map { NextTokenCandidate(token: $0.0, probability: exp($0.1)) }
        var chosen = candidates[0].token
        if prompt == LiveModelRecording.prompt {
            chosen = Self.draw(temperature: temperature, seed: seed)
        } else if temperature >= 0.001 {
            // Beyond the first step only the probabilities are recorded, so T = 1 is the honest choice here.
            // После первого шага записаны только вероятности, поэтому здесь честно выбрать можно только как при T = 1.
            chosen = Self.pick(candidates.map { ($0.token, $0.probability) }, seed: seed)
        }
        return LiveModelStep(chosen: chosen, candidates: candidates, promptTokens: recorded.promptTokens, milliseconds: 0)
    }

    /// Picks a token as the real draws at the nearest recorded temperature fell. / Выбирает токен так, как он выпадал при ближайшей записанной температуре.
    static func draw(temperature: Double, seed: Int) -> String {
        let row = LiveModelRecording.draws.min { abs($0.temperature - temperature) < abs($1.temperature - temperature) }!
        let weighted = row.counts.map { ($0.0, Double($0.1)) } + [(otherToken, Double(row.other))]
        return pick(weighted, seed: seed)
    }

    private static func pick(_ weighted: [(String, Double)], seed: Int) -> String {
        let total = weighted.reduce(0) { $0 + $1.1 }
        var left = Double(abs(seed) % 1_000_003) / 1_000_003 * total
        for item in weighted {
            left -= item.1
            if left < 0 { return item.0 }
        }
        return weighted[weighted.count - 1].0
    }
}

/// The lab's state with no drawing, so a script can check it. / Состояние тренажёра без рисования, чтобы его мог проверить скрипт.
struct LiveModelLabState: Equatable {
    struct Written: Equatable, Identifiable {
        let id: Int
        let token: String
        /// What the model computed for this token, if it was among the candidates. / Что модель посчитала для этого токена.
        let probability: Double?
    }

    /// One real experiment: the temperature and how often the best token fell. / Один настоящий опыт: температура и как часто выпал лучший токен.
    struct Experiment: Equatable, Identifiable {
        let temperature: Double
        let bestShare: Double

        var id: Double { temperature }
    }

    static let shownCandidates = 6
    static let throwsPerExperiment = 100

    private(set) var prompt: String
    private(set) var written: [Written] = []
    private(set) var candidates: [NextTokenCandidate] = []
    private(set) var promptTokens = 0
    private(set) var milliseconds = 0.0
    private(set) var counts: [String: Int] = [:]
    private(set) var thrown = 0
    private(set) var countedTemperature: Double?
    private(set) var experiments: [Experiment] = []

    init(prompt: String) {
        self.prompt = prompt
    }

    /// The text the model reads next. / Текст, который модель читает дальше.
    var fullText: String { prompt + written.map(\.token).joined() }
    var best: NextTokenCandidate? { candidates.first }
    var shown: [NextTokenCandidate] { Array(candidates.prefix(Self.shownCandidates)) }

    /// What the model gives to all tokens that are not shown. / Сколько модель отдаёт всем токенам, которых нет на экране.
    var restProbability: Double { max(0, 1 - shown.reduce(0) { $0 + $1.probability }) }
    var otherCount: Int { max(0, thrown - shown.reduce(0) { $0 + (counts[$1.token] ?? 0) }) }

    func share(of token: String) -> Double? {
        thrown > 0 ? Double(counts[token] ?? 0) / Double(thrown) : nil
    }

    var otherShare: Double? { thrown > 0 ? Double(otherCount) / Double(thrown) : nil }

    /// The three temperatures of the lesson's experiment, tried on one text. / Три температуры из опыта урока на одном тексте.
    var experimentDone: Bool {
        experiments.contains { $0.temperature <= 0.1 }
            && experiments.contains { (0.9...1.1).contains($0.temperature) }
            && experiments.contains { $0.temperature >= 1.8 }
    }

    mutating func restart(prompt newPrompt: String) {
        self = LiveModelLabState(prompt: newPrompt)
    }

    /// Goes back to the same text without its added tokens, and keeps the experiments. / Убирает дописанные токены и сохраняет опыты.
    mutating func eraseWritten() {
        written = []
        counts = [:]
        thrown = 0
        countedTemperature = nil
    }

    mutating func show(_ step: LiveModelStep) {
        candidates = step.candidates
        promptTokens = step.promptTokens
        if step.milliseconds > 0 { milliseconds = step.milliseconds }
    }

    mutating func append(token: String) {
        let probability = candidates.first { $0.token == token }?.probability
        written.append(Written(id: written.count, token: token, probability: probability))
        counts = [:]
        thrown = 0
        countedTemperature = nil
        experiments = []
    }

    mutating func startThrows(temperature: Double) {
        counts = [:]
        thrown = 0
        countedTemperature = temperature
    }

    mutating func recordThrow(token: String, milliseconds newMilliseconds: Double) {
        counts[token, default: 0] += 1
        thrown += 1
        if newMilliseconds > 0 { milliseconds = newMilliseconds }
    }

    mutating func finishThrows() {
        guard let temperature = countedTemperature, thrown > 0, let best else { return }
        let rounded = (temperature * 10).rounded() / 10
        experiments.removeAll { $0.temperature == rounded }
        experiments.append(Experiment(temperature: rounded, bestShare: Double(counts[best.token] ?? 0) / Double(thrown)))
        experiments.sort { $0.temperature < $1.temperature }
    }
}

/// Talks to the source, and falls back to the recording when Ollama is off. / Обращается к источнику, а если Ollama выключена, переходит на запись.
@MainActor
final class LiveModelLabController: ObservableObject {
    enum Mode: Equatable {
        case checking, live, recording
    }

    @Published private(set) var state = LiveModelLabState(prompt: LiveModelRecording.prompt)
    @Published private(set) var mode = Mode.checking
    @Published private(set) var busy = false
    @Published private(set) var outOfRecording = false

    private let live: LiveModelSource
    private let recording: LiveModelSource
    private var work: Task<Void, Never>?

    init(live: LiveModelSource = OllamaLiveSource(), recording: LiveModelSource = RecordedLiveSource()) {
        self.live = live
        self.recording = recording
    }

    private var source: LiveModelSource { mode == .live ? live : recording }

    func start() {
        guard mode == .checking else { return }
        refreshCandidates()
    }

    func stop() {
        work?.cancel()
        work = nil
        busy = false
    }

    func checkAgain() {
        stop()
        mode = .checking
        outOfRecording = false
        refreshCandidates()
    }

    func use(prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return }
        stop()
        state.restart(prompt: trimmed)
        outOfRecording = false
        refreshCandidates()
    }

    func restart() {
        stop()
        state.eraseWritten()
        outOfRecording = false
        refreshCandidates()
    }

    private func refreshCandidates() {
        run { controller in
            let text = controller.state.fullText
            let step = try await controller.answer(prompt: text, temperature: 0, seed: 1)
            try Task.checkCancellation()
            controller.state.show(step)
        }
    }

    /// The model itself chooses, at this temperature. / Токен выбирает сама модель при этой температуре.
    func nextToken(temperature: Double) {
        run { controller in
            let step = try await controller.answer(prompt: controller.state.fullText, temperature: temperature, seed: Int.random(in: 1..<2_147_483_647))
            try Task.checkCancellation()
            controller.state.show(step)
            try await controller.write(step.chosen)
        }
    }

    /// The learner chooses a token by clicking its bar. / Токен выбирает сам ученик, щёлкая по его полосе.
    func pick(token: String) {
        run { controller in
            try await controller.write(token)
        }
    }

    private func write(_ token: String) async throws {
        state.append(token: token)
        let step = try await answer(prompt: state.fullText, temperature: 0, seed: 1)
        try Task.checkCancellation()
        state.show(step)
    }

    /// Asks the real model again and again and counts what falls. / Снова и снова спрашивает настоящую модель и считает, что выпало.
    func throwMany(temperature: Double) {
        run { controller in
            controller.state.startThrows(temperature: temperature)
            for _ in 0..<LiveModelLabState.throwsPerExperiment {
                let seed = Int.random(in: 1..<2_147_483_647)
                let step = try await controller.answer(prompt: controller.state.fullText, temperature: temperature, seed: seed)
                try Task.checkCancellation()
                controller.state.recordThrow(token: step.chosen, milliseconds: step.milliseconds)
                if controller.mode == .recording {
                    // A recording answers at once, so the bars would not visibly grow. / Запись отвечает мгновенно, и полосы не успели бы расти.
                    try await Task.sleep(nanoseconds: 30_000_000)
                }
            }
            controller.state.finishThrows()
        }
    }

    private func answer(prompt: String, temperature: Double, seed: Int) async throws -> LiveModelStep {
        if mode == .recording {
            return try await recording.step(prompt: prompt, temperature: temperature, seed: seed)
        }
        do {
            let step = try await live.step(prompt: prompt, temperature: temperature, seed: seed)
            mode = .live
            return step
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if (error as? URLError)?.code == .cancelled { throw CancellationError() }
            mode = .recording
            if state.fullText != LiveModelRecording.prompt, !LiveModelRecording.path.contains(where: { $0.prefix == state.fullText }) {
                state.restart(prompt: LiveModelRecording.prompt)
            }
            return try await recording.step(prompt: state.fullText, temperature: temperature, seed: seed)
        }
    }

    private func run(_ action: @escaping (LiveModelLabController) async throws -> Void) {
        work?.cancel()
        busy = true
        work = Task { [weak self] in
            guard let self else { return }
            do {
                try await action(self)
                self.busy = false
            } catch is CancellationError {
                // A newer action took over and owns `busy`. / Управление перешло к новому действию, `busy` теперь за ним.
            } catch {
                self.busy = false
                self.outOfRecording = true
            }
        }
    }
}

/// Generated from `02_Areas/Programming/resources/live_model_recording.json`; a test keeps the two equal.
/// Создано из записи настоящих ответов модели; тест следит, чтобы они совпадали.
enum LiveModelRecording {
    struct Step {
        let prefix: String
        let promptTokens: Int
        /// Token and log-probability, best first. / Токен и логарифм вероятности, лучший первым.
        let candidates: [(String, Double)]
    }

    /// 200 real throws at one temperature. / 200 настоящих бросков при одной температуре.
    struct Draw {
        let temperature: Double
        let counts: [(String, Int)]
        let other: Int
    }

    static let prompt = "The capital of France is"
    static let vocabulary = 152064

    static let path: [Step] = [
        Step(prefix: "The capital of France is", promptTokens: 5, candidates: [(" Paris", -0.4599), (" __", -3.0503), (":\n", -3.1145), (" ______", -3.1598), (" a", -3.5436), (":\n\n", -3.5548), (" located", -3.5708), (" ____", -4.4905)]),
        Step(prefix: "The capital of France is Paris", promptTokens: 6, candidates: [(".", -0.685), (",", -1.6899), (".\n", -1.7109), (".\n\n", -2.449), (" and", -3.7064), (" (", -5.0704), ("\n", -6.0919), (" which", -6.2716)]),
        Step(prefix: "The capital of France is Paris.", promptTokens: 7, candidates: [(" Paris", -1.3449), (" The", -1.8266), (" If", -2.8285), (" It", -2.9647), (" True", -3.4469), (" What", -3.5993), (" \n\n", -3.7143), (" Therefore", -3.8099)]),
        Step(prefix: "The capital of France is Paris. Paris", promptTokens: 8, candidates: [(" is", -0.1416), (" has", -2.5607), (" was", -4.8708), (",", -5.0601), (" means", -5.3387), (" lies", -5.6354), ("ian", -6.0103), (" (", -6.13)]),
        Step(prefix: "The capital of France is Paris. Paris is", promptTokens: 9, candidates: [(" located", -1.219), (" a", -1.8927), (" the", -2.0604), (" known", -2.1138), (" not", -2.604), (" also", -3.0093), (" situated", -3.3742), (" one", -3.5172)]),
        Step(prefix: "The capital of France is Paris. Paris is located", promptTokens: 10, candidates: [(" in", -0.1517), (" on", -2.2053), (" at", -4.1816), (" along", -5.3443), (" near", -5.4882), (" between", -6.6629), (" approximately", -7.0419), (" ", -7.467)]),
        Step(prefix: "The capital of France is Paris. Paris is located in", promptTokens: 11, candidates: [(" the", -0.1141), (" France", -3.3349), (" central", -3.7335), (" northern", -3.8621), (" northeastern", -4.8851), (" a", -5.6086), (" which", -5.9676), (" north", -6.0834)])
    ]

    static let draws: [Draw] = [
        Draw(temperature: 0.0, counts: [(" Paris", 200), (" __", 0), (":\n", 0), (" ______", 0), (" a", 0), (":\n\n", 0)], other: 0),
        Draw(temperature: 0.5, counts: [(" Paris", 198), (" __", 0), (":\n", 0), (" ______", 0), (" a", 1), (":\n\n", 0)], other: 1),
        Draw(temperature: 1.0, counts: [(" Paris", 122), (" __", 11), (":\n", 8), (" ______", 11), (" a", 6), (":\n\n", 6)], other: 36),
        Draw(temperature: 1.5, counts: [(" Paris", 29), (" __", 5), (":\n", 1), (" ______", 7), (" a", 8), (":\n\n", 4)], other: 146),
        Draw(temperature: 2.0, counts: [(" Paris", 3), (" __", 0), (":\n", 2), (" ______", 0), (" a", 1), (":\n\n", 1)], other: 193)
    ]
}
