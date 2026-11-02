import Foundation

/// The lesson's stack of layers, x → tanh(W x), with or without the bypass x + tanh(W x), and a true backward pass that
/// measures how much of the error reaches each layer. The start comes from the lesson's generator, so the numbers match it.
/// Стопка слоёв из урока, с обходом или без него, и настоящий обратный проход: сколько ошибки доходит до каждого слоя.
/// Начало задаёт генератор из урока, поэтому числа совпадают с ним.
struct GradientStackModel: Equatable {
    static let size = 8
    static let gain = 0.25
    static let seed = 99
    static let depths: ClosedRange<Int> = 2...16
    /// The task: at this depth or more, the signal at the bottom stays between these bounds.
    static let challengeDepth = 12
    static let keptSignal: ClosedRange<Double> = 0.1...10

    let depth: Int
    let bypass: Bool
    let layers: [[[Double]]]
    let start: [Double]
    /// The size of the signal after each layer on its way down: the first is the top layer, the last is the bottom one.
    let signalSizes: [Double]

    init(depth: Int = 12, bypass: Bool = false) {
        self.depth = depth
        self.bypass = bypass
        var state = Self.seed
        func next() -> Double {
            state = state * 16807 % 2147483647
            return Double(state) / 2147483647 - 0.5
        }
        var built: [[[Double]]] = []
        for _ in 0..<depth {
            var layer: [[Double]] = []
            for _ in 0..<Self.size {
                var row: [Double] = []
                for _ in 0..<Self.size { row.append(Self.gain * 2 * next()) }
                layer.append(row)
            }
            built.append(layer)
        }
        var first: [Double] = []
        for _ in 0..<Self.size { first.append(next()) }
        layers = built
        start = first
        signalSizes = Self.signal(layers: built, start: first, bypass: bypass).sizes
    }

    private static func apply(_ matrix: [[Double]], _ vector: [Double]) -> [Double] {
        matrix.map { row in
            var total = 0.0
            for i in row.indices { total += row[i] * vector[i] }
            return total
        }
    }

    /// The forward pass, keeping the input of each layer. / Прямой проход с сохранением входа каждого слоя.
    static func forward(layers: [[[Double]]], start: [Double], bypass: Bool) -> (output: [Double], states: [[Double]]) {
        var x = start
        var states: [[Double]] = []
        for layer in layers {
            states.append(x)
            let y = apply(layer, x).map { tanh($0) }
            x = bypass ? zip(x, y).map { $0 + $1 } : y
        }
        return (x, states)
    }

    /// The backward pass from the first number of the top layer. / Обратный проход от первого числа верхнего слоя.
    static func signal(layers: [[[Double]]], start: [Double], bypass: Bool) -> (gradient: [Double], sizes: [Double]) {
        let states = forward(layers: layers, start: start, bypass: bypass).states
        var g = [Double](repeating: 0, count: size)
        g[0] = 1
        var sizes: [Double] = []
        for (layer, before) in zip(layers.reversed(), states.reversed()) {
            let slopes = apply(layer, before).map { 1 - tanh($0) * tanh($0) }
            var back = [Double](repeating: 0, count: size)
            for c in 0..<size {
                for r in 0..<size { back[c] += layer[r][c] * slopes[r] * g[r] }
            }
            g = bypass ? zip(g, back).map { $0 + $1 } : back
            sizes.append(g.map { $0 * $0 }.reduce(0, +).squareRoot())
        }
        return (g, sizes)
    }

    var bottomSignal: Double { signalSizes.last ?? 1 }

    var solvesChallenge: Bool { depth >= Self.challengeDepth && Self.keptSignal.contains(bottomSignal) }
}
