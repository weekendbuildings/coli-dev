import Foundation

/// A model's belief Q in three symbols A, B, C, against their true frequencies P. Its error is the true cross-entropy in
/// bits, and training is true gradient descent on softmax scores, whose gradient is simply q − p.
/// Вера модели Q в три символа против их настоящих частот P. Ошибка это настоящая кросс-энтропия в битах, а обучение это
/// настоящий градиентный спуск по оценкам softmax, градиент которого равен просто q − p.
struct CrossEntropyBowlModel: Equatable {
    enum Phase: Equatable {
        case ready, training, reachedBottom, outOfSteps
    }

    /// Fixed truths: a skewed one, a uniform one, and an almost certain one, from high to low entropy in a clear order.
    static let truths: [[Double]] = [[0.6, 0.3, 0.1], [1.0 / 3, 1.0 / 3, 1.0 / 3], [0.9, 0.05, 0.05]]
    static let uniformBelief: [Double] = [1.0 / 3, 1.0 / 3, 1.0 / 3]
    /// The drawing stops here: at a belief of 0 the true height is infinite. / Рисунок обрезан здесь: при вере 0 высота бесконечна.
    static let heightLimit = 4.0
    /// The smallest belief a click may place, so that the error stays finite.
    static let smallestBelief = 0.002
    static let rate = 1.0
    static let stepLimit = 300
    /// The bottom counts as reached within this many bits of the entropy.
    static let reachedGap = 0.01
    /// The task must start at least this high above the bottom: starting there teaches nothing.
    static let challengeStartGap = 1.0

    private(set) var truth: [Double]
    private(set) var start: [Double]
    private(set) var scores: [Double]
    private(set) var path: [[Double]]
    private(set) var history: [Double] = []

    init(truth: [Double] = Self.truths[0], belief: [Double] = Self.uniformBelief) {
        self.truth = truth
        let placed = Self.placed(belief)
        start = placed
        scores = placed.map { log($0) }
        path = [placed]
    }

    /// Keeps a belief a true distribution with no zeros. / Вера остаётся настоящим распределением без нулей.
    static func placed(_ belief: [Double]) -> [Double] {
        let raised = belief.map { max($0, smallestBelief) }
        let total = raised.reduce(0, +)
        return raised.map { $0 / total }
    }

    static func softmax(_ scores: [Double]) -> [Double] {
        let exponents = scores.map { exp($0) }
        let total = exponents.reduce(0, +)
        return exponents.map { $0 / total }
    }

    static func entropy(_ p: [Double]) -> Double {
        -p.filter { $0 > 0 }.map { $0 * log2($0) }.reduce(0, +)
    }

    static func crossEntropy(_ p: [Double], _ q: [Double]) -> Double {
        var total = 0.0
        for (a, b) in zip(p, q) where a > 0 { total -= a * log2(b) }
        return total
    }

    var belief: [Double] { Self.softmax(scores) }
    var error: Double { Self.crossEntropy(truth, belief) }
    var bottom: Double { Self.entropy(truth) }
    var gap: Double { error - bottom }
    var startGap: Double { Self.crossEntropy(truth, start) - bottom }
    var steps: Int { history.count }

    var phase: Phase {
        if gap <= Self.reachedGap { return .reachedBottom }
        if steps >= Self.stepLimit { return .outOfSteps }
        return steps == 0 ? .ready : .training
    }

    var isFinished: Bool { phase == .reachedBottom || phase == .outOfSteps }

    var solvesChallenge: Bool { phase == .reachedBottom && steps > 0 && startGap >= Self.challengeStartGap }

    /// One step: z ← z − η (q − p), since the gradient of cross-entropy over softmax scores is q − p (in nats).
    mutating func step() {
        guard !isFinished else { return }
        history.append(error)
        let q = belief
        for index in scores.indices { scores[index] -= Self.rate * (q[index] - truth[index]) }
        path.append(belief)
    }

    mutating func restart() { self = Self(truth: truth, belief: start) }
}
