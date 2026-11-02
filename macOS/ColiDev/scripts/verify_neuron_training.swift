import Foundation

@main
enum NeuronTrainingVerification {
    static func close(_ a: Double, _ b: Double) -> Bool { abs(a - b) < 1e-9 }

    static func main() {
        // The lesson's program: η = 0.05 gives losses 1, 0.25, 0.0625 and w = 0.7, b = 0.1 after one step.
        var model = NeuronTrainingModel()
        precondition(close(model.output, 1) && close(model.loss, 1))
        precondition(close(model.weightGradient, -4) && close(model.biasGradient, -2))
        model.step(learningRate: 0.05)
        precondition(close(model.weight, 0.7) && close(model.bias, 0.1), "first step from the lesson")
        model.step(learningRate: 0.05)
        model.step(learningRate: 0.05)
        precondition(zip(model.lossHistory, [1, 0.25, 0.0625]).allSatisfy { close($0, $1) }, "printed losses")

        // The error factor explains every regime.
        precondition(close(NeuronTrainingModel.errorFactor(learningRate: 0.05), 0.5))
        precondition(close(NeuronTrainingModel.stableLearningRateLimit, 0.2))
        precondition(NeuronTrainingModel.regime(learningRate: 0.05) == .converging)
        precondition(NeuronTrainingModel.regime(learningRate: 0.2) == .oscillating)
        precondition(NeuronTrainingModel.regime(learningRate: 0.3) == .diverging)

        var oscillating = NeuronTrainingModel()
        for _ in 0..<4 { oscillating.step(learningRate: 0.2) }
        precondition(oscillating.lossHistory.allSatisfy { close($0, 1) }, "η = 0.2 keeps the loss at 1")

        var diverging = NeuronTrainingModel()
        for _ in 0..<3 { diverging.step(learningRate: 0.3) }
        precondition(zip(diverging.lossHistory, [1, 4, 16]).allSatisfy { close($0, $1) }, "η = 0.3 quadruples the loss")

        var oneStep = NeuronTrainingModel()
        oneStep.step(learningRate: 0.1)
        precondition(close(oneStep.loss, 0), "η = 0.1 reaches the target in one step for this example")

        model.reset()
        precondition(model == NeuronTrainingModel())
        verifyXORNetwork()
        print("Neuron training model checks passed.")
    }

    private static func verifyXORNetwork() {
        func trained(_ architecture: XORNetworkModel.Architecture, _ start: XORNetworkModel.Start = .first, iterations: Int) -> XORNetworkModel {
            var model = XORNetworkModel(architecture: architecture, start: start)
            for _ in 0..<iterations { model.step(learningRate: 1) }
            return model
        }
        func near(_ a: Double, _ b: Double, _ tolerance: Double) -> Bool { abs(a - b) <= tolerance }

        // The lesson's program prints these mean errors, and the worked example's first answer is y ≈ 0.525.
        precondition(near(XORNetworkModel().loss, 0.2483, 5e-5))
        precondition(near(XORNetworkModel().forward(1, 0).answer, 0.525, 5e-4))
        precondition(near(trained(.hiddenLayer, iterations: 500).loss, 0.1734, 5e-5))
        precondition(near(trained(.hiddenLayer, iterations: 1000).loss, 0.0272, 5e-5))
        let learned = trained(.hiddenLayer, iterations: 3000)
        precondition(near(learned.loss, 0.0026, 5e-5) && learned.correctAnswers == 4 && learned.phase == .learned)
        // h₁ comes to resemble OR and h₂ NAND; nothing told the network to do that.
        let hidden = XORNetworkModel.examples.map { learned.forward($0.x1, $0.x2) }
        precondition(hidden.map { $0.firstHidden.rounded() } == [0, 1, 1, 1])
        precondition(hidden.map { $0.secondHidden.rounded() } == [1, 1, 1, 0])

        // The chain-rule gradient agrees with a numerical one, for both architectures.
        for model in [XORNetworkModel(architecture: .hiddenLayer), XORNetworkModel(architecture: .singleNeuron)] {
            for index in model.weights.indices {
                var shifted = model
                shifted.weights[index] += 1e-6
                precondition(near((shifted.loss - model.loss) / 1e-6, model.gradient[index], 1e-5))
            }
        }

        // One neuron stops at 0.5 for everything; it is never learned, whatever the iterations.
        let single = trained(.singleNeuron, iterations: 1000)
        precondition(near(single.loss, XORNetworkModel.singleNeuronLimit, 1e-3) && single.phase == .singleNeuronLimit)
        precondition(single.correctAnswers == 0)
        precondition(XORNetworkModel(architecture: .singleNeuron).phase == .training)

        // Start 2 stalls on a plateau near 1/6 within the lab's iteration limit.
        let plateau = trained(.hiddenLayer, .plateau, iterations: XORNetworkModel.iterationLimit)
        precondition(near(plateau.loss, 1.0 / 6, 0.005) && plateau.correctAnswers < 4 && plateau.phase == .plateau)

        // Identical hidden neurons stay exact copies and never learn all four answers.
        let identical = trained(.hiddenLayer, .identical, iterations: XORNetworkModel.iterationLimit)
        precondition(identical.weights[0] == identical.weights[3] && identical.weights[1] == identical.weights[4])
        precondition(identical.weights[2] == identical.weights[5] && identical.weights[6] == identical.weights[7])
        precondition(identical.correctAnswers < 4 && identical.phase == .plateau)

        // The lab's challenge cannot start solved: the opening neuron has not stalled or learned anything.
        precondition(XORNetworkModel(architecture: .hiddenLayer).correctAnswers < 4)
    }
}
