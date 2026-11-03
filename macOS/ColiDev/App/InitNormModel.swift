import Foundation

/// One look at a deep tanh network before training: how signals and gradients spread by layer.
/// Один взгляд на глубокую сеть tanh до обучения: как сигналы и градиенты расходятся по слоям.
struct InitNormRun: Equatable {
    let activationSpread: [Double]
    let gradientSize: [Double]
    /// Share of activations in each of the bins from −1 to 1, by layer. / Доля активаций в каждом интервале от −1 до 1 по слоям.
    let histograms: [[Double]]
}

enum InitNormModel {
    static let layers = 8
    static let width = 32
    static let batch = 16
    static let bins = 20

    private struct Generator {
        var state = 4242

        mutating func uniform() -> Double {
            state = state * 16807 % 2147483647
            return Double(state) / 2147483647
        }

        mutating func gauss() -> Double {
            let first = uniform()
            let second = uniform()
            return (-2 * log(first)).squareRoot() * cos(2 * Double.pi * second)
        }
    }

    private static func spread(_ rows: [[Double]]) -> Double {
        let values = rows.flatMap { $0 }
        let mean = values.reduce(0, +) / Double(values.count)
        return (values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)).squareRoot()
    }

    /// Same random numbers and order as the lesson's program. / Те же случайные числа и порядок, что в программе урока.
    static func run(scale: Double, normalized: Bool) -> InitNormRun {
        var generator = Generator()
        let deviation = scale / Double(width).squareRoot()
        var weights: [[[Double]]] = []
        for _ in 0..<layers {
            var layer: [[Double]] = []
            for _ in 0..<width {
                var row: [Double] = []
                for _ in 0..<width { row.append(generator.gauss() * deviation) }
                layer.append(row)
            }
            weights.append(layer)
        }
        var inputs: [[Double]] = []
        for _ in 0..<batch {
            var row: [Double] = []
            for _ in 0..<width { row.append(generator.gauss()) }
            inputs.append(row)
        }

        var outputs: [[[Double]]] = []
        var scores: [[[Double]]] = []
        var scales: [[Double]] = []
        var current = inputs
        for layer in weights {
            var rows: [[Double]] = []
            var layerScores: [[Double]] = []
            var layerScales: [Double] = []
            for sample in current {
                var z = [Double](repeating: 0, count: width)
                for i in 0..<width {
                    var total = 0.0
                    for j in 0..<width { total += layer[i][j] * sample[j] }
                    z[i] = total
                }
                var s = 1.0
                if normalized {
                    let mean = z.reduce(0, +) / Double(width)
                    s = (z.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(width)).squareRoot() + 1e-9
                    z = z.map { ($0 - mean) / s }
                }
                rows.append(z.map { tanh($0) })
                layerScores.append(z)
                layerScales.append(s)
            }
            outputs.append(rows)
            scores.append(layerScores)
            scales.append(layerScales)
            current = rows
        }

        var gradients = [Double](repeating: 0, count: layers)
        var back = [[Double]](repeating: [Double](repeating: 1, count: width), count: batch)
        for depth in stride(from: layers - 1, through: 0, by: -1) {
            var size = 0.0
            var next: [[Double]] = []
            for k in 0..<batch {
                let z = scores[depth][k]
                var g = [Double](repeating: 0, count: width)
                for i in 0..<width {
                    let t = tanh(z[i])
                    g[i] = back[k][i] * (1 - t * t)
                }
                if normalized {
                    let meanG = g.reduce(0, +) / Double(width)
                    var meanGZ = 0.0
                    for i in 0..<width { meanGZ += g[i] * z[i] }
                    meanGZ /= Double(width)
                    for i in 0..<width { g[i] = (g[i] - meanG - meanGZ * z[i]) / scales[depth][k] }
                }
                var row = [Double](repeating: 0, count: width)
                for j in 0..<width {
                    var total = 0.0
                    for i in 0..<width { total += weights[depth][i][j] * g[i] }
                    row[j] = total
                }
                let previous = depth > 0 ? outputs[depth - 1][k] : inputs[k]
                let squares = previous.reduce(0) { $0 + $1 * $1 }
                for i in 0..<width { size += g[i] * g[i] * squares }
                next.append(row)
            }
            gradients[depth] = (size / Double(batch * width * width)).squareRoot()
            back = next
        }

        let histograms: [[Double]] = outputs.map { rows in
            var counts = [Double](repeating: 0, count: bins)
            for value in rows.flatMap({ $0 }) {
                let index = min(max(Int((value + 1) / 2 * Double(bins)), 0), bins - 1)
                counts[index] += 1
            }
            return counts.map { $0 / Double(batch * width) }
        }
        return InitNormRun(activationSpread: outputs.map(spread), gradientSize: gradients, histograms: histograms)
    }

    /// All layers carry a signal, and the gradient neither fades nor swells across the depth.
    /// Все слои несут сигнал, а градиент по глубине не гаснет и не разбухает.
    static func isHealthy(_ run: InitNormRun) -> Bool {
        guard run.activationSpread.allSatisfy({ (0.2...0.9).contains($0) }), let first = run.gradientSize.first, let last = run.gradientSize.last else { return false }
        let ratio = max(first, last) / max(min(first, last), 1e-12)
        return ratio <= 3
    }
}
