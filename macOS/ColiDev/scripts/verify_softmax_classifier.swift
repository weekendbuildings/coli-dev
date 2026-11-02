import Foundation

@main
enum SoftmaxClassifierVerification {
    typealias Model = SoftmaxClassifierModel

    static func run(_ start: Model, rate: Double, steps: Int) -> Model {
        var model = start
        for _ in 0..<steps where !model.isFinished { model.step(rate: rate) }
        return model
    }

    static func main() {
        // The lesson's numbers. / Числа урока.
        let q = Model.softmax([2, 1, 0])
        precondition(abs(q[0] - 0.665) < 0.001 && abs(q[1] - 0.245) < 0.001 && abs(q[2] - 0.090) < 0.001, "softmax")
        precondition(zip(Model.softmax([3, 2, 1]), q).allSatisfy { abs($0 - $1) < 1e-12 }, "only differences matter")
        let sharper = Model.softmax([4, 2, 0])
        precondition(abs(sharper[0] - 0.867) < 0.001 && abs(sharper[2] - 0.016) < 0.001, "larger differences, more confidence")
        // Huge scores must not overflow. / Огромные оценки не должны переполнять вычисление.
        let huge = Model.softmax([1000, 999, 0])
        precondition(huge.allSatisfy(\.isFinite) && abs(huge.reduce(0, +) - 1) < 1e-12, "no overflow")

        // The start is ln 3, and the opening does not solve the task.
        let opening = Model()
        precondition(abs(opening.loss - log(3)) < 1e-12 && opening.phase == .ready && !opening.solvesChallenge)
        precondition(opening.correctCount == 4, "with equal scores the first class is chosen")

        // The gradient equals the numerical slope.
        var probe = run(Model(), rate: 0.3, steps: 5)
        let exact = probe.gradient
        let base = probe
        for k in 0..<3 {
            for i in 0..<3 {
                var plus = base
                var minus = base
                plus.nudge(k, i, 1e-6)
                minus.nudge(k, i, -1e-6)
                let slope = (plus.loss - minus.loss) / 2e-6
                precondition(abs(slope - exact[k][i]) < 1e-6, "gradient")
            }
        }
        probe.restart()
        precondition(probe.steps == 0 && probe.loss == Model().loss)

        // The confidence slope equals the numerical slope of the relief.
        let trained = run(Model(), rate: 0.3, steps: 60)
        for (x1, x2) in [(0.4, -0.2), (-0.9, 0.6), (1.2, 1.1)] {
            let h = 1e-6
            let dx = (trained.confidence(x1: x1 + h, x2: x2) - trained.confidence(x1: x1 - h, x2: x2)) / (2 * h)
            let dy = (trained.confidence(x1: x1, x2: x2 + h) - trained.confidence(x1: x1, x2: x2 - h)) / (2 * h)
            let slope = trained.confidenceSlope(x1: x1, x2: x2)
            precondition(abs(dx - slope.x) < 1e-5 && abs(dy - slope.y) < 1e-5, "relief slope")
        }

        // The program of the lesson, step by step.
        precondition(abs(run(Model(), rate: 0.3, steps: 20).loss - 0.32) < 0.001)
        precondition(abs(trained.loss - 0.122) < 0.001)
        let finished = run(Model(), rate: 0.3, steps: 300)
        precondition(abs(finished.loss - 0.027) < 0.001 && finished.correctCount == 12)
        let sure = finished.probabilities(x1: 0.9, x2: -0.8)
        precondition(abs(sure[1] - 0.992) < 0.001, "the model is sure inside a cloud")
        let hesitant = finished.probabilities(x1: 0, x2: -0.3)
        precondition(abs(hesitant[0] - 0.396) < 0.001 && abs(hesitant[1] - 0.397) < 0.001, "the model hesitates between clouds")

        // The task: η = 0.1 is too slow for 40 steps, and η = 0.3 is enough.
        precondition(!run(Model(), rate: 0.1, steps: 40).solvesChallenge, "the default rate does not solve the task")
        precondition(run(Model(), rate: 0.3, steps: 40).solvesChallenge, "a higher rate solves it")
        var late = run(Model(), rate: 0.1, steps: 100)
        precondition(late.loss < 0.25 && !late.solvesChallenge, "too late earns nothing")
        late.restart()

        // A new point cancels the credit and raises the error. / Новая точка снимает зачёт и поднимает ошибку.
        var added = run(Model(), rate: 0.3, steps: 40)
        let lossBefore = added.loss
        added.add(.init(x1: 0, x2: 1, label: 0))
        precondition(added.loss > lossBefore && !added.solvesChallenge && added.samples.count == 13)
        added.restart()
        precondition(added.samples.count == 12 && added.addedPoints == 0)

        // XOR freezes near ln 2 with half the points wrong, as the lesson says.
        var xor = Model(dataSet: .xor)
        for _ in 0..<Model.stepLimit where !xor.isFinished && xor.phase != .stalled { xor.step(rate: 1) }
        precondition(xor.phase == .stalled, "XOR stalls")
        precondition(abs(xor.loss - log(2)) < 0.02, "XOR freezes near ln 2")
        precondition(xor.correctCount <= 6, "one line cannot separate XOR")

        // Too large a rate makes it worse. / Слишком большой шаг всё портит.
        precondition(run(Model(dataSet: .xor), rate: 30, steps: 60).phase == .flewOff, "a huge rate flies off")

        // The step limit stops training.
        var long = Model()
        for _ in 0..<(Model.stepLimit + 20) { long.step(rate: 0.01) }
        precondition(long.steps == Model.stepLimit && long.phase == .outOfSteps)

        print("Softmax classifier verification passed.")
    }
}

extension SoftmaxClassifierModel {
    /// For the numerical check only: rebuilds a model with one weight moved. / Только для численной проверки.
    mutating func nudge(_ k: Int, _ i: Int, _ amount: Double) {
        var moved = weights
        moved[k][i] += amount
        replaceWeights(moved)
    }
}
