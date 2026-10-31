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
