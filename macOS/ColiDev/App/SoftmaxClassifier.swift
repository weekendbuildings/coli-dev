import Foundation

/// A real softmax classifier on two inputs with three classes: three scores, each a weighted sum of the inputs, trained by
/// gradient descent on cross-entropy, with the gradient (q − p) · x from the lesson.
/// Настоящий softmax-классификатор: три оценки, каждая взвешенная сумма входов, обучается спуском по кросс-энтропии.
struct SoftmaxClassifierModel: Equatable {
    struct Sample: Equatable {
        let x1: Double
        let x2: Double
        let label: Int
    }

    enum DataSet: Int, CaseIterable, Equatable {
        case clouds, xor

        /// The clouds are the lesson's twelve points. XOR needs two classes, so the third stays empty.
        var samples: [Sample] {
            switch self {
            case .clouds:
                return [
                    Sample(x1: -1.0, x2: -0.6, label: 0), Sample(x1: -0.7, x2: -1.0, label: 0), Sample(x1: -1.1, x2: -1.0, label: 0), Sample(x1: -0.6, x2: -0.5, label: 0),
                    Sample(x1: 1.0, x2: -0.7, label: 1), Sample(x1: 0.7, x2: -1.0, label: 1), Sample(x1: 1.1, x2: -0.3, label: 1), Sample(x1: 0.6, x2: -0.5, label: 1),
                    Sample(x1: 0.0, x2: 1.0, label: 2), Sample(x1: -0.4, x2: 0.7, label: 2), Sample(x1: 0.4, x2: 0.8, label: 2), Sample(x1: 0.1, x2: 0.5, label: 2)
                ]
            case .xor:
                return [
                    Sample(x1: -1, x2: -1, label: 0), Sample(x1: -0.8, x2: -1, label: 0), Sample(x1: 1, x2: 1, label: 0), Sample(x1: 0.8, x2: 1, label: 0),
                    Sample(x1: -1, x2: 1, label: 1), Sample(x1: -0.8, x2: 1, label: 1), Sample(x1: 1, x2: -1, label: 1), Sample(x1: 0.8, x2: -1, label: 1)
                ]
            }
        }
    }

    enum Phase: Equatable {
        case ready, training, stalled, flewOff, outOfSteps
    }

    static let classCount = 3
    static let domain: ClosedRange<Double> = -1.6...1.6
    static let rateExponents: ClosedRange<Double> = -1...2
    static let stepLimit = 400
    /// The task: from zero weights, the clean clouds below this error within this many steps.
    static let challengeLoss = 0.2
    static let challengeSteps = 40
    /// Above this error, training has made the model worse than guessing among all three classes by far.
    static let flewOffLoss = 2.0
    static let stallChange = 2e-4
    static let stallWindow = 20

    private(set) var dataSet: DataSet
    private(set) var samples: [Sample]
    private(set) var weights: [[Double]]
    private(set) var history: [Double] = []
    private(set) var addedPoints = 0
    private var stallCheckStart = 0

    init(dataSet: DataSet = .clouds) {
        self.dataSet = dataSet
        samples = dataSet.samples
        weights = Array(repeating: [0, 0, 0], count: Self.classCount)
    }

    /// Softmax, computed from differences with the largest score, so that huge scores cannot overflow.
    static func softmax(_ scores: [Double]) -> [Double] {
        let top = scores.max() ?? 0
        let powers = scores.map { exp($0 - top) }
        let total = powers.reduce(0, +)
        return powers.map { $0 / total }
    }

    func scores(x1: Double, x2: Double) -> [Double] {
        weights.map { $0[0] * x1 + $0[1] * x2 + $0[2] }
    }

    func probabilities(x1: Double, x2: Double) -> [Double] {
        Self.softmax(scores(x1: x1, x2: x2))
    }

    func prediction(x1: Double, x2: Double) -> Int {
        let q = probabilities(x1: x1, x2: x2)
        return q.indices.max { q[$0] < q[$1] } ?? 0
    }

    /// The confidence: the probability of the chosen class. / Уверенность: вероятность выбранного класса.
    func confidence(x1: Double, x2: Double) -> Double {
        probabilities(x1: x1, x2: x2).max() ?? 0
    }

    /// The slope of the confidence, by the chain rule on softmax: ∂q_m/∂x = q_m (w_m − Σ q_j w_j).
    func confidenceSlope(x1: Double, x2: Double) -> SIMD2<Double> {
        let q = probabilities(x1: x1, x2: x2)
        let m = q.indices.max { q[$0] < q[$1] } ?? 0
        var mean = SIMD2<Double>(0, 0)
        for k in q.indices { mean += SIMD2(weights[k][0], weights[k][1]) * q[k] }
        return (SIMD2(weights[m][0], weights[m][1]) - mean) * q[m]
    }

    func isCorrect(_ sample: Sample) -> Bool { prediction(x1: sample.x1, x2: sample.x2) == sample.label }

    var loss: Double {
        var total = 0.0
        for sample in samples { total -= log(max(probabilities(x1: sample.x1, x2: sample.x2)[sample.label], 1e-300)) }
        return total / Double(samples.count)
    }

    var correctCount: Int { samples.filter(isCorrect).count }
    var steps: Int { history.count }

    var phase: Phase {
        if !loss.isFinite || loss > Self.flewOffLoss { return .flewOff }
        if steps >= Self.stepLimit { return .outOfSteps }
        if steps - stallCheckStart >= Self.stallWindow, abs(history[steps - Self.stallWindow] - loss) < Self.stallChange { return .stalled }
        return steps == 0 ? .ready : .training
    }

    var isFinished: Bool { phase == .flewOff || phase == .outOfSteps }

    var solvesChallenge: Bool {
        dataSet == .clouds && addedPoints == 0 && steps > 0 && steps <= Self.challengeSteps && loss < Self.challengeLoss
    }

    /// The mean gradient (q − p) · (x₁, x₂, 1) over the samples.
    var gradient: [[Double]] {
        var total: [[Double]] = Array(repeating: [0, 0, 0], count: Self.classCount)
        let share = 1 / Double(samples.count)
        for sample in samples {
            let q = probabilities(x1: sample.x1, x2: sample.x2)
            for k in 0..<Self.classCount {
                let difference = q[k] - (k == sample.label ? 1 : 0)
                total[k][0] += difference * sample.x1 * share
                total[k][1] += difference * sample.x2 * share
                total[k][2] += difference * share
            }
        }
        return total
    }

    mutating func step(rate: Double) {
        guard !isFinished else { return }
        history.append(loss)
        let slope = gradient
        for k in 0..<Self.classCount {
            for i in 0..<3 { weights[k][i] -= rate * slope[k][i] }
        }
    }

    /// A new point with a chosen class. The weights stay, so the learner sees how the old model copes with it.
    mutating func add(_ sample: Sample) {
        samples.append(sample)
        addedPoints += 1
        stallCheckStart = steps
    }

    mutating func resume() { stallCheckStart = steps }

    /// Sets the weights directly, for the numerical check of the gradient. / Задаёт веса напрямую для численной проверки градиента.
    mutating func replaceWeights(_ newWeights: [[Double]]) { weights = newWeights }

    mutating func restart() { self = Self(dataSet: dataSet) }

    static func rate(exponent: Double) -> Double { pow(10, exponent) }
}
