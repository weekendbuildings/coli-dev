import Foundation

/// One linear neuron y = w·x + b trained by gradient descent on the squared error L = (y − t)²,
/// as in the programming backpropagation lesson (Goodfellow, Bengio, Courville, Deep Learning, ch. 4 and 6).
/// For one example the error shrinks by the factor (1 − 2η(x² + 1)) per step, so training is stable
/// only while that factor stays between −1 and 1.
struct NeuronTrainingModel: Equatable {
    static let input = 2.0
    static let target = 2.0
    static let startWeight = 0.5
    static let startBias = 0.0
    static let learningRateRange = 0.01...0.3

    var weight = startWeight
    var bias = startBias
    var lossHistory: [Double] = []

    var output: Double { weight * Self.input + bias }
    var loss: Double { (output - Self.target) * (output - Self.target) }
    var weightGradient: Double { 2 * (output - Self.target) * Self.input }
    var biasGradient: Double { 2 * (output - Self.target) }

    /// One gradient descent step; records the loss before the update, as the lesson's program prints it.
    mutating func step(learningRate: Double) {
        lossHistory.append(loss)
        let gradW = weightGradient
        let gradB = biasGradient
        weight -= learningRate * gradW
        bias -= learningRate * gradB
    }

    mutating func reset() {
        self = NeuronTrainingModel()
    }

    /// The factor by which the error y − t is multiplied each step.
    static func errorFactor(learningRate: Double) -> Double {
        1 - 2 * learningRate * (input * input + 1)
    }

    /// The largest learning rate that does not grow or keep the error: |factor| < 1.
    static var stableLearningRateLimit: Double { 1 / (input * input + 1) }

    enum Regime: Equatable {
        case converging, oscillating, diverging
    }

    static func regime(learningRate: Double) -> Regime {
        let factor = abs(errorFactor(learningRate: learningRate))
        if factor < 1 - 1e-9 { return .converging }
        if factor <= 1 + 1e-9 { return .oscillating }
        return .diverging
    }
}

/// A small network learning XOR by gradient descent on the mean squared error, as in the programming lesson on the
/// hidden layer: either one sigmoid neuron y = σ(w₁x₁ + w₂x₂ + b), or two hidden sigmoid neurons feeding one output
/// neuron. The chain rule with σ′ = σ(1 − σ) gives the gradients (Dive into Deep Learning; CS231n notes).
struct XORNetworkModel: Equatable {
    enum Architecture: Hashable {
        case singleNeuron, hiddenLayer
    }

    enum Start: Hashable {
        /// Learns all four answers in about 800 iterations at η = 1; h₁ comes to resemble OR and h₂ NAND.
        case first
        /// Different weights that stall near a mean error of 1/6 at η = 1.
        case plateau
        /// Identical hidden neurons, which get identical gradients and stay copies.
        case identical

        /// In the lesson's order: w₁₁, w₁₂, b₁, w₂₁, w₂₂, b₂, v₁, v₂, c.
        var weights: [Double] {
            switch self {
            case .first: return [0.7, 0.7, 0.6, 0.1, -0.9, 0.5, 0.7, 0.7, -0.9]
            case .plateau: return [0.2, -0.7, -0.5, 0.8, 0.9, -0.9, -0.6, -0.1, -0.5]
            case .identical: return [0.5, 0.5, -0.2, 0.5, 0.5, -0.2, 0.5, 0.5, -0.2]
            }
        }
    }

    enum Phase: Equatable {
        case training, singleNeuronLimit, learned, plateau
    }

    struct Output: Equatable {
        var firstHidden: Double
        var secondHidden: Double
        var answer: Double
    }

    struct Example: Equatable {
        var x1: Double
        var x2: Double
        var target: Double
    }

    static let examples = [
        Example(x1: 0, x2: 0, target: 0), Example(x1: 0, x2: 1, target: 1),
        Example(x1: 1, x2: 0, target: 1), Example(x1: 1, x2: 1, target: 0)
    ]
    static let singleNeuronStart = [0.5, -0.5, 0.2]
    /// The best a single neuron can do: 0.5 for every input, so a mean squared error of 0.25.
    static let singleNeuronLimit = 0.25
    static let learningRateRange = 0.1...5.0
    static let iterationLimit = 5000
    static let iterationsPerFrame = 25
    /// An answer counts as correct when it is this close to the target, so that a shrugged 0.5 does not count.
    static let correctTolerance = 0.3

    let architecture: Architecture
    let start: Start
    /// w₁, w₂, b for a single neuron; the nine weights of `Start.weights` for the hidden layer.
    var weights: [Double]
    /// The mean error before each iteration so far.
    var lossHistory: [Double] = []

    init(architecture: Architecture = .hiddenLayer, start: Start = .first) {
        self.architecture = architecture
        self.start = start
        weights = architecture == .singleNeuron ? Self.singleNeuronStart : start.weights
    }

    var iterations: Int { lossHistory.count }

    static func sigmoid(_ z: Double) -> Double { 1 / (1 + exp(-z)) }

    func forward(_ x1: Double, _ x2: Double) -> Output {
        let w = weights
        if architecture == .singleNeuron {
            return Output(firstHidden: 0, secondHidden: 0, answer: Self.sigmoid(w[0] * x1 + w[1] * x2 + w[2]))
        }
        let first = Self.sigmoid(w[0] * x1 + w[1] * x2 + w[2])
        let second = Self.sigmoid(w[3] * x1 + w[4] * x2 + w[5])
        return Output(firstHidden: first, secondHidden: second, answer: Self.sigmoid(w[6] * first + w[7] * second + w[8]))
    }

    var loss: Double {
        Self.examples.reduce(0) { total, example in
            let error = forward(example.x1, example.x2).answer - example.target
            return total + error * error
        } / Double(Self.examples.count)
    }

    /// The mean gradient over the four examples, by the chain rule from the output back to the inputs.
    var gradient: [Double] {
        var total = [Double](repeating: 0, count: weights.count)
        let w = weights
        for example in Self.examples {
            let output = forward(example.x1, example.x2)
            let y = output.answer
            let out = 2 * (y - example.target) * y * (1 - y)
            let parts: [Double]
            if architecture == .singleNeuron {
                parts = [out * example.x1, out * example.x2, out]
            } else {
                let h1 = output.firstHidden, h2 = output.secondHidden
                let back1 = out * w[6] * h1 * (1 - h1)
                let back2 = out * w[7] * h2 * (1 - h2)
                parts = [back1 * example.x1, back1 * example.x2, back1,
                         back2 * example.x1, back2 * example.x2, back2,
                         out * h1, out * h2, out]
            }
            for index in total.indices { total[index] += parts[index] / Double(Self.examples.count) }
        }
        return total
    }

    mutating func step(learningRate: Double) {
        lossHistory.append(loss)
        let slope = gradient
        for index in weights.indices { weights[index] -= learningRate * slope[index] }
    }

    static func isCorrect(answer: Double, target: Double) -> Bool { abs(answer - target) < correctTolerance }

    var correctAnswers: Int {
        Self.examples.filter { Self.isCorrect(answer: forward($0.x1, $0.x2).answer, target: $0.target) }.count
    }

    var phase: Phase {
        if architecture == .singleNeuron {
            return iterations >= 200 && abs(loss - Self.singleNeuronLimit) < 0.001 ? .singleNeuronLimit : .training
        }
        if correctAnswers == Self.examples.count { return .learned }
        // A plateau is what the learner sees: the error is high and has barely moved over the last 500 iterations.
        if iterations >= 1000, loss > 0.1, abs(lossHistory[iterations - 500] - loss) < 0.001 { return .plateau }
        return .training
    }
}
