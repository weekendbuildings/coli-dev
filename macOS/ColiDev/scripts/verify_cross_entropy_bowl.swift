import Foundation

@main
enum CrossEntropyBowlVerification {
    typealias Model = CrossEntropyBowlModel

    static func run(_ start: Model) -> Model {
        var model = start
        while !model.isFinished { model.step() }
        return model
    }

    static func main() {
        // The lesson's numbers. / Числа урока.
        let letters = [0.5, 0.25, 0.125, 0.125]
        precondition(abs(Model.entropy(letters) - 1.75) < 1e-12, "entropy")
        precondition(abs(Model.crossEntropy(letters, [0.25, 0.25, 0.25, 0.25]) - 2) < 1e-12, "uniform belief")
        precondition(abs(Model.crossEntropy(letters, [0.125, 0.125, 0.25, 0.5]) - 2.625) < 1e-12, "wrong order")
        precondition(abs(Model.crossEntropy(letters, letters) - 1.75) < 1e-12, "matching belief")

        // The bowl has one bottom: no belief goes below the entropy, for every truth.
        for truth in Model.truths {
            let bottom = Model.entropy(truth)
            for a in stride(from: 0.01, to: 1, by: 0.03) {
                for b in stride(from: 0.01, to: 1 - a, by: 0.03) {
                    let q = [a, b, 1 - a - b]
                    guard q[2] > 0 else { continue }
                    precondition(Model.crossEntropy(truth, q) >= bottom - 1e-12, "cross-entropy stays above entropy")
                }
            }
            precondition(abs(Model.crossEntropy(truth, truth) - bottom) < 1e-12, "the bottom is at the truth")
        }
        // The entropies of the three truths, in the order the lab names them.
        precondition(abs(Model.entropy(Model.truths[0]) - 1.295) < 0.001)
        precondition(abs(Model.entropy(Model.truths[1]) - 1.585) < 0.001)
        precondition(abs(Model.entropy(Model.truths[2]) - 0.569) < 0.001)

        // The gradient over softmax scores is q − p, in nats: compare with the numerical slope.
        let scores = [0.3, -1.1, 0.7]
        let q = Model.softmax(scores)
        let truth = Model.truths[0]
        for index in scores.indices {
            var up = scores
            var down = scores
            up[index] += 1e-6
            down[index] -= 1e-6
            let slope = (Model.crossEntropy(truth, Model.softmax(up)) - Model.crossEntropy(truth, Model.softmax(down))) / 2e-6 * log(2.0)
            precondition(abs(slope - (q[index] - truth[index])) < 1e-6, "softmax gradient")
        }

        // The opening does not solve the task, and neither does training from it: it starts too low.
        let opening = Model()
        precondition(opening.phase == .ready && !opening.solvesChallenge)
        precondition(abs(opening.belief[0] - 1.0 / 3) < 1e-12)
        let fromOpening = run(opening)
        precondition(fromOpening.phase == .reachedBottom && !fromOpening.solvesChallenge, "the opening is too low for the task")

        // A start high on the wall can be trained to the bottom, and that solves it.
        let high = Model(belief: [0.02, 0.02, 0.96])
        precondition(high.startGap >= Model.challengeStartGap)
        let trained = run(high)
        precondition(trained.phase == .reachedBottom && trained.solvesChallenge, "training reaches the bottom")
        precondition(trained.steps <= Model.stepLimit)
        precondition(zip(trained.history, trained.history.dropFirst()).allSatisfy { $0 >= $1 }, "the error never rises")
        for (a, b) in zip(trained.belief, Model.truths[0]) { precondition(abs(a - b) < 0.1, "the belief approaches the truth") }

        // A click on the bottom itself earns nothing. / Щелчок прямо в дно не засчитывается.
        let inside = Model(belief: Model.truths[0])
        precondition(inside.phase == .reachedBottom && !inside.solvesChallenge)

        // A belief of zero is lifted, so the error stays finite, and restart returns to the same start.
        let zero = Model(belief: [1, 0, 0])
        precondition(zero.belief.allSatisfy { $0 > 0 } && zero.error.isFinite)
        precondition(abs(zero.belief.reduce(0, +) - 1) < 1e-12)
        var restarted = trained
        restarted.restart()
        precondition(restarted.steps == 0 && restarted.start == trained.start && restarted.path.count == 1)

        print("Cross-entropy bowl verification passed.")
    }
}
