import Foundation

/// The three rules take the same number of steps as the lesson's program. / Три правила делают столько же шагов, сколько в программе урока.
@main
enum OptimizerValleyVerification {
    static func main() {
        let start = OptimizerRaceState.defaultStart
        func steps(_ kind: OptimizerKind, _ rate: Double) -> Int? {
            OptimizerValley.stepsToGoal(OptimizerValley.path(kind, rate: rate, start: start))
        }
        precondition(steps(.plain, 0.1) == nil && steps(.plain, 0.5) == 346 && steps(.plain, 0.9) == 192 && steps(.plain, 0.99) == 187)
        precondition(steps(.plain, 1.01) == nil && OptimizerValley.diverged(OptimizerValley.path(.plain, rate: 1.01, start: start)))
        precondition(steps(.momentum, 0.1) == 166 && steps(.momentum, 0.3) == 55 && steps(.momentum, 0.5) == 36 && steps(.momentum, 1) == 41)
        precondition(steps(.adam, 0.1) == 87 && steps(.adam, 0.5) == 15 && steps(.adam, 1) == 9)
        let first = OptimizerValley.path(.adam, rate: 0.5, start: start, steps: 1)[1]
        precondition(abs(first.x + 7.5) < 1e-6 && abs(first.y - 1.5) < 1e-6, "Adam's first step equals the rate on each axis. / Первый шаг Adam равен шагу по каждой оси.")

        var state = OptimizerRaceState()
        precondition(!state.solved && state.step == 0)
        state.setRate(.plain, 0.99)
        state.setRate(.momentum, 0.3)
        state.setRate(.adam, 0.5)
        precondition(!state.solved, "Good steps alone are not enough: first see the limit. / Сначала надо увидеть предел.")
        state.setRate(.plain, 1.05)
        precondition(state.sawDivergence && state.diverged(.plain))
        state.setRate(.plain, 0.99)
        precondition(state.solved)
        for _ in 0..<500 { state.advance() }
        precondition(state.step == OptimizerRaceState.lastStep)
        let revision = state.revision
        state.restart()
        precondition(state.step == 0 && state.revision == revision + 1)
        print("Optimizer valley verified. / Долина оптимизаторов проверена.")
    }
}
