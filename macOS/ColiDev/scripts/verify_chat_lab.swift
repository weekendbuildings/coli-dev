import Foundation

/// The chat lab's template, state and fallback to the recording, with no Ollama needed.
/// Шаблон, состояние и переход на запись в тренажёре о чате: Ollama для проверки не нужна.
@main
enum ChatLabVerification {
    private struct DownSource: ChatLabSource {
        func chat(messages: [ChatLabMessage], window: Int) async throws -> ChatLabAnswer { throw URLError(.cannotConnectToHost) }
        func complete(prompt: String, window: Int) async throws -> ChatLabAnswer { throw URLError(.cannotConnectToHost) }
    }

    @MainActor
    private static func waitUntilIdle(_ controller: ChatLabController) async {
        for _ in 0..<2000 {
            if !controller.busy { return }
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
        preconditionFailure("The lab must finish. / Тренажёр должен закончить работу.")
    }

    private static func checkTemplate() {
        var state = ChatLabState()
        state.scenario = .wrapper
        let expected = "<|im_start|>system\nОтвечай одним словом.<|im_end|>\n<|im_start|>user\nСтолица Франции?<|im_end|>\n<|im_start|>assistant\n"
        precondition(state.renderedPrompt == expected, "The rendered text must be the template's. / Текст должен совпасть с шаблоном.")
        precondition(ChatLabRecording.answers[expected]?.1 == 28)
        state.useRule = false
        precondition(state.renderedPrompt.contains(ChatLabAPI.defaultSystem), "Without a rule the template adds its own. / Без правила шаблон добавляет своё.")
        precondition(ChatLabRecording.answers[state.renderedPrompt] != nil)
    }

    private static func checkWindow() {
        var state = ChatLabState()
        state.scenario = .window
        precondition(state.messages.count == 63 && state.messages.first?.text.contains("кактус") == true)
        state.window = 4096
        precondition(state.droppedMessages == 0, "A window larger than the chat drops nothing. / Окно больше чата ничего не отбрасывает.")
        state.window = 2048
        precondition(state.droppedMessages >= 1, "A smaller window drops the secret first. / Меньшее окно первым отбрасывает секрет.")
        state.window = 256
        let few = state.droppedMessages
        precondition(few > 40 && few < state.messages.count)
    }

    private static func checkParsing() throws {
        let chat = try ChatLabAPI.parse(Data(#"{"message":{"role":"assistant","content":"Париж"},"prompt_eval_count":28}"#.utf8))
        precondition(chat == ChatLabAnswer(text: "Париж", promptTokens: 28))
        let raw = try ChatLabAPI.parse(Data(#"{"response":"Париж","prompt_eval_count":28}"#.utf8))
        precondition(raw == chat, "Both endpoints must give the same answer shape. / Оба адреса дают ответ одного вида.")
        precondition((try? ChatLabAPI.parse(Data("{}".utf8))) == nil)
        let body = ChatLabAPI.chatBody(messages: [ChatLabMessage(id: 0, role: .user, text: "x")], window: 512)
        precondition((body["options"] as? [String: Any])?["num_ctx"] as? Int == 512)
    }

    @MainActor
    private static func checkExperiments() async {
        let controller = ChatLabController(live: DownSource())
        controller.state.sendHistory = false
        controller.ask()
        await waitUntilIdle(controller)
        precondition(controller.mode == .recording && controller.state.answer?.text.contains("Тимур") == false, "Without history the name is unknown. / Без истории имя неизвестно.")
        controller.changed()
        controller.state.sendHistory = true
        controller.ask()
        await waitUntilIdle(controller)
        precondition(controller.state.answer?.text.contains("Тимур") == true, "With history the name is known. / С историей имя известно.")
        precondition(!controller.state.solved)

        controller.changed()
        controller.state.scenario = .forged
        controller.state.followUp = 0
        controller.ask()
        await waitUntilIdle(controller)
        precondition(controller.state.answer?.text.contains("2 + 2 = 5") == true, "The model repeats the forged words. / Модель повторяет подделанные слова.")
        controller.changed()
        controller.state.forgedAnswer = "другой текст"
        controller.ask()
        await waitUntilIdle(controller)
        precondition(controller.notRecorded, "A changed text is not in the recording. / Изменённого текста нет в записи.")

        controller.changed()
        controller.state.scenario = .wrapper
        controller.ask()
        await waitUntilIdle(controller)
        precondition(controller.state.answersMatch == true, "The chat and the hand-written text agree. / Чат и текст вручную совпадают.")

        controller.changed()
        controller.state.scenario = .window
        controller.state.window = 2048
        controller.ask()
        await waitUntilIdle(controller)
        precondition(controller.state.remembersSecret == false)
        controller.changed()
        controller.state.window = 4096
        controller.ask()
        await waitUntilIdle(controller)
        precondition(controller.state.remembersSecret == true && controller.state.solved, "Both sides of the window solve the task. / Обе стороны окна решают задание.")
    }

    @MainActor
    static func main() async {
        do {
            checkTemplate()
            checkWindow()
            try checkParsing()
            await checkExperiments()
            print("Chat anatomy lab verified. / Тренажёр о чате проверен.")
        } catch {
            preconditionFailure("\(error)")
        }
    }
}
