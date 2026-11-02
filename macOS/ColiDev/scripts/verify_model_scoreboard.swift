import Foundation

/// The scoreboard's recorded data and rules, matching the lesson. / Записанные данные и правила таблицы, как в уроке.
@main
enum ModelScoreboardVerification {
    static func main() {
        let items = ModelScoreboardState.items
        precondition(items.count == 20)
        precondition(items.filter(\.right).count == 9, "The lesson says 9 of 20. / В уроке 9 из 20.")
        precondition(items.filter(\.biggerRight).count == 14, "The lesson says 14 of 20. / В уроке 14 из 20.")
        let above = ModelScoreboardState.rule(above: 0.8)
        precondition(above.trusted == 12 && above.right == 8, "The lesson's threshold table. / Таблица порогов из урока.")
        precondition(items.filter { $0.confidence < 0.7 }.allSatisfy { !$0.right }, "Low confidence answers are all wrong here. / Все ответы с низкой уверенностью неверны.")
        precondition(items.contains { $0.confidence > 0.95 && !$0.right }, "High confidence can be wrong. / Высокая уверенность бывает неверной.")

        var state = ModelScoreboardState()
        precondition(!state.isRevealed)
        state.threshold = 0.9995
        precondition(!state.solved, "Nothing passes, so this is no solution. / Ничего не прошло, это не решение.")
        state.threshold = 0.9965
        precondition(ModelScoreboardState.rule(above: 0.9965).trusted == 1 && ModelScoreboardState.rule(above: 0.9965).right == 1)
        precondition(!state.solved, "Bets come first. / Сначала ставки.")
        for index in 0..<ModelScoreboardState.betsForTask {
            state.selected = index
            state.bet(trust: true)
            state.bet(trust: false)
            precondition(state.bets[index] == true, "A bet cannot be changed. / Ставку нельзя поменять.")
        }
        precondition(state.solved)
        precondition(state.guessedRight == items.prefix(ModelScoreboardState.betsForTask).filter(\.right).count)
        state.threshold = 0.8
        precondition(!state.solved, "A lower threshold lets wrong answers in. / Низкий порог пропускает неверные ответы.")
        print("Model scoreboard verified. / Таблица модели проверена.")
    }
}
