import Foundation

/// The prompt lab's recorded results, matching the lesson. / Записанные результаты тренажёра, как в уроке.
@main
enum PromptLabVerification {
    static func main() {
        func combo(_ rule: Bool, _ examples: Bool, _ shape: Bool) -> PromptLabCombo {
            var state = PromptLabState()
            state.rule = rule
            state.examples = examples
            state.shape = shape
            return state.combo
        }
        precondition(PromptLabRecording.combos.count == 8 && PromptLabRecording.orders.count == 12)
        precondition(PromptLabRecording.combos.allSatisfy { $0.answers.count == 12 && $0.marks.count == 12 })
        precondition(combo(false, false, false).rightCount == 0)
        precondition(combo(true, false, false).rightCount == 0 && combo(true, false, false).brokenCount == 12, "A rule alone fails on the markup. / Одно правило ломается на разметке.")
        precondition(combo(false, true, false).rightCount == 12, "Examples alone are enough here. / Здесь хватает одних примеров.")
        precondition(combo(false, false, true).rightCount == 10 && combo(false, false, true).brokenCount == 0, "A shape stops failures, not errors of meaning. / Форма убирает сбои, а не ошибки смысла.")
        let best = PromptLabState.cheapestFull
        precondition(best.rule && !best.examples && best.shape && best.tokens == 101)
        var state = PromptLabState()
        precondition(!state.solved)
        state.select(best)
        precondition(state.solved && state.rule && state.shape && !state.examples)
        state.examples = true
        precondition(state.combo.rightCount == 12 && !state.solved, "All right but costlier is not the task. / Всё верно, но дороже: это не решение.")
        print("Prompt lab verified. / Тренажёр о подсказках проверен.")
    }
}
