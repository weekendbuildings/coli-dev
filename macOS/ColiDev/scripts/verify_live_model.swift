import Foundation

/// The lab's maths, Ollama parsing, state and fallback to the recording, with no Ollama needed.
/// Математика тренажёра, разбор ответа Ollama, состояние и переход на запись: Ollama для проверки не нужна.
@main
enum LiveModelVerification {
    private struct DownSource: LiveModelSource {
        func step(prompt: String, temperature: Double, seed: Int) async throws -> LiveModelStep {
            throw URLError(.cannotConnectToHost)
        }
    }

    private struct FakeLiveSource: LiveModelSource {
        func step(prompt: String, temperature: Double, seed: Int) async throws -> LiveModelStep {
            let best = NextTokenCandidate(token: " Paris", probability: 0.5)
            let second = NextTokenCandidate(token: " a", probability: 0.25)
            return LiveModelStep(chosen: temperature < 0.5 ? " Paris" : " odd", candidates: [best, second], promptTokens: prompt.count, milliseconds: 80)
        }
    }

    private static func rounded(_ values: [Double]) -> [Double] {
        values.map { ($0 * 1000).rounded() / 1000 }
    }

    @MainActor
    private static func waitUntilIdle(_ controller: LiveModelLabController) async {
        for _ in 0..<2000 {
            if !controller.busy { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        preconditionFailure("The lab must finish its work. / Тренажёр должен закончить работу.")
    }

    private static func checkMaths() {
        precondition(rounded(LiveModelMath.reshape([0.6, 0.3, 0.1], temperature: 1)) == [0.6, 0.3, 0.1])
        precondition(rounded(LiveModelMath.reshape([0.6, 0.3, 0.1], temperature: 0.5)) == [0.783, 0.196, 0.022])
        precondition(rounded(LiveModelMath.reshape([0.6, 0.3, 0.1], temperature: 2)) == [0.473, 0.334, 0.193])
        precondition(LiveModelMath.reshape([0.1, 0.6, 0.3], temperature: 0) == [0, 1, 0], "T = 0 always takes the best. / При T = 0 всегда берётся лучший.")
        precondition(LiveModelMath.visibleToken(" Paris") == "␣Paris")
        precondition(LiveModelMath.visibleToken(":\n") == ":⏎")
    }

    private static func checkParsing() throws {
        let answer = """
        {"response":" Paris","prompt_eval_count":5,"eval_duration":80000000,
         "logprobs":[{"token":" Paris","logprob":-0.4599,"top_logprobs":[
           {"token":" Paris","logprob":-0.4599},{"token":" __","logprob":-3.0503}]}]}
        """
        let step = try LiveModelAPI.parse(Data(answer.utf8))
        precondition(step.chosen == " Paris" && step.promptTokens == 5 && step.milliseconds == 80)
        precondition(step.candidates.count == 2 && abs(step.candidates[0].probability - 0.6313) < 0.001, "Log-probabilities must become probabilities. / Логарифмы должны стать вероятностями.")
        precondition((try? LiveModelAPI.parse(Data("{}".utf8))) == nil, "An answer without tokens is an error. / Ответ без токенов это ошибка.")

        let body = LiveModelAPI.body(prompt: "x", temperature: 2, seed: 7)
        let options = body["options"] as? [String: Any]
        precondition(body["raw"] as? Bool == true && body["top_logprobs"] as? Int == 20)
        precondition(options?["top_k"] as? Int == 0 && options?["top_p"] as? Int == 1 && options?["num_predict"] as? Int == 1, "Other filters must be off, as in the lesson. / Другие фильтры выключены, как в уроке.")
    }

    private static func checkState() {
        var state = LiveModelLabState(prompt: "x")
        state.show(LiveModelStep(chosen: "a", candidates: [
            NextTokenCandidate(token: "a", probability: 0.6), NextTokenCandidate(token: "b", probability: 0.1)
        ], promptTokens: 1, milliseconds: 80))
        precondition(abs(state.restProbability - 0.3) < 1e-9)
        for temperature in [0.0, 1.0, 2.0] {
            state.startThrows(temperature: temperature)
            state.recordThrow(token: "a", milliseconds: 80)
            state.recordThrow(token: "rare", milliseconds: 80)
            precondition(state.otherCount == 1 && state.share(of: "a") == 0.5)
            state.finishThrows()
        }
        precondition(state.experiments.map(\.temperature) == [0, 1, 2] && state.experimentDone)
        state.append(token: "a")
        precondition(state.fullText == "xa" && state.written[0].probability == 0.6)
        precondition(state.experiments.isEmpty && !state.experimentDone, "A new text needs new experiments. / Для нового текста нужны новые опыты.")
    }

    private static func checkRecording() async throws {
        let source = RecordedLiveSource()
        let first = try await source.step(prompt: LiveModelRecording.prompt, temperature: 0, seed: 1)
        precondition(first.chosen == " Paris" && first.promptTokens == 5 && first.candidates[0].token == " Paris")
        precondition(LiveModelRecording.vocabulary == 152_064)
        var rare = 0
        for seed in 0..<1000 where RecordedLiveSource.draw(temperature: 2, seed: seed * 997) == RecordedLiveSource.otherToken { rare += 1 }
        precondition(rare > 900, "At T = 2 the recording must fall on rare tokens, as the real model did. / При T = 2 запись должна падать на редкие токены, как настоящая модель.")
        var unknown = false
        do { _ = try await source.step(prompt: "not recorded", temperature: 0, seed: 1) } catch { unknown = error as? LiveModelError == .notRecorded }
        precondition(unknown)
    }

    @MainActor
    private static func checkController() async {
        let down = LiveModelLabController(live: DownSource())
        down.start()
        await waitUntilIdle(down)
        precondition(down.mode == .recording && down.state.best?.token == " Paris", "Without Ollama the lab must show the recording. / Без Ollama тренажёр показывает запись.")
        down.nextToken(temperature: 0)
        await waitUntilIdle(down)
        precondition(down.state.written.map(\.token) == [" Paris"] && down.state.candidates.first?.token == ".")
        down.restart()
        await waitUntilIdle(down)
        precondition(down.state.written.isEmpty)
        for temperature in [0.0, 1.0, 2.0] {
            down.throwMany(temperature: temperature)
            await waitUntilIdle(down)
            precondition(down.state.thrown == LiveModelLabState.throwsPerExperiment)
        }
        precondition(down.state.experimentDone, "Three experiments solve the task. / Три опыта решают задание.")
        let shares = down.state.experiments.map(\.bestShare)
        precondition(shares[0] == 1 && shares[1] > 0.4 && shares[2] < 0.15, "The best token falls less often when hot. / Чем горячее, тем реже лучший токен: \(shares)")
        down.use(prompt: "текст, которого нет в записи")
        await waitUntilIdle(down)
        precondition(down.outOfRecording, "A text outside the recording must say so. / Текст вне записи должен об этом сообщить.")

        let live = LiveModelLabController(live: FakeLiveSource())
        live.start()
        await waitUntilIdle(live)
        precondition(live.mode == .live && live.state.promptTokens == LiveModelRecording.prompt.count)
        live.pick(token: " a")
        await waitUntilIdle(live)
        precondition(live.state.written.first?.probability == 0.25, "The learner's pick keeps its probability. / Выбор ученика сохраняет вероятность.")
        live.nextToken(temperature: 2)
        await waitUntilIdle(live)
        precondition(live.state.written.last?.token == " odd" && live.state.written.last?.probability == nil, "The model's own choice may lie outside the candidates. / Модель может выбрать токен вне кандидатов.")
    }

    @MainActor
    static func main() async {
        do {
            checkMaths()
            try checkParsing()
            checkState()
            try await checkRecording()
            await checkController()
            print("Live model lab verified. / Тренажёр с живой моделью проверен.")
        } catch {
            preconditionFailure("\(error)")
        }
    }
}
