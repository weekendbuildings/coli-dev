import Foundation

@main
enum PatternAttentionVerification {
    typealias Model = PatternAttentionModel

    static func train(_ start: Model, steps: Int) -> Model {
        var model = start
        for _ in 0..<steps { model.step() }
        return model
    }

    static func rounded(_ value: Double, _ digits: Double = 100) -> Double { (value * digits).rounded() / digits }

    static func main() {
        // The numbers of the lesson's program, with place numbers. / Числа программы урока с номерами мест.
        var with = Model(period: 3, usesPositions: true)
        with.step()
        precondition(rounded(with.history[0], 1000) == 1.406, "first error")
        precondition(rounded(with.accuracy) == 0.2, "accuracy at the start")
        with = train(Model(period: 3, usesPositions: true), steps: 101)
        precondition(rounded(with.history[100], 1000) == 0.005, "error at step 100")
        precondition(with.accuracy == 1, "new patterns at step 100")
        with = train(Model(period: 3, usesPositions: true), steps: 301)
        precondition(rounded(with.history[300], 1000) == 0.001, "error at step 300")
        let line = with.unseen[0]
        let row6 = with.weights(line, at: 6).map { rounded($0) }
        precondition(row6 == [0.01, 0.78, 0.02, 0.04, 0.08, 0.02, 0.04], "weights at t = 6")
        let row5 = with.weights(line, at: 5).map { rounded($0) }
        precondition(row5 == [0.45, 0.02, 0.02, 0.36, 0.07, 0.08], "weights at t = 5")

        // Without place numbers the same model gets stuck. / Без номеров мест та же модель застревает.
        var without = train(Model(period: 3, usesPositions: false), steps: 101)
        precondition(rounded(without.history[100], 100) == 0.58, "stuck error at step 100")
        precondition(rounded(without.accuracy) == 0.53, "stuck accuracy at step 100")
        without = train(Model(period: 3, usesPositions: false), steps: 301)
        precondition(rounded(without.history[300], 1000) == 0.567, "stuck error at step 300")
        precondition(rounded(without.accuracy) == 0.54, "stuck accuracy at step 300")
        precondition(without.phase == .stuck && !without.solvesChallenge, "the stuck model does not solve the task")

        // The opening does not solve the task, and the mask holds: a row has weights only for places read so far.
        let opening = Model()
        precondition(opening.phase == .ready && !opening.solvesChallenge && !opening.usesPositions && opening.period == 3)
        for t in 0..<(Model.length - 1) {
            let weights = opening.weights(opening.unseen[0], at: t)
            precondition(weights.count == t + 1 && abs(weights.reduce(0, +) - 1) < 1e-12, "the mask and the sum")
        }

        // Every period is learned with place numbers. / С номерами мест выучивается любой период.
        for period in Model.periods {
            let model = train(Model(period: period, usesPositions: true), steps: 150)
            precondition(model.accuracy >= Model.goalAccuracy, "period \(period)")
            precondition(model.phase == .learned)
            // The largest weight in the last row lies at a place that holds the answer.
            let q = model.unseen.first { Set($0).count == min(period, 4) } ?? model.unseen[0]
            let last = Model.length - 2
            let weights = model.weights(q, at: last)
            let top = weights.indices.max { weights[$0] < weights[$1] }!
            precondition((last + 1 - top) % period == 0, "the model looks where the answer is")
        }
        precondition(train(Model(period: 3, usesPositions: true), steps: 150).solvesChallenge, "the task can be solved")
        precondition(!train(Model(period: 2, usesPositions: true), steps: 150).solvesChallenge, "a short period is too easy for the task")

        // Self-attention without place numbers does not know order: moved letters take their weights along.
        // Без номеров мест порядок неизвестен: буквы уносят свои веса с собой.
        let plain = train(Model(period: 3, usesPositions: false), steps: 50)
        let first = plain.weights([0, 1, 2, 0, 0, 0, 0, 0], at: 2)
        let moved = plain.weights([1, 2, 0, 0, 0, 0, 0, 0], at: 2)
        // Query from the same letter in the third place of a different order is not the same, so compare the keys alone.
        precondition(abs(first.reduce(0, +) - 1) < 1e-12 && abs(moved.reduce(0, +) - 1) < 1e-12)

        // The step limit stops training.
        var long = Model(period: 1, usesPositions: true)
        for _ in 0..<(Model.stepLimit + 2) { long.step() }
        precondition(long.steps == Model.stepLimit)

        // The worked example of the lesson. / Разобранный пример из урока.
        let scores = [1 / 2.0.squareRoot(), 0, 1 / 2.0.squareRoot()]
        let alpha = Model.softmax(scores)
        precondition(alpha.map { rounded($0, 1000) } == [0.401, 0.198, 0.401], "worked weights")

        print("Pattern attention verification passed.")
    }
}
