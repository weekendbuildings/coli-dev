import Foundation

/// The gradient graph agrees with numeric slopes, and the task needs the largest gradient.
/// Граф градиентов совпадает с численным наклоном, а задание требует самого большого градиента.
@main
enum GradGraphVerification {
    static func main() {
        var state = GradGraphState()
        precondition(state.result == -8)
        precondition(state.gradient(of: .a) == 6 && state.gradient(of: .b) == -4 && state.gradient(of: .c) == -2 && state.gradient(of: .f) == 4)
        precondition(state.strongestInput == .a)
        func formula(_ a: Double, _ b: Double, _ c: Double, _ f: Double) -> Double { (a * b + c) * f }
        let h = 1e-5
        let numeric = (formula(2 + h, -3, 10, -2) - formula(2 - h, -3, 10, -2)) / (2 * h)
        precondition(abs(numeric - state.gradient(of: .a)) < 1e-6, "The gradient must match the numeric slope. / Градиент совпадает с численным наклоном.")

        precondition(state.revealedGradient(of: .a) == nil)
        state.stepBack()
        precondition(state.revealedGradient(of: .result) == 1 && state.revealedGradient(of: .sum) == nil)
        state.finishBackward()
        precondition(state.finished && state.revealedGradient(of: .a) == 6)

        state.nudge(.a, up: true)
        precondition(state.lastPredicted == 3 && state.lastReal == 3, "A linear input moves exactly as predicted. / Линейный вход меняется точно по предсказанию.")
        precondition(state.stage == 0 && !state.finished, "New numbers need a new pass. / Новым числам нужен новый проход.")
        state.nudge(.a, up: true)
        state.nudge(.a, up: true)
        precondition(state.result == 1 && state.solved, "Three pushes of a are enough. / Хватает трёх толчков по a.")

        var other = GradGraphState()
        for _ in 0..<3 { other.nudge(.f, up: true) }
        precondition(other.result <= 0 && !other.solved, "A weaker input does not solve it in three pushes. / Слабый вход за три толчка не решает.")
        var late = GradGraphState()
        for _ in 0..<4 { late.nudge(.f, up: true) }
        late.nudge(.a, up: true)
        precondition(!late.solved, "Too many pushes do not count. / Слишком много толчков не считается.")
        print("Gradient graph verified. / Граф градиентов проверен.")
    }
}
