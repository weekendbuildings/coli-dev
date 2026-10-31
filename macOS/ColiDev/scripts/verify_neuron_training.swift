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
        print("Neuron training model checks passed.")
    }
}
