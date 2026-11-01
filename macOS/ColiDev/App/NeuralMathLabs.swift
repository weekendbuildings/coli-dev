import Foundation

/// One layer of an artificial neural network for the mathematics lesson on vectors and matrices
/// (Goodfellow, Bengio, Courville, Deep Learning, chapter 6): each output is the dot product of one weight row
/// with the input plus a bias, h = g(Wx + b), here with the optional nonlinearity g(z) = max(0, z) (ReLU).
enum NeuralLayerModel {
    static let weightRange = -3...3
    static let inputRange = -5...5
    static let biasRange = -5...5

    static func preActivation(weights: [[Int]], input: [Int], bias: [Int]) -> [Int] {
        zip(weights, bias).map { row, offset in zip(row, input).reduce(offset) { $0 + $1.0 * $1.1 } }
    }

    static func relu(_ values: [Int]) -> [Int] { values.map { max(0, $0) } }
}

/// Gradient descent on f(x, y) = x² + 3y² for the mathematics lesson on gradients: ∇f = (2x, 6y), and a step
/// x′ = x − ε∇f(x) multiplies x by (1 − 2ε) and y by (1 − 6ε), so it converges only while both stay within (−1, 1).
enum GradientDescent2DModel {
    struct Point: Equatable {
        var x: Double
        var y: Double
    }

    static let rateRange = 0.01...0.5
    static let starts = [Point(x: 1, y: 1), Point(x: 2, y: -1)]
    /// Beyond this distance the lab stops stepping: the descent has clearly diverged.
    static let divergenceLimit = 1_000.0

    static func value(_ point: Point) -> Double { point.x * point.x + 3 * point.y * point.y }

    static func gradient(_ point: Point) -> Point { Point(x: 2 * point.x, y: 6 * point.y) }

    static func step(_ point: Point, rate: Double) -> Point {
        let slope = gradient(point)
        return Point(x: point.x - rate * slope.x, y: point.y - rate * slope.y)
    }

    static func xFactor(rate: Double) -> Double { 1 - 2 * rate }

    static func yFactor(rate: Double) -> Double { 1 - 6 * rate }

    static func converges(rate: Double) -> Bool { abs(xFactor(rate: rate)) < 1 && abs(yFactor(rate: rate)) < 1 }

    static func hasDiverged(_ point: Point) -> Bool { max(abs(point.x), abs(point.y)) > divergenceLimit }
}
