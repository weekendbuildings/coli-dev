import Foundation

@main
enum NeuralMathLabsVerification {
    static func close(_ a: Double, _ b: Double, _ tolerance: Double = 1e-9) -> Bool { abs(a - b) < tolerance }

    static func main() {
        typealias Layer = NeuralLayerModel
        // Lesson quiz: W = [[1, 2], [0, −1]], x = (3, 4) gives Wx = (11, −4).
        let quiz = Layer.preActivation(weights: [[1, 2], [0, -1]], input: [3, 4], bias: [0, 0])
        precondition(quiz == [11, -4])
        precondition(Layer.relu(quiz) == [11, 0])
        precondition(Layer.preActivation(weights: [[1, 2], [0, -1]], input: [3, 4], bias: [-2, 5]) == [9, 1])
        // Perpendicular vectors from the practice task: (2, 1) · (−1, 2) = 0.
        precondition(Layer.preActivation(weights: [[2, 1]], input: [-1, 2], bias: [0]) == [0])

        typealias Descent = GradientDescent2DModel
        typealias Point = Descent.Point
        // Lesson quiz: from (1, 1) with ε = 0.1 the step lands at (0.8, 0.4).
        let quizStep = Descent.step(Point(x: 1, y: 1), rate: 0.1)
        precondition(close(quizStep.x, 0.8) && close(quizStep.y, 0.4))
        // Practice task: ∇f(2, −1) = (4, −6); with ε = 0.1 the value falls from 7 to 3.04.
        let start = Point(x: 2, y: -1)
        precondition(Descent.gradient(start) == Point(x: 4, y: -6) && close(Descent.value(start), 7))
        let small = Descent.step(start, rate: 0.1)
        precondition(close(small.x, 1.6) && close(small.y, -0.4) && close(Descent.value(small), 3.04))
        // With ε = 0.5, y jumps over the minimum from −1 to 2 and the value grows to 12.
        let large = Descent.step(start, rate: 0.5)
        precondition(close(large.x, 0) && close(large.y, 2) && close(Descent.value(large), 12))
        // Convergence needs |1 − 2ε| < 1 and |1 − 6ε| < 1, that is 0 < ε < 1/3.
        precondition(Descent.converges(rate: 0.1) && Descent.converges(rate: 0.33) && !Descent.converges(rate: 0.34))
        precondition(!Descent.converges(rate: 0.5))
        for rate in [0.05, 0.1, 0.2, 0.3] {
            var point = start
            for _ in 0..<200 { point = Descent.step(point, rate: rate) }
            precondition(Descent.value(point) < 1e-6, "ε = \(rate) must converge")
        }
        var point = start
        var steps = 0
        while !Descent.hasDiverged(point) && steps < 100 { point = Descent.step(point, rate: 0.5); steps += 1 }
        precondition(Descent.hasDiverged(point), "ε = 0.5 must diverge in y")
        print("Neural layer and 2D gradient descent lab models verified")
    }
}
