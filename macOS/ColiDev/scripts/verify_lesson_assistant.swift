import Foundation

// Проверяет логику ассистента в уроке: разбор потока, переход на другую модель, историю, заметку Obsidian, порядок моделей.
// Verifies the in-lesson assistant logic: stream parsing, fallback, history, the Obsidian note, model order.

func require(_ condition: Bool, _ message: String) {
    if !condition {
        print("FAIL: \(message)")
        exit(1)
    }
}

@main
struct VerifyLessonAssistant {
    static func main() {
        // Stream with a fallback: Claude not signed in, OpenRouter fails midway, Ollama answers.
        // Поток с переходом: Claude без входа, OpenRouter падает на полпути, отвечает Ollama.
        let lines = [
            ": connected",
            "",
            #"data: {"type":"provider","provider":"claude_cli","label":"Claude","model":"sonnet"}"#,
            #"data: {"type":"fallback","provider":"claude_cli","label":"Claude","reason":"not_signed_in"}"#,
            #"data: {"type":"provider","provider":"openrouter","label":"OpenRouter","model":"openrouter/free"}"#,
            #"data: {"type":"token","content":"полу"}"#,
            #"data: {"type":"reset","provider":"openrouter"}"#,
            #"data: {"type":"fallback","provider":"openrouter","label":"OpenRouter","reason":"rate_limited"}"#,
            #"data: {"type":"provider","provider":"ollama_local","label":"Ollama","model":"qwen3.5"}"#,
            #"data: {"type":"token","content":"Спи"}"#,
            #"data: {"type":"token","content":"сок"}"#,
            #"data: {"type":"done","provider":"ollama_local","label":"Ollama","tier":"local","model":"qwen3.5:latest","answer":"Список","attempts":[]}"#,
            "data: not json",
        ]
        var state = AssistantAnswerState()
        var seen = 0
        for line in lines {
            guard let event = AssistantStreamEvent.parse(line: line) else { continue }
            seen += 1
            state.apply(event)
            if event.type == "reset" { require(state.text.isEmpty, "reset drops the partial answer") }
        }
        require(seen == 10, "ten data events are parsed, comments and garbage skipped: \(seen)")
        require(state.text == "Список" && state.finished, "the final answer is kept")
        require(state.answeredBy == "Ollama" && state.model == "qwen3.5:latest" && state.tier == "local", "who answered is shown")
        require(state.skipped == [AssistantSkip(label: "Claude", reason: "not_signed_in"),
                                  AssistantSkip(label: "OpenRouter", reason: "rate_limited")], "skipped models and why")
        require(state.trying == nil, "nothing is still being tried")

        var failed = AssistantAnswerState()
        failed.apply(AssistantStreamEvent.parse(line: #"data: {"type":"error","error":"Ни одна модель не ответила."}"#)!)
        require(failed.finished && failed.error == "Ни одна модель не ответила." && failed.answeredBy == nil, "error ends the answer")

        // Reasons map to localized keys. / Причины → ключи перевода.
        require(AssistantReason.key("rate_limited") == "assistant.reason.rate_limited", "known reason")
        require(AssistantReason.key("weird") == "assistant.reason.failed", "unknown reason falls back to failed")

        // History for follow-up questions keeps the code and the last 12 turns.
        // История для уточняющих вопросов хранит код и последние 12 реплик.
        var conversation = AssistantConversation()
        for index in 0..<8 {
            conversation.record(AssistantExchange(shownQuestion: "q\(index)", sentQuestion: "Вопрос \(index)",
                                                  code: index == 7 ? "print(1)" : nil, answer: "Ответ \(index)",
                                                  answeredBy: "Claude", model: "claude-sonnet-5-5", skipped: []))
        }
        let history = conversation.history
        require(history.count == AssistantConversation.maxHistoryTurns, "history is cut to 12 turns")
        require(history.first?.role == "user" && history.last?.content == "Ответ 7", "history starts with the learner and ends with the last answer")
        require(history[history.count - 2].content.hasSuffix("```python\nprint(1)\n```"), "the learner's code goes with the question")

        // Obsidian note. / Заметка Obsidian.
        let context = AssistantLessonContext(kind: "lesson", title: "Списки и кортежи: что / выбрать?", subject: "Programming",
                                             goal: "Понять списки")
        let date = Date(timeIntervalSince1970: 1_762_600_000)
        let path = AssistantObsidianNote.path(context: context, date: date)
        require(path.hasPrefix("ColiDev/Assistant/Programming/Списки-и-кортежи-что--выбрать-") && path.hasSuffix(".md"),
                "a safe note path: \(path)")
        require(!path.dropFirst("ColiDev/Assistant/".count).contains("..") && path.split(separator: "/").count == 4, "no extra folders")
        let skillbox = AssistantLessonContext(kind: "skillbox", title: "Декораторы", course: "Python Advanced")
        require(AssistantObsidianNote.path(context: skillbox, date: date).hasPrefix("ColiDev/Assistant/Skillbox/Декораторы-"),
                "Skillbox notes have their own folder")
        let note = AssistantObsidianNote.markdown(context: context, exchanges: conversation.exchanges, date: date,
                                                  answeredByLabel: "Ответил", questionLabel: "Вопрос", codeLabel: "Код")
        require(note.hasPrefix("# Списки и кортежи: что / выбрать?\n") && note.contains("## Вопрос: q7")
                && note.contains("```python\nprint(1)\n```") && note.contains("*Ответил: Claude · claude-sonnet-5-5*"),
                "the note has every question, the code and who answered")

        // Model order in settings. / Порядок моделей в настройках.
        let order = ["claude_cli", "openrouter", "ollama_local"]
        require(AssistantModelOrder.move("ollama_local", by: -1, in: order) == ["claude_cli", "ollama_local", "openrouter"], "move up")
        require(AssistantModelOrder.move("claude_cli", by: -1, in: order) == order, "the first one stays first")
        require(AssistantModelOrder.toggle("gemini", enabled: false, disabled: ["groq"]) == ["gemini", "groq"], "switch off")
        require(AssistantModelOrder.toggle("groq", enabled: true, disabled: ["gemini", "groq"]) == ["gemini"], "switch on")

        let payload = #"{"order":["claude_cli"],"disabled":[],"providers":[{"id":"claude_cli","label":"Claude","tier":"subscription","model":"sonnet","enabled":true,"configured":true,"reachable":false,"detail":"not_signed_in","key_provider":null}]}"#
        let decoded = try? JSONDecoder().decode(AssistantModelsPayload.self, from: Data(payload.utf8))
        require(decoded?.providers.first?.detail == "not_signed_in" && decoded?.providers.first?.remainingToday == nil,
                "settings payload decodes")

        print("Lesson assistant verified / Ассистент в уроке проверен")
    }
}
