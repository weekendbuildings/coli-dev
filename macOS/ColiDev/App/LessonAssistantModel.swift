import Foundation

// Logic of the in-lesson assistant without SwiftUI, checked by scripts/verify_lesson_assistant.swift.
// Логика ассистента в уроке без SwiftUI, её проверяет scripts/verify_lesson_assistant.swift.

/// What the assistant knows about the lesson or Skillbox topic. / Что ассистент знает об уроке или теме Skillbox.
struct AssistantLessonContext: Encodable, Equatable {
    var kind: String = "lesson"
    var title: String
    var subject: String = ""
    var goal: String = ""
    var position: String = ""
    var course: String = ""
    var track: String = ""

    var isSkillbox: Bool { kind == "skillbox" }
}

struct AssistantTurn: Codable, Equatable {
    let role: String
    let content: String
}

struct AssistantAskBody: Encodable {
    let language: String
    let context: AssistantLessonContext
    let question: String
    let code: String?
    let history: [AssistantTurn]
}

/// One server-sent event of `/assistant/ask/stream`. / Одно событие потока `/assistant/ask/stream`.
struct AssistantStreamEvent: Decodable, Equatable {
    let type: String
    var provider: String? = nil
    var label: String? = nil
    var model: String? = nil
    var tier: String? = nil
    var content: String? = nil
    var reason: String? = nil
    var answer: String? = nil
    var error: String? = nil

    /// Parses a `data: {...}` line; other lines (comments, blanks) give nil.
    /// Разбирает строку `data: {...}`; прочие строки дают nil.
    static func parse(line: String) -> AssistantStreamEvent? {
        guard line.hasPrefix("data:") else { return nil }
        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        guard let data = payload.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(AssistantStreamEvent.self, from: data)
    }
}

struct AssistantSkip: Equatable {
    let label: String
    let reason: String
}

/// The answer being received now. / Ответ, который приходит сейчас.
struct AssistantAnswerState: Equatable {
    var text = ""
    var trying: String?
    var skipped: [AssistantSkip] = []
    var answeredBy: String?
    var model: String?
    var tier: String?
    var error: String?
    var finished = false

    mutating func apply(_ event: AssistantStreamEvent) {
        switch event.type {
        case "provider":
            trying = event.label ?? event.provider
            model = event.model
        case "token":
            text += event.content ?? ""
        case "reset":
            // The provider failed midway: its partial answer is dropped. / Провайдер упал на полпути: часть ответа убираем.
            text = ""
        case "fallback":
            skipped.append(AssistantSkip(label: event.label ?? event.provider ?? "?", reason: event.reason ?? "failed"))
        case "done":
            if let answer = event.answer, !answer.isEmpty { text = answer }
            answeredBy = event.label ?? event.provider
            model = event.model ?? model
            tier = event.tier
            trying = nil
            finished = true
        case "error":
            error = event.error
            trying = nil
            finished = true
        default:
            break
        }
    }
}

/// One finished question and answer. / Один законченный вопрос и ответ.
struct AssistantExchange: Identifiable, Equatable {
    let id = UUID()
    let shownQuestion: String
    let sentQuestion: String
    let code: String?
    let answer: String
    let answeredBy: String
    let model: String
    let skipped: [AssistantSkip]
}

/// The dialogue for follow-up questions. / Разговор для уточняющих вопросов.
struct AssistantConversation: Equatable {
    static let maxHistoryTurns = 12
    private(set) var exchanges: [AssistantExchange] = []

    var isEmpty: Bool { exchanges.isEmpty }

    /// Last turns sent with a new question, code included as the learner sent it.
    /// Последние реплики, которые уходят с новым вопросом, вместе с кодом ученика.
    var history: [AssistantTurn] {
        let turns = exchanges.flatMap { exchange -> [AssistantTurn] in
            var question = exchange.sentQuestion
            if let code = exchange.code, !code.isEmpty { question += "\n\n```python\n\(code)\n```" }
            return [AssistantTurn(role: "user", content: question), AssistantTurn(role: "assistant", content: exchange.answer)]
        }
        return Array(turns.suffix(Self.maxHistoryTurns))
    }

    mutating func record(_ exchange: AssistantExchange) {
        exchanges.append(exchange)
    }
}

/// Failure reasons from the router mapped to `L10n` keys. / Причины отказа маршрутизатора → ключи `L10n`.
enum AssistantReason {
    static let known: Set<String> = [
        "not_configured", "not_signed_in", "rate_limited", "offline", "timeout", "paid_blocked", "empty", "disabled", "failed",
        "cooling_down",
    ]

    static func key(_ reason: String) -> String {
        "assistant.reason." + (known.contains(reason) ? reason : "failed")
    }
}

/// A note for Obsidian with the whole dialogue. / Заметка для Obsidian со всем разговором.
enum AssistantObsidianNote {
    static func path(context: AssistantLessonContext, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let folder = context.isSkillbox ? "Skillbox" : safeName(context.subject.isEmpty ? "Lessons" : context.subject)
        return "ColiDev/Assistant/\(folder)/\(safeName(context.title))-\(formatter.string(from: date)).md"
    }

    /// Letters, digits, `-` and `_` only; spaces become `-`; at most 60 characters.
    /// Только буквы, цифры, `-` и `_`; пробелы → `-`; не длиннее 60 символов.
    static func safeName(_ text: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let words = text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let joined = words.joined(separator: "-")
        let cleaned = String(String.UnicodeScalarView(joined.unicodeScalars.filter { allowed.contains($0) }))
        let short = String(cleaned.prefix(60))
        return short.isEmpty ? "note" : short
    }

    static func markdown(context: AssistantLessonContext, exchanges: [AssistantExchange], date: Date,
                         answeredByLabel: String, questionLabel: String, codeLabel: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        var lines = ["# \(context.title)", "", "- date: \(formatter.string(from: date))"]
        if !context.subject.isEmpty { lines.append("- subject: \(context.subject)") }
        if !context.course.isEmpty { lines.append("- course: \(context.course)") }
        if !context.goal.isEmpty { lines.append("- goal: \(context.goal)") }
        for exchange in exchanges {
            lines += ["", "## \(questionLabel): \(exchange.shownQuestion)"]
            if let code = exchange.code, !code.isEmpty {
                lines += ["", "\(codeLabel):", "", "```python", code, "```"]
            }
            lines += ["", exchange.answer, "", "*\(answeredByLabel): \(exchange.answeredBy) · \(exchange.model)*"]
        }
        return lines.joined(separator: "\n") + "\n"
    }
}

/// Order and state of assistant models from `/settings/assistant-models`. / Порядок и состояние моделей ассистента.
struct AssistantModelRow: Decodable, Identifiable, Equatable {
    let id: String
    let label: String
    let tier: String
    let model: String
    let enabled: Bool
    let configured: Bool
    let reachable: Bool?
    let detail: String
    let keyProvider: String?
    let remainingToday: Int?

    enum CodingKeys: String, CodingKey {
        case id, label, tier, model, enabled, configured, reachable, detail
        case keyProvider = "key_provider"
        case remainingToday = "remaining_today"
    }
}

struct AssistantModelsPayload: Decodable, Equatable {
    let order: [String]
    let disabled: [String]
    let providers: [AssistantModelRow]
}

enum AssistantModelOrder {
    /// Moves one id up (-1) or down (+1); out-of-range moves change nothing.
    /// Сдвигает модель вверх (-1) или вниз (+1); за край не сдвигает.
    static func move(_ id: String, by offset: Int, in order: [String]) -> [String] {
        guard let index = order.firstIndex(of: id) else { return order }
        let target = index + offset
        guard order.indices.contains(target) else { return order }
        var result = order
        result.swapAt(index, target)
        return result
    }

    static func toggle(_ id: String, enabled: Bool, disabled: [String]) -> [String] {
        var set = Set(disabled)
        if enabled { set.remove(id) } else { set.insert(id) }
        return set.sorted()
    }
}
