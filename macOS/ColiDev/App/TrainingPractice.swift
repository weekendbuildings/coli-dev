import Foundation

/// A line fitted to the lesson's 24 points by mini-batch gradient descent. The numbers come from the lesson's generator,
/// so they match its program. / Прямая по 24 точкам урока, обучение мини-батчами. Числа совпадают с программой урока.
struct MinibatchLineModel: Equatable {
    static let batches = [1, 4, 8, 24]
    static let rateRange: ClosedRange<Double> = 0.02...0.2
    static let dataSeed = 31337
    static let shuffleSeed = 555
    static let start = (w: -2.5, b: 2.5)
    static let readLimit = 1500
    /// The target is this many times the best possible error. / Цель: столько раз лучшая возможная ошибка.
    static let targetRatio = 1.05
    /// The task: reach the target in less than this many reads, that is, within one pass over the data.
    static let challengeReads = 24

    /// The 24 points of the lesson. / 24 точки урока.
    static let points: [(x: Double, y: Double)] = {
        var state = dataSeed
        func next() -> Double {
            state = state * 16807 % 2147483647
            return Double(state) / 2147483647
        }
        return (0..<24).map { i in
            let x = -1.5 + 3 * Double(i) / 23
            let first = next(), second = next(), third = next()
            return (x, 1.2 * x + 0.5 + (first + second + third - 1.5) * 0.7)
        }
    }()

    /// The exact least-squares solution. / Точное решение метода наименьших квадратов.
    static let best: (w: Double, b: Double) = {
        let n = Double(points.count)
        let sx = points.map(\.x).reduce(0, +), sy = points.map(\.y).reduce(0, +)
        let sxx = points.map { $0.x * $0.x }.reduce(0, +), sxy = points.map { $0.x * $0.y }.reduce(0, +)
        let w = (n * sxy - sx * sy) / (n * sxx - sx * sx)
        return (w, (sy - w * sx) / n)
    }()

    static func loss(w: Double, b: Double) -> Double {
        points.map { ($0.x * w + b - $0.y) * ($0.x * w + b - $0.y) }.reduce(0, +) / Double(points.count)
    }

    static func slope(w: Double, b: Double) -> SIMD2<Double> {
        var total = SIMD2<Double>(0, 0)
        for point in points {
            let miss = 2 * (point.x * w + b - point.y)
            total += SIMD2(miss * point.x, miss)
        }
        return total / Double(points.count)
    }

    static var target: Double { loss(w: best.w, b: best.b) * targetRatio }

    private(set) var w = start.w
    private(set) var b = start.b
    private(set) var reads = 0
    private(set) var path: [(w: Double, b: Double)] = [start]
    private(set) var history: [(reads: Int, loss: Double)] = [(0, loss(w: start.w, b: start.b))]
    /// The gradient of the last batch, to compare with the true one. / Градиент последнего пакета.
    private(set) var batchSlope: SIMD2<Double>?
    private(set) var readsAtTarget: Int?
    private var order = Array(0..<24)
    private var cursor = 24
    private var state = shuffleSeed

    static func == (left: Self, right: Self) -> Bool { left.w == right.w && left.b == right.b && left.reads == right.reads }

    var loss: Double { Self.loss(w: w, b: b) }
    var isFinished: Bool { reads >= Self.readLimit }
    var trueSlope: SIMD2<Double> { Self.slope(w: w, b: b) }
    var solvesChallenge: Bool { (readsAtTarget ?? Int.max) <= Self.challengeReads }

    /// One step on one batch, reshuffling when an epoch ends, exactly as in the lesson's program.
    mutating func step(batch: Int, rate: Double) {
        guard !isFinished else { return }
        if cursor + batch > order.count {
            var i = order.count - 1
            while i > 0 {
                state = state * 16807 % 2147483647
                let j = Int(Double(state) / 2147483647 * Double(i + 1))
                order.swapAt(i, j)
                i -= 1
            }
            cursor = 0
        }
        var total = SIMD2<Double>(0, 0)
        for k in order[cursor..<(cursor + batch)] {
            let point = Self.points[k]
            let miss = 2 * (point.x * w + b - point.y)
            total += SIMD2(miss * point.x, miss)
        }
        cursor += batch
        let slope = total / Double(batch)
        batchSlope = slope
        w -= rate * slope.x
        b -= rate * slope.y
        reads += batch
        path.append((w, b))
        history.append((reads, loss))
        if readsAtTarget == nil, loss <= Self.target { readsAtTarget = reads }
    }
}

/// The lesson's model of 21 waves on 12 noisy points, with 40 held-out points. / Модель из 21 волны на 12 шумных точках и 40 отложенных.
struct WaveFitModel: Equatable {
    static let stepLimit = 600
    static let rate = 0.05
    static let seed = 2718
    static let waveCount = 21
    /// The task: at the end of training the held-out error is at most this. / Задание: отложенная ошибка в конце не выше этого.
    static let challengeHeldError = 0.35

    private static func generate() -> (train: [(x: Double, y: Double)], held: [(x: Double, y: Double)]) {
        var state = seed
        func next() -> Double {
            state = state * 16807 % 2147483647
            return Double(state) / 2147483647
        }
        func make(_ xs: [Double]) -> [(x: Double, y: Double)] {
            xs.map { x in
                let first = next(), second = next(), third = next()
                return (x, 1.2 * sin(1.5 * x) + (first + second + third - 1.5) * 0.9)
            }
        }
        let train = make((0..<12).map { -1.5 + 3 * Double($0) / 11 })
        let held = make((0..<40).map { -1.5 + 3 * (Double($0) + 0.5) / 40 })
        return (train, held)
    }

    static let data = generate()
    static let trainFeatures = data.train.map { features($0.x) }
    static let heldFeatures = data.held.map { features($0.x) }

    static func features(_ x: Double) -> [Double] {
        var wave = [1.0]
        for k in 1...10 {
            wave.append(cos(1.05 * Double(k) * x) / Double(k))
            wave.append(sin(1.05 * Double(k) * x) / Double(k))
        }
        return wave
    }

    let decay: Double
    private(set) var weights = [Double](repeating: 0, count: waveCount)
    private(set) var steps = 0
    private(set) var trainHistory: [Double]
    private(set) var heldHistory: [Double]
    private(set) var bestHeld: (error: Double, step: Int)

    init(decay: Double = 0) {
        self.decay = decay
        let zero = [Double](repeating: 0, count: Self.waveCount)
        let held = Self.error(zero, features: Self.heldFeatures, data: Self.data.held)
        trainHistory = [Self.error(zero, features: Self.trainFeatures, data: Self.data.train)]
        heldHistory = [held]
        bestHeld = (held, 0)
    }

    static func == (left: Self, right: Self) -> Bool { left.steps == right.steps && left.decay == right.decay && left.weights == right.weights }

    private static func error(_ weights: [Double], features: [[Double]], data: [(x: Double, y: Double)]) -> Double {
        var total = 0.0
        for (f, point) in zip(features, data) {
            var value = -point.y
            for i in f.indices { value += weights[i] * f[i] }
            total += value * value
        }
        return total / Double(data.count)
    }

    var trainError: Double { trainHistory.last ?? 0 }
    var heldError: Double { heldHistory.last ?? 0 }
    var isFinished: Bool { steps >= Self.stepLimit }
    var solvesChallenge: Bool { isFinished && heldError <= Self.challengeHeldError }

    func value(at x: Double) -> Double {
        var total = 0.0
        let f = Self.features(x)
        for i in f.indices { total += weights[i] * f[i] }
        return total
    }

    mutating func step() {
        guard !isFinished else { return }
        var slope = weights.map { 2 * decay * $0 }
        let share = 2 / Double(Self.data.train.count)
        for (f, point) in zip(Self.trainFeatures, Self.data.train) {
            var value = -point.y
            for i in f.indices { value += weights[i] * f[i] }
            for i in f.indices { slope[i] += share * value * f[i] }
        }
        for i in weights.indices { weights[i] -= Self.rate * slope[i] }
        steps += 1
        trainHistory.append(Self.error(weights, features: Self.trainFeatures, data: Self.data.train))
        let held = Self.error(weights, features: Self.heldFeatures, data: Self.data.held)
        heldHistory.append(held)
        if held < bestHeld.error { bestHeld = (held, steps) }
    }
}
