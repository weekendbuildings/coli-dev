import Foundation

@main
enum GradientStackVerification {
    typealias Model = GradientStackModel

    static func main() {
        // The numbers of the lesson's program. / Числа программы урока.
        let without = Model(depth: 12, bypass: false)
        let with = Model(depth: 12, bypass: true)
        precondition(String(format: "%.2e", without.bottomSignal) == "4.59e-06", "without a bypass")
        precondition(String(format: "%.2e", with.bottomSignal) == "1.28e+00", "with a bypass")

        // The backward pass is the true slope: compare with finite differences, in both modes.
        for model in [without, with, Model(depth: 3, bypass: false), Model(depth: 3, bypass: true)] {
            let exact = Model.signal(layers: model.layers, start: model.start, bypass: model.bypass).gradient
            for index in 0..<Model.size {
                var up = model.start
                var down = model.start
                up[index] += 1e-6
                down[index] -= 1e-6
                let slope = (Model.forward(layers: model.layers, start: up, bypass: model.bypass).output[0]
                    - Model.forward(layers: model.layers, start: down, bypass: model.bypass).output[0]) / 2e-6
                precondition(abs(slope - exact[index]) < 1e-5, "the backward pass matches the numerical slope")
            }
        }

        // The signal fades with depth without a bypass, and holds with one.
        var previous = 1.0
        for depth in stride(from: 4, through: 16, by: 4) {
            let fading = Model(depth: depth, bypass: false).bottomSignal
            precondition(fading < previous, "deeper fades more")
            previous = fading
            let held = Model(depth: depth, bypass: true).bottomSignal
            precondition(Model.keptSignal.contains(held), "a bypass holds the signal at depth \(depth)")
        }

        // The opening does not solve the task, a shallow stack earns nothing, and the bypass solves it.
        let opening = Model()
        precondition(opening.depth == 12 && !opening.bypass && !opening.solvesChallenge)
        precondition(with.solvesChallenge)
        precondition(!Model(depth: 4, bypass: true).solvesChallenge, "a shallow stack is too easy")
        precondition(Model(depth: 16, bypass: true).solvesChallenge)

        // One size per layer, from the top to the bottom. / По размеру на слой, от верхнего к нижнему.
        precondition(with.signalSizes.count == 12 && Model(depth: 2).signalSizes.count == 2)

        // The exercise of the lesson has an answer: the depth where the signal falls below a thousandth.
        let crossing = Model.depths.first { Model(depth: $0, bypass: false).bottomSignal < 1e-3 }
        precondition(crossing != nil && crossing! >= 3 && crossing! <= 8, "the exercise has a clear answer")

        print("Gradient stack verification passed.")
    }
}
